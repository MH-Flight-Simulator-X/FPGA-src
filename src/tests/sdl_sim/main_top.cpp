#include <stdio.h>
#include <SDL.h>
#include <verilated.h>
#include "Vtop.h"

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;

const int VERTEX_WIDTH = 16;

typedef struct Pixel {
    uint8_t a;
    uint8_t b;
    uint8_t g;
    uint8_t r;
} Pixel;


vluint64_t clk_100m_cnt = 0;


int interpret_as_nbit_signed(int value, int n) {
    // Mask the value to the n-bit width
    int mask = (1 << n) - 1;
    value &= mask;

    // Check if the sign bit (the n-th bit) is set
    int sign_bit = 1 << (n - 1);
    if (value & sign_bit) {
        // Sign extend the value by setting all bits above the n-th bit
        value |= ~mask;
    }
    
    return value;
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

    // main loop
    while (true) {
        // update main clock
        top->clk_100m ^= 1;
        clk_100m_cnt++;

        // pixel clock runs at 25MHz, so it should run 4 times as slow as main clock
        if (clk_100m_cnt%4) {
            top->clk_pix ^= 1;
        }

        top->eval(); 

        // update pixel if not in blanking interval
        if (top->sdl_de) {
            Pixel* p = &screenbuffer[top->sdl_sy*H_RES + top->sdl_sx];
            p->a = 0xFF;
            p->b = top->sdl_b;
            p->g = top->sdl_g;
            p->r = top->sdl_r;
        }

        // update texture once per frame (in blanking)
        if (top->frame) { 

            // check for quit event
            SDL_Event e;
            if (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) {
                    break;
                }
            }

            if (keyb_state[SDL_SCANCODE_Q]) break;  // quit if user presses 'Q'

            SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
            SDL_RenderClear(sdl_renderer);
            SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
            SDL_RenderPresent(sdl_renderer);
            frame_count++;
            
            if (top->done) {
                printf("min_x: %d max_x: %d min_y: %d max_y: %d\n", top->min_x, top->max_x, top->min_y, top->max_y);

                int e0_dx = interpret_as_nbit_signed(top->e0_dx, VERTEX_WIDTH);
                int e0_dy = interpret_as_nbit_signed(top->e0_dy, VERTEX_WIDTH);
                int e1_dx = interpret_as_nbit_signed(top->e1_dx, VERTEX_WIDTH);
                int e1_dy = interpret_as_nbit_signed(top->e1_dy, VERTEX_WIDTH);
                int e2_dx = interpret_as_nbit_signed(top->e2_dx, VERTEX_WIDTH);
                int e2_dy = interpret_as_nbit_signed(top->e2_dy, VERTEX_WIDTH);

                printf("e0_dx: %d e0_dy: %d e1_dx: %d e1_dy: %d, e2_dx: %d e2_dy %d\n", e0_dx, e0_dy, e1_dx, e1_dy, e2_dx, e2_dy);
                return 0;
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
