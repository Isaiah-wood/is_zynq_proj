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
            localparam SLICE_NUM = (VEC_WIDTH + LUT_WIDTH - 1) / LUT_WIDTH; // 向上取整
            localparam LUT_IN_WIDTH = LUT_WIDTH;
            localparam LUT_OUT_WIDTH = $clog2(LUT_WIDTH + 1);

            localparam integer LEVELS = $clog2(SLICE_NUM) + 1; // 流水级数（含末级）
            wire addends_ready[0:LEVELS];
            reg addends_valid[0:LEVELS-1];
            // ready信号反馈链
            // addends_ready[i] = 当前i级可以接收新数据
            // 当i级没有有效数据时，可以接收新数据
            // 当i级有有效数据时，只有当i+1级已经取走数据后，才能接收新数据
            assign addends_ready[LEVELS] = next_ready;
            genvar ready_idx;
            for (ready_idx = 0; ready_idx < LEVELS; ready_idx = ready_idx + 1) begin : READY_CHAIN
                // 可以接收新数据的条件：
                // 1) 当前级没有有效数据（不占用），或
                // 2) 当前级有数据，但下一级ready（可以继续流动）
                assign addends_ready[ready_idx] = (~addends_valid[ready_idx]) || addends_ready[ready_idx+1];
            end
            // valid信号传递链 - 使用握手协议
            // 当当前级 ready=1 时，接收前一级的 valid
            // 当当前级 ready=0 时，保持当前的 valid 不变（背压）
            integer lv;
            always @(posedge clk) begin
                if (!rst_n) begin
                    for (lv = 0; lv < LEVELS; lv = lv + 1) begin
                        addends_valid[lv] <= 1'b0;
                    end
                end else begin
                    for (lv = 0; lv < LEVELS; lv = lv + 1) begin
                        if (lv == 0) begin
                            // 第0级：in_valid 握手
                            if (addends_ready[0]) begin
                                addends_valid[0] <= in_valid;
                            end
                        end else begin
                            // 第lv级：来自第lv-1级的握手
                            // 只有当前级ready=1时，才接收前一级的有效信号
                            if (addends_ready[lv]) begin
                                addends_valid[lv] <= addends_valid[lv-1];
                            end
                            // 否则保持当前值（等待下游接收）
                        end
                    end
                end
            end

            // 加法树，基于AdderLevel
            genvar glv,gai;     // glv: level index, gai: adder index
            for(glv = 0; glv < LEVELS; glv = glv + 1) begin : ADDER_LEVELS
                // 当前级的输入节点数（来自前一级的输出）
                localparam integer INPUT_NUM = glv == 0 ? SLICE_NUM : ((SLICE_NUM + (1 << (glv - 1)) - 1) >> (glv - 1));
                // 当前级的输出节点数
                localparam integer OUTPUT_NUM = glv == 0 ? SLICE_NUM : ((SLICE_NUM + (1 << glv) - 1) >> glv);
                localparam integer SUM_WIDTH = LUT_OUT_WIDTH + glv; // 每级加法器输入宽度逐级增加1
                reg [SUM_WIDTH-1:0] sum_reg[0:OUTPUT_NUM-1];
                if (glv == 0) begin
                    for(gai = 0; gai < OUTPUT_NUM; gai = gai + 1) begin : SLICES
                        wire [LUT_IN_WIDTH-1:0] vecslice;
                        wire [LUT_OUT_WIDTH-1:0] cntslice;
                        assign vecslice = (gai+1)*LUT_WIDTH > VEC_WIDTH ?
                                        {{(gai+1)*LUT_WIDTH-VEC_WIDTH{1'b0}}, vec[VEC_WIDTH-1:gai*LUT_WIDTH]} :
                                        vec[gai*LUT_WIDTH +: LUT_WIDTH];
                        LUT6_Popcount #(
                            .DIN_WIDTH (LUT_IN_WIDTH),
                            .DOUT_WIDTH(LUT_OUT_WIDTH)
                        ) u_lut6_popcount (
                            .din (vecslice),
                            .dout(cntslice)
                        );
                        always @(posedge clk) begin
                            if(!rst_n) begin
                                sum_reg[gai] <= {SUM_WIDTH{1'b0}};
                            end else if (addends_ready[glv]) begin
                                sum_reg[gai] <= cntslice;
                            end
                        end
                    end
                end else begin
                    for(gai = 0; gai < OUTPUT_NUM; gai = gai + 1) begin : ADDERS
                        always @(posedge clk) begin
                            if (!rst_n) begin
                                sum_reg[gai] <= {SUM_WIDTH{1'b0}};
                            end else if (addends_ready[glv]) begin
                                if (gai == OUTPUT_NUM - 1 && (INPUT_NUM % 2 == 1)) begin
                                    // 奇数个加数，最后一个直接传递
                                    sum_reg[gai] <= ADDER_LEVELS[glv-1].sum_reg[(2*gai)];
                                end else begin
                                    sum_reg[gai] <= ADDER_LEVELS[glv-1].sum_reg[(2*gai)] + ADDER_LEVELS[glv-1].sum_reg[(2*gai+1)];
                                end
                            end
                        end
                    end
                end
            end
            // 输出接口连接
            assign popcount = ADDER_LEVELS[LEVELS-1].sum_reg[0];
            assign out_valid = addends_valid[LEVELS-1];
            assign this_ready = addends_ready[0];
        end // end of WITH_ADDER_TREE
    endgenerate
endmodule