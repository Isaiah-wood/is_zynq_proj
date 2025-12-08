`timescale 1ns/1ps

module tb_axi_ddr3_sim;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter DATA_WIDTH = 256;
    parameter ADDR_WIDTH = 32;
    parameter ID_WIDTH   = 4;
    parameter MEM_DEPTH  = 1024; // 仿真用较小深度
    parameter INIT_FILE  = "ddr_init_test.mem"; // 仿真生成的临时初始化文件

    // =========================================================================
    // Signals
    // =========================================================================
    reg                     ACLK;
    reg                     ARESETN;

    // Read Address Channel
    reg  [ADDR_WIDTH-1:0]   S_AXI_araddr;
    reg  [1:0]              S_AXI_arburst;
    reg  [3:0]              S_AXI_arcache;
    reg  [ID_WIDTH-1:0]     S_AXI_arid;
    reg  [7:0]              S_AXI_arlen;
    reg  [1:0]              S_AXI_arlock;
    reg  [2:0]              S_AXI_arprot;
    reg  [3:0]              S_AXI_arqos;
    wire                    S_AXI_arready;
    reg  [2:0]              S_AXI_arsize;
    reg                     S_AXI_arvalid;

    // Read Data Channel
    wire [ID_WIDTH-1:0]     S_AXI_rid;
    wire [DATA_WIDTH-1:0]   S_AXI_rdata;
    wire                    S_AXI_rlast;
    reg                     S_AXI_rready;
    wire [1:0]              S_AXI_rresp;
    wire                    S_AXI_rvalid;

    // Write Channel (Unused, tied to 0)
    reg  [ADDR_WIDTH-1:0]   S_AXI_awaddr  = 0;
    reg  [1:0]              S_AXI_awburst = 0;
    reg  [3:0]              S_AXI_awcache = 0;
    reg  [ID_WIDTH-1:0]     S_AXI_awid    = 0;
    reg  [7:0]              S_AXI_awlen   = 0;
    reg  [1:0]              S_AXI_awlock  = 0;
    reg  [2:0]              S_AXI_awprot  = 0;
    reg  [3:0]              S_AXI_awqos   = 0;
    wire                    S_AXI_awready;
    reg  [2:0]              S_AXI_awsize  = 0;
    reg                     S_AXI_awvalid = 0;
    wire [ID_WIDTH-1:0]     S_AXI_bid;
    reg                     S_AXI_bready  = 0;
    wire [1:0]              S_AXI_bresp;
    wire                    S_AXI_bvalid;
    reg  [DATA_WIDTH-1:0]   S_AXI_wdata   = 0;
    reg                     S_AXI_wlast   = 0;
    wire                    S_AXI_wready;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_wstrb = 0;
    reg                     S_AXI_wvalid  = 0;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    axi_ddr3_sim #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE(INIT_FILE)
    ) dut (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        
        // Read Address
        .S_AXI_araddr(S_AXI_araddr),
        .S_AXI_arburst(S_AXI_arburst),
        .S_AXI_arcache(S_AXI_arcache),
        .S_AXI_arid(S_AXI_arid),
        .S_AXI_arlen(S_AXI_arlen),
        .S_AXI_arlock(S_AXI_arlock),
        .S_AXI_arprot(S_AXI_arprot),
        .S_AXI_arqos(S_AXI_arqos),
        .S_AXI_arready(S_AXI_arready),
        .S_AXI_arsize(S_AXI_arsize),
        .S_AXI_arvalid(S_AXI_arvalid),
        
        // Read Data
        .S_AXI_rid(S_AXI_rid),
        .S_AXI_rdata(S_AXI_rdata),
        .S_AXI_rlast(S_AXI_rlast),
        .S_AXI_rready(S_AXI_rready),
        .S_AXI_rresp(S_AXI_rresp),
        .S_AXI_rvalid(S_AXI_rvalid),
        
        // Write (Ignored)
        .S_AXI_awaddr(S_AXI_awaddr),
        .S_AXI_awburst(S_AXI_awburst),
        .S_AXI_awcache(S_AXI_awcache),
        .S_AXI_awid(S_AXI_awid),
        .S_AXI_awlen(S_AXI_awlen),
        .S_AXI_awlock(S_AXI_awlock),
        .S_AXI_awprot(S_AXI_awprot),
        .S_AXI_awqos(S_AXI_awqos),
        .S_AXI_awready(S_AXI_awready),
        .S_AXI_awsize(S_AXI_awsize),
        .S_AXI_awvalid(S_AXI_awvalid),
        .S_AXI_bid(S_AXI_bid),
        .S_AXI_bready(S_AXI_bready),
        .S_AXI_bresp(S_AXI_bresp),
        .S_AXI_bvalid(S_AXI_bvalid),
        .S_AXI_wdata(S_AXI_wdata),
        .S_AXI_wlast(S_AXI_wlast),
        .S_AXI_wready(S_AXI_wready),
        .S_AXI_wstrb(S_AXI_wstrb),
        .S_AXI_wvalid(S_AXI_wvalid)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK; // 100MHz
    end

    // =========================================================================
    // Tasks
    // =========================================================================
    task axi_read;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0]            len;
        input [ID_WIDTH-1:0]   id;
        begin
            // Address Phase
            @(posedge ACLK);
            S_AXI_araddr  <= addr;
            S_AXI_arlen   <= len;
            S_AXI_arid    <= id;
            S_AXI_arvalid <= 1'b1;
            S_AXI_arsize  <= $clog2(DATA_WIDTH/8); // 256bit -> 32bytes -> 5
            S_AXI_arburst <= 2'b01; // INCR
            S_AXI_arcache <= 4'b0000;
            S_AXI_arlock  <= 2'b00;
            S_AXI_arprot  <= 3'b000;
            S_AXI_arqos   <= 4'b0000;

            // Wait for Ready
            do begin
                @(posedge ACLK);
            end while (!S_AXI_arready);
            
            // Deassert Valid
            S_AXI_arvalid <= 1'b0;
        end
    endtask

    // =========================================================================
    // Main Stimulus
    // =========================================================================
    initial begin
        // 1. Initialize Signals
        ARESETN = 0;
        S_AXI_arvalid = 0;
        S_AXI_rready = 0;
        
        // 2. Create Dummy Init File
        begin : file_gen
            integer f;
            integer i;
            f = $fopen(INIT_FILE, "w");
            if (f) begin
                // 写入一些测试数据
                // 格式：十六进制，每行一个 DATA_WIDTH 数据
                // 256bit = 64 hex chars
                for (i = 0; i < 16; i = i + 1) begin
                    $fwrite(f, "%064x\n", i + 1); // 1, 2, 3...
                end
                $fclose(f);
                $display("Created init file: %s", INIT_FILE);
            end else begin
                $display("Error: Could not create init file!");
                $finish;
            end
        end

        // 3. Reset Sequence
        #100;
        ARESETN = 1;
        $display("Reset released");
        #20;

        // ---------------------------------------------------------------------
        // Test Case 1: Single Read (Len=0)
        // ---------------------------------------------------------------------
        $display("[%t] Starting Test 1: Single Read", $time);
        S_AXI_rready = 1; // Always ready
        axi_read(32'h0, 8'd0, 4'd1); // Addr 0, Len 0 (1 beat), ID 1
        
        wait(S_AXI_rvalid && S_AXI_rlast);
        @(posedge ACLK);
        $display("[%t] Test 1 Complete", $time);
        #50;

        // ---------------------------------------------------------------------
        // Test Case 2: Burst Read (Len=3 -> 4 beats)
        // ---------------------------------------------------------------------
        $display("[%t] Starting Test 2: Burst Read (4 beats)", $time);
        axi_read(32'h0, 8'd3, 4'd2); // Addr 0, Len 3, ID 2
        
        wait(S_AXI_rvalid && S_AXI_rlast);
        @(posedge ACLK);
        $display("[%t] Test 2 Complete", $time);
        #50;

        // ---------------------------------------------------------------------
        // Test Case 3: Back-pressure (Random RREADY)
        // ---------------------------------------------------------------------
        $display("[%t] Starting Test 3: Random RREADY (Back-pressure)", $time);
        fork
            // Thread 1: Issue Read Command
            axi_read(32'h0, 8'd7, 4'd3); // 8 beats
            
            // Thread 2: Randomize Ready Signal
            begin
                repeat(30) begin
                    @(posedge ACLK);
                    S_AXI_rready <= $random; // Randomly toggle ready
                end
                S_AXI_rready <= 1; // Ensure ready at end
            end
        join
        
        wait(S_AXI_rvalid && S_AXI_rlast);
        @(posedge ACLK);
        $display("[%t] Test 3 Complete", $time);
        
        #100;
        $display("All Tests Finished");
        $finish;
    end

    // Monitor
    always @(posedge ACLK) begin
        if (S_AXI_rvalid && S_AXI_rready) begin
            $display("[%t] DATA RECEIVED: ID=%0d, Last=%b, Data=%h", 
                     $time, S_AXI_rid, S_AXI_rlast, S_AXI_rdata);
        end
    end

endmodule
