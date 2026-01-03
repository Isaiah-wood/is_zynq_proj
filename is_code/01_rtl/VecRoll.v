// ============================================================================
// VecRoll.v
// - 向量遍历模块，基于计数器模块Counter实现对导航向量和观测向量的循环访问
// ============================================================================


`timescale 1ns / 1ps

module VecRoll #(
    parameter integer OBS_VEC_NUM = 49,
    parameter integer NAV_VEC_NUM = 539,
    parameter integer NAV_ADDR_WIDTH = $clog2(NAV_VEC_NUM),
    parameter integer OBS_ADDR_WIDTH = $clog2(OBS_VEC_NUM)
) (
    input wire clk,
    input wire rst_n,

    input wire start,
    output wire out_valid,
    input wire next_ready,

    output wire [NAV_ADDR_WIDTH-1:0] navvec_addr,
    output wire [OBS_ADDR_WIDTH-1:0] obsvec_addr
);
    // 计数器实例化
    wire navvec_valid;
    wire navvec_enter;
    Counter #(
        .COUNT_NUM(NAV_VEC_NUM)
    ) u_counter_nav (
        .clk(clk),
        .rst_n(rst_n),
        .en(start),
        .load(1'b0),
        .carry(navvec_enter),
        .cnt(navvec_addr)
    );
    wire obsvec_valid;
    wire obsvec_enter;
    Counter #(
        .COUNT_NUM(OBS_VEC_NUM),
        .COUNT_WIDTH(OBS_ADDR_WIDTH)
    ) u_counter_obs (
        .clk(clk),
        .rst_n(rst_n),
        .en(navvec_enter),
        .load(1'b0),
        .carry(obsvec_enter),
        .cnt(obsvec_addr)
    );

    // 运行标志
    reg fire;
    always @(posedge clk) begin
        if (!rst_n) begin
            fire <= 1'b0;
        end else if (next_ready && out_valid) begin
            if (obsvec_enter) begin
                fire <= 1'b0;
            end
        end else if (start) begin
            fire <= 1'b1;
        end
    end
    assign out_valid = fire;



endmodule