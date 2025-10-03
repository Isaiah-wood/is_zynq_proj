`timescale 1ns / 1ps
`include "config.vh"




module Multicast #(
    parameter N = 15486,
    parameter M = 80,
    parameter DATA_W = 64,
    parameter IDX_W = 7
)(
    input  wire                 clk,
    input  wire                 rst_n,

    // upstream
    input  wire [DATA_W-1:0]    s_data,
    input  wire [$clog2(N)-1:0] s_seq,
    input  wire                 s_valid,
    output wire                 s_ready,

    // downstream (M ports)
    output wire [M-1:0][DATA_W-1:0] m_data,
    output wire [M-1:0]             m_valid,
    input  wire [M-1:0]              m_ready
);

    // -------------------------------------------------------
    // BRAM ROM storage (sparse encoding): implemented offline
    // Content per address:
    //   [1:0] count, [1+IDX_W-1:2] idx0, [..] idx1, idx2, idx3
    // -------------------------------------------------------
    wire [ (2 + 4*IDX_W) - 1 : 0 ] rom_q;
    reg  [$clog2(N)-1:0] rom_addr;
    // instantiate your BRAM/ROM here: sync read on clk, addr->rom_q next cycle

    // cycle t: latch incoming seq as bram addr (if s_valid & s_ready)
    always @(posedge clk) begin
        if(!rst_n) begin
            rom_addr <= 0;
        end else if (s_valid && s_ready) begin
            rom_addr <= s_seq;
        end
    end

    // cycle t+1: rom_q valid -> decode count and indices, register data
    reg [1:0]        reg_count;
    reg [IDX_W-1:0]  reg_idx0, reg_idx1, reg_idx2, reg_idx3;
    reg [DATA_W-1:0] reg_data;
    reg              reg_valid_t1;
    always @(posedge clk) begin
        if(!rst_n) begin
            reg_count <= 0;
            reg_idx0 <= 0; reg_idx1 <= 0; reg_idx2 <= 0; reg_idx3 <= 0;
            reg_data <= 0;
            reg_valid_t1 <= 0;
        end else begin
            // rom_q assumed available this cycle
            {reg_count, reg_idx0, reg_idx1, reg_idx2, reg_idx3} <= rom_q;
            reg_data <= s_data;     // data from previous cycle (or latch earlier)
            reg_valid_t1 <= s_valid; // indicates pipeline stage holds a valid pkt
        end
    end

    // cycle t+2: expand to outputs; produce m_valid and m_data (registered)
    // We'll build m_valid_reg and m_data_reg arrays
    genvar i;
    generate
      for (i=0; i<M; i=i+1) begin : OUTS
        reg v_reg;
        reg [DATA_W-1:0] d_reg;
        always @(posedge clk) begin
          if(!rst_n) begin
            v_reg <= 0;
            d_reg <= 0;
          end else begin
            // default no valid
            v_reg <= 1'b0;
            // set valid if this index matches one of reg_idx*
            if (reg_valid_t1) begin
               if (reg_count == 2'd1 && reg_idx0 == i) v_reg <= 1'b1;
               else if (reg_count == 2'd2 && (reg_idx0==i || reg_idx1==i)) v_reg <= 1'b1;
               else if (reg_count == 2'd3 && (reg_idx0==i || reg_idx1==i || reg_idx2==i)) v_reg <= 1'b1;
               else if (reg_count == 2'd4 && (reg_idx0==i || reg_idx1==i || reg_idx2==i || reg_idx3==i)) v_reg <= 1'b1;
            end
            if (v_reg) d_reg <= reg_data; // latch data for this consumer
          end
        end
        assign m_valid[i] = v_reg;
        assign m_data[i]  = d_reg;
      end
    endgenerate

    // s_ready logic: if you require all targets to be ready, then check:
    // compute mask_ready = for each i: if this pkt wants i then m_ready[i] else 1
    // For efficiency, compute mask_ready in a reduction or by incrementing matches.
    // For simplicity, assume downstream never blocks => s_ready = 1
    assign s_ready = 1'b1;

endmodule
