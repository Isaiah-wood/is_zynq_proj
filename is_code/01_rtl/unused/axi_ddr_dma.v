
`timescale 1ns/1ps
module axi_is_ddr_reader #(
    parameter integer DATA_WIDTH = 256,
    parameter integer N = 5,
    parameter integer ADDR_WIDTH = 32,
    parameter integer ID_WIDTH = 4
)(

    // 用户控制接口（BRAM 风格的触发接口）
    input  wire [ADDR_WIDTH-1:0] is_dma_raddr, // 读起始地址
    input  wire [15:0]           is_dma_rsize, // 读长度
    input  wire                  is_dma_rareq, // 启动信号，高电平有效
    output reg                   is_dma_rbusy, // 忙信号，高电平有效

    output reg [DATA_WIDTH-1:0]  is_dma_rdata_valid, // 数据有效，高电平有效
    output reg                   is_dma_rvalid,      // 数据输出有效，高电平有效
    input  wire                  is_dma_rready,      // 数据接收就绪，高电平有效

    // AXI4 接口
    input  wire                     ACLK,
    input  wire                     ARESETN,
    // ---------------- AXI4 Read Address Channel (Master -> Slave) ----------------
    output reg  [ADDR_WIDTH-1:0]    M_AXI_araddr,
    output reg  [1:0]               M_AXI_arburst,
    output reg  [3:0]               M_AXI_arcache,
    output reg  [ID_WIDTH-1:0]      M_AXI_arid,
    output reg  [7:0]               M_AXI_arlen,
    output reg  [1:0]               M_AXI_arlock,
    output reg  [2:0]               M_AXI_arprot,
    output reg  [3:0]               M_AXI_arqos,
    input  wire                     M_AXI_arready,
    output reg  [2:0]               M_AXI_arsize,
    output reg                      M_AXI_arvalid,

    // ---------------- AXI4 Read Data Channel (Slave -> Master) ----------------
    input  wire [ID_WIDTH-1:0]      M_AXI_rid,
    input  wire [DATA_WIDTH-1:0]    M_AXI_rdata,
    input  wire                     M_AXI_rlast,
    output reg                      M_AXI_rready,
    input  wire [1:0]               M_AXI_rresp,
    input  wire                     M_AXI_rvalid

    // ------------------ AXI Write Channel (未实现) ------------------
    input  wire [ADDR_WIDTH-1:0]    M_AXI_awaddr,
    input  wire [1:0]               M_AXI_awburst,
    input  wire [3:0]               M_AXI_awcache,
    input  wire [ID_WIDTH-1:0]      M_AXI_awid,
    input  wire [7:0]               M_AXI_awlen,
    input  wire [1:0]               M_AXI_awlock,
    input  wire [2:0]               M_AXI_awprot,
    input  wire [3:0]               M_AXI_awqos,
    output wire                     M_AXI_awready,
    input  wire [2:0]               M_AXI_awsize,
    input  wire                     M_AXI_awvalid,

    output wire [ID_WIDTH-1:0]      M_AXI_bid,
    input  wire                     M_AXI_bready,
    output wire [1:0]               M_AXI_bresp,
    output wire                     M_AXI_bvalid,

    input  wire [DATA_WIDTH-1:0]    M_AXI_wdata,
    input  wire                     M_AXI_wlast,
    output wire                     M_AXI_wready,
    input  wire [(DATA_WIDTH/8)-1:0] M_AXI_wstrb,
    input  wire                     M_AXI_wvalid
);
