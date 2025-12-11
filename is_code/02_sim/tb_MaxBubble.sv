`timescale 1ns / 1ps

module tb_MaxBubble;
    localparam CLK_PERIOD   = 10;
    localparam DATA_WIDTH   = 11;
    localparam DATA_NUM     = 15486;
    localparam INDEX_WIDTH  = $clog2(DATA_NUM);

    logic clk;
    logic rst_n;

    logic in_valid;
    logic this_ready;
    logic out_valid;
    logic next_ready;

    logic [DATA_WIDTH-1:0] in_data;
    logic in_last;

    logic [DATA_WIDTH-1:0] max_data;
    logic [INDEX_WIDTH-1:0] max_index;

    MaxBubble #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_NUM(DATA_NUM),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .this_ready(this_ready),
        .out_valid(out_valid),
        .next_ready(next_ready),
        .in_data(in_data),
        .in_last(in_last),
        .max_data(max_data),
        .max_index(max_index)
    );

    // clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // random downstream readiness (70% ready)
    always @(posedge clk) begin
        if (!rst_n) begin
            next_ready <= 1'b1;
        end else begin
            next_ready <= ($urandom_range(0, 99) < 70);
        end
    end

    // drive a single beat, hold until握手完成
    task automatic send_word(
        input logic [DATA_WIDTH-1:0] d,
        input logic                  last
    );
        begin
            while (1) begin
                @(negedge clk);
                in_valid <= 1'b1;
                in_data  <= d;
                in_last  <= last;
                if (this_ready) begin
                    @(posedge clk); // 完成握手
                    break;
                end
            end
            @(negedge clk);
            in_valid <= 1'b0;
            in_last  <= 1'b0;
        end
    endtask

    // 期望队列
    int expected_max_q[$];
    int expected_idx_q[$];
    int pass_cnt = 0;
    int fail_cnt = 0;

    // 发送一帧
    task automatic drive_frame(input int frame_len);
        int max_val;
        int max_idx;
        bit first;
        logic [DATA_WIDTH-1:0] sample;
        begin
            first   = 1'b1;
            max_val = 0;
            max_idx = 0;
            for (int i = 0; i < frame_len; i++) begin
                sample = $urandom_range((1<<DATA_WIDTH)-1, 0);
                send_word(sample, (i == frame_len-1));
                if (first || sample > max_val) begin
                    max_val = sample;
                    max_idx = i;
                    first   = 1'b0;
                end
                if (i == frame_len-1) begin
                    expected_max_q.push_back(max_val);
                    expected_idx_q.push_back(max_idx);
                    $display("[FRAME] len=%0d exp_max=%0d exp_idx=%0d", frame_len, max_val, max_idx);
                end
            end
        end
    endtask

    // 输出检查
    always @(posedge clk) begin
        if (!rst_n) begin
            // do nothing
        end else if (out_valid && next_ready) begin
            if (expected_max_q.size() == 0) begin
                $display("[ERROR] Unexpected output: max=%0d idx=%0d", max_data, max_index);
                fail_cnt++;
            end else begin
                int exp_max = expected_max_q.pop_front();
                int exp_idx = expected_idx_q.pop_front();
                if ((max_data === exp_max[DATA_WIDTH-1:0]) && (max_index === exp_idx[INDEX_WIDTH-1:0])) begin
                    $display("[PASS] max=%0d idx=%0d", max_data, max_index);
                    pass_cnt++;
                end else begin
                    $display("[FAIL] got max=%0d idx=%0d, exp max=%0d idx=%0d", max_data, max_index, exp_max, exp_idx);
                    fail_cnt++;
                end
            end
        end
    end

    // 主流程
    initial begin
        clk       = 0;
        rst_n     = 0;
        in_valid  = 0;
        in_last   = 0;
        in_data   = 0;
        next_ready = 1;

        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("[TEST 1] Reset Complete");

        // 单拍帧（特殊情况：只有一个数据，in_last=1）
        $display("[TEST 2] Single beat frame");
        drive_frame(1);
        repeat(5) @(posedge clk);

        // 短帧
        $display("[TEST 3] Short frame (3 beats)");
        drive_frame(3);
        repeat(5) @(posedge clk);

        // 中等帧
        $display("[TEST 4] Medium frame (10 beats)");
        drive_frame(10);
        repeat(5) @(posedge clk);

        // 随机长度帧
        $display("[TEST 5] Random frames");
        for (int k = 0; k < 5; k++) begin
            drive_frame($urandom_range(2, 20));
            repeat(3) @(posedge clk);
        end

        // 等待所有输出完成
        repeat(100) @(posedge clk);

        $display("========================================");
        $display("Test Results:");
        $display("  PASS=%0d", pass_cnt);
        $display("  FAIL=%0d", fail_cnt);
        $display("  REMAIN=%0d (expected outputs not received)", expected_max_q.size());
        $display("========================================");

        if (fail_cnt == 0 && expected_max_q.size() == 0) begin
            $display("[SUCCESS] All tests passed!");
        end else begin
            $display("[FAILURE] Some tests failed or outputs missing!");
        end

        $finish;
    end
endmodule
