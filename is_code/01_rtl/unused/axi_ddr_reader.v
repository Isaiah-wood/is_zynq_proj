

// // =============================================================
// // 2. DDR 读取封装模块（完整AXI接口 + BRAM样式接口） axi_ddr_reader.v
// // =============================================================

// module axi_ddr_reader #(
//     parameter DATA_WIDTH = 256,
//     parameter N          = 5,
//     parameter ADDR_WIDTH = 32,
//     parameter ID_WIDTH   = 4,
//     parameter DATA_BYTES = DATA_WIDTH/8
// )(
//     input  wire                     ACLK,
//     input  wire                     ARESETN,

//     // 用户接口
//     input  wire                     start,
//     output reg                      busy,
//     output reg                      valid,
//     output reg [N*DATA_WIDTH-1:0]   data_out,

//     // AXI Read Address Channel
//     output reg [ADDR_WIDTH-1:0]     M_AXI_araddr,
//     output reg [1:0]                M_AXI_arburst,
//     output reg [3:0]                M_AXI_arcache,
//     output reg [ID_WIDTH-1:0]       M_AXI_arid,
//     output reg [7:0]                M_AXI_arlen,
//     output reg [1:0]                M_AXI_arlock,
//     output reg [2:0]                M_AXI_arprot,
//     output reg [3:0]                M_AXI_arqos,
//     input  wire                     M_AXI_arready,
//     output reg [2:0]                M_AXI_arsize,
//     output reg                     M_AXI_arvalid,

//     // AXI Read Data Channel
//     input  wire [ID_WIDTH-1:0]      M_AXI_rid,
//     input  wire [DATA_WIDTH-1:0]    M_AXI_rdata,
//     input  wire                     M_AXI_rlast,
//     output reg                      M_AXI_rready,
//     input  wire [1:0]               M_AXI_rresp,
//     input  wire                     M_AXI_rvalid
// );

// // 地址递增
// reg [ADDR_WIDTH-1:0] base_addr = 0;

// // buffer
// reg [DATA_WIDTH-1:0] buffer[0:N-1];
// reg [$clog2(N):0] recv_cnt;

// // FSM
// localparam S_IDLE=0,S_AR=1,S_RECV=2,S_DONE=3;
// reg [1:0] state;

// // ------------------ AR 控制块 ------------------
// always @(posedge ACLK) begin
//     if (!ARESETN) begin
//         M_AXI_arvalid <= 0;
//         M_AXI_arburst <= 2'b01;
//         M_AXI_arcache <= 4'b0011;
//         M_AXI_arid    <= 0;
//         M_AXI_arlock  <= 0;
//         M_AXI_arprot  <= 0;
//         M_AXI_arqos   <= 0;
//         M_AXI_arsize  <= $clog2(DATA_BYTES);
//     end else begin
//         case(state)
//             S_IDLE: begin
//                 if (start) begin
//                     M_AXI_araddr  <= base_addr;
//                     M_AXI_arlen   <= N-1;
//                     M_AXI_arvalid <= 1;
//                 end
//             end
//             S_AR: begin
//                 if (M_AXI_arvalid && M_AXI_arready)
//                     M_AXI_arvalid <= 0;
//             end
//         endcase
//     end
// end

// // ------------------ R 通道接收 ------------------
// always @(posedge ACLK) begin
//     if (!ARESETN) begin
//         M_AXI_rready <= 0;
//     end else begin
//         case(state)
//             S_AR:
//                 if(M_AXI_arready)
//                     M_AXI_rready <= 1;
//             S_RECV:
//                 if(M_AXI_rvalid && M_AXI_rready)
//                     buffer[recv_cnt] <= M_AXI_rdata;
//             S_DONE:
//                 M_AXI_rready <= 0;
//         endcase
//     end
// end

// // ------------------ 主状态机 ------------------
// integer i;
// always @(posedge ACLK) begin
//     if(!ARESETN) begin
//         state<=S_IDLE; recv_cnt<=0; busy<=0; valid<=0;
//     end else begin
//         valid<=0;
//         case(state)
//         S_IDLE: begin
//             busy<=0;
//             if(start) begin
//                 recv_cnt<=0;
//                 busy<=1;
//                 state<=S_AR;
//             end
//         end
//         S_AR: begin
//             if(M_AXI_arready) state<=S_RECV;
//         end
//         S_RECV: begin
//             if(M_AXI_rvalid && M_AXI_rready) begin
//                 recv_cnt <= recv_cnt + 1;
//                 if(M_AXI_rlast) state<=S_DONE;
//             end
//         end
//         S_DONE: begin
//             for(i=0;i<N;i=i+1) begin
//                 data_out[(N-1-i)*DATA_WIDTH +: DATA_WIDTH] <= buffer[i];
//             end
//             valid<=1;
//             base_addr <= base_addr + N*DATA_BYTES;
//             state<=S_IDLE;
//         end
//         endcase
//     end
// end
// endmodule




// axi_ddr_reader.v
// 流式 DDR 读取封装（AXI Master 只读）：
// - 接收 N 个 256-bit beat，使用滑动拼接（shift register）输出一个 N*256 位的长字
// - 流式、低额外存储、适合流水线/连续读
// - 将 AXI 接口命名为 M_AXI_*（master）以便直接连到 DDR 模型或 AXI interconnect
`timescale 1ns/1ps
module axi_ddr_reader #(
    parameter integer DATA_WIDTH = 256,
    parameter integer N = 5,
    parameter integer ADDR_WIDTH = 32,
    parameter integer ID_WIDTH = 4
)(
    input  wire                     ACLK,
    input  wire                     ARESETN,

    // 用户控制接口（BRAM 风格的触发接口）
    input  wire                     start,      // 触发一次读取（一次读取为 N beats 的 burst）
    output reg                      busy,       // 正在读取中
    output reg                      valid,      // 输出 data_out 有效（一次 N-beat 的拼接结果）
    output reg [N*DATA_WIDTH-1:0]   data_out,   // 拼接后的输出（N 个 DATA_WIDTH 拼接，N 默认为 5）

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

    // (写通道等信号可按你给出的完整列表扩展，当前仅声明了读通道相关信号)
);

// 字节宽度常量
localparam integer DATA_BYTES = DATA_WIDTH/8;
localparam integer TOTAL_WIDTH = N * DATA_WIDTH;

// 基地址（顺序循环访问整个数据块时由上层维护或可在此处加上 MEM_DEPTH 参数）
reg [ADDR_WIDTH-1:0] base_addr;

// 滑动拼接寄存器（shift register），采用流式拼接：每来一拍，左移并把最新数据放低位
reg [TOTAL_WIDTH-1:0] concat_shift;

// 已接收 beat 计数（0..N-1）
reg [$clog2(N)-1:0] recv_cnt;

// 简单 FSM 状态
localparam S_IDLE = 2'd0;
localparam S_AR   = 2'd1;
localparam S_RECV = 2'd2;
localparam S_DONE = 2'd3;
reg [1:0] state;

// ---------------- AR 控制块（独立 always 块，负责 AR 发起与 AR 信号预配置） ----------------
always @(posedge ACLK) begin
    if (!ARESETN) begin
        M_AXI_arvalid <= 1'b0;
        M_AXI_araddr  <= {ADDR_WIDTH{1'b0}};
        M_AXI_arlen   <= 8'd0;
        M_AXI_arburst <= 2'b01;      // 默认 INCR
        M_AXI_arcache <= 4'b0011;
        M_AXI_arid    <= {ID_WIDTH{1'b0}};
        M_AXI_arlock  <= 2'b0;
        M_AXI_arprot  <= 3'b000;
        M_AXI_arqos   <= 4'b0000;
        M_AXI_arsize  <= $clog2(DATA_BYTES);
    end else begin
        // 只有在空闲时按用户请求发起 AR
        if (state == S_IDLE) begin
            if (start) begin
                M_AXI_araddr  <= base_addr;
                M_AXI_arlen   <= N - 1;   // ARLEN = N-1 表示 N beats
                M_AXI_arvalid <= 1'b1;
                // 其他字段（id/size/burst）在复位时已设定好
            end else begin
                M_AXI_arvalid <= 1'b0;
            end
        end else begin
            // 在 AR 已经发出并被接受前保持 arvalid
            if (state == S_AR) begin
                if (M_AXI_arvalid && M_AXI_arready) begin
                    M_AXI_arvalid <= 1'b0; // 已被接受
                end
            end else begin
                M_AXI_arvalid <= 1'b0;
            end
        end
    end
end

// ---------------- R 接收块（独立 always 块，负责 RREADY 控制与数据采集的即时移位拼接） ----------------
always @(posedge ACLK) begin
    if (!ARESETN) begin
        M_AXI_rready   <= 1'b0;
        concat_shift   <= {TOTAL_WIDTH{1'b0}};
        recv_cnt       <= {($clog2(N)){1'b0}};
    end else begin
        case (state)
            S_AR: begin
                // 在 AR 被接受后准备接收 R
                if (M_AXI_arready) begin
                    M_AXI_rready <= 1'b1;
                    // recv_cnt 和 concat_shift 在进入接收前清零由 FSM 主块负责设置
                end
            end

            S_RECV: begin
                // 当 R 通道有效且我们准备好接收时捕获数据
                if (M_AXI_rvalid && M_AXI_rready) begin
                    // 滑动窗口：丢弃最旧的 DATA_WIDTH 位，左移，低位拼接新数据
                    // 新的数据放在低位（便于输出时直接把 concat_shift 作为 [N-1..0] 的拼接）
                    concat_shift <= { concat_shift[TOTAL_WIDTH-1 -: (TOTAL_WIDTH-DATA_WIDTH)], M_AXI_rdata };
                    // 计数
                    if (recv_cnt == (N-1)) begin
                        recv_cnt <= 0;
                        // keep M_AXI_rready asserted until S_DONE -> FSM 会清掉
                    end else begin
                        recv_cnt <= recv_cnt + 1;
                    end
                end
            end

            S_DONE: begin
                // 完成后不再接受 R 数据
                M_AXI_rready <= 1'b0;
            end

            default: begin
                M_AXI_rready <= 1'b0;
            end
        endcase
    end
end

// ---------------- 主状态机与输出生成（独立块，提高可读性） ----------------
always @(posedge ACLK) begin
    if (!ARESETN) begin
        state <= S_IDLE;
        busy  <= 1'b0;
        valid <= 1'b0;
        data_out <= {TOTAL_WIDTH{1'b0}};
        base_addr <= {ADDR_WIDTH{1'b0}};
    end else begin
        // 默认信号
        valid <= 1'b0;

        case (state)
            S_IDLE: begin
                busy <= 1'b0;
                // 等待 start
                if (start) begin
                    // 进入 AR 发起阶段，同时清空 concat_shift 与计数，进入 S_AR
                    concat_shift <= {TOTAL_WIDTH{1'b0}};
                    recv_cnt <= 0;
                    busy <= 1'b1;
                    state <= S_AR;
                end
            end

            S_AR: begin
                // 等 AR 被接受后进入接收状态
                if (M_AXI_arvalid && M_AXI_arready) begin
                    state <= S_RECV;
                end
            end

            S_RECV: begin
                // 当到达最后一个 beat（M_AXI_rlast）并且该 beat 被接收后，进入 DONE
                // 注意：R 的接收动作在另一个 always 块中完成（移位/计数），这里只检测 handshake
                if (M_AXI_rvalid && M_AXI_rready && M_AXI_rlast) begin
                    // 拼接结果已在 concat_shift 中（最近 N 个 beat）
                    data_out <= concat_shift;
                    valid <= 1'b1;
                    // advance base_addr 按 N beats 的字节数（外层如需循环访问整个内存，可根据 MEM_DEPTH 调整）
                    base_addr <= base_addr + (N * DATA_BYTES);
                    state <= S_DONE;
                end
            end

            S_DONE: begin
                // 一次 burst 完成后回到 IDLE，允许下一次 start
                busy <= 1'b0;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
    