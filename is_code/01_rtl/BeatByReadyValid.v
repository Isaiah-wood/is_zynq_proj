

`timescale 1ns / 1ps


module BeatByReadyValid(
    input wire clk,
    input wire rst_n,
    input wire combout,
    input wire combout_valid,
    output reg beatout,
    output wire beatout_valid,
    output wire this_ready,
    input wire next_ready
);
    reg beatout_valid_reg;
    assign beatout_valid = beatout_valid_reg;
    assign this_ready = (~beatout_valid) || next_ready;

    always @(posedge clk) begin
        if (!rst_n) begin
            beatout <= 1'b0;
            beatout_valid_reg <= 1'b0;
        end else begin
            if (this_ready) begin
                beatout <= combout;
                beatout_valid_reg <= combout_valid;
            end
        end
    end

endmodule
