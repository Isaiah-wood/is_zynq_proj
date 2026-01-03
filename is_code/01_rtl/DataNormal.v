// ============================================================================
// DataNormal.v
//  - 数据归一化模块，将输入数据流根据归一化系数进行归一化处理
// ============================================================================



`timescale 1ns / 1ps
module DataNormal #(
    parameter integer DIN_WIDTH = 11,
    parameter integer FACTOR_WIDTH = 11,
    parameter integer DOUT_WIDTH = 11
) (
    input wire clk,
    input wire rst_n,
    input wire in_valid,
    output wire this_ready,
    output wire out_valid,
    input wire next_ready,
    input wire [DIN_WIDTH-1:0] in_data,
    input wire [FACTOR_WIDTH-1:0] norm_factor,
    output wire [DOUT_WIDTH-1:0] out_data
);
    // 输出寄存
    reg [DOUT_WIDTH-1:0] out_data_reg;
    reg out_valid_reg;

    // 归一化计算
    localparam NORM_WIDTH = DIN_WIDTH + FACTOR_WIDTH;
    wire [NORM_WIDTH-1:0] norm_data;
    assign norm_data = (in_data >= norm_factor) ? (in_data * norm_factor) : {(NORM_WIDTH){1'b0}};

    // 输出寄存逻辑
    always @(posedge clk) begin
        if (!rst_n) begin
            out_data_reg <= {DOUT_WIDTH{1'b0}};
            out_valid_reg <= 1'b0;
        end else if (this_ready && in_valid) begin
            out_data_reg <= norm_data[NORM_WIDTH-1 -: DOUT_WIDTH];
            out_valid_reg <= 1'b1;
        end else if (next_ready) begin
            out_valid_reg <= 1'b0;
        end
    end

    // 输出接口连接
    assign out_data = out_data_reg;
    assign out_valid = out_valid_reg;
    assign this_ready = (~out_valid_reg) || next_ready;
endmodule