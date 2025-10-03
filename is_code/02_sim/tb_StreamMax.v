`timescale 1ns / 1ps
`include "../01_rtl/config.vh"



module tb_StreamMax;
    parameter IMG_VEC_N = 3;
    parameter LIB_VEC_N = 5;
    parameter VEC_WIDTH = 48;
    reg clk, rst_n;
    reg in_valid;
    wire this_ready;
    wire out_valid;
    reg nest_ready;
    reg inner_done, outer_done, indone_valid, outdone_valid;
    reg [$clog2(VEC_WIDTH+1)-1:0] in_data, norm_data;
    wire [$clog2(VEC_WIDTH)-1:0] max_index;
    wire [$clog2(VEC_WIDTH+1)-1:0] max_value;
    wire out_last;

    // DUT实例化
    StreamMax #(
        .IMG_VEC_N(IMG_VEC_N),
        .LIB_VEC_N(LIB_VEC_N),
        .VEC_WIDTH(VEC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .this_ready(this_ready),
        .out_valid(out_valid),
        .nest_ready(nest_ready),
        .inner_done(inner_done),
        .outer_done(outer_done),
        .indone_valid(indone_valid),
        .outdone_valid(outdone_valid),
        .in_data(in_data),
        .norm_data(norm_data),
        .max_index(max_index),
        .max_value(max_value),
        .out_last(out_last)
    );

    // 时钟
    initial clk = 0;
    always #5 clk = ~clk;

    // 激励
    integer i, j;
    reg [$clog2(VEC_WIDTH+1)-1:0] test_data [0:IMG_VEC_N-1][0:LIB_VEC_N-1];
    reg [$clog2(VEC_WIDTH+1)-1:0] test_norm [0:IMG_VEC_N-1][0:LIB_VEC_N-1];
    reg [$clog2(VEC_WIDTH+1)-1:0] test_target [0:IMG_VEC_N-1][0:LIB_VEC_N-1];

    initial begin
        $dumpfile("waveform.vcd");   // VCD 文件名
        $dumpvars(1, tb_StreamMax);              // 只记录顶层信号
        $dumpvars(2, tb_StreamMax.dut);          // 记录DUT的信号
        $dumpon;                                 // 开始记录


        rst_n = 0;
        in_valid = 0;
        nest_ready = 1;
        inner_done = 0;
        outer_done = 0;
        indone_valid = 0;
        outdone_valid = 0;
        in_data = 0;
        norm_data = 0;
        #20;
        rst_n = 1;
        #10;
        // 构造测试数据
        for (i = 0; i < IMG_VEC_N; i = i + 1) begin
            for (j = 0; j < LIB_VEC_N; j = j + 1) begin
                
                // 方案1：简单递增数据便于调试
                test_data[i][j] = i * LIB_VEC_N + j + 1;    
                test_norm[i][j] = (i + 1) * (j + 1);
                // test_data[i][j] = $random % (VEC_WIDTH+1);
                // test_norm[i][j] = $random % (VEC_WIDTH+1);
            end
        end
        // 送入多行数据
        for (i = 0; i < IMG_VEC_N; i = i + 1) begin
            for (j = 0; j < LIB_VEC_N; j = j + 1) begin
                @(negedge clk);
                in_valid = 1;
                in_data = test_data[i][j];
                norm_data = test_norm[i][j];
                indone_valid = 0;
                inner_done = 0;
                if (j == 3) begin
                    indone_valid = 1;
                    inner_done = 1;
                end
            end
            @(negedge clk);
            in_valid = 0;
            indone_valid = 0;
            inner_done = 0;
        end
        // 送outer_done
        @(negedge clk);
        outdone_valid = 1;
        outer_done = 1;
        @(negedge clk);
        outdone_valid = 0;
        outer_done = 0;
        // 等待输出
        wait(out_valid);
        while (!out_last) begin
            @(negedge clk);
        end
        #20;
        $dumpoff;                                // 停止记录
        $finish;
    end

    // 输出监控
    always @(posedge clk) begin
        if (out_valid) begin
            $display("[OUT] max_value=%0d, max_index=%0d, out_last=%b", max_value, max_index, out_last);
        end
    end
endmodule
