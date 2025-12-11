// =============================================================
// AXI DDR3 COMPLETE SIMULATION PACKAGE
// 包含三个文件的内容：
// 1. DDR 仿真模块 axi_ddr3_sim.v
// 2. DDR 顺序读取封装模块 axi_ddr_reader.v
// 3. 读取模块 testbench axi_ddr_reader_tb.v
// （统一放在同一文档中，便于你复制到三个文件中）
// =============================================================

// =============================================================
// 1. DDR 仿真模块（完整AXI接口, 只支持读） axi_ddr3_sim.v
// =============================================================

`include "config.vh"
`timescale 1ns/1ps

module axi_ddr3_sim #(
    parameter ID_WIDTH   = 4,
    parameter DATA_WIDTH = 256,
    parameter ADDR_WIDTH = 32,
    parameter SLICE_NUM = (`CFG_VEC_WIDTH + DATA_WIDTH - 1) / DATA_WIDTH,           //向上取整
    parameter MEM_DEPTH  = `CFG_LIB_VEC_NUM * SLICE_NUM,  // 存储深度，单位：DATA_WIDTH bits
    parameter INIT_FILE  = `CFG_LIB_VEC_FILE
)(
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

    // -------------------------------------------------------------
    // 悬空输出位置零
    // -------------------------------------------------------------
    assign S_AXI_awready = 1'b0;
    assign S_AXI_wready  = 1'b0;
    assign S_AXI_bvalid  = 1'b0;
    assign S_AXI_bresp   = 2'b00;
    assign S_AXI_bid     = {ID_WIDTH{1'b0}};

    // -------------------------------------------------------------
    // 输入配置位断言，推荐配置为：
    // S_AXI_arburst: 2'b01 (INCR)
    // S_AXI_arsize:  3'b101 (32-Byte/256-bit)
    // S_AXI_arlen:  8'd15 (16 beats)
    // S_AXI_arlock:  2'b00 (Normal)
    // S_AXI_arcache: 4'b0110 (Read-Allocate, Modifiable)
    // S_AXI_arprot:  3'b000 (Non-secure, Non-privileged, Data Access)
    // S_AXI_arqos:   4'b0000 (No QoS)
    // -------------------------------------------------------------
    always @(*) begin
        // 地址对齐检查
        if (S_AXI_araddr[ADDR_WIDTH-1:ADDR_WIDTH-5] != 0) begin
            $display("[%t] ERROR: AXI_araddr is not aligned to %d bytes. Address must be a multiple of %d.", $time, (1 << S_AXI_arsize), (1 << S_AXI_arsize));
        end


        // 突发配置检查
        if (S_AXI_arburst == 2'b00) begin
            $display("[%t] INFO: AXI_arburst is set to 00 (FIXED).", $time);
        end else if (S_AXI_arburst == 2'b01) begin
            $display("[%t] INFO: AXI_arburst is set to 01 (INCR). ", $time);
        end else if (S_AXI_arburst == 2'b10) begin
            $display("[%t] INFO: AXI_arburst is set to 10 (WRAP)", $time);
        end else if (S_AXI_arburst == 2'b10 || S_AXI_arburst == 2'b11) begin
            $display("[%t] ERROR: AXI_arburst is set to 11 (Reserved). Only INCR (01) is supported.", $time, S_AXI_arburst);
        end
        if (S_AXI_arlen == 8'd0) begin
            $display("[%t] INFO: AXI_arlen is set to 0 (Single Beat). ", $time);
        end else if (S_AXI_arlen == 8'd15) begin
            $display("[%t] INFO: AXI_arlen is set to 15 (16 Beats). ", $time);
        end else if (S_AXI_arlen < 8'd16) begin
            $display("[%t] INFO: AXI_arlen is set to %d (Less than 16 Beats). ", $time, S_AXI_arlen);
        end else begin
            $display("[%t] ERROR: AXI_arlen is set to %d (More than 16 Beats), which is not supported.", $time, S_AXI_arlen);
        end
        if (S_AXI_arsize == 3'b101) begin
            $display("[%t] INFO: AXI_arsize is set to 101 (%d-Byte/%d-bit). ", $time, S_AXI_arsize, 1 << S_AXI_arsize, (1 << S_AXI_arsize)*8);
        end else if (S_AXI_arsize <= 3'b111) begin
            $display("[%t] WARNING: AXI_arsize is set to %b (%d-bit). ", $time, S_AXI_arsize, 1 << S_AXI_arsize*8);
        end else begin
            $display("[%t] ERROR: AXI_arsize is set to an unsupported value: %b.", $time, S_AXI_arsize);
        end

        // 其他配置检查
        if (S_AXI_arlock == 2'b00) begin
            $display("[%t] INFO: AXI_arlock is set to 00(Normal). ", $time);
        end else if (S_AXI_arlock == 2'b01) begin
            $display("[%t] INFO: AXI_arlock is set to 01(Locked). ", $time);
        end else if (S_AXI_arlock == 2'b10) begin
            $display("[%t] ERROR: AXI_arlock is set to 10(Reserved). ", $time);
        end else if (S_AXI_arlock == 2'b11) begin
            $display("[%t] ERROR: AXI_arlock is set to 11(Reserved). ", $time);
        end
        if (S_AXI_arcache == 4'b0110) begin
            $display("[%t] INFO: AXI_arcache is set to 0110(Modifiable and Read-Allocate). ", $time);
        end else begin
            $display("[%t] ERROR: AXI_arcache is set to an unsupported configuration item: %b.", $time, S_AXI_arcache);
        end
        if (S_AXI_arprot[2:0] == 3'b000) begin
            $display("[%t] INFO: AXI_arprot is set to 000(Non-secure, Non-privileged). ", $time);
        end else begin
            $display("[%t] ERROR: AXI_arprot is set to an unsupported configuration item: %b. ", $time, S_AXI_arprot);
        end
        if (S_AXI_arqos == 4'b0000) begin
            $display("[%t] INFO: AXI_arqos is set to 0000(No QoS). ", $time);
        end else begin
            $display("[%t] ERROR: AXI_arqos is set to an unsupported configuration item: %b.", $time, S_AXI_arqos);
        end
    end


    // -------------------------------------------------------------
    // Memory Model
    // -------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // -------------------------------------------------------------
    // Address Helper
    // -------------------------------------------------------------
    localparam integer DATA_BYTES = DATA_WIDTH / 8;         // 256/8=32 Bytes
    localparam integer ADDR_LSB   = $clog2(DATA_BYTES);     // 32 Bytes 对应的地址位数 = 5: 0b101

    function automatic [31:0] addr_to_index;
        input [ADDR_WIDTH-1:0] addr;
        addr_to_index = addr >> ADDR_LSB;
    endfunction

    // -------------------------------------------------------------
    // Read Channel Logic
    // -------------------------------------------------------------
    wire ar_handshake = S_AXI_arvalid && S_AXI_arready;
    wire r_handshake  = S_AXI_rvalid  && S_AXI_rready;

    // Internal State
    reg                       burst_active;
    reg [31:0]                base_index;
    reg                       burst_err;
    reg [7:0]                 transfer_cnt;

    wire [31:0] next_index = addr_to_index(S_AXI_araddr);



    // 1. Address Channel & State Control
    // Separate always blocks for better clarity and synthesis
    // burst_active 控制，当【读地址握手】时突发开始，当【读数据握手/读到最后一个数据】时结束
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            burst_active  <= 1'b0;
        end else begin
            if (ar_handshake) begin
                burst_active <= 1'b1;
            end else if (burst_active && r_handshake && S_AXI_rlast) begin
                // Burst complete
                burst_active <= 1'b0;
            end
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_arready <= 1'b0;
        end else begin
            // Simple flow control: Ready when not processing a burst
            S_AXI_arready <= !burst_active;
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            base_index    <= 32'd0;
        end else begin
            if (ar_handshake) begin
                base_index   <= next_index;
            end
        end
    end


    always @(posedge ACLK) begin
        if (!ARESETN) begin
            burst_err     <= 1'b0;
        end else begin
            if (ar_handshake) begin
                // Check for out-of-bounds access
                burst_err    <= (next_index + S_AXI_arlen) >= MEM_DEPTH;
            end
        end
    end

    // 2. Data Channel Output
    // Separate always blocks for better clarity and synthesis


    // Condition to update output data:
    // 1. Burst is active
    // 2. AND (Output is not valid yet OR Current data is accepted)
    wire update_output = burst_active && (!S_AXI_rvalid || r_handshake);

    wire last_beat = (transfer_cnt == S_AXI_arlen);
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            transfer_cnt     <= 8'd0;
        end else begin
            // Beat Counter Logic
            if (ar_handshake) begin
                transfer_cnt <= 8'd0;
            end else if (update_output && !last_beat) begin
                transfer_cnt <= transfer_cnt + 1'b1;
            end
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_rvalid <= 1'b0;
        end else begin
            // Output Logic (Priority Encoded)
            if (r_handshake && S_AXI_rlast) begin
                // Case 1: Burst Finished
                S_AXI_rvalid <= 1'b0;
            end else if (update_output) begin
                // Case 2: Output Next Beat
                S_AXI_rvalid <= 1'b1;
            end else if (!burst_active) begin
                // Case 3: Idle
                S_AXI_rvalid <= 1'b0;
            end
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_rlast  <= 1'b0;
        end else begin
            // Output Logic (Priority Encoded)
            if (r_handshake && S_AXI_rlast) begin
                // Case 1: Burst Finished
                S_AXI_rlast  <= 1'b0;
            end else if (update_output) begin
                // Case 2: Output Next Beat
                S_AXI_rlast  <= last_beat;
            end else if (!burst_active) begin
                // Case 3: Idle
                S_AXI_rlast  <= 1'b0;
            end
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_rid    <= {ID_WIDTH{1'b0}};
        end else begin
            // Output Logic (Priority Encoded)
            if (update_output) begin
                // Case 2: Output Next Beat
                S_AXI_rid    <= S_AXI_arid;
            end
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_rresp  <= 2'b00;
        end else begin
            // Output Logic (Priority Encoded)
            if (update_output) begin
                // Case 2: Output Next Beat
                S_AXI_rresp  <= burst_err ? 2'b10 : 2'b00; // SLVERR if error
            end
        end
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_rdata  <= {DATA_WIDTH{1'b0}};
        end else begin
            // Output Logic (Priority Encoded)
            if (update_output) begin
                // Case 2: Output Next Beat
                if (!burst_err && (base_index + transfer_cnt) < MEM_DEPTH) begin
                    S_AXI_rdata <= mem[base_index + transfer_cnt];
                end else begin
                    S_AXI_rdata <= {DATA_WIDTH{1'b0}};
                end
            end
        end
    end


    




    // 1. Address Channel & State Control

    // always @(posedge ACLK) begin
    //     if (!ARESETN) begin
    //         S_AXI_arready <= 1'b0;
    //         burst_active  <= 1'b0;
    //         base_index    <= 32'd0;
    //         burst_len     <= 8'd0;
    //         burst_id      <= {ID_WIDTH{1'b0}};
    //         burst_err     <= 1'b0;
    //     end else begin
    //         // Simple flow control: Ready when not processing a burst
    //         S_AXI_arready <= !burst_active;

    //         if (ar_handshake) begin
    //             burst_active <= 1'b1;
    //             base_index   <= next_index;
    //             burst_len    <= S_AXI_arlen;
    //             burst_id     <= S_AXI_arid;
    //             // Check for out-of-bounds access
    //             burst_err    <= (next_index + S_AXI_arlen) >= MEM_DEPTH;

    //         end else if (burst_active && r_handshake && S_AXI_rlast) begin
    //             // Burst complete
    //             burst_active <= 1'b0;
    //         end
    //     end
    // end

    // 2. Data Channel Output

    // always @(posedge ACLK) begin
    //     if (!ARESETN) begin
    //         transfer_cnt     <= 8'd0;
    //         S_AXI_rvalid <= 1'b0;
    //         S_AXI_rlast  <= 1'b0;
    //         S_AXI_rid    <= {ID_WIDTH{1'b0}};
    //         S_AXI_rresp  <= 2'b00;
    //         S_AXI_rdata  <= {DATA_WIDTH{1'b0}};
    //     end else begin
    //         // Beat Counter Logic
    //         if (ar_handshake) begin
    //             transfer_cnt <= 8'd0;
    //         end else if (update_output && !last_beat) begin
    //             transfer_cnt <= transfer_cnt + 1'b1;
    //         end

    //         // Output Logic (Priority Encoded)
    //         if (r_handshake && S_AXI_rlast) begin
    //             // Case 1: Burst Finished
    //             S_AXI_rvalid <= 1'b0;
    //             S_AXI_rlast  <= 1'b0;
    //         end else if (update_output) begin
    //             // Case 2: Output Next Beat
    //             S_AXI_rvalid <= 1'b1;
    //             S_AXI_rid    <= burst_id;
    //             S_AXI_rresp  <= burst_err ? 2'b10 : 2'b00; // SLVERR if error
    //             S_AXI_rlast  <= last_beat;

    //             if (!burst_err && (base_index + transfer_cnt) < MEM_DEPTH) begin
    //                 S_AXI_rdata <= mem[base_index + transfer_cnt];
    //             end else begin
    //                 S_AXI_rdata <= {DATA_WIDTH{1'b0}};
    //             end
    //         end else if (!burst_active) begin
    //             // Case 3: Idle
    //             S_AXI_rvalid <= 1'b0;
    //             S_AXI_rlast  <= 1'b0;
    //         end
    //     end
    // end

endmodule

