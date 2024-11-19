// Class to manage SDL context
#pragma once
#include <cstdlib>

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
    const Uint8 *keyb_state;

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

    void update_screen() {
        SDL_UpdateTexture(texture, NULL, screenbuffer.data(), H_RES * sizeof(Pixel));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
    }

    void set_pixel(int x, int y, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
        if (x < 0 || x >= H_RES || y < 0 || y >= V_RES) {
            return;
        }

        int index = y * H_RES + x;
        screenbuffer.at(index).a = a;
        screenbuffer.at(index).b = b;
        screenbuffer.at(index).g = g;
        screenbuffer.at(index).r = r;
    }
};
