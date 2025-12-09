// ============================================================================
// AdderLevel
//  - 加法树的一层加法器
//  - 输入多个 DIN_WIDTH 位宽的向量，输出其逐位相加的结果（DOUT_WIDTH 位宽）
//  - 纯组合逻辑，无时序
// ============================================================================


`timescale 1ns / 1ps

module AdderLevel #(
    parameter integer ADDEND_WIDTH = 3,
    parameter integer SUM_WIDTH = ADDEND_WIDTH + 1,
    parameter integer NUM_INPUTS  = 4,
    parameter integer NUM_OUTPUTS = (NUM_INPUTS + 1) / 2,
    parameter integer DIN_WIDTH  = NUM_INPUTS * ADDEND_WIDTH,
    parameter integer DOUT_WIDTH = NUM_OUTPUTS * SUM_WIDTH
) (
    input  wire [DIN_WIDTH-1:0]  din,
    output wire [DOUT_WIDTH-1:0] dout
);
    // 输入断言
    initial begin
        if (NUM_INPUTS < 2) begin
            $fatal("AdderLevel: NUM_INPUTS must be >= 2");
        end
    end
    // 逐位相加
    integer i;
    reg [DOUT_WIDTH-1:0] sum;
    always @(*) begin
        for (i = 0; i < NUM_OUTPUTS - 1; i = i + 1) begin
            sum[i*SUM_WIDTH +: SUM_WIDTH] = din[(2*i)*ADDEND_WIDTH +: ADDEND_WIDTH] +
                                             din[(2*i+1)*ADDEND_WIDTH +: ADDEND_WIDTH];
        end
        // 处理奇数个输入的情况
        if (NUM_INPUTS % 2 == 1) begin
            sum[(NUM_OUTPUTS-1)*SUM_WIDTH +: SUM_WIDTH] = din[(NUM_INPUTS-1)*ADDEND_WIDTH +: ADDEND_WIDTH];
        end else begin
            sum[(NUM_OUTPUTS-1)*SUM_WIDTH +: SUM_WIDTH] = din[(2*(NUM_OUTPUTS-1))*ADDEND_WIDTH +: ADDEND_WIDTH] +
                                             din[(2*(NUM_OUTPUTS-1)+1)*ADDEND_WIDTH +: ADDEND_WIDTH];
        end
    end
    assign dout = sum;
endmodule