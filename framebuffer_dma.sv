// Authors:
// - Wang Zhe <gmlayer0@outlook.com>

`include "vga_def.svh"

module framebuffer_dma#(
// 可配置参数
parameter FIFO_DEPTH = 48,
parameter FETCH_WORD_CNT = 16,
parameter FIFO_PTR_LEN = $clog2(FIFO_DEPTH) // 5
)(
    input clk,
    input rst_n,
    AXI_BUS.Master     dma,

    input  fbdma_cfg_t fbdma_i,
    input              update_i,
    input              framefinish_i,

    // FIFO 接口
    output             rdata_valid_o,
    input              rdata_ready_i,
    output      [31:0] rdata_o,

    // 激活状态输入
    input              active_i,

    // 性能输出
    output [FIFO_PTR_LEN-1:0] level_o
);

reg [FIFO_PTR_LEN-1:0] fifo_allocated_space_q;
wire fifo_ready_for_next_trans_w = fifo_allocated_space_q <= (FIFO_DEPTH - FETCH_WORD_CNT);

// 配置更新逻辑
fbdma_cfg_t fbdma_q;
always_ff @(posedge clk) begin
    if(update_i) begin
        fbdma_q <= fbdma_i;
    end
end

// FIFO 空间分配逻辑
always_ff @(posedge clk) begin
    if(!rst_n || !active_i) begin
        fifo_allocated_space_q <= '0;
    end else begin
        if(dma.ar_valid && dma.ar_ready && !(rdata_valid_o && rdata_ready_i)) begin
            fifo_allocated_space_q <= fifo_allocated_space_q + FETCH_WORD_CNT;
        end else if(dma.ar_valid && dma.ar_ready && rdata_valid_o && rdata_ready_i) begin
            fifo_allocated_space_q <= fifo_allocated_space_q + FETCH_WORD_CNT - 1;
        end else if(rdata_valid_o && rdata_ready_i) begin
            fifo_allocated_space_q <= fifo_allocated_space_q - 1;
        end
    end
end

// FIFO 逻辑 及 R 握手
wire fifo_full, fifo_empty;
wire fifo_push = dma.r_valid   & dma.r_ready;
wire fifo_pop  = rdata_valid_o & rdata_ready_i;
assign dma.r_ready = !fifo_full;
assign rdata_valid_o = !fifo_empty;
fifo_v3 #(
    .FALL_THROUGH ( 1'b0        ),
    .DEPTH        ( FIFO_DEPTH  ),
    .dtype        ( logic[31:0] )
) fetch_fifo (
    .clk_i     ( clk        ),
    .rst_ni    ( rst_n      ),
    .flush_i   ( !active_i  ),
    .testmode_i( 1'b0       ),
    .full_o    ( fifo_full  ),
    .empty_o   ( fifo_empty ),
    .usage_o   ( level_o[FIFO_PTR_LEN-1:0] ),
    .data_i    ( dma.r_data ),
    .push_i    ( fifo_push  ),
    .data_o    ( rdata_o    ),
    .pop_i     ( fifo_pop   )
);

// FETCH 计数器 及 地址逻辑
(*mark_debug="true"*) reg[16:0] fetch_cnt_q;
(*mark_debug="true"*) reg[31:0] ar_addr_q;
always_ff @(posedge clk) begin
    if(!rst_n || !active_i || framefinish_i) begin
        fetch_cnt_q <= fbdma_q.dma_length[22:6];
        ar_addr_q   <= fbdma_q.dma_start;
    end else begin
        if(dma.ar_valid && dma.ar_ready) begin
            fetch_cnt_q <= fetch_cnt_q - 1'd1;
            ar_addr_q[31:$clog2(FETCH_WORD_CNT)+2] <= ar_addr_q[31:$clog2(FETCH_WORD_CNT)+2] + 1'd1;
        end
    end
end

// AR 握手
(*mark_debug="true"*) reg arvalid_q;
(*mark_debug="true"*) wire arready_w = dma.ar_ready;
always_ff @(posedge clk) begin
    if(!rst_n || !active_i) begin
        arvalid_q <= '0;
    end else begin
        if(dma.ar_valid && dma.ar_ready) begin
            arvalid_q <= '0;
        end else begin
            arvalid_q <= fifo_ready_for_next_trans_w && (fetch_cnt_q != '0);
        end
    end
end
assign dma.ar_valid = arvalid_q;

// AR 控制信号
assign dma.ar_id = '0;
assign dma.ar_addr = ar_addr_q;
assign dma.ar_len = FETCH_WORD_CNT-1;
assign dma.ar_size = 3'b010;
assign dma.ar_burst = 2'b01;
assign dma.ar_lock = '0;
assign dma.ar_cache = '0;
assign dma.ar_prot = '0;
assign dma.ar_qos = '0;
assign dma.ar_region = '0;
assign dma.ar_user = '0;

// AW 控制信号
assign dma.aw_id = '0;
assign dma.aw_addr = '0;
assign dma.aw_len = '0;
assign dma.aw_size = '0;
assign dma.aw_burst = '0;
assign dma.aw_lock = '0;
assign dma.aw_cache = '0;
assign dma.aw_prot = '0;
assign dma.aw_qos = '0;
assign dma.aw_region = '0;
assign dma.aw_atop = '0;
assign dma.aw_user = '0;
assign dma.aw_valid = '0;

// W 控制信号
assign dma.w_data = '0;
assign dma.w_strb = '0;
assign dma.w_last = '0;
assign dma.w_user = '0;
assign dma.w_valid = '0;

// B 控制信号
assign dma.b_ready = '1;

endmodule
