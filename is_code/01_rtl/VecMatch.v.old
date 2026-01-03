`timescale 1ns / 1ps
`include "config.vh"


// ============================================================================
// VecMatch
//  - 仅使用 VecErgodic + VirtualROM + Popcount 组装
//  - 支持背压：next_ready=0 时暂停内部推进；与下游握手对齐
//  - 输出每对(img, lib)的 popcount 结果，以及索引与帧内 last 标志
// ============================================================================


module VecMatch #(
    parameter integer IMG_VEC_N = `CFG_IMG_VEC_NUM,
    parameter integer LIB_VEC_N = `CFG_LIB_VEC_NUM,
    parameter integer VEC_WIDTH = `CFG_VEC_WIDTH,
    parameter integer COEFF_WIDTH = `CFG_COEFF_WIDTH
) (
    input wire clk,
    input wire rst_n,
    input wire start,  // 启动脉冲


    output wire inner_done,    // 对应帧的最后一个（lib 最后一个）
    output wire outer_done,    // 所有(img,lib)对处理完（与末个结果对齐）
    output wire indone_valid,  // inner_done 有效
    output wire outdone_valid, // outer_done 有效

    input wire next_ready,
    output wire out_valid,  // 结果有效
    output reg [$clog2(VEC_WIDTH+1)-1:0] out_data,  // popcount(and)
    output reg [$clog2(VEC_WIDTH+1)-1:0] norm_data  // 归一化结果 (0..IMG_VEC_N)
);

    // ----------------------------
    // 向量 ROM（同步 1 拍）
    // ----------------------------
    wire [$clog2(IMG_VEC_N)-1:0] img_addr;
    wire [$clog2(LIB_VEC_N)-1:0] lib_addr;
    wire linefeed, finish;
    wire pc_ready;
    AddrDeal #(
        .IMG_VEC_N(IMG_VEC_N),
        .LIB_VEC_N(LIB_VEC_N)
    ) u_addr_deal (
        .clk       (clk),
        .rst_n     (rst_n),
        .fire      (start),
        .next_ready(pc_ready),
        .linefeed  (linefeed),
        .finish    (finish),
        .lib_avalid(lib_avalid),
        .img_avalid(img_avalid),
        .lib_addr  (lib_addr),
        .img_addr  (img_addr)
    );

    wire [VEC_WIDTH-1:0] img_vec, lib_vec;

    wire lib_valid, img_valid;

    VirtualDDR #(
        .ROM_DEPTH (LIB_VEC_N),
        .DATA_WIDTH(VEC_WIDTH),
        .INIT_FILE (`CFG_LIB_VEC_FILE)
    ) u_ddr_lib (
        .clk    (clk),
        .rst_n  (rst_n),
        .arvalid(lib_avalid),
        .araddr (lib_addr),
        .rvalid (lib_valid),
        .rready (pc_ready),
        .rdata  (lib_vec)
    );



    // inner_done 对齐
    FIFOSync #(
        .FIFO_DEPTH(16),
        .FIFO_WIDTH(1)
    ) u_fifo_linefeed (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (lib_avalid),
        .this_ready(),
        .din       (linefeed),
        .out_valid (indone_valid),
        .next_ready(pc_ready),
        .dout      (inner_done)
    );



    VirtualBROM #(
        .ROM_DEPTH (IMG_VEC_N),
        .DATA_WIDTH(VEC_WIDTH),
        .INIT_FILE (`CFG_IMG_VEC_FILE)
    ) u_brom_img (
        .clk    (clk),
        .rst_n  (rst_n),
        .arvalid(img_avalid),
        .araddr (img_addr),
        .rvalid (img_valid),
        .rready (pc_ready),
        .rdata  (img_vec)
    );

    // outer_done 对齐
    FIFOSync #(
        .FIFO_DEPTH(4),
        .FIFO_WIDTH(1)
    ) u_fifo_finish (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (img_avalid),
        .this_ready(),
        .din       (finish),
        .out_valid (outdone_valid),
        .next_ready(pc_ready),
        .dout      (outer_done)
    );









    wire [$clog2(VEC_WIDTH+1)-1:0] pc_now;
    wire pc_out_valid;

    Popcount #(
        .VEC_WIDTH(VEC_WIDTH)
    ) u_pop (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (lib_valid && img_valid),
        .this_ready(pc_ready),
        .vec       (img_vec & lib_vec),
        .out_valid (pc_out_valid),
        .next_ready(next_ready),
        .popcount  (pc_now)
    );


    wire coeff_valid, fifo_ready;
    wire [COEFF_WIDTH-1:0] lib_coeff;
    VirtualBROM #(
        .ROM_DEPTH (LIB_VEC_N),
        .DATA_WIDTH(COEFF_WIDTH),
        .INIT_FILE (`CFG_LIB_COEFF_FILE)
    ) u_brom_norm (
        .clk    (clk),
        .rst_n  (rst_n),
        .arvalid(lib_avalid),
        .araddr (lib_addr),
        .rvalid (coeff_valid),
        .rready (fifo_ready),
        .rdata  (lib_coeff)
    );


    wire [COEFF_WIDTH-1:0] lib_coeff_d;
    wire coeff_d_valid;

    // coeff 也需要 FIFO，和 popcount 结果对齐
    FIFOSync #(
        .FIFO_WIDTH(COEFF_WIDTH),
        .FIFO_DEPTH(32)
    ) u_fifo_coeff (
        .clk       (clk),
        .rst_n     (rst_n),
        .din       (lib_coeff),
        .in_valid  (coeff_valid),
        .this_ready(fifo_ready),
        .dout      (lib_coeff_d),
        .out_valid (coeff_d_valid),
        .next_ready(next_ready)
    );

    assign out_valid = pc_out_valid && coeff_d_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_data  <= 0;
            norm_data <= 0;
        end else if (out_valid && next_ready) begin
            out_data  <= pc_now;
            norm_data <= pc_now * lib_coeff_d;
        end
    end

    // 地址与popcount对齐
    FIFOSync #(
        .FIFO_DEPTH(16),
        .FIFO_WIDTH(1)
    ) u_fifo_pc_ready (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (lib_valid && img_valid),
        .this_ready(),
        .din       (1'b1),
        .out_valid (pc_ready),
        .next_ready(next_ready),
        .dout      ()
    );


endmodule
