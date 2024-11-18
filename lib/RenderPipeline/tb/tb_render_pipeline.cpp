#include <stdio.h>
#include <verilated.h>
#include <SDL2/SDL.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include "../../../verilator_utils/fixed_point.h"
#include "../../../verilator_utils/file_data.h"
#include "obj_dir/Vrender_pipeline.h"

#define INPUT_VERTEX_DATAWIDTH 24
#define INPUT_VERTEX_FRACBITS 13

// screen dimensions
const int H_RES = 320;
const int V_RES = 320;

const int VERTEX_WIDTH = 12;
const int RECIPROCAL_WIDTH = 12;

typedef struct Pixel {
    uint8_t a;
    uint8_t b;
    uint8_t g;
    uint8_t r;
} Pixel;

// 16 color palette
Pixel color_lookup[16] = {
    (Pixel){0xFF, 0x00, 0x00, 0x00},
    (Pixel){0xFF, 0x00, 0x00, 0xFF},
    (Pixel){0xFF, 0x00, 0xFF, 0x00},
    (Pixel){0xFF, 0x00, 0xFF, 0xFF},
    (Pixel){0xFF, 0xFF, 0x00, 0x00},
    (Pixel){0xFF, 0xFF, 0x00, 0xFF},
    (Pixel){0xFF, 0xFF, 0xFF, 0x00},
    (Pixel){0xFF, 0xFF, 0xFF, 0xFF},
    (Pixel){0xFF, 0x00, 0x00, 0x00},
    (Pixel){0xFF, 0x00, 0x00, 0xFF},
    (Pixel){0xFF, 0x00, 0xFF, 0x00},
    (Pixel){0xFF, 0x00, 0xFF, 0xFF},
    (Pixel){0xFF, 0xFF, 0x00, 0x00},
    (Pixel){0xFF, 0xFF, 0x00, 0xFF},
    (Pixel){0xFF, 0xFF, 0xFF, 0x00},
    (Pixel){0xFF, 0xFF, 0xFF, 0xFF}
};

vluint64_t clk_100m_cnt = 0;

glm::mat4 generate_mvp() {
    // Generate matrix and vector data using GLM
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::translate(model, glm::vec3(0.0f, -2.5f, -5.0f));
    model = glm::rotate(model, glm::radians(45.0f), glm::vec3(0.0f, 1.0f, 0.0f));
    model = glm::scale(model, glm::vec3(1.0f, 1.0f, 1.0f));

    glm::mat4 view = glm::lookAt(
        glm::vec3(0.0f, 0.0f, 3.0f), // Camera position
        glm::vec3(0.0f, 0.0f, 0.0f), // Look at point
        glm::vec3(0.0f, 1.0f, 0.0f)  // Up vector
    );

    float fov = glm::radians(45.0f);
    float aspectRatio = (float)H_RES / V_RES;
    float farPlane = 100.0f;
    glm::mat4 projection = glm::perspective(fov, aspectRatio, 0.1f, 100.0f);
    glm::mat4 mvp = projection * view * model;

    return mvp;
}

void assign_mvp_data(Vrender_pipeline* dut, glm::mat4 mvp) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int32_t fixed_point = FixedPoint<int32_t>::fromFloat(mvp[j][i], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_mvp_matrix[i][j] = fixed_point;
            printf("(%d, %d): %b\n", i, j, dut->i_mvp_matrix[i][j]);
        }
    }
};

void assign_vertex_data(Vrender_pipeline* dut, std::vector<glm::vec3>& vertex_data, bool new_frame = false) {
    static int vertex_data_addr = 0;
    if (new_frame)
        vertex_data_addr = 0;
    
    // if (dut->o_model_buff_vertex_read_en) {
    //     if (vertex_data_addr >= vertex_data.size()) {
    //         return;
    //     } else if (vertex_data_addr == vertex_data.size() - 1) {
    //         dut->i_vertex_last = 1;
    //     }
    //
    //     dut->i_vertex[0] = FixedPoint<int32_t>::fromFloat(vertex_data[vertex_data_addr].x, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
    //     dut->i_vertex[1] = FixedPoint<int32_t>::fromFloat(vertex_data[vertex_data_addr].y, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
    //     dut->i_vertex[2] = FixedPoint<int32_t>::fromFloat(vertex_data[vertex_data_addr].z, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
    //     dut->i_vertex_dv = 1;
    //     vertex_data_addr++;
    // } else {
    //     dut->i_index_data[0] = 0;
    //     dut->i_index_data[1] = 0;
    //     dut->i_index_data[2] = 0;
    //     dut->i_vertex_dv = 0;
    // }
    
    std::vector<glm::vec3> verts = {
        {-1, 0, 0.5},
        { 1, 0, 0.5},
        { 0, 1, 0.5}
    };

    static int a = 0;
    if (a == 0) {
        a++;
        for (int i = 0; i < 3; i++) {
            glm::vec4 v = glm::vec4(verts[i], 1.0f);
            glm::vec4 p = glm::mat4(1.0f) * v;
            printf("Vertex %d: (%f, %f, %f) -> (%f, %f, %f)\n", i, v.x, v.y, v.z, p.x, p.y, p.z);
        }
    }

    if (dut->o_model_buff_vertex_read_en) {
        if (vertex_data_addr < 3) {
            dut->i_vertex[0] = FixedPoint<int32_t>::fromFloat(verts[vertex_data_addr].x, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_vertex[1] = FixedPoint<int32_t>::fromFloat(verts[vertex_data_addr].y, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_vertex[2] = FixedPoint<int32_t>::fromFloat(verts[vertex_data_addr].z, INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_vertex_last = vertex_data_addr == 2;
            dut->i_vertex_dv = 1;
            vertex_data_addr++;
        } else {
            dut->i_vertex[0] = 0;
            dut->i_vertex[1] = 0;
            dut->i_vertex[2] = 0;
            dut->i_vertex_dv = 0;
            dut->i_vertex_last = 0;
        }
    }
};

void assign_input_index(Vrender_pipeline* dut, std::vector<glm::ivec3>& index_data, bool new_frame = false) {
    static int index_data_addr = 0;
    if (new_frame)
        index_data_addr = 0;

    if (dut->o_model_buff_index_read_en) {
        // if (index_data_addr >= index_data.size()) {
        //     return;
        // } else if (index_data_addr == index_data.size() - 1) {
        //     dut->i_index_last = 1;
        // }

        printf("Hi\n");
        dut->i_index_data[0] = 0;
        dut->i_index_data[1] = 1;
        dut->i_index_data[2] = 2;
        dut->i_index_last = 1;
        dut->i_vertex_dv = 1;
        // dut->i_index_data[0] = index_data[index_data_addr].x;
        // dut->i_index_data[1] = index_data[index_data_addr].y;
        // dut->i_index_data[2] = index_data[index_data_addr].z;
        // dut->i_index_dv = 1;
        // index_data_addr++;
    } else {
        dut->i_index_data[0] = 0;
        dut->i_index_data[1] = 0;
        dut->i_index_data[2] = 0;
        dut->i_index_dv = 0;
        dut->i_vertex_last = 0;
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
    Vrender_pipeline* dut = new Vrender_pipeline;

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
    while (true) {
        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                break;
            }
        }
        if (keyb_state[SDL_SCANCODE_Q]) break;  // quit if user presses 'Q'

        // Main sim
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk) {
            dut->i_mvp_dv = 0;
            dut->i_vertex_dv = 0;
            dut->i_vertex_last = 0;

            bool new_frame = false;
            if (dut->ready) {
                dut->start = 1;
                new_frame = true;
                printf("New frame\n");
            }

            if (dut->o_mvp_matrix_read_en) {
                // glm::mat4 mvp = generate_mvp();
                glm::mat4 mvp = glm::mat4(1.0f);
                assign_mvp_data(dut, mvp);                
                dut->i_mvp_dv = 1;
            }

            // printf("Transform pipeline state: %d\n", dut->render_pipeline__DOT__transform_pipeline_inst__DOT__current_state);
            // printf("Rasterizer ready: %d\n", dut->render_pipeline__DOT__w_rasterizer_ready);
            // printf("Rasterizer backend ready: %d\n", dut->render_pipeline__DOT__rasterizer_inst__DOT__w_rasterizer_backend_ready);
            
            if (dut->render_pipeline__DOT__rasterizer_inst__DOT__w_rasterizer_backend_done) {
                printf("Backend DONE!\n");
                break;
            }

            // printf("Write en: %d\n", dut->o_fb_write_en);

            assign_vertex_data(dut, vertex_buffer, new_frame);
            assign_input_index(dut, index_buffer, new_frame);

            if (dut->o_fb_write_en) {
                if (dut->o_fb_addr_write >= H_RES * V_RES)
                    continue;

                Pixel* p = &screenbuffer[dut->o_fb_addr_write];
                p->a = 0xFF;
                p->b = 0xFF;
                p->g = 0xFF;
                p->r = 0xFF;
            }

            if (dut->finished) {
                printf("Finished!\n");
                // Render to display
                SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
                SDL_RenderClear(sdl_renderer);
                SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
                SDL_RenderPresent(sdl_renderer);
                frame_count++;
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
