// ========================================
// valid/ready FIFO
// - 参数化数据宽度、深度
// - 支持背压：下游 not ready 时保持数据
// - 支持满/空自动阻塞
// ========================================
module FIFOSync #(
    parameter integer FIFO_WIDTH = 8,          // 数据位宽
    parameter integer FIFO_DEPTH = 16          // FIFO 深度，必须为 2^N
)(
    input  wire              clk,
    input  wire              rst_n,

    // 上游接口
    input  wire [FIFO_WIDTH-1:0]  din,
    input  wire              in_valid,
    output wire              this_ready,

    // 下游接口
    output wire [FIFO_WIDTH-1:0]  dout,
    output wire              out_valid,
    input  wire              next_ready
);

    // -------------------------------
    // 内部存储
    // -------------------------------
    reg [FIFO_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    reg [$clog2(FIFO_DEPTH):0] wr_ptr;  // 写指针
    reg [$clog2(FIFO_DEPTH):0] rd_ptr;  // 读指针

    wire full;
    wire empty;

    // -------------------------------
    // 满/空判断
    // -------------------------------
    assign full  = ( (wr_ptr[$clog2(FIFO_DEPTH)-1:0] == rd_ptr[$clog2(FIFO_DEPTH)-1:0]) &&
                     (wr_ptr[$clog2(FIFO_DEPTH)]     != rd_ptr[$clog2(FIFO_DEPTH)]) );
    assign empty = (wr_ptr == rd_ptr);
    
    

    // -------------------------------
    // 写入逻辑
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (in_valid && this_ready) begin
            mem[wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= din;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // -------------------------------
    // 读取逻辑
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (out_valid && next_ready) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    // -------------------------------
    // 接口信号
    // -------------------------------
    assign this_ready  = !full;
    assign out_valid = !empty;
    assign dout      = mem[rd_ptr[$clog2(FIFO_DEPTH)-1:0]];

endmodule
