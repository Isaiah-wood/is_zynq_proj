`timescale 1ns / 1ps

module tb_VecPopcount ();
    localparam CLK_PERIOD = 10;
    localparam VEC_WIDTH = 1100;
    localparam LUT_WIDTH = 6;
    localparam POPCNT_WIDTH = $clog2(VEC_WIDTH+1);
    
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
        @(posedge clk);
        vec = {VEC_WIDTH{1'b0}};
        in_valid = 1;
        expected_popcount = 0;
        $display("[TEST 2] Input: All zeros, Expected popcount: %d", expected_popcount);
        wait_for_output("Test 2: All zeros");
        
        // Test 3: All ones
        #CLK_PERIOD;
        @(posedge clk);
        vec = {VEC_WIDTH{1'b1}};
        in_valid = 1;
        expected_popcount = VEC_WIDTH;
        $display("[TEST 3] Input: All ones, Expected popcount: %d", expected_popcount);
        wait_for_output("Test 3: All ones");
        
        // Test 4: Random pattern 1
        #CLK_PERIOD;
        @(posedge clk);
        vec = {VEC_WIDTH{1'b0}};
        // Set some bits
        for (int i = 0; i < VEC_WIDTH; i += 7) begin
            vec[i] = 1'b1;
        end
        in_valid = 1;
        expected_popcount = count_ones(vec);
        $display("[TEST 4] Input: Pattern 1 (every 7th bit), Expected popcount: %d", expected_popcount);
        wait_for_output("Test 4: Pattern 1");
        
        // Test 5: Random pattern 2
        #CLK_PERIOD;
        @(posedge clk);
        vec = {VEC_WIDTH{1'b0}};
        // Set alternating bits
        for (int i = 0; i < VEC_WIDTH; i += 2) begin
            vec[i] = 1'b1;
        end
        in_valid = 1;
        expected_popcount = count_ones(vec);
        $display("[TEST 5] Input: Pattern 2 (alternating bits), Expected popcount: %d", expected_popcount);
        wait_for_output("Test 5: Pattern 2");
        
        // Test 6: Backpressure test - next_ready=0
        #CLK_PERIOD;
        @(posedge clk);
        vec = 128'hAAAA_AAAA_AAAA_AAAA;
        in_valid = 1;
        next_ready = 0;  // Apply backpressure
        expected_popcount = count_ones(vec);
        $display("[TEST 6] Input: With backpressure (next_ready=0), Expected popcount: %d", expected_popcount);
        
        // Wait a few cycles with backpressure
        repeat(3) @(posedge clk);
        
        // Release backpressure
        next_ready = 1;
        wait_for_output("Test 6: Backpressure release");
        
        // Test 7: Continuous stream test
        #CLK_PERIOD;
        $display("[TEST 7] Continuous stream test");
        for (int t = 0; t < 5; t++) begin
            @(posedge clk);
            vec = $random();
            in_valid = 1;
            next_ready = 1;
            expected_popcount = count_ones(vec);
            @(posedge clk);
            wait(out_valid);
            check_result();
        end
        
        // Test 8: No input (in_valid=0)
        #CLK_PERIOD;
        @(posedge clk);
        in_valid = 0;
        repeat(5) @(posedge clk);
        $display("[TEST 8] No input - out_valid should be low: %b", out_valid);
        
        // Final summary
        #(CLK_PERIOD * 2);
        $display("========================================");
        $display("All tests completed!");
        $display("========================================");
        $finish;
    end
    
    // Task to wait for output with timeout
    task automatic wait_for_output(string test_name);
        integer timeout = 0;
        begin
            while (!out_valid && timeout < 100) begin
                @(posedge clk);
                timeout++;
            end
            
            if (out_valid) begin
                check_result();
            end else begin
                $display("[ERROR] %s - Timeout waiting for output", test_name);
            end
        end
    endtask
    
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
    
endmodule
