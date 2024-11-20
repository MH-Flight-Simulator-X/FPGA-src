#include <stdio.h>
#include <verilated.h>
#ifdef __APPLE__
    #include <SDL.h>
#else
    #include <SDL2/SDL.h>
#endif
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include "../../../verilator_utils/fixed_point.h"
#include "../../../verilator_utils/file_data.h"
#include "obj_dir/Vrender_pipeline.h"

#define INPUT_VERTEX_DATAWIDTH 24
#define INPUT_VERTEX_FRACBITS 13

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

void assign_mvp_data(Vrender_pipeline* dut, glm::mat4 mvp) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int32_t fixed_point = FixedPoint<int32_t>::fromFloat(mvp[j][i], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_mvp_matrix[i][j] = fixed_point;
        }
    }
};

void assign_vertex_data(Vrender_pipeline* dut, std::vector<glm::vec3>& vertex_data, bool reset = false) {
    static vluint64_t vertex_read_addr = 0;
    if (reset) {
        vertex_read_addr = 0;
        printf("Resetting vertex read address\n");
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
            printf("Last vertex!\n");
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

void assign_index_data(Vrender_pipeline* dut, std::vector<glm::ivec3>& index_data, bool reset = false) {
    static vluint64_t index_read_addr = 0;
    if (reset)
        index_read_addr = 0;

    if (dut->o_model_buff_index_read_en) {
        if (index_read_addr == index_data.size() - 1) {
            dut->i_index_last = 1;
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
        H_RES * 2,  // Double the width
        V_RES * 2,  // Double the height
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

    SDL_RenderSetLogicalSize(sdl_renderer, H_RES, V_RES);

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
    Vrender_pipeline* dut = new Vrender_pipeline;
    vluint64_t posedge_cnt = 0;

    // initialize frame rate
    uint64_t start_ticks = SDL_GetPerformanceCounter();
    uint64_t frame_count = 0;

    // Reset
    dut->clk = 0;
    for (int i = 0; i < 8; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;
        dut->start = 0;
        dut->i_mvp_dv = 0;
        dut->i_vertex_dv = 0;
        dut->i_index_dv = 0;
        dut->i_vertex_last = 0;

        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->i_mvp_matrix[i][j] = 0;
            }
        }

        for (int i = 0; i < 3; i++) {
            dut->i_vertex[i] = 0;
            dut->i_index_data[i] = 0;
        }
    }
    dut->rstn = 1;

    // Main loop
    float t = 0.0f;
    vluint64_t clk_frame_start = posedge_cnt;
    while (true) {
        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                break;
            }
            else if (e.type == SDL_KEYDOWN) {
                glm::vec3 forward = glm::vec3(
                    -sin(glm::radians(camera_rotation.y)),
                    0.0f,
                    -cos(glm::radians(camera_rotation.y))
                );
                forward = glm::normalize(forward);
                glm::vec3 right = glm::normalize(glm::cross(forward, glm::vec3(0.0f, 1.0f, 0.0f)));

                if (keyb_state[SDL_SCANCODE_W]) {
                    camera_position += forward * camera_speed;
                }
                if (keyb_state[SDL_SCANCODE_S]) {
                    camera_position -= forward * camera_speed;
                }
                if (keyb_state[SDL_SCANCODE_A]) {
                    camera_position -= right * camera_speed;
                }
                if (keyb_state[SDL_SCANCODE_D]) {
                    camera_position += right * camera_speed;
                }

                // Rotate camera
                if (keyb_state[SDL_SCANCODE_LEFT]) {
                    camera_rotation.y -= rotation_speed;
                }
                if (keyb_state[SDL_SCANCODE_RIGHT]) {
                    camera_rotation.y += rotation_speed;
                }
                if (keyb_state[SDL_SCANCODE_UP]) {
                    camera_rotation.x -= rotation_speed;
                }
                if (keyb_state[SDL_SCANCODE_DOWN]) {
                    camera_rotation.x += rotation_speed;
                }
            }
        }
        if (keyb_state[SDL_SCANCODE_Q]) break;  // quit if user presses 'Q'


        // Main sim
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk) {
            posedge_cnt++;
            dut->i_mvp_dv = 0;
            dut->i_vertex_dv = 0;
            dut->i_vertex_last = 0;

            static bool new_frame = false;
            if (dut->ready) {
                dut->start = 1;
                new_frame = true;
                printf("New frame\n");
            }

            if (dut->o_mvp_matrix_read_en) {
                glm::mat4 mvp = generate_mvp(glm::vec3(0.0f, 0.0f, -1.0f), glm::vec3(15.0f, -15.0f, -25.0f), t);
                t = t + 1.0f;

                // glm::mat4 mvp = glm::mat4(1.0f);
                assign_mvp_data(dut, mvp);                
                dut->i_mvp_dv = 1;
            }

            assign_vertex_data(dut, vertex_buffer, new_frame);
            assign_index_data(dut, index_buffer, new_frame);

            if (dut->o_fb_write_en) {
                if (dut->o_fb_addr_write >= H_RES * V_RES)
                    continue;

                // float z = FixedPoint<int32_t>(dut->o_fb_depth_data, 12, 12, false).toFloat();
                // if (z < zbuffer[dut->o_fb_addr_write]) {
                //     zbuffer[dut->o_fb_addr_write] = z;
                // } else {
                //     continue;
                // }

                Pixel* p = &screenbuffer[dut->o_fb_addr_write];
                p->a = 0xFF;
                p->b = color_palette[dut->o_fb_color_data % 10].b;
                p->g = color_palette[dut->o_fb_color_data % 10].g;
                p->r = color_palette[dut->o_fb_color_data % 10].r;
            }

            if (dut->finished) {
                printf("Finished!\n");
                SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
                SDL_RenderClear(sdl_renderer);
                SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
                SDL_RenderPresent(sdl_renderer);
                frame_count++;

                // Clear screen buffer
                for (int i = 0; i < H_RES*V_RES; i++) {
                    screenbuffer[i].a = 0xFF;
                    screenbuffer[i].b = 0x00;
                    screenbuffer[i].g = 0x00;
                    screenbuffer[i].r = 0x00;
                    zbuffer[i] = 1.0f;
                }

                vluint64_t clk_frame_end = posedge_cnt;
                float time_per_frame = (clk_frame_end - clk_frame_start) * 1e-8;
                float frame_rate = 1.0 / time_per_frame;
                printf("Clks per frame: %lu\n", clk_frame_end - clk_frame_start);
                printf("Time per frame: %fs\n", time_per_frame);
                printf("Frame rate: %f\n", frame_rate);
                clk_frame_start = clk_frame_end;

                new_frame = true;
            } else {
                new_frame = false;
            }
        }
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
