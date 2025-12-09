
// ==============================================================
// Popcount
//  - 按固定宽度(缺省 6)切分输入向量；每块用小型查表
//  - 将所有分片结果送入通用加法树归约
//  - 加法树每层直接配置寄存器，以实现流水化
//  - 可通过参数调整总体宽度与块宽度
// ==============================================================



`include "config.vh"





`timescale 1ns / 1ps
module Popcount #(
    parameter integer VEC_WIDTH = `CFG_VEC_WIDTH,  // 输入向量位宽 (>=1)
    parameter integer LUT_WIDTH = `CFG_LUT_IN_WIDTH,  // 每个局部 popcount 的切分宽度 (>=1)
    parameter integer POPCNT_WIDTH = `CFG_VEC_POPCOUNT_WIDTH    
) (
    input  wire                 clk,
    input  wire                 rst_n,
    // 流接口
    input  wire                 in_valid,    // 输入有效
    output wire                 this_ready,  // 可接收下一拍
    input  wire [VEC_WIDTH-1:0] vec,

    output wire                    out_valid,   // 输出有效
    input  wire                    next_ready,  // 下游就绪
    output wire [POPCNT_WIDTH-1:0] popcount
);
    // ========== 派生参数 ==========
    localparam integer LEAF_NUM = `CFG_ADDER_TREE_LEAF_NUM;  // ceil(VEC_WIDTH / LUT_WIDTH)
    localparam integer LEAF_WIDEH = `CFG_LUT_OUT_WIDTH;  // 单块 popcount 结果位宽
    // AdderTree 内部自带 LEVELS+1 级流水，外层无需再补偿有效位移位

    // ========== 参数合法性检查（仿真期 / 综合期静态） ==========
    initial begin
        if (VEC_WIDTH < 1) $fatal("Popcount: VEC_WIDTH must be >=1");
        if (LUT_WIDTH < 1) $fatal("Popcount: LUT_WIDTH must be >=1");
    end

    // ========== 局部 popcount 结果数组：NCHUNK 组，每组 0..CHUNK_BITS ==========
    wire [LEAF_WIDEH-1:0] chunk_pc[0:LEAF_NUM-1];

    genvar c;
    generate
        for (c = 0; c < LEAF_NUM; c = c + 1) begin : CHUNKS
            // 对于最后一块可能不足 LUT_WIDTH 位：高位补 0
            wire [LUT_WIDTH-1:0] slice_bits;
            if ((c + 1) * LUT_WIDTH <= VEC_WIDTH) begin : FULL
                // assign slice_bits = vec[(c + 1)*LUT_WIDTH - 1 : c*LUT_WIDTH];
                assign slice_bits = vec[c*LUT_WIDTH+:LUT_WIDTH];
            end else begin : PART
                localparam integer REM = VEC_WIDTH - c*LUT_WIDTH; // 剩余有效位数 ( < LUT_WIDTH )
                assign slice_bits = {{(LUT_WIDTH - REM) {1'b0}}, vec[VEC_WIDTH-1-:REM]};
                // assign slice_bits = {{((c + 1) * LUT_WIDTH - VEC_WIDTH) {1'b0}}, vec[VEC_WIDTH-1 : c*LUT_WIDTH]};
            end
            LookupTable #(
                .DIN_WIDTH (LUT_WIDTH),
                .DOUT_WIDTH(LEAF_WIDEH)
            ) u_chunk_pop (
                .din (slice_bits),
                .dout(chunk_pc[c])
            );
        end
    endgenerate

    // ========== 打包局部结果为扁平总线 ==========
    wire [LEAF_NUM*LEAF_WIDEH-1:0] in_flat_bus;
    generate
        for (c = 0; c < LEAF_NUM; c = c + 1) begin : PACK
            assign in_flat_bus[c*LEAF_WIDEH+:LEAF_WIDEH] = chunk_pc[c];
        end
    endgenerate

    // ========== 二叉加法树归约 ==========
    AdderTree #(
        .LEAF_NUM(LEAF_NUM),
        .MAXVAL  (LUT_WIDTH)  // 每块最大值 = LUT_WIDTH（全 1）
        // INW 自动 = $clog2(MAXVAL+1) 与 LEAF_WIDEH 匹配
    ) u_tree (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_data  (in_flat_bus),
        .in_valid (in_valid),
        .in_ready (this_ready),
        .sum      (popcount),
        .out_valid(out_valid),
        .out_ready(next_ready)
    );
endmodule
