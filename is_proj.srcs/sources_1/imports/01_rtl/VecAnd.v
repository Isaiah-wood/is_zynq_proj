// ============================================================================
// VecAnd
//  - 输入两个向量，逐位与运算
// ============================================================================

`timescale 1ns / 1ps
module VecAnd #(
    parameter integer VEC_WIDTH = 1100
) (
    input wire clk,
    input wire rst_n,
    input wire [VEC_WIDTH-1:0] img_vec,
    input wire [VEC_WIDTH-1:0] lib_vec,
    input wire in_valid,
    output wire out_valid,
    output wire this_ready,
    input wire next_ready,
    output wire [VEC_WIDTH-1:0] and_vec
);
    // ----------------------------
    // 向量与运算
    // ----------------------------
    reg [VEC_WIDTH-1:0] and_vec_reg;
    assign and_vec = and_vec_reg;
    reg and_vec_valid_reg;
    // valid/ready 信号
    assign out_valid = and_vec_valid_reg;
    assign this_ready = (~and_vec_valid_reg) || next_ready;




    always @(posedge clk) begin
        if (!rst_n) begin
            and_vec_reg <= {VEC_WIDTH{1'b0}};
            and_vec_valid_reg <= 1'b0;
        end else if (this_ready) begin
            and_vec_reg <= img_vec & lib_vec;
            and_vec_valid_reg <= in_valid;
        end
    end


endmodule
