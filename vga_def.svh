// Authors:
// - Wang Zhe <gmlayer0@outlook.com>

`ifndef _VGA_DEF_HEADER
`define _VGA_DEF_HEADER

/* 
    此模块共三组寄存器，分别为全局/DMA控制部分 0x00,0x04,0x08,0x0c
    hcfg 配置部分 0x10,0x14,0x18,0x1c
    vcfg 配置部分 0x20,0x24,0x28,0x2c
*/

/*
    全局配置寄存器 --- 0x00
    0位 ENABLE_FRAMEBUFFER  (下一帧时生效)
    1位 UPDATE_CONFIGURE    (写入 1 时候，发出更新色彩模式/ HCFG / VCFG / FRAMESIZE 配置请求)
    3:2位 色彩模式配置, 0: 32bits, 1: 24bits, 3: 16bits
*/

/*
    状态寄存器 --- 0x04
    0 位 ACTICE
    1 位 UPDATE_PENDING (读取为 1 时，说明有未完成的色彩模式更新请求，不要更新 色彩模式 / HCFG / VCFG / FRAMESIZE 配置)
    15:8  位 FIFO LEVEL
    31:16 位 FIFO-UNDERRUN 计数
*/

/*
    DMA 起始地址寄存器 --- 0x08
    11:0  位 始终为0
    31:12 位 DMA 起始地址有效位，4K 对齐
*/

/*
    DMA 长度寄存器 --- 0x0c
    5:0   位 始终为0，FETCH 以 64Byte==16-Words 为单位
    22:6  位 DMA 长度 - 1，最大 8M
*/

/*
    XCFG 配置寄存器
    0x0,0x4,0x8,0xc 分别对应 xcfg 中的 0,1,2,3
    其中填入的值低 11 位有效，分别表示下述阶段持续周期数-1：
    0 - sync        == sync:1 de:0 (start mode)
    1 - back_proch  == sync:0 de:0
    2 - active      == sync:0 de:1
    3 - front_proch == sync:0 de:0 (reset mode)
*/

parameter HTOTAL_LEN = 11;
parameter VTOTAL_LEN = 11;
typedef struct {
  logic activecfg;
  logic [1:0]bitcfg;                // 色彩模式配置, 0: 32bits, 1: 24bits, 3: 16bits
  logic [3:0][HTOTAL_LEN-1:0] hcfg;  // 配置 Horizen timer
  logic [3:0][HTOTAL_LEN-1:0] vcfg;  // 配置 Vertical timer
} vga_cfg_t;

typedef struct {
  logic[31:0] dma_start;
  logic[31:0] dma_length;
} fbdma_cfg_t;

`endif

