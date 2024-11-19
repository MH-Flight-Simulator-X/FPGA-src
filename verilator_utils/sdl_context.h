// Static class to manage SDL context
#pragma once

#ifdef __APPLE__
    #include <SDL.h>
#else
    #include <SDL2/SDL.h>
#endif
#include <vector>

class SDLContext {
public:
    static SDL_Window* window;
    static SDL_Renderer* renderer;
    static SDL_Texture* texture;

    static std::vector<uint8_t> screenbuffer;
    static std::vector<float> zbuffer;

    static void init(int h_res, int v_res) {
        if (SDL_Init(SDL_INIT_VIDEO) < 0) {
            printf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
            exit(1);
        }

        window = SDL_CreateWindow("Verilator Render Pipeline", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, h_res, v_res, SDL_WINDOW_SHOWN);
        if (window == NULL) {
            printf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
            exit(1);
        }

        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
        if (renderer == NULL) {
            printf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
            exit(1);
        }

        texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ABGR8888, SDL_TEXTUREACCESS_STREAMING, h_res, v_res);
        if (texture == NULL) {
            printf("Texture could not be created! SDL_Error: %s\n", SDL_GetError());
            exit(1);
        }

        screenbuffer.resize(h_res * v_res);
        zbuffer.resize(h_res * v_res);
    }

    static void setPixel(int x, int y, uint32_t color) {
        if (x < 0 || x >= 640 || y < 0 || y >= 480) {
            return;
        }

        screenbuffer[y * 640 + x] = color;
    }

    static void update() {
        SDL_UpdateTexture(texture, NULL, screenbuffer.data(), screenbuffer.size() * sizeof(uint8_t));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    static void clear() {
        for (int i = 0; i < screenbuffer.size(); i++) {
            screenbuffer[i] = 0;
            zbuffer[i] = 1.0f;
        }
    }

    static void destroy() {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
    }
};

