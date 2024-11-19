// Class to manage SDL context
#pragma once

#ifdef __APPLE__
    #include <SDL.h>
#else
    #include <SDL2/SDL.h>
#endif
#include <vector>

class SDLContext {
private:
    typedef struct Pixel {
        uint8_t a;
        uint8_t b;
        uint8_t g;
        uint8_t r;
    } Pixel;

public:
    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* texture;

    int H_RES = 320;
    int V_RES = 240;
    std::vector<Pixel> screenbuffer;
    std::vector<float> zbuffer;

    SDLContext(int H_RES, int V_RES) {
        this->H_RES = H_RES;
        this->V_RES = V_RES;

        SDL_Init(SDL_INIT_VIDEO);
        window = SDL_CreateWindow(
                "MH-Flight-Simulator", 
                SDL_WINDOWPOS_CENTERED,
                SDL_WINDOWPOS_CENTERED, 
                H_RES * 4,  // Double the width
                V_RES * 4,  // Double the height
                SDL_WINDOW_SHOWN
                );
        if (!window) {
            printf("Window creation failed: %s\n", SDL_GetError());
            return;
        }

        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
        if (!renderer) {
            printf("Renderer creation failed: %s\n", SDL_GetError());
            return;
        }

        SDL_RenderSetLogicalSize(renderer, H_RES, V_RES);

        texture = SDL_CreateTexture(
                renderer, 
                SDL_PIXELFORMAT_RGBA8888,
                SDL_TEXTUREACCESS_STREAMING, 
                H_RES, 
                V_RES
                );
        if (!texture) {
            printf("Texture creation failed: %s\n", SDL_GetError());
            return;
        }

        screenbuffer.resize(H_RES * V_RES);
        zbuffer.resize(H_RES * V_RES);
    }
    
    ~SDLContext() {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
    }

    void update() {
        SDL_UpdateTexture(texture, NULL, screenbuffer.data(), screenbuffer.size() * sizeof(uint8_t));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    void set_pixel(int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
        if (x < 0 || x >= H_RES || y < 0 || y >= V_RES) {
            return;
        }

        int index = y * H_RES + x;
        screenbuffer[index].a = a;
        screenbuffer[index].b = b;
        screenbuffer[index].g = g;
        screenbuffer[index].r = r;
    }
};
