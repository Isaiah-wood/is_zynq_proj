

// ==========================================================
// Sync DDR3 Model (single-port, read-only)
// - Synchronous read, configurable LATENCY == 10
// - Optional rvalid (data valid)
// - Optional init from HEX/MEM file
// ==========================================================

/* @wavedrom VirtualDDR
{
    "signal": [
        { "name": "clk", "wave": "p.........." },
        { "name": "rst_n", "wave": "01........." },
        { "name": "araddr", "wave": "x.3456789==", "data": ["0x00","0x01","0x02","0x03","0x04","0x05","0x06"] },
        { "name": "arvalid", "wave": "0.1........", "data": ["valid"], node: '..a........' },
        { "name": "rvalid", "wave": "0..|1......", "data": ["valid"], node: '....b......'  },
        { "name": "rdata", "wave": "x..|3456789", "data": ["data0","data1","data2","data3","data4","data5","data6"] },
        { "name": "rready", "wave": "1.........." }
    ],
    "edge": [
        'a~>b 10clk'
    ]
}
*/


`include "config.vh"

`timescale 1ns / 1ps
module VirtualDDR #(
    parameter int unsigned ROM_DEPTH  = `CFG_LIB_VEC_NUM,
    parameter int unsigned ADDR_WIDTH = $clog2(ROM_DEPTH),
    parameter int unsigned DATA_WIDTH = `CFG_VEC_WIDTH,
    parameter int unsigned LATENCY    = 10,                 // >=1
    parameter string       INIT_FILE  = `CFG_LIB_VEC_FILE
) (
    input logic clk,
    input logic rst_n,

    input logic                  arvalid,  // read address valid
    input logic [ADDR_WIDTH-1:0] araddr,   // read address

    output logic                  rvalid,  // read data valid
    input  logic                  rready,  // read data ready
    output logic [DATA_WIDTH-1:0] rdata    // read data
);
    // 参数合法性检查
    initial begin
        if (LATENCY < 1) begin
            $error("VirtualDDR: LATENCY must be >= 1");
            $finish;
        end
    end

    // ROM storage
    logic [DATA_WIDTH-1:0] mem[0:ROM_DEPTH-1];
    initial begin
        if (INIT_FILE != "") begin
            automatic int fd = $fopen(INIT_FILE, "r");
            if (fd == 0) begin
                $error("brom_sync: cannot open INIT_FILE='%s'", INIT_FILE);
            end else begin
                $fclose(fd);
                $display("brom_sync: loading INIT_FILE = %s", INIT_FILE);
                $readmemb(INIT_FILE, mem);
            end
        end
    end

    // Latency FIFO for arvalid & araddr
    logic [ADDR_WIDTH-1:0] araddr_d;
    logic                  arvalid_d;
    Latency #(
        .DATA_WIDTH(1 + ADDR_WIDTH),  // +1 for arvalid
        .LATENCY(LATENCY - 1)
    ) u_latency (
        .clk  (clk),
        .rst_n(rst_n),
        .din  ({arvalid, araddr}),
        .dout ({arvalid_d, araddr_d})
    );


    logic                  rvalid_d;
    logic [DATA_WIDTH-1:0] rdata_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_d <= 1'b0;
            rdata_d  <= '0;
        end else begin
            rvalid_d <= arvalid_d && rready;
            if (arvalid_d && rready) begin
                rdata_d <= (araddr_d < ROM_DEPTH) ? mem[araddr_d] : 'x;
            end
        end
    end

    assign rdata  = rdata_d;
    assign rvalid = rvalid_d;

    // SVA断言
    property p_latency;
        @(posedge clk) disable iff (!rst_n) arvalid |=> ##(LATENCY-1) rvalid;
    endproperty
    assert property (p_latency);


endmodule
