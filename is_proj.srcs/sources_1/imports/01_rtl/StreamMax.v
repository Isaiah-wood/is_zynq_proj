`timescale 1ns / 1ps
`include "config.vh"


// ============================================================================


module StreamMax #(
    parameter integer IMG_VEC_N = `CFG_IMG_VEC_NUM,
    parameter integer LIB_VEC_N = `CFG_LIB_VEC_NUM,
    parameter integer VEC_WIDTH = `CFG_VEC_WIDTH,
    parameter integer LUT_WIDTH = `CFG_LUT_IN_WIDTH
) (
    input wire clk,
    input wire rst_n,

    input  wire in_valid,   
    output wire this_ready, 
    output wire out_valid,  
    input  wire nest_ready, 

    input wire inner_done,
    input wire outer_done,
    input wire indone_valid,
    input wire outdone_valid,

    input  wire [$clog2(VEC_WIDTH+1)-1:0] in_data,  // 输入数据
    input  wire [$clog2(VEC_WIDTH+1)-1:0] norm_data,
    output reg  [$clog2(VEC_WIDTH)-1:0] max_index,
    output reg  [$clog2(VEC_WIDTH+1)-1:0] max_value,
    output wire  out_last  // 输出最后一个标志
);




    // 状态寄存器
    reg [$clog2(VEC_WIDTH+1)-1:0] cur_max_value;
    reg [$clog2(VEC_WIDTH+1)-1:0] cur_max_in_data;
    reg [$clog2(VEC_WIDTH)-1:0] cur_max_index;
    reg [$clog2(VEC_WIDTH)-1:0] cur_index;
    reg [$clog2(IMG_VEC_N)-1:0] line_cnt;
    reg [$clog2(IMG_VEC_N)-1:0] out_cnt;
    reg out_valid_r;
    reg out_last_r;

    // 存储每行最大值和序号
    reg [$clog2(VEC_WIDTH+1)-1:0] max_value_mem [0:IMG_VEC_N-1];
    reg [$clog2(VEC_WIDTH)-1:0] max_index_mem [0:IMG_VEC_N-1];

    // 最大值比较与索引递增
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_max_value <= 0;
            cur_max_in_data <= 0;
            cur_max_index <= 0;
            cur_index <= 0;
        end else if (in_valid) begin
            if ((cur_index == 0) || (norm_data > cur_max_value) ||
                ((norm_data == cur_max_value) && (in_data > cur_max_in_data))) begin
                cur_max_value <= norm_data;
                cur_max_in_data <= in_data;
                cur_max_index <= cur_index;
            end
            cur_index <= cur_index + 1;
        end else if (indone_valid && inner_done) begin
            cur_index <= 0;
            cur_max_value <= 0;
            cur_max_in_data <= 0;
            cur_max_index <= 0;
        end
    end

    // 行结束，保存最大值和序号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_cnt <= 0;
            // max_value_mem and max_index_mem initialization
            for (integer i = 0; i < IMG_VEC_N; i = i + 1) begin
                max_value_mem[i] <= 0;
                max_index_mem[i] <= 0;
            end
        end else if (indone_valid && inner_done) begin
            max_value_mem[line_cnt] <= cur_max_value;
            max_index_mem[line_cnt] <= cur_max_index;
            line_cnt <= line_cnt + 1;
        end else if (outdone_valid && outer_done) begin
            line_cnt <= 0;
        end
    end

    // 输出控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_cnt <= 0;
            out_valid_r <= 0;
            out_last_r <= 0;
        end else if (outdone_valid && outer_done) begin
            out_cnt <= 0;
            out_valid_r <= 1;
            out_last_r <= 0;
        end else if (out_valid_r && nest_ready) begin
            if (out_cnt == IMG_VEC_N-1) begin
                out_last_r <= 1;
                out_valid_r <= 0;
            end else begin
                out_cnt <= out_cnt + 1;
            end
        end
    end

    // 输出数据
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_value <= 0;
            max_index <= 0;
        end else if (out_valid_r && nest_ready) begin
            max_value <= max_value_mem[out_cnt];
            max_index <= max_index_mem[out_cnt];
        end
    end

    assign out_valid = out_valid_r;
    assign out_last = out_last_r;
    assign this_ready = 1'b1; // 可根据实际需求调整

endmodule
