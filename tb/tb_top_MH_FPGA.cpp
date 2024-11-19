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
#include "obj_dir/Vtop_MH_FPGA.h"

#define INPUT_VERTEX_DATAWIDTH 24
#define INPUT_VERTEX_FRACBITS 13

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;
const int H_SCREEN_RES = 160;
const int V_SCREEN_RES = 120;

const int VERTEX_WIDTH = 12;
const int RECIPROCAL_WIDTH = 12;

typedef struct Pixel {
    uint8_t a;
    uint8_t b;
    uint8_t g;
    uint8_t r;
} Pixel;

// 16 color palette
Pixel color_palette[10] = {
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

vluint64_t clk_100m_cnt = 0;

glm::vec3 camera_position = glm::vec3(0.0f, 0.0f, 3.0f);
glm::vec3 camera_rotation = glm::vec3(0.0f, 0.0f, 0.0f);
float camera_speed = 0.75f;
float rotation_speed = glm::pi<float>() / 4.0f;

glm::mat4 generate_mvp(glm::vec3 pos, glm::vec3 rot, float t) {
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::translate(model, pos);
    model = glm::rotate(model, glm::radians(rot.x), glm::vec3(0.0f, 0.0f, 1.0f));
    model = glm::rotate(model, glm::radians(rot.y * t), glm::vec3(0.0f, 1.0f, 0.0f));
    model = glm::rotate(model, glm::radians(rot.z), glm::vec3(1.0f, 0.0f, 0.0f));

    float scale = 3.0f;
    model = glm::scale(model, glm::vec3(scale, scale, scale));

    // Adjust the camera view based on current position and rotation
    glm::mat4 view = glm::mat4(1.0f);
    view = glm::rotate(view, glm::radians(camera_rotation.x), glm::vec3(1.0f, 0.0f, 0.0f)); // Pitch
    view = glm::rotate(view, glm::radians(camera_rotation.y), glm::vec3(0.0f, 1.0f, 0.0f)); // Yaw
    view = glm::translate(view, -camera_position); // Camera position

    float fov = glm::radians(45.0f);
    float aspectRatio = (float)H_RES / V_RES;
    float farPlane = 100.0f;
    glm::mat4 projection = glm::perspective(fov, aspectRatio, 0.1f, farPlane);

    glm::mat4 mvp = projection * view * model;

    return mvp;
}

void assign_mvp_data(Vtop_MH_FPGA* dut, glm::mat4 mvp) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int32_t fixed_point = FixedPoint<int32_t>::fromFloat(mvp[j][i], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_mvp_matrix[i][j] = fixed_point;
            dut->i_mvp_dv = 1;
        }
    }
};

void assign_vertex_data(Vtop_MH_FPGA* dut, std::vector<glm::vec3>& vertex_data, bool reset = false) {
    static vluint64_t vertex_read_addr = 0;
    if (reset) {
        vertex_read_addr = 0;
    }

    if (vertex_read_addr >= vertex_data.size()) {
        dut->i_vertex_last = 0;
        dut->i_vertex[0] = 0;
        dut->i_vertex[1] = 0;
        dut->i_vertex[2] = 0;
        dut->i_vertex_dv = 0;
        return;
    }
    
    if (dut->o_model_buff_vertex_read_en) {
        if (vertex_read_addr == vertex_data.size() - 1) {
            dut->i_vertex_last = 1;
        } else {
            dut->i_vertex_last = 0;
        }

        dut->i_vertex[0] = FixedPoint<int32_t>::fromFloat(vertex_data.at(vertex_read_addr).x, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
        dut->i_vertex[1] = FixedPoint<int32_t>::fromFloat(vertex_data.at(vertex_read_addr).y, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
        dut->i_vertex[2] = FixedPoint<int32_t>::fromFloat(vertex_data.at(vertex_read_addr).z, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
        dut->i_vertex_dv = 1;

        vertex_read_addr++;
    } else {
        dut->i_vertex_last = 0;
        dut->i_vertex[0] = 0;
        dut->i_vertex[1] = 0;
        dut->i_vertex[2] = 0;
        dut->i_vertex_dv = 0;
    }
};

void assign_index_data(Vtop_MH_FPGA* dut, std::vector<glm::ivec3>& index_data, bool reset = false) {
    static vluint64_t index_read_addr = 0;
    if (reset)
        index_read_addr = 0;

    if (dut->o_model_buff_index_read_en) {
        if (index_read_addr == index_data.size() - 1) {
            dut->i_index_last = 1;
            printf("Last index\n");
        } else {
            dut->i_index_last = 0;
        }

        dut->i_index_data[0] = index_data.at(index_read_addr).x;
        dut->i_index_data[1] = index_data.at(index_read_addr).y;
        dut->i_index_data[2] = index_data.at(index_read_addr).z;
        dut->i_index_dv = 1;

        index_read_addr++;
    } else {
        dut->i_index_last = 0;
        dut->i_index_data[0] = 0;
        dut->i_index_data[1] = 0;
        dut->i_index_data[2] = 0;
        dut->i_index_dv = 0;
    }
}

int main(int argc, char* argv[]) {
    printf("Program started\n");
    Verilated::commandArgs(argc, argv);

    std::vector<glm::vec3> vertex_buffer = SimDataFileHandler::read_vertex_data("model.vert");
    std::vector<glm::ivec3> index_buffer = SimDataFileHandler::read_index_data("model.face");

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL init failed.\n");
        return 1;
    }

    Pixel screenbuffer[H_RES*V_RES];
    float zbuffer[H_RES*V_RES];

    for (int i = 0; i < H_RES*V_RES; i++) {
        screenbuffer[i].a = 0xFF;
        screenbuffer[i].b = 0x00;
        screenbuffer[i].g = 0x00;
        screenbuffer[i].r = 0x00;
        zbuffer[i] = 1.0f;
    }

    SDL_Window*   sdl_window   = NULL;
    SDL_Renderer* sdl_renderer = NULL;
    SDL_Texture*  sdl_texture  = NULL;

    sdl_window = SDL_CreateWindow(
        "MH-Flight-Simulator", 
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, 
        H_RES,  // Double the width
        V_RES,  // Double the height
        SDL_WINDOW_SHOWN
    );
    if (!sdl_window) {
        printf("Window creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_renderer = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!sdl_renderer) {
        printf("Renderer creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_texture = SDL_CreateTexture(
        sdl_renderer, 
        SDL_PIXELFORMAT_RGBA8888,
        SDL_TEXTUREACCESS_STREAMING, 
        H_RES, 
        V_RES
    );
    if (!sdl_texture) {
        printf("Texture creation failed: %s\n", SDL_GetError());
        return 1;
    }

    // reference SDL keyboard state array: https://wiki.libsdl.org/SDL_GetKeyboardState
    const Uint8 *keyb_state = SDL_GetKeyboardState(NULL);
    printf("Simulation running. Press 'Q' in simulation window to quit.\n\n");

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
            dut->clk_pix ^= 1;
        }
        dut->eval();

        if (dut->clk) {
            posedge_cnt++;
        }

        dut->rstn = 0;
        dut->start = 0;
        dut->i_mvp_dv = 0;
        dut->i_vertex_dv = 0;
        dut->i_index_dv = 0;
        dut->i_vertex_last = 0;
        // dut->clear = 1;

        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->i_mvp_matrix[i][j] = 0;
            }
        }

        for (int i = 0; i < 3; i++) {
            dut->i_vertex[i] = 0;
            dut->i_index_data[i] = 0;
        }

        sim_time++;
    }    
    dut->rstn = 1;
    dut->clear = 0;

    // Main loop
    float t = 0.0f;
    vluint64_t clk_frame_start = posedge_cnt;

    bool new_frame = false;
    dut->start = 0;

    vluint64_t frame_start = 0;

    while (true) {
        // Main sim
        dut->clk ^= 1;
        if (sim_time % 4 == 0) {
            dut->clk_pix ^= 1;
        }
        dut->eval();

        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                break;
            }
            else if (e.type == SDL_KEYDOWN) {
                if (keyb_state[SDL_SCANCODE_Q]) break;  // quit if user presses 'Q'
            }
        }

        if (dut->clk) {
            posedge_cnt++;
            dut->i_mvp_dv = 0;
            dut->i_vertex_dv = 0;
            dut->i_vertex_last = 0;

            if (dut->ready && dut->display_ready) {
                printf("Render pipeline new frame\n");
                dut->start = 1;
            } else {
                dut->start = 0;
            }

            static int frame_last = 0;
            static bool should_reset_buffers = false;
            if (frame_last && !dut->frame) {
                should_reset_buffers = true;
            }
            frame_last = dut->frame;

            if (should_reset_buffers && dut->display_ready) {
                new_frame = true;
                should_reset_buffers = false;
                printf("Reset\n");
            } else {
                new_frame = false;
            }

            if (dut->o_mvp_matrix_read_en) {
                glm::mat4 mvp = generate_mvp(glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(15.0f, -15.0f, -25.0f), t);
                assign_mvp_data(dut, mvp);                
                t = t + 1.0f;
            }

            assign_vertex_data(dut, vertex_buffer, new_frame);
            assign_index_data(dut, index_buffer, new_frame);
        }

        static int pix_clk_last = 0;
        // if (dut->clk_pix && !pix_clk_last) {
        if (dut->clk_pix && !pix_clk_last) {
            if (dut->display_ready) {

                if (dut->display_en) {
                    if (dut->sx < 0 || dut->sx >= H_RES || dut->sy < 0 || dut->sy >= V_RES) {
                        continue;
                    }
                
                    Pixel* p = &screenbuffer[dut->sy*H_RES + dut->sx];
                    p->a = 0xFF;
                    p->b = (dut->vga_b << 4) + dut->vga_b;
                    p->g = (dut->vga_g << 4) + dut->vga_g;
                    p->r = (dut->vga_r << 4) + dut->vga_r;
                }
                
                static bool frame_last = false;
                if (dut->frame && !frame_last) {
                    printf("Display new frame\n");
                    SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
                    SDL_RenderClear(sdl_renderer);
                    SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
                    SDL_RenderPresent(sdl_renderer);


                    vluint64_t time_diff = posedge_cnt - frame_start;
                    printf("Clks per frame: %lu\n", time_diff);

                    float frame_time = (float)time_diff * 10e-9;
                    float frame_rate = 1.0f / frame_time;
                    printf("Frame rate: %.2f\n", frame_rate);
                    printf("Frame time: %.2f\n", frame_time);
                    printf("\n");
                    frame_start = posedge_cnt;
                    frame_count++;
                    dut->clear = 1;
                } else {
                    dut->clear = 0;
                }
                frame_last = dut->frame;
            }
        }
        pix_clk_last = dut->clk_pix;


        sim_time++;
    }

    // calculate frame rate
    uint64_t end_ticks = SDL_GetPerformanceCounter();
    double duration = ((double)(end_ticks-start_ticks))/SDL_GetPerformanceFrequency();
    double fps = (double)frame_count/duration;
    printf("Frames per second: %.1f\n", fps);

    SDL_DestroyTexture(sdl_texture);
    SDL_DestroyRenderer(sdl_renderer);
    SDL_DestroyWindow(sdl_window);
    SDL_Quit();

    dut->final();  // simulation done
    delete dut;
    return 0;
}

