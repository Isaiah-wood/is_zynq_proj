// pipelined_adder_tree_clean.v
module pipelined_adder_tree_clean #(
    parameter integer N = 16,
    parameter integer K = 8,
    parameter integer PIPELINED = 1
)(
    input  wire                     clk,
    input  wire                     rstn,
    input  wire                     in_valid,
    input  wire [(N*K)-1:0]         in_flat,
    output reg                      sum_valid,
    output reg  [(K + clog2_ceil(N))-1:0] sum_out
);
    // helper
    function integer clog2_ceil;
        input integer v;
        integer i;
        begin
            if (v <= 1) begin
                clog2_ceil = 0;
            end else begin
                clog2_ceil = 0;
                i = v - 1;
                while (i > 0) begin
                    clog2_ceil = clog2_ceil + 1;
                    i = i >> 1;
                end
            end
        end
    endfunction

    localparam integer LEVELS = (N <= 1) ? 0 : clog2_ceil(N);
    localparam integer SUM_W  = K + clog2_ceil(N);

    // compute sizes per level (small static array)
    integer size_arr_int [0:64]; // support up to 65 levels (way more than needed)
    integer lvl;
    initial begin
        size_arr_int[0] = N;
        for (lvl = 1; lvl <= LEVELS; lvl = lvl + 1)
            size_arr_int[lvl] = (size_arr_int[lvl-1] + 1) >> 1;
    end

    // layer storage: we declare vectors per-level with correct width and size
    // Use generate to instantiate per-level nets and regs
    genvar L, J;
    // We'll keep arrays in generate scopes: layer_wire[L][j], layer_reg[L][j] (if pipelined)
    generate
        // Level 0: unpack
        if (1) begin : LVL0
            localparam integer W0 = K;
            localparam integer S0 = N;
            wire [W0-1:0] layer0_wire [0:S0-1];
            for (J = 0; J < S0; J = J + 1) begin : UNP0
                assign layer0_wire[J] = in_flat[(J+1)*K-1 -: K];
            end
            if (PIPELINED) begin : REG0
                reg [W0-1:0] layer0_reg [0:S0-1];
                integer ii;
                always @(posedge clk or negedge rstn) begin
                    if (!rstn) begin
                        for (ii = 0; ii < S0; ii = ii + 1) layer0_reg[ii] <= {W0{1'b0}};
                    end else begin
                        for (ii = 0; ii < S0; ii = ii + 1) layer0_reg[ii] <= layer0_wire[ii];
                    end
                end
            end
        end

        // Build successive levels explicitly
        for (L = 0; L < LEVELS; L = L + 1) begin : BUILD
            localparam integer Wl = K + L;
            localparam integer Sl = (L==0) ? N : size_arr_int[L];
            localparam integer Snext = size_arr_int[L+1];
            localparam integer Wnext = K + (L+1);

            // source for this level: if L==0, select between layer0_reg and layer0_wire; else select prev level's wires/regs
            // To simplify, define src wire array
            wire [Wl-1:0] src [0:Sl-1];
            // fill src
            if (L == 0) begin : SRC0
                for (J = 0; J < Sl; J = J + 1) begin : S0
                    if (PIPELINED) begin
                        assign src[J] = LVL0.REG0.layer0_reg[J];
                    end else begin
                        assign src[J] = LVL0.layer0_wire[J];
                    end
                end
            end else begin : SRCN
                // previous build created next_layer_wire or next_layer_reg - access accordingly
                for (J = 0; J < Sl; J = J + 1) begin : SN
                    if (PIPELINED) begin
                        // previous level had REG_NEXT when pipelined
                        // hierarchical reference: BUILD[L-1].REG_NEXT.next_layer_reg[J]
                        assign src[J] = BUILD[L-1].REG_NEXT.next_layer_reg[J];
                    end else begin
                        assign src[J] = BUILD[L-1].next_layer_wire[J];
                    end
                end
            end

            // compute sums into next_layer_wire (combinational)
            wire [Wnext-1:0] next_layer_wire [0:Snext-1];
            integer idx;
            for (idx = 0; idx < Sl; idx = idx + 2) begin : PAIR
                localparam integer tgt = idx >> 1;
                wire [Wl-1:0] a = src[idx];
                wire [Wl-1:0] b = (idx+1 < Sl) ? src[idx+1] : {Wl{1'b0}};
                assign next_layer_wire[tgt] = {{1'b0, a} + {1'b0, b}};
            end

            // register next layer if pipelined
            if (PIPELINED) begin : REG_NEXT
                reg [Wnext-1:0] next_layer_reg [0:Snext-1];
                integer r;
                always @(posedge clk or negedge rstn) begin
                    if (!rstn) begin
                        for (r = 0; r < Snext; r = r + 1) next_layer_reg[r] <= {Wnext{1'b0}};
                    end else begin
                        for (r = 0; r < Snext; r = r + 1) begin
                            // if source index > generated combinational indices (happens when idx loop didn't assign some targets),
                            // we need to default to zero; but loop above covers all 0..Snext-1 targets (with b=0 for odd)
                            next_layer_reg[r] <= next_layer_wire[r];
                        end
                    end
                end
            end
        end // for L
    endgenerate

    // final output selection
    // if LEVELS==0 (N<=1): sum is just input[0]
    generate
        if (LEVELS == 0) begin : FINAL0
            localparam integer W0 = K;
            // src is LVL0 layer0_wire/regs
            always @(*) begin
                if (PIPELINED) begin
                    sum_out = LVL0.REG0.layer0_reg[0];
                end else begin
                    sum_out = LVL0.layer0_wire[0];
                end
                sum_valid = in_valid;
            end
        end else begin : FINALN
            // top level index is LEVELS-1 produced next_layer (width = K+LEVELS)
            // Actually BUILD[LEVELS-1] produced next_layer_wire / REG_NEXT.next_layer_reg of size 1
            if (PIPELINED) begin
                // sum is in BUILD[LEVELS-1].REG_NEXT.next_layer_reg[0]
                always @(posedge clk or negedge rstn) begin
                    if (!rstn) begin
                        sum_out <= {SUM_W{1'b0}};
                        sum_valid <= 1'b0;
                    end else begin
                        sum_out <= BUILD[LEVELS-1].REG_NEXT.next_layer_reg[0];
                        // valid pipeline shifts by LEVELS cycles
                        // implement valid pipeline shifting
                        reg [0:64] valid_shift; // small shift register
                        integer v;
                        // initialize and shift (we cannot declare variable sized reg inside always easily; so do a simple shift)
                    end
                end
                // Simpler approach: create a separate pipeline for valid of length LEVELS
                reg [LEVELS-1:0] valid_pipe;
                integer vi;
                always @(posedge clk or negedge rstn) begin
                    if (!rstn) begin
                        valid_pipe <= {LEVELS{1'b0}};
                        sum_valid <= 1'b0;
                    end else begin
                        valid_pipe <= {valid_pipe[LEVELS-2:0], in_valid};
                        sum_valid <= valid_pipe[LEVELS-1];
                        sum_out <= BUILD[LEVELS-1].REG_NEXT.next_layer_reg[0];
                    end
                end
            end else begin
                // combinational: directly compute output from last build's next_layer_wire[0]
                always @(*) begin
                    sum_out = BUILD[LEVELS-1].next_layer_wire[0];
                    sum_valid = in_valid;
                end
            end
        end
    endgenerate

endmodule
