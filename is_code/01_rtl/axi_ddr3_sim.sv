// axi_ddr3_sim.sv
//
// Behavior-level AXI DDR3 simulation module (read-only).
// - Command FIFO + Scheduler + Data FIFO
// - Memory initialized from INIT_FILE using $readmemh
// - Supports burst reads, alignment check, backpressure via RREADY
//
// 注意：为简洁起见，此版本假设 AXI 地址为字节寻址，且 DATA_WIDTH 为 2^N * 8（如256bit=32bytes）
// 初始化文件格式：使用 $readmemh，文件中每行代表一个 DATA_WIDTH 宽度单元（hex），
// 例如 256-bit 的一行需要 64 hex 字符。不匹配时自行调整读入方式。

module axi_ddr3_sim #(
    parameter ID_WIDTH   = 4,
    parameter DATA_WIDTH = 256,
    parameter ADDR_WIDTH = 32,
    // other params provided by user context:
    // SLICE_NUM and MEM_DEPTH computed externally in instantiation
    parameter SLICE_NUM = (`CFG_VEC_WIDTH + DATA_WIDTH - 1) / DATA_WIDTH,           //向上取整
    parameter MEM_DEPTH  = `CFG_LIB_VEC_NUM * SLICE_NUM,  // 存储深度，单位：DATA_WIDTH bits
    parameter INIT_FILE  = `CFG_LIB_VEC_FILE,  // 初始化文件路径
    // FIFO depths and latency (tunable)
    parameter integer CMD_FIFO_DEPTH   = 16,
    parameter integer DATA_FIFO_DEPTH  = 128,
    parameter integer CMD2DATA_LATENCY = 12      // cycles from command pop -> first data ready
) (
    input  wire                     ACLK,
    input  wire                     ARESETN,

    // ------------------ AXI Read Address Channel ------------------
    input  wire [ADDR_WIDTH-1:0]    S_AXI_araddr,
    input  wire [1:0]               S_AXI_arburst,
    input  wire [3:0]               S_AXI_arcache,
    input  wire [ID_WIDTH-1:0]      S_AXI_arid,
    input  wire [7:0]               S_AXI_arlen,
    input  wire [1:0]               S_AXI_arlock,
    input  wire [2:0]               S_AXI_arprot,
    input  wire [3:0]               S_AXI_arqos,
    output reg                      S_AXI_arready,
    input  wire [2:0]               S_AXI_arsize,
    input  wire                     S_AXI_arvalid,

    // ------------------ AXI Read Data Channel ------------------
    output reg [ID_WIDTH-1:0]       S_AXI_rid,
    output reg [DATA_WIDTH-1:0]     S_AXI_rdata,
    output reg                      S_AXI_rlast,
    input  wire                     S_AXI_rready,
    output reg [1:0]                S_AXI_rresp,
    output reg                      S_AXI_rvalid,

    // ------------------ AXI Write Channel (未实现) ------------------
    input  wire [ADDR_WIDTH-1:0]    S_AXI_awaddr,
    input  wire [1:0]               S_AXI_awburst,
    input  wire [3:0]               S_AXI_awcache,
    input  wire [ID_WIDTH-1:0]      S_AXI_awid,
    input  wire [7:0]               S_AXI_awlen,
    input  wire [1:0]               S_AXI_awlock,
    input  wire [2:0]               S_AXI_awprot,
    input  wire [3:0]               S_AXI_awqos,
    output wire                     S_AXI_awready,
    input  wire [2:0]               S_AXI_awsize,
    input  wire                     S_AXI_awvalid,
    output wire [ID_WIDTH-1:0]      S_AXI_bid,
    input  wire                     S_AXI_bready,
    output wire [1:0]               S_AXI_bresp,
    output wire                     S_AXI_bvalid,
    input  wire [DATA_WIDTH-1:0]    S_AXI_wdata,
    input  wire                     S_AXI_wlast,
    output wire                     S_AXI_wready,
    input  wire [(DATA_WIDTH/8)-1:0] S_AXI_wstrb,
    input  wire                     S_AXI_wvalid
);

    // ----------------------------------------------------------------
    // Local parameters and helpers
    // ----------------------------------------------------------------
    localparam integer BYTES_PER_BEAT = DATA_WIDTH/8;
    localparam integer BEAT_SHIFT = $clog2(BYTES_PER_BEAT); // shift to convert byte addr -> mem index
    localparam integer CMD_PTR_W = $clog2(CMD_FIFO_DEPTH);
    localparam integer DATA_PTR_W = $clog2(DATA_FIFO_DEPTH);

    // AXI RRESP encoding
    localparam [1:0] RRESP_OKAY  = 2'b00;
    localparam [1:0] RRESP_EXOK  = 2'b01;
    localparam [1:0] RRESP_SLVERR = 2'b10;
    localparam [1:0] RRESP_DECERR = 2'b11;

    // ----------------------------------------------------------------
    // Behavior memory (initialized from INIT_FILE)
    // ----------------------------------------------------------------
    // memory element width = DATA_WIDTH
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    initial begin
        // try to read mem file; user must ensure formatting matches DATA_WIDTH
        // each line -> one DATA_WIDTH word in hex (for $readmemh)
        $display("[%0t] axi_ddr3_sim: loading memory file %s", $time, INIT_FILE);
        $readmemh(INIT_FILE, mem);
    end

    // ----------------------------------------------------------------
    // Command FIFO: store incoming AR requests
    // Fields: addr, id, len, size, burst
    // ----------------------------------------------------------------
    typedef struct packed {
        logic [ADDR_WIDTH-1:0] addr;
        logic [ID_WIDTH-1:0]   id;
        logic [7:0]            len;    // ARLEN
        logic [2:0]            size;   // ARSIZE
        logic [1:0]            burst;  // ARBURST
    } cmd_t;

    cmd_t cmd_fifo [CMD_FIFO_DEPTH];
    reg [CMD_PTR_W:0] cmd_wr_ptr, cmd_rd_ptr; // one-hot depth encoding by pointer distance
    reg [CMD_PTR_W:0] cmd_count;

    wire cmd_fifo_full = (cmd_count == CMD_FIFO_DEPTH);
    wire cmd_fifo_empty = (cmd_count == 0);

    // ----------------------------------------------------------------
    // Data FIFO: store ready-to-output beats
    // Fields: data, id, last
    // ----------------------------------------------------------------
    typedef struct packed {
        logic [DATA_WIDTH-1:0] data;
        logic [ID_WIDTH-1:0]   id;
        logic                  last;
        logic [1:0]            resp; // response for this beat (OKAY/SLVERR)
    } beat_t;

    beat_t data_fifo [DATA_FIFO_DEPTH];
    reg [DATA_PTR_W:0] data_wr_ptr, data_rd_ptr;
    reg [DATA_PTR_W:0] data_count;

    wire data_fifo_full = (data_count == DATA_FIFO_DEPTH);
    wire data_fifo_empty = (data_count == 0);

    // ----------------------------------------------------------------
    // cycle counter for scheduling
    // ----------------------------------------------------------------
    reg [31:0] cycle_cnt;
    always @(posedge ACLK) begin
        if (!ARESETN) cycle_cnt <= 0;
        else          cycle_cnt <= cycle_cnt + 1;
    end

    // ----------------------------------------------------------------
    // ARREADY generation & command enqueue (separate block)
    // - ARREADY = !cmd_fifo_full  (simple policy)
    // - On handshake (ARVALID && ARREADY), push a cmd entry
    // ----------------------------------------------------------------
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_arready <= 1'b0;
        end else begin
            S_AXI_arready <= ~cmd_fifo_full;
        end
    end

    // push logic: when ARVALID && ARREADY, push to cmd_fifo
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            cmd_wr_ptr <= 0;
            cmd_count  <= 0;
        end else begin
            if (S_AXI_arvalid && S_AXI_arready) begin
                // write into FIFO at wr_ptr
                cmd_fifo[cmd_wr_ptr % CMD_FIFO_DEPTH].addr  <= S_AXI_araddr;
                cmd_fifo[cmd_wr_ptr % CMD_FIFO_DEPTH].id    <= S_AXI_arid;
                cmd_fifo[cmd_wr_ptr % CMD_FIFO_DEPTH].len   <= S_AXI_arlen;
                cmd_fifo[cmd_wr_ptr % CMD_FIFO_DEPTH].size  <= S_AXI_arsize;
                cmd_fifo[cmd_wr_ptr % CMD_FIFO_DEPTH].burst <= S_AXI_arburst;

                cmd_wr_ptr <= cmd_wr_ptr + 1;
                cmd_count  <= cmd_count + 1;
            end
            // no explicit pop here; pop handled by scheduler FSM below
        end
    end

    // ----------------------------------------------------------------
    // Simple Scheduler FSM
    // - Pops a command from cmd_fifo (if not empty)
    // - For each popped command, schedules generation of its beats:
    //     generate start_time = cycle_cnt + CMD2DATA_LATENCY
    // - Generation will push beats into data_fifo when start_time reached
    // - If data_fifo_full, generation stalls (i.e., won't push and will retry)
    // ----------------------------------------------------------------

    // scheduler state for current active command
    reg                 sched_busy;
    reg [ADDR_WIDTH-1:0] sched_addr;
    reg [ID_WIDTH-1:0]  sched_id;
    reg [7:0]           sched_remain;    // beats remaining
    reg [2:0]           sched_size;
    reg [1:0]           sched_burst;
    reg [31:0]          sched_start_cycle; // cycle when first beat becomes available
    reg [31:0]          sched_next_beat_cycle; // next beat produce time

    // pop command into scheduler when idle
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            cmd_rd_ptr <= 0;
            sched_busy <= 1'b0;
        end else begin
            if (!sched_busy && !cmd_fifo_empty) begin
                // pop cmd
                cmd_t tmp = cmd_fifo[cmd_rd_ptr % CMD_FIFO_DEPTH];
                cmd_rd_ptr <= cmd_rd_ptr + 1;
                cmd_count  <= cmd_count - 1;

                // schedule it
                sched_addr <= tmp.addr;
                sched_id   <= tmp.id;
                sched_remain <= tmp.len + 1; // ARLEN is len-1 encoding
                sched_size <= tmp.size;
                sched_burst <= tmp.burst;
                // configure first data cycle
                sched_start_cycle <= cycle_cnt + CMD2DATA_LATENCY;
                sched_next_beat_cycle <= cycle_cnt + CMD2DATA_LATENCY;
                sched_busy <= 1'b1;
            end else begin
                // nothing to pop or still busy -> keep state
            end
        end
    end

    // ----------------------------------------------------------------
    // Data generation: when sched_busy, generate beats into data_fifo
    // - respect sched_next_beat_cycle
    // - if data_fifo_full -> stall generation (do not decrement remain or advance next beat)
    // - translate address -> mem index (index = addr >> BEAT_SHIFT), increment per beat
    // - handle address wrap / bounds check: if index >= MEM_DEPTH -> produce zeros and set SLVERR
    // - note: we do not implement bank/row/ACT logic in detail, only inject a latency CMD2DATA
    // ----------------------------------------------------------------

    // helper: compute index and alignment check
    function automatic integer addr_to_index(input logic [ADDR_WIDTH-1:0] a);
        addr_to_index = a >> BEAT_SHIFT;
    endfunction

    function automatic bit is_aligned(input logic [ADDR_WIDTH-1:0] a, input logic [2:0] size);
        // aligned when low BEAT_SHIFT bits are zero and size == expected
        // require requested size (ARSIZE) equals our beat size
        is_aligned = (a[BEAT_SHIFT-1:0] == 0) && (size == $clog2(BYTES_PER_BEAT));
    endfunction

    // generate beats into data_fifo
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            data_wr_ptr <= 0;
            data_count  <= 0;
            // clear scheduler indicators
            sched_busy <= 1'b0;
        end else begin
            if (sched_busy) begin
                // check if it's time to produce the next beat
                if (cycle_cnt >= sched_next_beat_cycle) begin
                    if (!data_fifo_full) begin
                        // produce one beat
                        integer idx = addr_to_index(sched_addr);
                        bit misaligned = ~is_aligned(sched_addr, sched_size);

                        if (idx < MEM_DEPTH) begin
                            data_fifo[data_wr_ptr % DATA_FIFO_DEPTH].data <= mem[idx];
                            data_fifo[data_wr_ptr % DATA_FIFO_DEPTH].resp <= (misaligned ? RRESP_SLVERR : RRESP_OKAY);
                        end else begin
                            // out of memory range -> zero data and SLVERR
                            data_fifo[data_wr_ptr % DATA_FIFO_DEPTH].data <= {DATA_WIDTH{1'b0}};
                            data_fifo[data_wr_ptr % DATA_FIFO_DEPTH].resp <= RRESP_SLVERR;
                        end
                        data_fifo[data_wr_ptr % DATA_FIFO_DEPTH].id   <= sched_id;
                        data_fifo[data_wr_ptr % DATA_FIFO_DEPTH].last <= (sched_remain == 1);

                        data_wr_ptr <= data_wr_ptr + 1;
                        data_count  <= data_count + 1;

                        // advance address for next beat (INCR burst only supported easily)
                        // for INCR, addr += BYTES_PER_BEAT
                        if (sched_burst == 2'b01) begin
                            sched_addr <= sched_addr + BYTES_PER_BEAT;
                        end else begin
                            // FIXED or WRAP not fully supported: treat as INCR for now
                            sched_addr <= sched_addr + BYTES_PER_BEAT;
                        end

                        // decrement remain
                        sched_remain <= sched_remain - 1;
                        // schedule next beat time (assume continuous beats every cycle)
                        sched_next_beat_cycle <= sched_next_beat_cycle + 1;
                        // if finished
                        if (sched_remain == 1) begin
                            sched_busy <= 1'b0;
                        end
                    end else begin
                        // data_fifo is full -> stall generation; keep sched_next_beat_cycle unchanged
                        // in a real controller you might also apply backpressure to ARREADY when internal pressure is too high
                    end
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // Data FIFO -> R channel output
    // - drive S_AXI_rvalid, S_AXI_rdata, S_AXI_rid, S_AXI_rlast, S_AXI_rresp
    // - handshake when (S_AXI_rvalid && S_AXI_rready)
    // ----------------------------------------------------------------

    // rvalid generation & outputs
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_rvalid <= 1'b0;
            S_AXI_rdata  <= {DATA_WIDTH{1'b0}};
            S_AXI_rid    <= {ID_WIDTH{1'b0}};
            S_AXI_rlast  <= 1'b0;
            S_AXI_rresp  <= RRESP_OKAY;
        end else begin
            if (!data_fifo_empty) begin
                // present head of FIFO on outputs (but only assert rvalid when there is data)
                beat_t head = data_fifo[data_rd_ptr % DATA_FIFO_DEPTH];

                S_AXI_rvalid <= 1'b1;
                S_AXI_rdata  <= head.data;
                S_AXI_rid    <= head.id;
                S_AXI_rlast  <= head.last;
                S_AXI_rresp  <= head.resp;
            end else begin
                // no data to send
                S_AXI_rvalid <= 1'b0;
                S_AXI_rdata  <= {DATA_WIDTH{1'b0}};
                S_AXI_rid    <= {ID_WIDTH{1'b0}};
                S_AXI_rlast  <= 1'b0;
                S_AXI_rresp  <= RRESP_OKAY;
            end

            // consume when handshake occurs
            if (S_AXI_rvalid && S_AXI_rready) begin
                // pop FIFO head
                data_rd_ptr <= data_rd_ptr + 1;
                data_count  <= data_count - 1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Tie-off unused write channel outputs to safe values
    // ----------------------------------------------------------------
    assign S_AXI_awready = 1'b0;
    assign S_AXI_bid     = {ID_WIDTH{1'b0}};
    assign S_AXI_bresp   = 2'b00;
    assign S_AXI_bvalid  = 1'b0;
    assign S_AXI_wready  = 1'b0;

endmodule
