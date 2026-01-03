// ============================================================================
// VecMatch.v
//  - 输入 img_vec 和 lib_vec，计算公共向量
//  - 使用 VecPopcount 模块实现位统计，支持背压与流水化
// ============================================================================



`timescale 1ns / 1ps

module VecMatch #(
    parameter integer VEC_WIDTH = 1100,
    parameter integer POPCNT_WIDTH = $clog2(VEC_WIDTH+1)
) (
    input wire clk,
    input wire rst_n,

    input wire [VEC_WIDTH-1:0] img_vec,
    input wire [VEC_WIDTH-1:0] lib_vec,

    input wire in_valid,
    output wire this_ready,
    output wire out_valid,
    input wire next_ready,

    output wire [POPCNT_WIDTH-1:0] match_count
);
    // 计算公共向量
    wire [VEC_WIDTH-1:0] and_vec;
    assign and_vec = img_vec & lib_vec;

    // 使用 VecPopcount 计算公共向量中 1 的个数
    wire [POPCNT_WIDTH-1:0] vec_popcount;
    VecPopcount #(
        .VEC_WIDTH(VEC_WIDTH),
        .LUT_WIDTH(6),
        .POPCNT_WIDTH(POPCNT_WIDTH)
    ) u_vec_popcount (
        .clk        (clk),
        .rst_n      (rst_n),
        .vec        (and_vec),
        .in_valid   (in_valid),
        .out_valid  (out_valid),
        .this_ready (this_ready),
        .next_ready (next_ready),
        .popcount   (vec_popcount)
    );
    // 输出连接
    assign match_count = vec_popcount;
endmodule