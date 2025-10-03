`timescale 1ns / 1ps
`include "config.vh"
// 变换模块：遍历图向量（外循环）与库向量（内循环）的组合

module VecErgodic #(
    parameter integer IMG_VEC_N = `CFG_IMG_VEC_NUM,
    parameter integer LIB_VEC_N = `CFG_LIB_VEC_NUM
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         start,             // 启动脉冲
    input  wire                         ready,          // 为0时背压暂停
    output wire                         valid,         // 数据有效信号

    output reg [$clog2(IMG_VEC_N)-1:0] img_addr,
    output reg [$clog2(LIB_VEC_N)-1:0] lib_addr,
    
    output wire                        linefeed,
    output wire                        finish
);
    // 最后一个库地址和最后一个图像地址
    wire last_lib_addr   = (lib_addr == LIB_VEC_N - 1);
    wire last_img_addr   = (img_addr == IMG_VEC_N - 1);


    reg running;
    // 数据有效信号running（正运行标志），随着start信号拉高而拉高，随着计数结束而恢复
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running <= 1'b0;
        end else if (!running && start) begin
            running <= 1'b1;
        end else if (finish) begin
            running <= 1'b0;
        end
    end
    assign valid = running;


    // img_addr作为外循环，lib_addr作为内循环遍历访问所有向量，使用双重计数器实现
    wire add_lib_addr, end_lib_addr;
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
    assign add_lib_addr = valid && ready;                       // 模块启动且后级ready才开始计数
    assign end_lib_addr = add_lib_addr && last_lib_addr;        // 计数到头结束

    wire add_img_addr, end_img_addr;
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
    assign add_img_addr = end_lib_addr;                         // 内循环结束时，开始外循环计数+1
    assign end_img_addr = add_img_addr && last_img_addr;        // 计数到头结束

    assign linefeed = end_lib_addr;
    assign finish = end_img_addr;



endmodule









