`timescale 1ns/1ps
`include "../01_rtl/config.vh"

module tb_VecMatch;
	// 参数配置，建议与config.vh保持一致
	localparam integer IMG_VEC_N = `CFG_IMG_VEC_NUM;
	localparam integer LIB_VEC_N = `CFG_LIB_VEC_NUM;
	localparam integer VEC_WIDTH = `CFG_VEC_WIDTH;
	localparam integer COEFF_WIDTH = `CFG_COEFF_WIDTH;
	localparam integer OUTW = $clog2(VEC_WIDTH+1);

	// 时钟与复位
	reg clk = 0;
	always #5 clk = ~clk;
	reg rst_n = 0;

	// DUT接口
	reg  start = 0;
	reg  out_ready = 1;
	wire out_valid;
	wire inner_done;
	wire outer_done;
	wire [OUTW-1:0] out_data;
	wire [OUTW-1:0] norm_data;

	// 例化DUT
	VecMatch #(
		.IMG_VEC_N(IMG_VEC_N),
		.LIB_VEC_N(LIB_VEC_N),
		.VEC_WIDTH(VEC_WIDTH),
		.COEFF_WIDTH(COEFF_WIDTH)
	) dut (
		.clk(clk),
		.rst_n(rst_n),
		.start(start),
		.out_valid(out_valid),
		.next_ready(out_ready),
		.inner_done(inner_done),
		.outer_done(outer_done),
		.out_data(out_data),
		.norm_data(norm_data)
	);

	// 激励与背压
	initial begin
		rst_n = 0; start = 0; out_ready = 1;
		repeat (5) @(posedge clk);
		rst_n = 1; @(posedge clk);
		// 启动一次
		start = 1; @(posedge clk); start = 0;
		// 运行一段时间后施加背压
		repeat (20) @(posedge clk);
		out_ready = 0; repeat (5) @(posedge clk);
		out_ready = 1; repeat (10) @(posedge clk);
		out_ready = 0; repeat (3) @(posedge clk);
		out_ready = 1;
	end

	// 监控输出
	integer cnt = 0;
	always @(posedge clk) begin
		if (rst_n && out_valid && out_ready) begin
			$display("[T=%0t] OUT: data=%0d inner_done=%b outer_done=%b", $time, out_data, inner_done, outer_done);
			cnt = cnt + 1;
		end
	end

	// 仿真结束条件
	initial begin
		wait(rst_n);
		wait(outer_done);
		repeat (5) @(posedge clk);
		$display("\n==== tb_VecMatch Summary ====\nTotal output count: %0d", cnt);
		$finish;
	end

endmodule
