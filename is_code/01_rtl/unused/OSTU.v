`timescale 1ns / 1ps
`include "config.vh"

// ============================================================================
// OSTU模块：根据输入的IMG_VEC_N个max_value，计算最大类间方差阈值
// 输入：max_value_stream（流式输入，或可改为并行输入）
// 输出：ostu_threshold

module OSTU #(
    parameter integer IMG_VEC_N = `CFG_IMG_VEC_NUM,
    parameter integer VALUE_WIDTH = `CFG_VEC_WIDTH
) (
    input  wire clk,
    input  wire rst_n,
    input  wire in_valid,
    input  wire [VALUE_WIDTH-1:0] max_value_in,
    input  wire in_last, // 输入最后一个标志
    output reg  [VALUE_WIDTH-1:0] ostu_threshold,
    output reg  out_valid
);

    // 直方图统计
    reg [15:0] hist [0:(1<<VALUE_WIDTH)-1];
    reg [$clog2(IMG_VEC_N):0] total_cnt;
    integer i;

    // 状态机：0-收集，1-计算，2-输出
    reg [1:0] state;
    reg [VALUE_WIDTH-1:0] t, best_t;
    reg [31:0] max_var;

    // 统计输入
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < (1<<VALUE_WIDTH); i = i + 1) hist[i] <= 0;
            total_cnt <= 0;
            state <= 0;
        end else begin
            case (state)
                0: begin // 收集max_value
                    if (in_valid) begin
                        hist[max_value_in] <= hist[max_value_in] + 1;
                        total_cnt <= total_cnt + 1;
                        if (in_last) state <= 1;
                    end
                end
                1: begin // 计算OSTU
                    // 这里只做骨架，实际应流水展开
                    // 伪代码：遍历t，计算类间方差，找最大
                    // 可用外部控制或多周期实现
                    state <= 2;
                end
                2: begin
                    out_valid <= 1;
                    ostu_threshold <= best_t;
                    state <= 0;
                end
            endcase
        end
    end

    // 类间方差计算（建议用外部控制或多周期展开，这里仅为结构示例）
    // ...实际实现需补充...

endmodule
