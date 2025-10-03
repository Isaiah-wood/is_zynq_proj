module LatencySync #(
    parameter integer DATA_WIDTH = 8,
    parameter integer LATENCY    = 4
)(
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [DATA_WIDTH-1:0]    din,
    input  wire                     in_valid,
    output wire                     in_ready,

    output wire [DATA_WIDTH-1:0]    dout,
    output wire                     out_valid,
    input wire                     out_ready
);
    reg [DATA_WIDTH-1:0] mem [0:LATENCY-1];
    reg [LATENCY:0]   valid_shift;  // 有效位移寄存器

    assign dout       = mem[LATENCY-1];
    assign out_valid = valid_shift[LATENCY-1];
    assign in_ready  = !valid_shift[0];  // 如果第一级空闲，则可接收新数据

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_shift <= 'b0;
            // for (i=0; i<LATENCY; i=i+1) begin
            //     valid_shift[i] <= 1'b0;
            // end
        end else begin
            // valid_shift[0] <= in_valid;
            // for (i=1; i<LATENCY; i=i+1) begin
            //     valid_shift[i] <= valid_shift[i-1];
            // end
            if (in_ready && in_valid) begin
                // 新数据写入
                mem[0] <= din;
                valid_shift[0] <= 1'b1;
            end else begin
                valid_shift[0] <= 1'b0;
            end

            // 流水传递：仅当下游 ready 或者当前层未满
            if (out_ready || !out_valid) begin
                for (i=LATENCY-1; i>0; i=i-1) begin
                    if (!valid_shift[i]) begin
                        mem[i]        <= mem[i-1];
                        valid_shift[i]<= valid_shift[i-1];
                        valid_shift[i-1] <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
