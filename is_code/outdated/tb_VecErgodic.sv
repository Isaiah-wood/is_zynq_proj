`timescale 1ns/1ps


module tb_VecErgodic;
    // 常量配置
    localparam integer IMG_VEC_N = 5;
    localparam integer LIB_VEC_N = 20;

    // 时钟与复位信号
    logic clk;
    logic rst_n;
    always #5 clk = ~clk;


	// DUT 接口
    logic start;
    logic ready;
    logic valid;
    logic [$clog2(IMG_VEC_N)-1:0] img_addr;
    logic [$clog2(LIB_VEC_N)-1:0] lib_addr;
    logic inner_done;
    logic outer_done;


    // 复位与初值
    initial begin
        clk = 0;
        rst_n = 0;
        start = 0;
        ready = 0;
        
		repeat (5) @(posedge clk); 
        rst_n = 1;
		repeat (5) @(posedge clk);
        start = 1;
		repeat (2) @(posedge clk);
        start = 0;
        
        repeat (2) @(posedge clk);
        ready = 1;
		repeat (5) @(posedge clk);
        ready = 0;
        repeat (2) @(posedge clk);
        ready = 1;
		repeat (5) @(posedge clk);
		#2;
        ready = 0;
        repeat (2) @(posedge clk);
		#2;
        ready = 1;

    end

    // 仿真结束条件
    initial begin
        wait(outer_done);
		repeat (10) @(posedge clk);
        $finish;
    end

    // 例化
    VecErgodic #(
        .IMG_VEC_N(IMG_VEC_N),
        .LIB_VEC_N(LIB_VEC_N)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .ready(ready),
        .valid(valid),
        .img_addr(img_addr),
        .lib_addr(lib_addr),
        .linefeed(inner_done),
        .finish(outer_done)
    );








endmodule