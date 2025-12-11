// ============================================================================
// VecPopcountLUT
//  - 输入一个向量，计算其中 1 的个数, 采用LUT查表的方案, 位数<=6
//  - 输出插入reg，增加时序稳定性，以实现流水线设计
// ============================================================================

`timescale 1ns / 1ps
module VecPopcountLUT #(
    parameter integer VEC_WIDTH = 6,
    parameter integer POPCNT_WIDTH = $clog2(VEC_WIDTH+1)
) (
    input wire [VEC_WIDTH-1:0] vec,
    output wire [POPCNT_WIDTH-1:0] cnt
);
    wire [POPCNT_WIDTH-1:0] cnt_lut6;
    reg [POPCNT_WIDTH-1:0] cnt_reg;
    reg cnt_valid_reg;

    // 直接使用LUT查表
    LUT6_Popcount #(
        .DIN_WIDTH(VEC_WIDTH),
        .DOUT_WIDTH(POPCNT_WIDTH)
    ) u_lut6_popcount (
        .din(vec),
        .dout(cnt_lut6)
    );
    assign cnt = cnt_reg;
endmodule