
// ==========================================
//  Module Name: AddrDeal
//  Description: 地址生成模块
// ==========================================

/* @wavedrom AddrDeal
{
    "signal": [
        { "name": "clk", "wave": "p....................." },
        { "name": "rst_n", "wave": "01...................." },
        { "name": "fire", "wave": "0.10..................", "data": ["start"] },
        { "name": "next_ready", "wave": "x1...................." },
        { "name": "lib_avalid", "wave": "0..1................0."},
        { "name": "lib_addr", "wave": "x..3456xx934xx934xx9xx", "data": ["0", "1", "2", "3","N-1", "0","1","N-1","0", "1","N-1"] },
        { "name": "linefeed", "wave": "0........10...10...10."},
        { "name": "img_avalid", "wave": "0..1................0."},
        { "name": "img_addr", "wave": "x..3......x....9....xx", "data": ["0","M-1"] },
        { "name": "finish", "wave": "0..................10."}
    ]
}
*/





`timescale 1ns / 1ps
`include "config.vh"

module AddrDeal #(
    parameter integer IMG_VEC_N = `CFG_IMG_VEC_NUM,
    parameter integer LIB_VEC_N = `CFG_LIB_VEC_NUM
) (
    input wire clk,
    input wire rst_n,

    input  wire fire,      // 启动脉冲
    input  wire next_ready,     // 为0时背压暂停
    output wire linefeed,
    output wire finish,

    output wire lib_avalid,     // 数据有效信号
    output wire img_avalid,     // 数据有效信号
    output reg [$clog2(LIB_VEC_N)-1:0] lib_addr,
    output reg [$clog2(IMG_VEC_N)-1:0] img_addr
);

    wire add_lib_addr, end_lib_addr;
    wire last_lib_addr = (lib_addr == LIB_VEC_N - 1);
    wire in_start = fire | (linefeed & ~finish);
    wire in_stop = end_lib_addr;
    reg  in_running;
    // 数据有效信号running（正运行标志），随着start信号拉高而拉高，随着计数结束而恢复
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_running <= 1'b0;
        end else if (in_start) begin
            in_running <= 1'b1;
        end else if (in_stop) begin
            in_running <= 1'b0;
        end
    end
    wire lib_addr_valid = in_running;
    assign linefeed = in_stop;

    // 星库遍历，内循环，DDR
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lib_addr <= 0;
        end else begin
            if (add_lib_addr) begin
                if (end_lib_addr) begin
                    lib_addr <= 0;
                end else begin
                    lib_addr <= lib_addr + 1;
                end
            end
        end
    end
    assign add_lib_addr = lib_addr_valid && next_ready;  // 模块启动且后级ready才开始计数
    assign end_lib_addr = add_lib_addr && last_lib_addr;  // 计数到头结束



    wire add_img_addr, end_img_addr;
    wire last_img_addr = (img_addr == IMG_VEC_N - 1);
    wire out_start = fire | (linefeed & ~finish);
    wire out_stop = end_img_addr;
    reg  out_running;
    // 数据有效信号running（正运行标志），随着start信号拉高而拉高，随着计数结束而恢复
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_running <= 1'b0;
        end else if (out_start) begin
            out_running <= 1'b1;
        end else if (out_stop) begin
            out_running <= 1'b0;
        end
    end
    wire img_addr_valid = out_running;
    assign finish = out_stop;



    // 图像遍历，外循环，BRAM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            img_addr <= 0;
        end else begin
            if (add_img_addr) begin
                if (end_img_addr) begin
                    img_addr <= 0;
                end else begin
                    img_addr <= img_addr + 1;
                end
            end
        end
    end
    assign add_img_addr = in_stop && next_ready;  // 内循环结束时，开始外循环计数+1
    assign end_img_addr = add_img_addr && last_img_addr;  // 计数到头结束

    // assign valid = img_addr_valid && lib_addr_valid;  // 两个计数器都在运行时，数据有效
    assign img_avalid = img_addr_valid;  // 两个计数器都在运行时，数据有效
    assign lib_avalid = lib_addr_valid;  // 两个计数器都在运行时，数据有效


endmodule









