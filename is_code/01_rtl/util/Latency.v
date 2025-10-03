module Latency #(
    parameter integer DATA_WIDTH = 8,
    parameter integer LATENCY    = 4
) (
    input wire clk,
    input wire rst_n,

    input wire [DATA_WIDTH-1:0] din,

    output wire [DATA_WIDTH-1:0] dout
);
    reg [DATA_WIDTH-1:0] pipe[0:LATENCY-1];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < LATENCY; i = i + 1) begin
                pipe[i] <= {LATENCY{1'b0}};
            end
        end else begin
            pipe[0] <= din;
            for (i = 1; i < LATENCY; i = i + 1) begin
                pipe[i] <= pipe[i-1];
            end
        end
    end

    assign dout = pipe[LATENCY-1];

endmodule
