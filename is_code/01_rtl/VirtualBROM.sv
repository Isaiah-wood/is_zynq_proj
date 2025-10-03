
// ==========================================================
// Sync bROM Model (single-port, read-only)
// - Synchronous read, configurable LATENCY == 1
// - Optional rvalid (data valid)
// - Optional init from HEX/MEM file
// ==========================================================



/* @wavedrom VirtualBROM
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
        'a~>b 1clk'
    ]
}
*/


`include "config.vh"


`timescale 1ns / 1ps
module VirtualBROM #(
    parameter int unsigned ROM_DEPTH  = `CFG_IMG_VEC_NUM,
    parameter int unsigned DATA_WIDTH = `CFG_VEC_WIDTH,
    parameter int unsigned ADDR_WIDTH = $clog2(ROM_DEPTH),
    parameter string       INIT_FILE  = `CFG_IMG_VEC_FILE
) (
    input logic clk,
    input logic rst_n,

    input logic                  arvalid,  // read address valid
    input logic [ADDR_WIDTH-1:0] araddr,   // read address

    output logic                  rvalid,  // read data valid
    input  logic                  rready,  // read data ready
    output logic [DATA_WIDTH-1:0] rdata    // read data
);

    // ROM storage
    (* rom_style = "block" *)
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


    logic rvalid_d;
    logic [DATA_WIDTH-1:0] rdata_d;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rvalid_d <= 1'b0;
            rdata_d  <= '0;
        end else begin
            rvalid_d <= arvalid && rready;
            if (arvalid && rready) begin
                rdata_d <= (araddr < ROM_DEPTH) ? mem[araddr] : 'x;
            end
        end
    end

    assign rdata  = rdata_d;
    assign rvalid = rvalid_d;




endmodule
