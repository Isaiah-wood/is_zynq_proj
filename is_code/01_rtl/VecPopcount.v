// ============================================================================
// VecPopcount
//  - 输入一个向量，计算其中 1 的个数
//  - 采用加法树配合LUT的方案，根据ZYNQ特点将LUT宽度设为6
//  - 当Vec宽度小于等于LUT宽度时，直接使用LUT查表
//  - 当Vec宽度大于LUT宽度时，先按照LUT宽度切分向量，对每块使用LUT查表得到局部popcount
//    然后将所有局部popcount送入加法树归约得到最终结果
//  - 支持背压：next_ready=0 时暂停内部推进；与下游握手对齐，不使用Popcount模块
// ============================================================================



`timescale 1ns / 1ps
module VecPopcount #(
    parameter integer VEC_WIDTH = 1100,
    parameter integer LUT_WIDTH = 6,
    parameter integer POPCNT_WIDTH = $clog2(VEC_WIDTH+1)
) (
    input wire clk,
    input wire rst_n,

    input wire [VEC_WIDTH-1:0] vec,
    input wire in_valid,
    output wire out_valid,
    output wire this_ready,
    input wire next_ready,
    output wire [POPCNT_WIDTH-1:0] popcount
);
    // 判断是否需要加法树
    generate
        if (VEC_WIDTH <= LUT_WIDTH) begin : NO_ADDER_TREE
            // 输出寄存，提高时序稳定性
            reg [POPCNT_WIDTH-1:0] popcount_reg;
            reg popcount_valid_reg;
            // 直接使用LUT查表
            wire [POPCNT_WIDTH-1:0] lut_popcount;
            LUT6_Popcount #(
                .DIN_WIDTH(VEC_WIDTH),
                .DOUT_WIDTH(POPCNT_WIDTH)
            ) u_lut6_popcount (
                .din(vec),
                .dout(lut_popcount)
            );
            // 输出寄存
            always @(posedge clk) begin
                if (!rst_n) begin
                    popcount_reg <= {POPCNT_WIDTH{1'b0}};
                    popcount_valid_reg <= 1'b0;
                end else if (this_ready) begin
                    popcount_reg <= lut_popcount;
                    popcount_valid_reg <= in_valid;
                end
            end
            // 输出接口连接
            assign popcount = popcount_reg;
            assign out_valid = popcount_valid_reg;
            assign this_ready = (~popcount_valid_reg) || next_ready;

        end else begin : WITH_ADDER_TREE
            /* -------------------------------------------------------------------------- */
            /*                         使用Popcount模块 + AdderTree模块                         */
            /* -------------------------------------------------------------------------- */
            // 切分输入向量为多个LUT宽度块
            localparam SLICE_NUM = (VEC_WIDTH + LUT_WIDTH - 1) / LUT_WIDTH; // 向上取整
            localparam LUT_IN_WIDTH = LUT_WIDTH;
            localparam LUT_OUT_WIDTH = $clog2(LUT_WIDTH + 1);
            // 每块LUT的popcount结果
            reg [LUT_OUT_WIDTH-1:0] cntslices[0:SLICE_NUM-1];
            genvar si;
            generate
                for (si = 0; si < SLICE_NUM; si = si + 1) begin : SLICES
                    wire [LUT_IN_WIDTH-1:0] vecslice;
                    assign vecslice = (si+1)*LUT_WIDTH > VEC_WIDTH ?
                                    {{(si+1)*LUT_WIDTH-VEC_WIDTH{1'b0}}, vec[VEC_WIDTH-1:si*LUT_WIDTH]} :
                                    vec[si*LUT_WIDTH +: LUT_WIDTH];
                    LUT6_Popcount #(
                        .DIN_WIDTH (LUT_IN_WIDTH),
                        .DOUT_WIDTH(LUT_OUT_WIDTH)
                    ) u_lut6_popcount (
                        .din (vecslice),
                        .dout(cntslices[si])
                    );
                end
            endgenerate

            // 将切片结果输入加法树
            localparam integer LEVELS = $clog2(SLICE_NUM) + 1; // 流水级数（含末级）
            wire addends_ready[0:LEVELS];
            reg addends_valid[0:LEVELS-1];

            // ready信号反馈链
            assign addends_ready[LEVELS] = next_ready;
            genvar ready_idx;
            generate
                for (ready_idx = 0; ready_idx < LEVELS; ready_idx = ready_idx + 1) begin : READY_CHAIN
                    assign addends_ready[ready_idx] = (~addends_valid[ready_idx]) || addends_ready[ready_idx+1];
                end
            endgenerate
            // valid信号传递链
            integer lv;
            always @(posedge clk) begin
                if (!rst_n) begin
                    for (lv = 0; lv < LEVELS; lv = lv + 1) begin
                        addends_valid[lv] <= 1'b0;
                    end
                end else begin
                    for (lv = 0; lv < LEVELS; lv = lv + 1) begin
                        if (lv == 0) begin
                            if (addends_ready[0]) begin
                                addends_valid[0] <= in_valid;
                            end
                        end else begin
                            if (addends_ready[lv]) begin
                                addends_valid[lv] <= addends_valid[lv-1];
                            end
                        end
                    end
                end
            end
            // cntslices输入打包
            reg [LUT_OUT_WIDTH-1:0] addend_reg[0:SLICE_NUM-1];
            integer sn;
            always @(posedge clk) begin
                if (!rst_n) begin
                    for (sn = 0; sn < SLICE_NUM; sn = sn + 1) begin
                        addend_reg[sn] <= {LUT_OUT_WIDTH{1'b0}};
                    end
                end else if (addends_ready[0]) begin
                    for (sn = 0; sn < SLICE_NUM; sn = sn + 1) begin
                        addend_reg[sn] <= cntslices[sn];
                    end
                end
            end

            // 加法树，基于AdderLevel
            genvar glv,gai;     // glv: level index, gai: adder index
            generate
                for(glv = 0; glv < LEVELS; glv = glv + 1) begin : ADDER_LEVELS
                    localparam integer ADDER_NUM = (SLICE_NUM >> glv) / 2 + (SLICE_NUM >> glv) % 2; // 每级加法器数量
                    localparam integer SUM_WIDTH = LUT_OUT_WIDTH + 1 + glv; // 每级加法器输入宽度逐级增加1
                    reg [SUM_WIDTH-1:0] sum_reg[0:ADDER_NUM-1];
                    if (glv == 0) begin
                        for(gai = 0; gai < ADDER_NUM; gai = gai + 1) begin : ADDERS
                            always @(posedge clk) begin
                                if (!rst_n) begin
                                    sum_reg[gai] <= {SUM_WIDTH{1'b0}};
                                end else if (addends_ready[glv]) begin
                                    if (gai == ADDER_NUM - 1 && (SLICE_NUM % 2 == 1)) begin
                                        // 奇数个加数，最后一个直接传递
                                        sum_reg[gai] <= addend_reg[(2*gai)];
                                    end else begin
                                        sum_reg[gai] <= addend_reg[(2*gai)] + addend_reg[(2*gai+1)];
                                    end
                                end
                            end
                        end
                    end else begin
                        for(gai = 0; gai < ADDER_NUM; gai = gai + 1) begin : ADDERS
                            always @(posedge clk) begin
                                if (!rst_n) begin
                                    sum_reg[gai] <= {SUM_WIDTH{1'b0}};
                                end else if (addends_ready[glv]) begin
                                    if (gai == ADDER_NUM - 1 && ((SLICE_NUM >> glv) % 2 == 1)) begin
                                        // 奇数个加数，最后一个直接传递
                                        sum_reg[gai] <= ADDER_LEVELS[glv-1].ADDERS[(2*gai)].sum_reg;
                                    end else begin
                                        sum_reg[gai] <= ADDER_LEVELS[glv-1].ADDERS[(2*gai)].sum_reg + ADDER_LEVELS[glv-1].ADDERS[(2*gai+1)].sum_reg;
                                    end
                                end
                            end
                        end
                    end
                end
            endgenerate
            // 输出接口连接
            assign popcount = ADDER_LEVELS[LEVELS-1].ADDERS[0].sum_reg;
            assign out_valid = addends_valid[LEVELS-1];
            assign this_ready = addends_ready[0];
        end // end of WITH_ADDER_TREE
    endgenerate
endmodule