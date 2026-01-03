// ============================================================================
// LUT6_Popcount
//  - 输入 DIN_WIDTH 位宽的向量，输出其中 1 的个数（DOUT_WIDTH 位宽）
//  - 纯组合逻辑，无时序
// ============================================================================

`timescale 1ns / 1ps

module LUT6_Popcount #(
    parameter integer DIN_WIDTH    = 6,
    parameter integer DOUT_WIDTH   = $clog2(DIN_WIDTH+1)
) (
    input  wire [DIN_WIDTH-1:0]      din,
    output wire [DOUT_WIDTH-1:0]     dout
);
    // ========== 参数断言：基于LUT6的查找表，输入宽度应当 <= 6 ==========
    initial begin
        if (DIN_WIDTH > 6) begin
            $fatal("LookupTable: DIN_WIDTH must be <=6 to avoid too large LUT");
        end
    end


    // 初始化 LUT（综合为常量表）
    localparam integer DEPTH = (1 << DIN_WIDTH);          // 2 ^ DIN_WIDTH
    (* rom_style = "distributed", ram_style = "distributed" *) reg [DOUT_WIDTH-1:0] lut_table [0:DEPTH-1];
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            lut_table[i] = lookup(i[DIN_WIDTH-1:0]);
        end
    end


    // 组合输出（读取 LUT）
    assign dout = lut_table[din];


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
