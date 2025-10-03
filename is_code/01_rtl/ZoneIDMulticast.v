`timescale 1ns / 1ps
`include "config.vh"

// ============================================================================
// ZoneIDMulticast
//  - 根据分区表，生成广播掩码
//  - 每个分区ID宽度根据分区数自动计算
//  - 每个库向量对应4个分区ID
//  - 分区ID全1表示留空，0表示第1分区，1表示第2分区，依次类推
//  - 利用移位得到掩码；留空对应全1，通过移位溢出得到全0掩码，实现对其的忽略，因此存在约束如下：
//  ! 约束:ZONE_NUM < 2^ZONE_ADDR_W
//  - 为提高频率，采用寄存器，因此有2拍延迟
// ============================================================================



module ZoneIDMulticast #(
    parameter integer IMG_VEC_N = `CFG_IMG_VEC_NUM,
    parameter integer LIB_VEC_N = `CFG_LIB_VEC_NUM,
    parameter integer VEC_WIDTH = `CFG_VEC_WIDTH,
    parameter integer ZONE_NUM = `CFG_ZONE_NUM,
    parameter integer ZONE_ADDR_W = 8,
    parameter integer ZONE_INFO_W = 4 * ZONE_ADDR_W  // 每个库向量对应4个分区ID
) (
    input wire clk,
    input wire rst_n,
    input wire [$clog2(LIB_VEC_N)-1:0] libvec_addr,
    input wire libvec_avalid,
    output reg [ZONE_NUM-1:0] zone_mask,
    output wire mask_valid,
    input  wire mask_ready
);    
    // 读取 ZoneID ROM
    wire zones_valid, zones_ready;
    wire [(4*ZONE_ADDR_W)-1:0] zones_info;
    VirtualBROM #(
        .ROM_DEPTH(LIB_VEC_N),
        .ADDR_WIDTH($clog2(LIB_VEC_N)),
        .DATA_WIDTH(ZONE_INFO_W),
        .INIT_FILE(`CFG_ZONE_LIB_FILE)
    ) u_zoneid_rom (
        .clk  (clk),
        .rst_n(rst_n),
        .arvalid(libvec_avalid),
        .araddr(libvec_addr),
        .rvalid(zones_valid),
        .rready(zones_ready),
        .rdata(zones_info)
    );

    wire [ZONE_ADDR_W-1:0] zoneid0, zoneid1, zoneid2, zoneid3;
    assign {zoneid3, zoneid2, zoneid1, zoneid0} = zones_info;

    reg [ZONE_NUM-1:0] zoneid0_mask, zoneid1_mask, zoneid2_mask, zoneid3_mask;
    always @(posedge clk) begin
        if (!rst_n) begin
            zoneid0_mask <= 0;
            zoneid1_mask <= 0;
            zoneid2_mask <= 0;
            zoneid3_mask <= 0;
        end else if (zones_valid && zones_ready) begin
            zoneid0_mask <= (1 << zoneid0);
            zoneid1_mask <= (1 << zoneid1);
            zoneid2_mask <= (1 << zoneid2);
            zoneid3_mask <= (1 << zoneid3);
        end
    end


    reg zones_valid_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            zone_mask <= 0;
        end else begin
            zone_mask <= zoneid0_mask | zoneid1_mask | zoneid2_mask | zoneid3_mask;
            zones_valid_d <= zones_valid;
        end
    end

    assign zones_ready = mask_ready;
    assign mask_valid = zones_valid_d;




endmodule
