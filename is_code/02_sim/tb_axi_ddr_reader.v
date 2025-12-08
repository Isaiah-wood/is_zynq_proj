
// =============================================================
// 3. Testbench tb_axi_ddr_reader.v
// =============================================================

module tb_axi_ddr_reader;

reg ACLK=0; always #2.5 ACLK=~ACLK; // 200MHz
reg ARESETN=0;

// user iface
reg start;
wire busy;
wire valid;
wire [256*5-1:0] data_out;

// AXI wires
wire [31:0] araddr;
wire        arvalid;
wire        arready;
wire [7:0]  arlen;
wire [2:0]  arsize;
wire [1:0]  arburst;
wire [3:0]  arcache;
wire [3:0]  arqos;
wire [3:0]  arid;
wire [1:0]  arlock;
wire [2:0]  arprot;

wire        rvalid;
wire        rready;
wire        rlast;
wire [255:0] rdata;
wire [3:0]   rid;
wire [1:0]   rresp;

// 实例化 DDR 模型
axi_ddr3_sim ddr(
    .ACLK(ACLK), .ARESETN(ARESETN),
    .S_AXI_araddr(araddr), .S_AXI_arburst(arburst), .S_AXI_arcache(arcache),
    .S_AXI_arid(arid), .S_AXI_arlen(arlen), .S_AXI_arlock(arlock),
    .S_AXI_arprot(arprot), .S_AXI_arqos(arqos), .S_AXI_arready(arready),
    .S_AXI_arsize(arsize), .S_AXI_arvalid(arvalid),
    .S_AXI_rid(rid), .S_AXI_rdata(rdata), .S_AXI_rlast(rlast),
    .S_AXI_rready(rready), .S_AXI_rresp(rresp), .S_AXI_rvalid(rvalid),
    .S_AXI_awaddr(), .S_AXI_awburst(), .S_AXI_awcache(), .S_AXI_awid(),
    .S_AXI_awlen(), .S_AXI_awlock(), .S_AXI_awprot(), .S_AXI_awqos(),
    .S_AXI_awready(), .S_AXI_awsize(), .S_AXI_awvalid(),
    .S_AXI_bid(), .S_AXI_bready(1'b0), .S_AXI_bresp(), .S_AXI_bvalid(),
    .S_AXI_wdata(), .S_AXI_wlast(), .S_AXI_wready(), .S_AXI_wstrb(),
    .S_AXI_wvalid()
);

// 实例化读取模块
axi_ddr_reader reader(
    .ACLK(ACLK), .ARESETN(ARESETN),
    .start(start), .busy(busy), .valid(valid), .data_out(data_out),

    .M_AXI_araddr(araddr), .M_AXI_arburst(arburst), .M_AXI_arcache(arcache),
    .M_AXI_arid(arid), .M_AXI_arlen(arlen), .M_AXI_arlock(arlock),
    .M_AXI_arprot(arprot), .M_AXI_arqos(arqos), .M_AXI_arready(arready),
    .M_AXI_arsize(arsize), .M_AXI_arvalid(arvalid),

    .M_AXI_rid(rid), .M_AXI_rdata(rdata), .M_AXI_rlast(rlast),
    .M_AXI_rready(rready), .M_AXI_rresp(rresp), .M_AXI_rvalid(rvalid)
);

initial begin
    $display("TB START");
    ARESETN=0; start=0;
    #50; ARESETN=1;
    #50; start=1;
    #10; start=0;

    wait(valid);
    $display("OUTPUT = %h", data_out);

    #2000; $stop;
end
endmodule
