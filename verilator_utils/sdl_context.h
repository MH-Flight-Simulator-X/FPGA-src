// Class to manage SDL context
#pragma once
#include <cstdlib>
#include <stdexcept>

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

    void update_screen() {
        SDL_UpdateTexture(texture, NULL, screenbuffer.data(), H_RES * sizeof(Pixel));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);
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
