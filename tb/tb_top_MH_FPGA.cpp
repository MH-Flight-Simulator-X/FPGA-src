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
#include "../verilator_utils/sdl_context.h"
#include "obj_dir/Vtop_MH_FPGA.h"


#define INPUT_VERTEX_DATAWIDTH 24
#define INPUT_VERTEX_FRACBITS 13

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;
const int H_SCREEN_RES = 320;
const int V_SCREEN_RES = 240;

const int VERTEX_WIDTH = 12;
const int RECIPROCAL_WIDTH = 12;

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

int main(int argc, char* argv[]) {
    printf("Program started\n");
    Verilated::commandArgs(argc, argv);

    SDLContext view(H_RES, V_RES, H_SCREEN_RES, V_SCREEN_RES);

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
        dut->i_mvp_dv = 0;

        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->i_mvp_matrix[i][j] = 0;
            }
        }

        sim_time++;
    }    
    dut->rstn = 1;
    dut->clear = 0;

    // Main loop
    float t = 0.0f;
    vluint64_t clk_frame_start = posedge_cnt;
    vluint64_t frame_start = 0;

    while (true) {
        // Main sim
        dut->clk ^= 1;
        if (sim_time % 4 == 0) {
            dut->clk_pix ^= 1;
        }
        dut->eval();

        if (view.update()) {
            break;
        }

        if (dut->clk) {
            posedge_cnt++;
            dut->i_mvp_dv = 0;

            if (dut->o_mvp_matrix_read_en) {
                printf("Assigning MVP matrix\n");
                glm::mat4 mvp = generate_mvp(glm::vec3(0.0f, 0.0f, -2.0f), glm::vec3(15.0f, -15.0f, -25.0f), t);
                assign_mvp_data(dut, mvp);                
                t = t + 1.0f;
            }

            if (dut->o_fb_write_en) {
                view.set_pixel(dut->o_fb_addr_write, color_palette[dut->o_fb_color_data % 10]);
            }

            if (dut->finished) {
                printf("Finished!\n");
                view.update_screen(true, posedge_cnt);
                view.clear_screen();
                frame_count++;
            }
        }

        sim_time++;
    }

    // calculate frame rate
    uint64_t end_ticks = SDL_GetPerformanceCounter();
    double duration = ((double)(end_ticks-start_ticks))/SDL_GetPerformanceFrequency();
    double fps = (double)frame_count/duration;
    printf("Frames per second: %.1f\n", fps);

    dut->final();
    delete dut;
    return 0;
}

