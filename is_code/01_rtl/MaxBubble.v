// ============================================================================
// MaxBubble.v
//  - 输入数据流，依次比较保留最大值，在last信号到达时输出最大值和对应索引
// ============================================================================


`timescale 1ns / 1ps



module MaxBubble #(
    parameter integer DATA_WIDTH = 11,
    parameter integer DATA_NUM = 15486,
    parameter integer INDEX_WIDTH = $clog2(DATA_NUM)
) (
    input wire clk,
    input wire rst_n,

    input wire in_valid,
    output wire this_ready,
    output wire out_valid,
    input wire next_ready,

    input wire [DATA_WIDTH-1:0] in_data,
    input wire in_last,

    output wire [DATA_WIDTH-1:0] max_data,
    output wire [INDEX_WIDTH-1:0] max_index
);
    reg [DATA_WIDTH-1:0] max_data_buffer;
    reg [INDEX_WIDTH-1:0] max_index_buffer;
    reg out_valid_reg;


    assign this_ready = (~out_valid_reg) || next_ready;

    // 输入数据计数
    // 输入握手时计数，遇到 in_last 清零
    reg [INDEX_WIDTH-1:0] cur_index;
    always @(posedge clk) begin
        if (!rst_n) begin
            cur_index <= {INDEX_WIDTH{1'b0}};
        end else if (this_ready && in_valid) begin
            if (in_last) begin
                cur_index <= {INDEX_WIDTH{1'b0}};     // 索引从1开始计数，0表示没有有效数据
            end else begin
                cur_index <= cur_index + 1;
            end
        end
    end

    // 
    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid_reg <= 0;
        end else begin
            if (in_valid && this_ready && in_last && !out_valid_reg) begin
                out_valid_reg <= 1;
            end else if (out_valid_reg && next_ready) begin
                out_valid_reg <= 0;
            end
        end
    end

    // reg [DATA_WIDTH-1:0] max_data_reg;
    // reg [INDEX_WIDTH-1:0] max_index_reg;
    // always @(posedge clk) begin
    //     if (!rst_n) begin
    //         max_data_reg <= {DATA_WIDTH{1'b0}};
    //         max_index_reg <= 32'd0;
    //     end else begin
    //         if (out_valid_reg) begin
    //             max_data_reg <= max_data_buffer;
    //             max_index_reg <= max_index_buffer;
    //         end
    //     end
    // end




    always @(posedge clk) begin
        if (!rst_n) begin
            max_data_buffer <= {DATA_WIDTH{1'b0}};
            max_index_buffer <= {INDEX_WIDTH{1'b0}};
        end else begin
            if (in_valid && this_ready) begin
                // 比较并更新最大值
                if (cur_index == 0 || in_data > max_data_buffer) begin
                    max_data_buffer <= in_data;
                    max_index_buffer <= cur_index;
                end
                // if (in_last) begin
                //     max_data_reg <= in_data > max_data_buffer ? in_data : max_data_buffer;
                //     max_index_reg <= in_data > max_data_buffer ? cur_index : max_index_buffer;
                // end
            end
        end
    end



    // 输出连接
    assign max_data =  out_valid_reg ? max_data_buffer : {DATA_WIDTH{1'b0}};
    assign max_index = out_valid_reg ? max_index_buffer : {INDEX_WIDTH{1'b0}};
    // assign max_data = max_data_reg;
    // assign max_index = max_index_reg;
    assign out_valid = out_valid_reg;








endmodule