`timescale 1ns / 1ps

module tb_VecPopcount ();
    localparam CLK_PERIOD = 10;
    localparam VEC_WIDTH = 1100;
    localparam LUT_WIDTH = 6;
    localparam POPCNT_WIDTH = $clog2(VEC_WIDTH+1);
    localparam PIPELINE_DEPTH = $clog2((VEC_WIDTH + LUT_WIDTH - 1) / LUT_WIDTH) + 1; // 流水线深度 = 9
    
    // Signals
    logic clk;
    logic rst_n;
    logic [VEC_WIDTH-1:0] vec;
    logic in_valid;
    logic out_valid;
    logic this_ready;
    logic next_ready;
    logic [POPCNT_WIDTH-1:0] popcount;
    logic [POPCNT_WIDTH-1:0] expected_popcount;
    
    // 用数组记录实际成功握手的输入数据和期望值
    logic [POPCNT_WIDTH-1:0] expected_array[100]; // 最多缓存100个握手成功的输入
    int input_handshake_count = 0;   // 记录成功握手的输入个数
    int output_handshake_count = 0;  // 记录成功输出的个数
    
    // Instantiate DUT
    VecPopcount #(
        .VEC_WIDTH(VEC_WIDTH),
        .LUT_WIDTH(LUT_WIDTH),
        .POPCNT_WIDTH(POPCNT_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .vec(vec),
        .in_valid(in_valid),
        .out_valid(out_valid),
        .this_ready(this_ready),
        .next_ready(next_ready),
        .popcount(popcount)
    );
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Helper function to count 1s in a vector
    function automatic int count_ones(logic [VEC_WIDTH-1:0] v);
        int cnt = 0;
        for (int i = 0; i < VEC_WIDTH; i++) begin
            if (v[i]) cnt++;
        end
        return cnt;
    endfunction
    
    // Test stimulus and monitor
    initial begin
        clk = 0;
        rst_n = 0;
        vec = 0;
        in_valid = 0;
        next_ready = 1;
        
        // Test 1: Reset test
        #(CLK_PERIOD * 2);
        rst_n = 1;
        $display("[TEST 1] Reset Complete");
        
        // Test 2: All zeros
        #CLK_PERIOD;
        @(negedge clk);
        vec = {VEC_WIDTH{1'b0}};
        in_valid <= 1;
        expected_popcount = 0;
        $display("[TEST 2] Input: All zeros, Expected popcount: %d", expected_popcount);
        @(negedge clk);
        in_valid <= 0;
        
        // Test 3: All ones
        #CLK_PERIOD;
        @(negedge clk);
        vec = {VEC_WIDTH{1'b1}};
        in_valid <= 1;
        expected_popcount = VEC_WIDTH;
        $display("[TEST 3] Input: All ones, Expected popcount: %d", expected_popcount);
        @(negedge clk);
        in_valid <= 0;
        
        // Test 4: Random pattern 1
        #CLK_PERIOD;
        @(negedge clk);
        vec = {VEC_WIDTH{1'b0}};
        // Set some bits
        for (int i = 0; i < VEC_WIDTH; i += 7) begin
            vec[i] = 1'b1;
        end
        in_valid <= 1;
        expected_popcount = count_ones(vec);
        $display("[TEST 4] Input: Pattern 1 (every 7th bit), Expected popcount: %d", expected_popcount);
        @(negedge clk);
        in_valid <= 0;
        
        // Test 5: Random pattern 2
        #CLK_PERIOD;
        @(negedge clk);
        vec = {VEC_WIDTH{1'b0}};
        // Set alternating bits
        for (int i = 0; i < VEC_WIDTH; i += 2) begin
            vec[i] = 1'b1;
        end
        in_valid <= 1;
        expected_popcount = count_ones(vec);
        $display("[TEST 5] Input: Pattern 2 (alternating bits), Expected popcount: %d", expected_popcount);
        @(negedge clk);
        in_valid <= 0;
        
        // Test 6: Backpressure test - next_ready=0
        #CLK_PERIOD;
        @(negedge clk);
        vec = 128'hAAAA_AAAA_AAAA_AAAA;
        in_valid <= 1;
        next_ready <= 0;  // Apply backpressure
        expected_popcount = count_ones(vec);
        $display("[TEST 6] Input: With backpressure (next_ready=0), Expected popcount: %d", expected_popcount);
        $display("  [Applying backpressure, will keep input valid until released]");
        
        // Wait a few cycles with backpressure while keeping input valid
        repeat(3) begin
            @(negedge clk);
            vec = 128'hAAAA_AAAA_AAAA_AAAA;
            in_valid <= 1;
            next_ready <= 0;
        end
        
        // Release backpressure
        next_ready <= 1;
        #(CLK_PERIOD);
        @(negedge clk);
        // input will be recorded by handshake monitor
        in_valid <= 0;
        
        // Test 7: Continuous stream test (3 连续输入)
        $display("[TEST 7] Continuous stream test");
        for (int t = 0; t < 3; t++) begin
            @(negedge clk);
            vec = $random();
            in_valid <= 1;
            next_ready <= 1;
            expected_popcount = count_ones(vec);
            $display("  [Stream %0d] Input popcount: %d", t, expected_popcount);
        end
        
        // 停止输入，等待所有流水线结果输出
        @(negedge clk);
        in_valid <= 0;
        $display("Stopping input, waiting for all pipeline results (PIPELINE_DEPTH=%0d)...", PIPELINE_DEPTH);
        repeat(PIPELINE_DEPTH + 10) @(posedge clk);
        
        // Test 8: No input (in_valid=0)
        #CLK_PERIOD;
        @(negedge clk);
        in_valid <= 0;
        repeat(5) @(posedge clk);
        $display("[TEST 8] No input - out_valid should be low: %b", out_valid);
        
        // Final summary
        #(CLK_PERIOD * 2);
        $display("========================================");
        $display("Test completed!");
        $display("  Input handshakes:  %0d", input_handshake_count);
        $display("  Output handshakes: %0d", output_handshake_count);
        $display("========================================");
        $finish;
    end
    
    // Output monitor - check results when out_valid && next_ready (handshake condition)
    logic [POPCNT_WIDTH-1:0] expected_val = 0;

    // 记录真正完成握手的输入，避免与ready错位
    always @(posedge clk) begin
        if (!rst_n) begin
            input_handshake_count <= 0;
        end else if (in_valid && this_ready) begin
            if (input_handshake_count < 100) begin
                expected_array[input_handshake_count] = count_ones(vec);
                $display("  [INPUT #%0d] Recorded: %0d", input_handshake_count, expected_array[input_handshake_count]);
                input_handshake_count <= input_handshake_count + 1;
            end else begin
                $display("[WARN] expected_array overflow, increase depth if needed");
            end
        end
    end
    
    initial begin
        @(posedge rst_n);  // Wait for reset to complete
        forever begin
            @(posedge clk);
            // Output handshake detected
            if (out_valid && next_ready) begin
                // Try to get the expected value for this output
                if (output_handshake_count < input_handshake_count) begin
                    expected_val = expected_array[output_handshake_count];
                    check_result_with_expected(expected_val, output_handshake_count);
                    output_handshake_count = output_handshake_count + 1;
                end else begin
                    // More outputs than inputs recorded - something is wrong
                    $display("[ERROR] Output #%0d but only %0d inputs recorded! Output: %d", 
                             output_handshake_count, input_handshake_count, popcount);
                end
            end
        end
    end
    
    // Task to check result
    task automatic check_result();
        begin
            if (popcount == expected_popcount) begin
                $display("[PASS] Output: %d (Expected: %d)", popcount, expected_popcount);
            end else begin
                $display("[FAIL] Output: %d (Expected: %d)", popcount, expected_popcount);
            end
        end
    endtask
    
    // Task to check result with expected value and index
    task automatic check_result_with_expected(logic [POPCNT_WIDTH-1:0] expected_val, int idx);
        begin
            if (popcount == expected_val) begin
                $display("[PASS] [%0d] Output: %d (Expected: %d)", idx, popcount, expected_val);
            end else begin
                $display("[FAIL] [%0d] Output: %d (Expected: %d)", idx, popcount, expected_val);
            end
        end
    endtask
    
endmodule
