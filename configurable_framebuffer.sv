// Authors:
// - Wang Zhe <gmlayer0@outlook.com>

`include "vga_def.svh"

module configurable_framebuffer
  //-----------------------------------------------------------------
  // Ports
  //-----------------------------------------------------------------
  (
    input clk,
    input rst_n,
    AXI_LITE.Slave slv,
    AXI_BUS.Master dma,

    output         vga_clk_x2_o,
    output         vga_clk_o,
    output         vga_de_o,
    output         vga_h_o,
    output         vga_v_o,
    output [7:0]   vga_r_o,
    output [7:0]   vga_g_o,
    output [7:0]   vga_b_o
  );

// Register Module
REG_BUS #(.ADDR_WIDTH(32),.DATA_WIDTH(32)) reg_bus();
axi_lite_to_reg_intf #(
  .ADDR_WIDTH(32),
  .DATA_WIDTH(32)
) axi_lite_to_reg_intf_inst (
  .clk_i(clk),
  .rst_ni(rst_n),
  .axi_i(slv),
  .reg_o(reg_bus)
);

wire update_valid, update_ready;
wire update_cfg = update_valid & update_ready;
wire active;
wire [5:0]  fifo_level;
wire [15:0] fifo_underrun;
vga_cfg_t cfg_reg;
fbdma_cfg_t fbdma_reg;
wire [31:0] perf_reg = {fifo_underrun,2'd0,fifo_level,7'd0,active};
framebuffer_regs  framebuffer_regs_inst (
    .clk(clk),
    .rst_n(rst_n),
    .reg_bus(reg_bus),
    .cfg_o(cfg_reg),
    .fbdma_o(fbdma_reg),
    .update_valid_o(update_valid),
    .update_ready_i(update_ready),
    .perf_i(perf_reg)
);

wire framefinish;
wire rdata_valid, rdata_ready;
wire[31:0] rdata;

framebuffer_dma framebuffer_dma_inst (
    .clk(clk),
    .rst_n(rst_n),
    .dma(dma),
    .fbdma_i(fbdma_reg),
    .update_i(update_cfg),
    .framefinish_i(framefinish),
    .rdata_valid_o(rdata_valid),
    .rdata_ready_i(rdata_ready),
    .rdata_o(rdata),
    .active_i(active),
    .level_o(fifo_level)
);

framebuffer_gen  framebuffer_gen_inst (
    .clk(clk),
    .rst_n(rst_n),
    .update_valid_i(update_valid),
    .update_ready_o(update_ready),
    .framefinish_o(framefinish),
    .cfg_i(cfg_reg),
    .fifo_valid_i(rdata_valid),
    .fifo_ready_o(rdata_ready),
    .fifo_data_i(rdata),
    .active_o(active),
    .vga_r_o(vga_r_o),
    .vga_g_o(vga_g_o),
    .vga_b_o(vga_b_o),
    .vga_de_o(vga_de_o),
    .vga_h_o(vga_h_o),
    .vga_v_o(vga_v_o),
    .vga_clk_o(vga_clk_o),
    .vga_clk_x2_o(vga_clk_x2_o),
    .fifo_underrun_o(fifo_underrun)
  );

endmodule
