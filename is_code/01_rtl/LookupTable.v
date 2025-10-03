`timescale 1ns / 1ps
`include "config.vh"

module LookupTable #(
    parameter integer DIN_WIDTH    = `CFG_LUT_IN_WIDTH,
    parameter integer DOUT_WIDTH   = `CFG_LUT_OUT_WIDTH
) (
    input  wire [DIN_WIDTH-1:0]      din,
    output wire [DOUT_WIDTH-1:0]     dout
);
    localparam integer DEPTH        = (1 << DIN_WIDTH);          // 2 ^ DIN_WIDTH

    // 优先综合为分布式 ROM（LUT）
    (* rom_style = "distributed", ram_style = "distributed" *) reg [DOUT_WIDTH-1:0] lut_table [0:DEPTH-1];

    // 初始化 LUT（综合为常量表）
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            lut_table[i] = lookup(i[DIN_WIDTH-1:0]);
        end
    end

    // 组合输出（读取 LUT）
    assign dout = lut_table[din];




    // 给存储器赋初值的initial是可综合的
    function [DOUT_WIDTH-1:0] lookup;
        input [DIN_WIDTH-1:0] v;
        integer j;
        begin
            lookup = {DOUT_WIDTH{1'b0}};
            for (j = 0; j < DIN_WIDTH; j = j + 1)
                lookup = lookup + v[j];
        end
    endfunction

endmodule
