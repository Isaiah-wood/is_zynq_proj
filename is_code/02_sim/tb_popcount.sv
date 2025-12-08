`timescale 1ns/1ps
// 相对本文件位置包含配置头
`include "../01_rtl/config.vh"

module tb_popcount;
	// 导入配置参数
	localparam int VEC_WIDTH     = `CFG_VEC_WIDTH;
	localparam int POPCNT_WIDTH  = `CFG_VEC_POPCOUNT_WIDTH;

	// 时钟与复位
	logic clk = 1'b0;
	logic rst_n = 1'b0;
	always #5 clk = ~clk; // 100MHz

	// DUT 接口
	logic                     in_valid;
	wire                      in_ready;
	logic [VEC_WIDTH-1:0]     vec;

	wire                      out_valid;
	logic                     out_ready;
	wire  [POPCNT_WIDTH-1:0]  popcount;

		// 待发送与接收计数、计分板
	typedef logic [POPCNT_WIDTH-1:0] cnt_t;
	cnt_t exp_q[$];
	int   sent_cnt;
	int   recv_cnt;
	int   err_cnt;

	// 用例规模：从 1 开始，每次左移并在 LSB 补 1，持续 VEC_WIDTH 次（得到 1,3,7,... 直至全 1）
	localparam int NUM_CASES = VEC_WIDTH;

	// 输入序列采用累积 1 的模式，无需随机/交替生成函数

	// 计算 popcount（避免依赖 $countones，以兼容性为主）
	function automatic cnt_t popcnt(logic [VEC_WIDTH-1:0] v);
		cnt_t acc;
		int i;
		begin
			acc = '0;
			for (i = 0; i < VEC_WIDTH; i++) begin
				acc = acc + v[i];
			end
			return acc;
		end
	endfunction

	// 复位与初值
	initial begin
		in_valid  = 1'b0;
		vec       = '0;
		out_ready = 1'b0;
		sent_cnt  = 0;
		recv_cnt  = 0;
		err_cnt   = 0;

		// 释放复位
		repeat (5) @(posedge clk);
		rst_n = 1'b1;
	end

	// 固定序列回压：0,1,1 重复（约 2/3 就绪）
	logic [1:0] rdy_cnt;
	always_ff @(posedge clk) begin
		if (!rst_n) begin
			rdy_cnt  <= 2'd0;
			out_ready <= 1'b0;
		end else begin
			rdy_cnt  <= (rdy_cnt == 2) ? 2'd0 : (rdy_cnt + 2'd1);
			out_ready <= (rdy_cnt != 2'd0);
		end
	end

	// 当前待发送向量
	logic [VEC_WIDTH-1:0] curr_vec;

		// 生成输入事务，并在被接受 (in_valid && in_ready) 时入队期望值
	always_ff @(posedge clk) begin
		if (!rst_n) begin
			in_valid <= 1'b0;
			sent_cnt <= 0;
				curr_vec <= '0;
		end else begin
				// 初次装载：序列从 1 开始
				if (!in_valid && sent_cnt < NUM_CASES) begin
					curr_vec <= {{(VEC_WIDTH-1){1'b0}}, 1'b1};
					in_valid <= 1'b1;
				end

				// 仅在真正握手时推进并记录期望
				if (in_valid && in_ready) begin
					exp_q.push_back(popcnt(curr_vec));
					sent_cnt <= sent_cnt + 1;
					if (sent_cnt + 1 < NUM_CASES) begin
						// 下一项：左移并在 LSB 补 1（限制在位宽内）
						curr_vec <= {curr_vec[VEC_WIDTH-2:0], 1'b1};
					end else begin
						in_valid <= 1'b0; // 已发完
					end
				end
		end
	end

	// 接收与比对
	always_ff @(posedge clk) begin
		if (!rst_n) begin
			recv_cnt <= 0;
			err_cnt  <= 0;
		end else if (out_valid && out_ready) begin
			cnt_t exp;
			if (exp_q.size() == 0) begin
				$error("Scoreboard underflow: no expected value but got output %0d", popcount);
				err_cnt <= err_cnt + 1;
			end else begin
				exp = exp_q.pop_front();
				if (popcount !== exp) begin
					$error("Mismatch at recv %0d: got %0d, expect %0d", recv_cnt, popcount, exp);
					err_cnt <= err_cnt + 1;
				end
			end
			recv_cnt <= recv_cnt + 1;
		end
	end

	// 结束条件：收满 + 额外等待若干拍，打印总结
	initial begin
		wait (rst_n);
		wait (recv_cnt == NUM_CASES);
		repeat (10) @(posedge clk);
		$display("\n==== Popcount TB Summary ====");
		$display("Sent: %0d, Received: %0d, Errors: %0d", sent_cnt, recv_cnt, err_cnt);
		if (err_cnt == 0) begin
			$display("RESULT: PASS");
		end else begin
			$display("RESULT: FAIL");
		end
		$finish;
	end

		// DUT 实例
	Popcount dut (
		.clk       (clk),
		.rst_n     (rst_n),
		.in_valid  (in_valid),
		.this_ready  (in_ready),
		.vec       (vec),
		.out_valid (out_valid),
		.next_ready (out_ready),
		.popcount  (popcount)
	);

		// 组合驱动：确保在握手采样的时钟沿，vec 已是当拍的 curr_vec
		assign vec = in_valid ? curr_vec : '0;

endmodule

