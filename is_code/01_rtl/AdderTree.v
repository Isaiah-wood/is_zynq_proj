`timescale 1ns / 1ps
`include "config.vh"

// ==========================================
// 通用二叉加法树
// 累加 LEAF_NUM 个、每个 IN_WIDTH 位的非负数；每项最大值为 MAXVAL
// ==========================================

module AdderTree #(
    parameter integer LEAF_NUM = `CFG_ADDER_TREE_LEAF_NUM,  // 操作数个数
    parameter integer MAXVAL   = `CFG_LUT_IN_WIDTH,         // 单个操作数最大可能值（用于求和位宽）
    parameter integer INW = `CFG_LUT_OUT_WIDTH,
    parameter integer IN_WIDTH = LEAF_NUM * INW,
    // parameter integer OUT_WIDTH = `CFG_VEC_POPCOUNT_WIDTH
    parameter integer OUT_WIDTH = $clog2(LEAF_NUM * MAXVAL + 1)
) (
    input wire clk,
    input wire rst_n,

    // 上游 valid/ready 接口
    input  wire [IN_WIDTH-1:0] in_data,   // N 个 INW 位操作数打包
    input  wire                in_valid,
    output wire                in_ready,

    // 下游 valid/ready 接口
    output wire [OUT_WIDTH-1:0] sum,        // 总和
    output wire                 out_valid,
    input  wire                 out_ready
);

    // ============== 参数与内部常量 ==============
    localparam integer LEVELS = $clog2(LEAF_NUM);  // 归约层数（不含输入层0）
    // localparam integer OUT_WIDTH = $clog2(LEAF_NUM * MAXVAL + 1);  // 部分和位宽
    localparam integer STAGES = LEVELS + 1;  // 流水级数（含末级）

    // 设计检查
    initial begin
        if (LEAF_NUM < 1) $fatal("AdderTree: LEAF_NUM must be >= 1");
        if (LEAF_NUM == 1)
            $fatal("NewAdderTree: This variant requires LEAF_NUM > 1 (no LEVELS==0 case)");
        if (INW < $clog2(MAXVAL + 1))
            $fatal("AdderTree: INW (%0d) too small for MAXVAL=%0d", INW, MAXVAL);
    end

    // ============== 输入级解包 ==============
    // stage0：输入直接解包，ready[0] 控制是否采样到 level[0]
    wire [INW-1:0] in_packet[0:LEAF_NUM-1];
    genvar i;
    generate
        for (i = 0; i < LEAF_NUM; i = i + 1) begin : UNPACK
            assign in_packet[i] = in_data[i*INW+:INW];
        end
    endgenerate


    // valid/ready 链（逐级通用，与 pipeline_valid_ready 一致）
    reg     valid_reg[0:STAGES-1];
    wire    ready    [  0:STAGES];

    integer lv;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (lv = 0; lv < STAGES; lv = lv + 1) begin
                valid_reg[lv] <= 1'b0;
            end
        end else begin
            // 逐级传输
            for (lv = 0; lv < STAGES; lv = lv + 1) begin
                if (ready[lv]) begin
                    if (lv == 0) begin
                        valid_reg[lv] <= in_valid;
                    end else begin
                        valid_reg[lv] <= valid_reg[lv-1];
                    end
                end
            end
        end
    end


    assign ready[STAGES] = out_ready;  // 最末级由下游决定
    genvar gen_idx;
    generate
        for (gen_idx = STAGES - 1; gen_idx >= 0; gen_idx = gen_idx - 1) begin : READY_GEN
            assign ready[gen_idx] = (~valid_reg[gen_idx]) || ready[gen_idx+1];
        end
    endgenerate

    // level[l][k]：第 l 层(1..LEVELS)第 k 个节点的部分和（每层寄存一次）
    reg [OUT_WIDTH-1:0] level[0:LEVELS][0:LEAF_NUM-1];

    // 层 0 组合赋值
    generate
        for (i = 0; i < LEAF_NUM; i = i + 1) begin : LVL0
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    level[0][i] <= {OUT_WIDTH{1'b0}};
                end else if (ready[0]) begin
                    level[0][i] <= in_packet[i]; // 零层为输入（零扩展到 OUT_WIDTH 在后续加法中隐式完成）
                end
            end
        end
    endgenerate



    // 逐层规约（stage 1..LEVELS）：
    // PREV：上一层节点数；CUR：当前层节点数 = ceil(PREV/2)
    genvar l, k;
    generate
        for (l = 1; l <= LEVELS; l = l + 1) begin : REDUCE_LEVEL
            localparam integer PREV = (LEAF_NUM + (1 << (l - 1)) - 1) >> (l - 1);   // 上一层节点数
            localparam integer CUR = (LEAF_NUM + (1 << l) - 1) >> l;  // 当前层节点数

            // 数据寄存（每个节点一个寄存器）
            for (k = 0; k < CUR; k = k + 1) begin : NODE
                wire [OUT_WIDTH-1:0] a;
                wire [OUT_WIDTH-1:0] b;
                assign a = level[l-1][2*k];
                assign b = (2 * k + 1 < PREV) ? level[l-1][2*k+1] : {OUT_WIDTH{1'b0}};
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) level[l][k] <= {OUT_WIDTH{1'b0}};
                    else if (ready[l]) level[l][k] <= a + b;
                end
            end
        end
    endgenerate

    // 接口输出
    assign in_ready = ready[0];
    assign sum = level[LEVELS][0];
    assign out_valid = valid_reg[LEVELS];



endmodule
