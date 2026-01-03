// ==========================================================
//* @title 通用计数器
//* @author Isaiah-wood
//*  - 可配置宽度的计数器模块，支持置位、使能和进位信号
// ==========================================================

`timescale 1ns / 1ps
module Counter #(
    parameter integer COUNT_CLEAR = 0,          //* 计数清零值
    parameter integer COUNT_LOAD = 0,           //* 计数置位值
    parameter integer COUNT_NUM = 256,          //* 计数最大值
    parameter integer COUNT_WIDTH = $clog2(COUNT_NUM)  //* 计数宽度
) (
    input wire clk,
    input wire rst_n,

    input wire en,              //* 计数使能
    input wire load,            //* 计数置位
    output wire carry,          //* 计数进位, 结束计数标志

    output reg [COUNT_WIDTH-1:0] cnt    //* 当前计数值
);
    localparam integer COUNT_MAX = COUNT_NUM - 1;
    // 计数逻辑
    wire [COUNT_WIDTH-1:0] cnt_clr = COUNT_CLEAR;
    wire [COUNT_WIDTH-1:0] cnt_load = COUNT_LOAD;
    wire cnt_add;               //* 计数加一标志
    wire cnt_end;               //* 计数结束标志
    always @(posedge clk) begin : counter
        if (!rst_n) begin
            cnt <= cnt_clr;
        end else if (load) begin
            cnt <= cnt_load;
        end else if (cnt_add) begin
                if (cnt_end) begin
                    cnt <= cnt_clr;
                end else begin
                    cnt <= cnt + 1;
                end
        end
    end

    assign cnt_add = en;
    assign cnt_end = cnt_add && (cnt == COUNT_MAX);
    assign carry = (cnt == COUNT_MAX);
endmodule
