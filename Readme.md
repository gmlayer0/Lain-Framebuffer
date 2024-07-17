# About Lain-Framebuffer

Lain-Framebuffer is an opensource Framebuffer that support configurable Video timing.

`configurable_framebuffer.sv` contains the top module `configurable_framebuffer`.

An axi4lite interface slv is reserved for configurations. An axi4 interface dma is used to fetch pixel datas from memory.

Support up to 2048x2048 resolution with customable Video timing.

You may need some AXI related modules and interfaces in [PULP-AXI](https://github.com/pulp-platform/axi) and [PULP-REGINTF](https://github.com/pulp-platform/register_interface) to use this module.

# About configuration interface

Here is an example C drivers to configure Framebuffer to specified resoulutions in u-boot.

```c
struct fb_ip_ctl
{
    volatile uint32_t conf;
    volatile uint32_t status;
    volatile uint32_t addr;
    volatile uint32_t length;
    volatile uint32_t hcfg[4];
    volatile uint32_t vcfg[4];
};
struct vcfg_t{
    uint32_t hcfg[4];
    uint32_t vcfg[4];
};
uint32_t support_resolution[] = {1080,1024,720,480,600};
struct vcfg_t support_cfg[] = {
    {{32,80,1920,48},{5,13,1080,3}},
    {{32,80,1024,48},{5, 6,576, 3}},
    {{32,80,1280,48},{5,13,720 ,3}},
    {{32,80,640 ,48},{5,13,480 ,3}},
    {{32,80,800 ,48},{4,11,600 ,3}}
};
int set_fb_args(struct vcfg_t use_cfg, int color_mode) {
    fb_ctl = (void*) FRAMEBUFFER_BASEADDR;
    uint32_t iters = 0;
    while(fb_ctl->status & 2) {
        iters ++;
        if(iters > 0xa0000000) {
            printf("FB seemed to be stucked, force to update!\n");
            break;
        }
    }
    for(int i = 0 ; i < 4 ; i+=1) {
        fb_ctl->hcfg[i] = use_cfg.hcfg[i] - 1;
        fb_ctl->vcfg[i] = use_cfg.vcfg[i] - 1;
    }
    color_mode = color_mode & 0x3;
    color_mode = color_mode == 2 ? 3 : color_mode;
    printf("Setting Framebuffer with the following parameters:\n");
    printf("\t-------------------------------------------------------------------\n");
    printf("\t;            ; Sync       ; Back Proch ; Active     ; Front Proch ;\n");
    printf("\t; Horizontal ; %-10d ; %-10d ; %-10d ; %-11d ;\n", use_cfg.hcfg[0], use_cfg.hcfg[1], use_cfg.hcfg[2], use_cfg.hcfg[3]);
    printf("\t; Vertical   ; %-10d ; %-10d ; %-10d ; %-11d ;\n", use_cfg.vcfg[0], use_cfg.vcfg[1], use_cfg.vcfg[2], use_cfg.vcfg[3]);
    printf("\t-------------------------------------------------------------------\n");

    uint32_t pixel_size = color_mode == 0 ? 4 : (color_mode == 1 ? 3 : 2);
    uint32_t fb_length = use_cfg.hcfg[2] * use_cfg.vcfg[2] * pixel_size;
    printf("Color mode is %s, with each pixel consume %c bytes, setting fb_length to %d bytes.", 
        color_mode == 0 ? "RGB8888" : (color_mode == 1 ? "RGB888" : "RGB565"),
        pixel_size + '0',
        fb_length
    );
    fb_ctl->length = fb_length;
    fb_ctl->conf = 0x3 | (color_mode << 2);
    return 0;
}
int do_setfb(struct cmd_tbl *cmdtp, int flag, int argc, char *const argv[]) {
    if(argc < 3) {
		printf("Usage: setfb <1080p/1024p/720p/480p/600p> <color-mode>\n");
		return 0;
    }
    int i;
    int color_mode = -1;
    struct vcfg_t use_cfg;
    uint32_t darg;
    if(argc == 3) {
	    sscanf(argv[1], "%dp", &darg);
        for(i = 0 ; i < sizeof(support_resolution) / sizeof(uint32_t); i++) {
            if(darg == support_resolution[i]) {
                use_cfg = support_cfg[i];
                color_mode = 0;
                break;
            }
        }
        if(color_mode == -1) {
            printf("Not a valid resolution %s.\n", argv[1]);
            return 0;
        }
        i = 2;
    } else if(argc == 10){
        uint32_t darg;
        for(i = 1; i < 9 ; i++) {
            int r = sscanf(argv[i], "%d", &darg);
            if(r == 0) {
                printf("Error reading %d %s\n", i, argv[i]);
            }
            ((uint32_t*)&use_cfg)[i - 1] = darg;
        }
    }
    sscanf(argv[i], "%d", &darg);
    if(darg == 565) {
        color_mode = 3;
    } else if(darg == 888) {
        color_mode = 1;
    } else {
        printf("Not valid colormode %s, support 565 or 888",argv[i]);
        color_mode = 3;
    }
    return set_fb_args(use_cfg, color_mode);
}
```
