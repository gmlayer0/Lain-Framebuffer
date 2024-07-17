// Authors:
// - Wang Zhe <gmlayer0@outlook.com>

`include "vga_def.svh"

/*
0 - sync        == sync:1 de:0 (start mode)
1 - back_proch  == sync:0 de:0
2 - active      == sync:0 de:1
3 - front_proch == sync:0 de:0 (reset mode)
*/
module framebuffer_gen (
    input clk,                           // vga_clk_x4
    input rst_n,

    (*mark_debug="true"*) input update_valid_i,                // 配置有效位
    (*mark_debug="true"*) output update_ready_o,               // 配置完成应答
    output framefinish_o,
    input vga_cfg_t    cfg_i,

    (*mark_debug="true"*) output active_o,                     // DMA 工作提示符


    (*mark_debug="true"*) input  fifo_valid_i,
    (*mark_debug="true"*) output fifo_ready_o,
    (*mark_debug="true"*) input [31:0] fifo_data_i,            // Fifo 返回数据

    output reg [7:0]   vga_r_o,
    output reg [7:0]   vga_g_o,
    output reg [7:0]   vga_b_o,
    output reg         vga_de_o,
    output reg         vga_h_o,
    output reg         vga_v_o,
    output         vga_clk_o,            // 33mhz
    output         vga_clk_x2_o,         // 67mhz used for double data rate transfer
    output [15:0]  fifo_underrun_o
  );
  // 分频计数器, 对于 pixel fetcher, 使用 x2 clk poseedge。
  reg [1:0] clk_div_cnt_q;
  always_ff @(posedge clk) begin
    clk_div_cnt_q <= clk_div_cnt_q + 2'b01;
  end
  reg vga_clk_q, vga_clk_q_2,vga_clk_x2_q, vga_posedge_q, pixel_edge_q;
  assign vga_clk_o = vga_clk_q_2;
  assign vga_clk_x2_o = vga_clk_x2_q;
  always_ff @(posedge clk) begin
    vga_clk_q     <= clk_div_cnt_q[1];
    vga_clk_x2_q  <= clk_div_cnt_q[0];
    vga_clk_q_2   <= clk_div_cnt_q[1];
    vga_posedge_q <= (~clk_div_cnt_q[1]) &   clk_div_cnt_q[0] ; // 2'b01
    pixel_edge_q  <= (~clk_div_cnt_q[1]) & (~clk_div_cnt_q[0]); // 2'b00
  end

  vga_cfg_t cfg_q;

  always_ff @(posedge clk) begin
    if(!rst_n || (update_valid_i && update_ready_o)) begin
      cfg_q <= cfg_i;
    end
  end

  // 状态在 Posedge 上更新
  (*mark_debug="true"*) reg [1:0] hfsm_q, vfsm_q;
  (*mark_debug="true"*) reg [HTOTAL_LEN-1:0] hcnt_q;
  (*mark_debug="true"*) reg [VTOTAL_LEN-1:0] vcnt_q;

  wire heq = hcnt_q == '0;
  wire veq = vcnt_q == '0;

  wire frame_finish = heq && veq && vfsm_q == 2'b00 && hfsm_q == 2'b00; // 3 cycle before actual load next frame parameter
  reg frame_finish_q; // 2 cycle before actual load next frame parameter
  always_ff @(posedge clk) frame_finish_q <= frame_finish;

  always_ff @(posedge clk) begin
    if(~rst_n) begin
      vfsm_q <= '0;
      vcnt_q <= '0;
      hfsm_q <= '0;
      hcnt_q <= '0;
    end
    else
      if(vga_posedge_q) begin
        if(heq) begin
          if(hfsm_q == '1) begin
            if(veq) begin
              vcnt_q <= cfg_q.vcfg[vfsm_q];
              vfsm_q <= vfsm_q + 2'd1;
            end
            else begin
              vcnt_q <= vcnt_q - 1'd1;
            end
          end
          hcnt_q <= cfg_q.hcfg[hfsm_q];
          hfsm_q <= hfsm_q + 2'd1;
        end
        else begin
          hcnt_q <= hcnt_q - 1'd1;
        end
      end
  end

  (*mark_debug="true"*) wire pixel_valid, pixel_ready;
  (*mark_debug="true"*) wire[23:0] pixel_data;
  (*mark_debug="true"*) wire pixel_pop;
  reg active_q;
  assign pixel_ready = pixel_pop || !active_q;
  assign active_o = active_q;
  assign update_ready_o = frame_finish_q && !vga_posedge_q;
  assign framefinish_o = frame_finish_q && vga_posedge_q;
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      active_q <= 1'b0;
    end else begin
      if(frame_finish_q && vga_posedge_q) begin
        active_q <= cfg_q.activecfg;
      end else if(!cfg_q.activecfg || (pixel_pop && !pixel_valid)) begin
        active_q <= '0;
      end
    end
  end

  wire fifo_valid_w, fifo_ready_w;
  wire[31:0] fifo_data_w;
  spill_register_noflushable #(
    .T(logic[31:0])
  ) pixel_input_register_inst (
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(fifo_valid_i),
    .flush_i(!active_q),
    .ready_o(fifo_ready_o),
    .data_i(fifo_data_i),
    .valid_o(fifo_valid_w),
    .ready_i(fifo_ready_w),
    .data_o(fifo_data_w)
  );
  wire pixel_valid_w, pixel_ready_w;
  wire[23:0] pixel_data_w;
  pixel_converter  pixel_converter_inst (
    .clk(clk),
    .rst_n(rst_n),
    .bitcfg_i(cfg_q.bitcfg),
    .flush_i(frame_finish_q),
    .fifo_valid_i(fifo_valid_w),
    .fifo_ready_o(fifo_ready_w),
    .fifo_data_i(fifo_data_w),
    .pixel_valid_o(pixel_valid_w),
    .pixel_ready_i(pixel_ready_w),
    .pixel_data_o(pixel_data_w)
  );
  spill_register_noflushable #(
    .T(logic[23:0])
  ) pixel_output_register_inst (
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(pixel_valid_w),
    .flush_i(!active_q),
    .ready_o(pixel_ready_w),
    .data_i(pixel_data_w),
    .valid_o(pixel_valid),
    .ready_i(pixel_ready),
    .data_o(pixel_data)
  );

  // 时序输出状态机
  assign pixel_pop = hfsm_q == 2'd3 && vfsm_q == 2'd3 && vga_posedge_q;
  wire [23:0]vga_rgb_w;
  wire vga_de_w, vga_h_w, vga_v_w;
  assign vga_rgb_w = (hfsm_q == 2'd3 && vfsm_q == 2'd3) ? pixel_data : '0;
  assign vga_de_w = hfsm_q == 2'd3 && vfsm_q == 2'd3;
  assign vga_h_w = hfsm_q == 2'd1;
  assign vga_v_w = vfsm_q == 2'd1;
  always_ff @(posedge vga_clk_q) begin
    vga_r_o  <= vga_rgb_w[23:16];
    vga_g_o  <= vga_rgb_w[15: 8];
    vga_b_o  <= vga_rgb_w[ 7: 0];
    vga_de_o <= vga_de_w;
    vga_h_o  <= vga_h_w;
    vga_v_o  <= vga_v_w;
  end

  // Underrun 计数器
  reg[15:0] underrun_q;
  assign fifo_underrun_o = underrun_q;
  always_ff @(posedge clk) begin
    if(~rst_n) begin
      underrun_q <= '0;
    end else begin
      if(active_q && pixel_pop && !pixel_valid) begin
        underrun_q <= underrun_q + 1'd1;
      end
    end
  end

endmodule
