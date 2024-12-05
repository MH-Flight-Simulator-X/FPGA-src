#include <stdio.h>
#include <verilated.h>
#ifdef __APPLE__
    #include <SDL.h>
#else
    #include <SDL2/SDL.h>
#endif
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include "../verilator_utils/fixed_point.h"
#include "../verilator_utils/file_data.h"
#include "../verilator_utils/sdl_context.h"
#include "obj_dir/Vtop_MH_FPGA.h"


#define INPUT_VERTEX_DATAWIDTH 24
#define INPUT_VERTEX_FRACBITS 13

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;
const int H_SCREEN_RES = 640;
const int V_SCREEN_RES = 480;

const int VERTEX_WIDTH = 12;
const int RECIPROCAL_WIDTH = 12;

vluint64_t clk_100m_cnt = 0;

int main(int argc, char* argv[]) {
    printf("Program started\n");
    Verilated::commandArgs(argc, argv);

    SDLContext view(H_RES, V_RES, H_SCREEN_RES, V_SCREEN_RES);

    // initialize Verilog module
    Vtop_MH_FPGA* dut = new Vtop_MH_FPGA;
    vluint64_t sim_time = 0;
    vluint64_t posedge_cnt = 0;

    // initialize frame rate
    uint64_t start_ticks = SDL_GetPerformanceCounter();
    uint64_t frame_count = 0;

    // Reset
    dut->clk = 0;
    for (int i = 0; i < 8; i++) {
        dut->clk ^= 1;
        if (sim_time % 4 == 0) {
            dut->clk_pixel ^= 1;
        }
        dut->eval();
        dut->rstn = 0;
        sim_time++;
    }    
    dut->rstn = 1;

    static int last_angle = dut->top_MH_FPGA__DOT__r_angle;
    while (true) {
        // Main sim
        dut->clk ^= 1;
        // if (sim_time % 4 == 0) {
        //     dut->clk_pixel ^= 1;
        // }
        dut->clk_pixel ^= 1;    // Makes it a lot faster for testing
        dut->eval();

        if (view.update()) {
            break;
        }

        if (dut->clk) {
            posedge_cnt++;
        }

        static bool clk_pixel_last = 0;
        if (dut->clk_pixel == 1 && clk_pixel_last == 0) {
            if (dut->display_en) {
                int addr = dut->sy * H_RES + dut->sx;
                Pixel color = {
                    .a = 0xFF, 
                    .b = dut->vga_b, 
                    .g = dut->vga_g, 
                    .r = dut->vga_r, 
                };
                view.set_pixel(addr, color);
            }

            static bool frame_last = 0;
            if (dut->frame == 1 && frame_last == 0) {
                printf("New Frame!\n");
                view.update_screen(true, posedge_cnt);
                view.clear_screen();
                frame_count++;
            }
            frame_last = dut->frame;
        }
        clk_pixel_last = dut->clk_pixel;

        sim_time++;
    }

    // calculate frame rate
    uint64_t end_ticks = SDL_GetPerformanceCounter();
    double duration = ((double)(end_ticks-start_ticks))/SDL_GetPerformanceFrequency();
    double fps = (double)frame_count/duration;
    printf("Frames per second: %.1f\n", fps);

    dut->final();
    delete dut;
    return 0;
}

