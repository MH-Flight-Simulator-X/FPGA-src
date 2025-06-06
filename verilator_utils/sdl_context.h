// Class to manage SDL context
#pragma once
#include <cstdlib>
#include <stdexcept>
#include <verilated.h>

#ifdef __APPLE__
    #include <SDL.h>
#else
    #include <SDL2/SDL.h>
#endif
#include <vector>

typedef struct Pixel {
    uint8_t a;
    uint8_t b;
    uint8_t g;
    uint8_t r;
} Pixel;

// 16 color palette
static Pixel color_palette[10] = {
    {0xFF, 255, 182, 193},  // Light Pink
    {0xFF, 255, 222, 173},  // Navajo White
    {0xFF, 176, 224, 230},  // Powder Blue
    {0xFF, 255, 239, 213},  // Papaya Whip
    {0xFF, 240, 230, 140},  // Khaki
    {0xFF, 221, 160, 221},  // Plum
    {0xFF, 250, 250, 210},  // Light Goldenrod Yellow
    {0xFF, 152, 251, 152},  // Pale Green
    {0xFF, 245, 222, 179},  // Wheat
    {0xFF, 216, 191, 216}   // Thistle
};


class SDLContext {
private:

public:
    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* texture;
    const Uint8 *keyb_state;

    int H_RES = 320;
    int V_RES = 240;
    int H_SCREEN_RES = 320;
    int V_SCREEN_RES = 240;
    std::vector<Pixel> screenbuffer;
    std::vector<float> zbuffer;

    // Timing shiz
    vluint64_t frame_start = 0;

    SDLContext(int H_RES, int V_RES, int H_SCREEN_RES = 320, int V_SCREEN_RES = 240) {
        this->H_RES = H_RES;
        this->V_RES = V_RES;
        this->H_SCREEN_RES = H_SCREEN_RES;
        this->V_SCREEN_RES = V_SCREEN_RES;

        SDL_Init(SDL_INIT_VIDEO);
        if (SDL_Init(SDL_INIT_VIDEO) < 0) {
            std::string error_msg = "SDL init failed.";
            throw std::runtime_error(error_msg);
        }

        window = SDL_CreateWindow(
            "MH-Flight-Simulator", 
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED, 
            this->H_RES,
            this->V_RES,
            SDL_WINDOW_SHOWN
        );
        if (!window) {
            std::string error_msg = "Could not initialize SDL window object:" +  std::string(SDL_GetError());
            throw std::runtime_error(error_msg);
        }

        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
        if (!renderer) {
            std::string error_msg = "Renderer creation failed" +  std::string(SDL_GetError());
            throw std::runtime_error(error_msg);
        }

        SDL_RenderSetLogicalSize(renderer, H_SCREEN_RES, V_SCREEN_RES);

        texture = SDL_CreateTexture(
                renderer, 
                SDL_PIXELFORMAT_RGBA8888,
                SDL_TEXTUREACCESS_STREAMING, 
                H_SCREEN_RES, 
                V_SCREEN_RES
                );
        if (!texture) {
            std::string error_msg = "Texture creation failed:" +  std::string(SDL_GetError());
            throw std::runtime_error(error_msg);
        }

        keyb_state = SDL_GetKeyboardState(NULL);

        screenbuffer.resize(H_RES * V_RES);
        zbuffer.resize(H_RES * V_RES);
    }
    
    ~SDLContext() {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
    }

    int update() {
        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                return 1;
            } else if (e.type == SDL_KEYDOWN) {
                if (keyb_state[SDL_SCANCODE_Q]) {
                    return 1;
                }
            }
        }
        return 0;
    }

    void clear_screen() {
        for (int i = 0; i < H_RES * V_RES; i++) {
            screenbuffer[i].a = 0xFF;
            screenbuffer[i].b = 0x00;
            screenbuffer[i].g = 0x00;
            screenbuffer[i].r = 0x00;
            zbuffer[i] = 1.0f;
        }
    }

    void update_screen(bool monitor_frame_rate = false, vluint64_t posedge_cnt = 0) {
        SDL_UpdateTexture(texture, NULL, screenbuffer.data(), H_RES * sizeof(Pixel));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);

        if (monitor_frame_rate) {
            vluint64_t time_diff = posedge_cnt - frame_start;
            printf("Clks per frame: %lu\n", time_diff);

            float frame_time = (float)time_diff * 10e-9;
            float frame_rate = 1.0f / frame_time;
            printf("Frame rate: %.2f\n", frame_rate);
            printf("Frame time: %.2f\n", frame_time);
            printf("\n");
            frame_start = posedge_cnt;
        }
    }

    void set_pixel(int addr, Pixel color) {
        if (addr >= this->H_SCREEN_RES * this->V_SCREEN_RES)
            return;
    
        int addr_fb = addr / this->H_SCREEN_RES * this->H_RES + addr % H_SCREEN_RES;
        Pixel* p = &screenbuffer.at(addr_fb);
        p->a = 0xFF;
        p->b = color.b;
        p->g = color.g;
        p->r = color.r;
    }
};
