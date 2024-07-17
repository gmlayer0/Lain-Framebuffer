// Authors:
// - Wang Zhe <gmlayer0@outlook.com>

`include "vga_def.svh"

module framebuffer_regs(
    input clk,
    input rst_n,
    REG_BUS.in reg_bus,

    output vga_cfg_t   cfg_o,
    output fbdma_cfg_t fbdma_o,
    output             update_valid_o,
    input              update_ready_i,

    // 性能计数器
    input wire [31:0]  perf_i
);

reg  [31:0] rdata_q;
wire [31:0] wdata = reg_bus.wdata;
wire [3:0] addr = reg_bus.addr[5:2];
wire we = reg_bus.write && reg_bus.valid;
wire re = reg_bus.valid;
assign reg_bus.rdata = rdata_q;
assign reg_bus.error = '0;
assign reg_bus.ready = '1;

reg pending_cfg_update_q;
vga_cfg_t cfg_q;
fbdma_cfg_t fbdma_q;
// 写入逻辑处理
always_ff @(posedge clk) begin
    if(~rst_n) begin
        cfg_q <= '{
            activecfg: 1'd1,
            bitcfg: 2'd3,
            hcfg: {
                11'd47,
                11'd1279,
                11'd79,
                11'd31
            },
            vcfg: {
                11'd2,
                11'd719,
                11'd12,
                11'd4
            }
        };
        fbdma_q <= '{
            dma_start:  32'h0F00_0000,
            dma_length: 1280*720*2
        };
    end else begin
        if(we) begin
            if(addr[3:2] == 2'd0) begin
                if(addr[1:0] == 2'd0) begin
                    cfg_q.activecfg   <= wdata[0]; 
                    cfg_q.bitcfg      <= wdata[3:2];
                end
                if(addr[1:0] == 2'd2) begin
                    fbdma_q.dma_start[31:12] <= wdata[31:12];
                end
                if(addr[1:0] == 2'd3) begin
                    fbdma_q.dma_length[22:6] <= wdata[22:6];
                end
            end
            if(addr[3:2] == 2'd1) begin
                // HCFG
                cfg_q.hcfg[addr[1:0]] <= wdata[10:0];
            end
            if(addr[3:2] == 2'd2) begin
                // VCFG
                cfg_q.vcfg[addr[1:0]] <= wdata[10:0];
            end
        end
    end
end

// 读出逻辑，仅支持状态寄存器，够用了
always_ff @(posedge clk) begin
  if(~rst_n) begin
    rdata_q <= '0;
  end else
//   if(addr[1:0] == 2'd1) begin
    // 仅有一个可读寄存器
    rdata_q[0]        <= perf_i[0];
    rdata_q[1]        <= pending_cfg_update_q;
    rdata_q[31:8]     <= perf_i[31:8];
//   end
end

// Pending 逻辑
always_ff @(posedge clk) begin
    if(~rst_n) begin
        pending_cfg_update_q <= '1;
    end else begin
        if(addr[3:1]==3'd0 && wdata[1] && we) begin
            pending_cfg_update_q <= '1;
        end else if(update_ready_i) begin
            pending_cfg_update_q <= '0;
        end
    end
end

// 输出逻辑
assign cfg_o = cfg_q;
assign fbdma_o = fbdma_q;
assign update_valid_o = pending_cfg_update_q;

endmodule