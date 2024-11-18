#include <stdio.h>
#include <verilated.h>
#ifdef __APPLE__
    #include <SDL.h>
#else
    #include <SDL2/SDL.h>
#endif
#include "../../../verilator_utils/fixed_point.h"
#include "obj_dir/Vtop.h"

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;

const int VERTEX_WIDTH = 12;
const int RECIPROCAL_WIDTH = 12;

typedef struct Pixel {
    uint8_t a;
    uint8_t b;
    uint8_t g;
    uint8_t r;
} Pixel;

vluint64_t clk_100m_cnt = 0;

int32_t sign_extend(int32_t a, int data_width) {
    int32_t sign = (a >> (data_width - 1)) & 1;
    int32_t sign_extended = a;
    if (sign) {
        for (int i = sizeof(int32_t) * 8 - 1; i >= data_width; i--) {
            sign_extended |= (1 << i);
        }
    }
    return sign_extended; 
}

// Turn int32_t into lower datawidth
int32_t truncate(int32_t a, int data_width) {
    int32_t truncated = a & ((1 << data_width) - 1);
    return truncated;
}

int main(int argc, char* argv[]) {
    printf("Program started\n");
    Verilated::commandArgs(argc, argv);

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL init failed.\n");
        return 1;
    }

    Pixel screenbuffer[H_RES*V_RES];

    SDL_Window*   sdl_window   = NULL;
    SDL_Renderer* sdl_renderer = NULL;
    SDL_Texture*  sdl_texture  = NULL;

    sdl_window = SDL_CreateWindow("MH-Flight-Simulator", SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, H_RES, V_RES, SDL_WINDOW_SHOWN);
    if (!sdl_window) {
        printf("Window creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!sdl_renderer) {
        printf("Renderer creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
        SDL_TEXTUREACCESS_TARGET, H_RES, V_RES);
    if (!sdl_texture) {
        printf("Texture creation failed: %s\n", SDL_GetError());
        return 1;
    }

    // reference SDL keyboard state array: https://wiki.libsdl.org/SDL_GetKeyboardState
    const Uint8 *keyb_state = SDL_GetKeyboardState(NULL);
    printf("Simulation running. Press 'Q' in simulation window to quit.\n\n");

    // initialize Verilog module
    Vtop* top = new Vtop;

    // reset
    top->sim_rst = 1;
    top->clk_100m = 0;
    top->eval();
    top->clk_100m = 1;
    top->eval();
    top->sim_rst = 0;
    top->clk_100m = 0;
    top->clk_pix = 0;
    top->eval();

    // initialize frame rate
    uint64_t start_ticks = SDL_GetPerformanceCounter();
    uint64_t frame_count = 0;

    bool running = true;
    while (running) {
        // update main clock
        top->clk_100m ^= 1;
        clk_100m_cnt++;

        // pixel clock runs at 25MHz, so it should run 4 times as slow as main clock
        if (clk_100m_cnt%4) {
            top->clk_pix ^= 1;
        }

        top->eval(); 

        if (top->clk_100m == 1) {
            // update pixel if not in blanking interval
            if (top->sdl_de) {
                Pixel* p = &screenbuffer[top->sdl_sy*H_RES + top->sdl_sx];
                p->a = 0xFF;
                p->b = top->sdl_b;
                p->g = top->sdl_g;
                p->r = top->sdl_r;
            }

            // int top_done = top->done;
            // if (top_done) {
            //     printf("Simulation done\n");
            //     break;
            // }

            // update texture once per frame (in blanking)
            if (top->frame) { 
                SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
                SDL_RenderClear(sdl_renderer);
                SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
                SDL_RenderPresent(sdl_renderer);
                frame_count++;

                SDL_Event e;
                while (SDL_PollEvent(&e)) {
                    if (e.type == SDL_QUIT) {
                        running = false;
                    }
                    if (e.type == SDL_KEYDOWN) {
                        auto code = e.key.keysym.scancode;
                        if (code == SDL_SCANCODE_Q) {
                            running = false;
                        }
                        
                        if (code == SDL_SCANCODE_D) {
                            top->display_clear = 1;
                        }
                        else {
                            top->display_clear = 0;
                        }

                        if (code == SDL_SCANCODE_R) {
                            top->rasterizer_dv = 1;
                        }
                        else {
                            top->rasterizer_dv = 0;
                        }
                    }
                }
            }
        }
    }

    // calculate frame rate
    uint64_t end_ticks = SDL_GetPerformanceCounter();
    double duration = ((double)(end_ticks-start_ticks))/SDL_GetPerformanceFrequency();
    double fps = (double)frame_count/duration;
    printf("Frames per second: %.1f\n", fps);

    top->final();  // simulation done

    SDL_DestroyTexture(sdl_texture);
    SDL_DestroyRenderer(sdl_renderer);
    SDL_DestroyWindow(sdl_window);
    SDL_Quit();
    return 0;
}
