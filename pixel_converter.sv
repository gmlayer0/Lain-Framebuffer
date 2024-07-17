// Authors:
// - Wang Zhe <gmlayer0@outlook.com>

`define R_BITS 23:16
`define G_BITS 15:8
`define B_BITS  7:0
`define M_3    31:24
`define M_2    23:16
`define M_1    15:8
`define M_0     7:0

module pixel_converter(
    input clk,
    input rst_n,
    input flush_i,

    input [1:0] bitcfg_i,                // 色彩模式配置, 0: 8bits, 1: 24bits, 3: 16bits

    input  fifo_valid_i,
    output fifo_ready_o,                   // Fifo 弹出一个数据
    input [31:0] fifo_data_i,            // Fifo 返回数据

    output pixel_valid_o,
    input  pixel_ready_i,
    output [23:0] pixel_data_o
  );

  reg [1:0] pixel_wptr_q;
  reg [1:0] pixel_rptr_q;
  reg [2:0] pixel_cnt_q;
  reg [3:0][23:0] fifo_q;
  wire double_write_w = pixel_wptr_q == 2'b10 || bitcfg_i[1];

  always_ff @(posedge clk) begin
    if(~rst_n || flush_i) begin
      pixel_wptr_q <= '0;
    end
    else
      if(fifo_valid_i && fifo_ready_o) begin
        pixel_wptr_q <= double_write_w ? {~pixel_wptr_q[1], 1'b0} : (pixel_wptr_q + 2'd1);
      end
  end

  always_ff @(posedge clk) begin
    if(~rst_n || flush_i) begin
      pixel_rptr_q <= '0;
    end
    else
      if(pixel_valid_o && pixel_ready_i) begin
        pixel_rptr_q <= pixel_rptr_q + 2'b01;
      end
  end

  always_ff @(posedge clk) begin
    if(~rst_n || flush_i) begin
      pixel_cnt_q <= '0;
    end
    else begin
      if((fifo_valid_i && fifo_ready_o) && !(pixel_valid_o && pixel_ready_i)) begin
        // W-Only
        if(double_write_w) begin
          pixel_cnt_q <= pixel_cnt_q + 3'd2;
        end
        else begin
          pixel_cnt_q <= pixel_cnt_q + 3'd1;
        end
      end
      else if((fifo_valid_i && fifo_ready_o) && (pixel_valid_o && pixel_ready_i)) begin
        // WR
        if(double_write_w) begin
          pixel_cnt_q <= pixel_cnt_q + 3'd1;
        end
      end
      else if(pixel_valid_o && pixel_ready_i) begin
        // R-Only
        pixel_cnt_q <= pixel_cnt_q - 3'd1;
      end
    end
  end
  assign fifo_ready_o  = pixel_cnt_q < 3'd2;
  assign pixel_valid_o = pixel_cnt_q > 3'd0;
  assign pixel_data_o = fifo_q[pixel_rptr_q];

  // fifo_q 写入逻辑
  // 色彩模式配置, 0: 32bits, 1: 24bits, 3: 16bits
  // 0
  always_ff @(posedge clk) begin
    if(fifo_valid_i && fifo_ready_o) begin
      if(pixel_wptr_q == 2'b00) begin
        if(bitcfg_i[1]) begin // 16bits mode
          fifo_q[0] <= {fifo_data_i[15:11],3'd0,fifo_data_i[10:5],2'd0,fifo_data_i[4:0],3'd0};
          fifo_q[1] <= {fifo_data_i[16+15:16+11],3'd0,fifo_data_i[16+10:16+5],2'd0,fifo_data_i[16+4:16+0],3'd0};
        end
        else begin
          // 24 bits mode
          fifo_q[0][`R_BITS] <= fifo_data_i[`M_0];
          fifo_q[0][`G_BITS] <= fifo_data_i[`M_1];
          fifo_q[0][`B_BITS] <= fifo_data_i[`M_2];
          fifo_q[1][`R_BITS] <= fifo_data_i[`M_3];
        end
      end
      else if(pixel_wptr_q == 2'b01) begin
        // 24 bits mode
        fifo_q[1][`G_BITS] <= fifo_data_i[`M_0];
        fifo_q[1][`B_BITS] <= fifo_data_i[`M_1];
        fifo_q[2][`R_BITS] <= fifo_data_i[`M_2];
        fifo_q[2][`G_BITS] <= fifo_data_i[`M_3];
      end
      else if(pixel_wptr_q == 2'b10) begin
        if(bitcfg_i[1]) begin // 16bits mode
          fifo_q[2] <= {fifo_data_i[15:11],3'd0,fifo_data_i[10:5],2'd0,fifo_data_i[4:0],3'd0};
          fifo_q[3] <= {fifo_data_i[16+15:16+11],3'd0,fifo_data_i[16+10:16+5],2'd0,fifo_data_i[16+4:16+0],3'd0};
        end
        else begin
          // 24 bits mode
          fifo_q[2][`B_BITS] <= fifo_data_i[`M_0];
          fifo_q[3][`R_BITS] <= fifo_data_i[`M_1];
          fifo_q[3][`G_BITS] <= fifo_data_i[`M_2];
          fifo_q[3][`B_BITS] <= fifo_data_i[`M_3];
        end
      end
    end
  end

endmodule
