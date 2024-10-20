#include <stdio.h>
#include <SDL.h>
#include <verilated.h>
#include "Vtop.h"

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;

const int VERTEX_WIDTH = 16;
const int RECIPROCAL_WIDTH = 12;

typedef struct Pixel {
    uint8_t a;
    uint8_t b;
    uint8_t g;
    uint8_t r;
} Pixel;


int clk_100m_cnt = 0;


int interpretAsNbitSigned(int value, int n) {
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


float unsignedFixedPointToFloat(unsigned int fixed_point_int, int fractional_bits) {
    // Convert the unsigned fixed-point number to float
    return static_cast<float>(fixed_point_int) / static_cast<float>(1 << fractional_bits);
}


float signedFixedPointToFloat(int fixed_point_int, int fractional_bits, int total_bits) {
    // Perform sign extension if necessary
    // total_bits includes both the integer and fractional parts
    if (fixed_point_int & (1 << (total_bits - 1))) {
        // If the sign bit is set, perform sign extension
        fixed_point_int |= ~((1 << total_bits) - 1);  // Sign-extend to the full int width
    }

    // Convert the signed fixed-point number to float
    return static_cast<float>(fixed_point_int) / static_cast<float>(1 << fractional_bits);
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

        int e0 = interpretAsNbitSigned(top->edge_val[0], VERTEX_WIDTH);
        int e1 = interpretAsNbitSigned(top->edge_val[1], VERTEX_WIDTH);
        int e2 = interpretAsNbitSigned(top->edge_val[2], VERTEX_WIDTH);

        int e0_dx = interpretAsNbitSigned(top->edge_delta[0][0], VERTEX_WIDTH);
        int e0_dy = interpretAsNbitSigned(top->edge_delta[0][1], VERTEX_WIDTH);
        int e1_dx = interpretAsNbitSigned(top->edge_delta[1][0], VERTEX_WIDTH);
        int e1_dy = interpretAsNbitSigned(top->edge_delta[1][1], VERTEX_WIDTH);
        int e2_dx = interpretAsNbitSigned(top->edge_delta[2][0], VERTEX_WIDTH);
        int e2_dy = interpretAsNbitSigned(top->edge_delta[2][1], VERTEX_WIDTH);

        int area = interpretAsNbitSigned(top->area, VERTEX_WIDTH);
        float area_reciprocal = unsignedFixedPointToFloat(top->area_reciprocal, RECIPROCAL_WIDTH);

        float w0 = signedFixedPointToFloat(top->bar_weight[0], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);
        float w1 = signedFixedPointToFloat(top->bar_weight[1], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);
        float w2 = signedFixedPointToFloat(top->bar_weight[2], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);

        float w0_dx = signedFixedPointToFloat(top->bar_weight_delta[0][0], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);
        float w0_dy = signedFixedPointToFloat(top->bar_weight_delta[0][1], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);
        float w1_dx = signedFixedPointToFloat(top->bar_weight_delta[1][0], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);
        float w1_dy = signedFixedPointToFloat(top->bar_weight_delta[1][1], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);
        float w2_dx = signedFixedPointToFloat(top->bar_weight_delta[2][0], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);
        float w2_dy = signedFixedPointToFloat(top->bar_weight_delta[2][1], RECIPROCAL_WIDTH, RECIPROCAL_WIDTH);

        printf("\n\n########\n\n");
        printf("clk_100m_cnt: %d\n", clk_100m_cnt);
        printf("e0: %d\ne1: %d\ne2: %d\n", e0, e1, e2);
        printf("e0_dx: %d\ne0_dy: %d\ne1_dx: %d\ne1_dy: %d\ne2_dx: %d\ne2_dy: %d\n", e0_dx, e0_dy, e1_dx, e1_dy, e2_dx, e2_dy); 
        printf("area = %d\narea_reciprocal = %f\n", area, area_reciprocal);
        printf("area_reciprocal_int = %d\n", top->area_reciprocal);
        printf("w0_int = %d\n", top->bar_weight[0]);
        printf("w1_int = %d\n", top->bar_weight[1]);
        printf("w2_int = %d\n", top->bar_weight[2]);
        printf("w0 = %f\nw1 = %f\nw2 = %f\n", w0, w1, w2);
        printf("w0_dx = %f\nw0_dy = %f\nw1_dx = %f\nw1_dy = %f\nw2_dx = %f\nw2_dy = %f\n", w0_dx, w0_dy, w1_dx, w1_dy, w2_dx, w2_dy);
        printf("test = %f\n", signedFixedPointToFloat(top->test, RECIPROCAL_WIDTH, RECIPROCAL_WIDTH));
        printf("state = %d\n", top->state);

        if (clk_100m_cnt > 9) {
            return 0;
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
