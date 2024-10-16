#include <verilated.h>
#include <verilated_vcd_c.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include "../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vtb_transform_pipeline.h"

#define INPUT_VERTEX_DATAWIDTH 24
#define INPUT_VERTEX_FRACBITS 13
#define OUTPUT_VERTEX_DATAWIDTH 10
#define OUTPUT_DEPTH_FRACBITS 11

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 320
#define ZFAR 100.0f
#define ZNEAR 0.1f

const int cube_verticies_size = 8;
glm::vec3 cube_verticies[] = {
    // Front face
    glm::vec3(-1.0f, -1.0f,  1.0f), // 0
    glm::vec3( 1.0f, -1.0f,  1.0f), // 1
    glm::vec3( 1.0f,  1.0f,  1.0f), // 2
    glm::vec3(-1.0f,  1.0f,  1.0f), // 3

    // Back face
    glm::vec3(-1.0f, -1.0f, -1.0f), // 4
    glm::vec3( 1.0f, -1.0f, -1.0f), // 5
    glm::vec3( 1.0f,  1.0f, -1.0f), // 6
    glm::vec3(-1.0f,  1.0f, -1.0f)  // 7
};

#define RESET_CLKS 8
#define MAX_SIM_TIME 2048
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void print_matrix(float mat[4][4]);
void print_vector(float vec[4]);
void print_matrix_fixed_point(void* mat);

void assign_mvp_data(Vtb_transform_pipeline* dut, glm::mat4 mvp) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int32_t fixed_point = FixedPoint<int32_t>::fromFloat(mvp[i][j], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_mvp_matrix[i][j] = fixed_point;
        }
    }
};

void assign_vertex_data(Vtb_transform_pipeline* dut, glm::vec3 vertex) {
    for (int i = 0; i < 3; i++) {
        dut->i_vertex[i] = FixedPoint<int32_t>::fromFloat(vertex[i], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_transform_pipeline* dut = new Vtb_transform_pipeline;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    // Generate matrix and vector data using GLM
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::translate(model, glm::vec3(0.0f, 0.0f, -5.0f));
    model = glm::rotate(model, glm::radians(45.0f), glm::vec3(0.0f, 1.0f, 0.0f));
    model = glm::scale(model, glm::vec3(1.0f, 1.0f, 1.0f));

    glm::mat4 view = glm::lookAt(
        glm::vec3(0.0f, 0.0f, 3.0f), // Camera position
        glm::vec3(0.0f, 0.0f, 0.0f), // Look at point
        glm::vec3(0.0f, 1.0f, 0.0f)  // Up vector
    );

    float fov = glm::radians(45.0f);
    float aspectRatio = (float)SCREEN_WIDTH / SCREEN_HEIGHT;
    float farPlane = 100.0f;
    glm::mat4 projection = glm::perspective(fov, aspectRatio, ZNEAR, ZFAR);

    // Finished mvp matrix
    glm::mat4 mvp = projection * view * model;
    float mvp_data[4][4];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            mvp_data[i][j] = mvp[i][j];
        }
    }   
    printf("MVP Matrix:\n");
    print_matrix(mvp_data);
    printf("\n");


    // Calculate expected vertex positions
    glm::vec4 cube_verticies_vs[cube_verticies_size];
    for (int i = 0; i < cube_verticies_size; i++) {
        glm::vec4 vertex = mvp * glm::vec4(cube_verticies[i], 1.0f);
        cube_verticies_vs[i] = vertex;

        printf("Expected intermediate %d: %f, %f, %f, %f\n", i, vertex.x, vertex.y, vertex.z, vertex.w);
    }
    printf("\n");

    for (int i = 0; i < cube_verticies_size; i++) {
        cube_verticies_vs[i] /= cube_verticies_vs[i].w;

        glm::vec2 screen_coords;
        screen_coords.x = (cube_verticies_vs[i].x + 1.0f) * SCREEN_WIDTH / 2.0f;
        screen_coords.y = (1.0f - cube_verticies_vs[i].y) * SCREEN_HEIGHT / 2.0f;

        printf("Expected Vertex %d: %f, %f, %f\n", i, screen_coords.x, screen_coords.y, cube_verticies_vs[i].z);
    }
    printf("\n");

    printf("Staring simulation...\n");

    // Reset
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;
        dut->i_mvp_dv = 0;
        dut->i_vertex_dv = 0;

        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->i_mvp_matrix[i][j] = 0; 
            }
        }
        for (int i = 0; i < 3; i++) {
            dut->i_vertex[i] = 0;
        }

        dut->i_vertex_last = 0;

        m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rstn = 1;

    // Run simulation while (sim_time < MAX_SIM_TIME) {
    int vertex_index = 0;
    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_vertex_dv = 0;
            dut->i_mvp_dv = 0;
            dut->i_vertex_last = 0;

            // Assign mvp matrix
            if (posedge_cnt == 2) {
                assign_mvp_data(dut, mvp);
                dut->i_mvp_dv = 1;
            }

            if (posedge_cnt >= 4) {
                if (dut->ready && vertex_index < cube_verticies_size) {
                    if (vertex_index == cube_verticies_size - 1) {
                        dut->i_vertex_last = 1;
                    }
                    assign_vertex_data(dut, cube_verticies[vertex_index++]);                    
                    dut->i_vertex_dv = 1;
                }
            }

            if (dut->o_vertex_vs_dv) {
                float vertex[4];
                vertex[0] = FixedPoint<int32_t>(dut->o_vertex_vs[0], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).toFloat();
                vertex[1] = FixedPoint<int32_t>(dut->o_vertex_vs[1], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).toFloat();
                vertex[2] = FixedPoint<int32_t>(dut->o_vertex_vs[2], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).toFloat();
                vertex[3] = FixedPoint<int32_t>(dut->o_vertex_vs[3], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).toFloat();

                printf("Got Intermediate: %f, %f, %f, %f\n", vertex[0], vertex[1], vertex[2], vertex[3]);
            }

            if (dut->o_vertex_dv) {
                int32_t vertex_pixel[2];
                float vertex_depth;

                vertex_pixel[0] = dut->o_vertex_pixel[0];
                vertex_pixel[1] = dut->o_vertex_pixel[1];
                vertex_depth = FixedPoint<int32_t>(dut->o_vertex_z, OUTPUT_DEPTH_FRACBITS, OUTPUT_DEPTH_FRACBITS+1).toFloat();

                printf("Got: \n");
                printf("Vertex: %d, %d, %f\n", vertex_pixel[0], vertex_pixel[1], vertex_depth);
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }
    
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

void print_matrix(float mat[4][4]) {
    printf("%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n", 
        mat[0][0], mat[0][1], mat[0][2], mat[0][3],
        mat[1][0], mat[1][1], mat[1][2], mat[1][3],
        mat[2][0], mat[2][1], mat[2][2], mat[2][3],
        mat[3][0], mat[3][1], mat[3][2], mat[3][3]
    );
}

void print_vector(float vec[4]) {
    printf("%f, %f, %f, %f\n", vec[0], vec[1], vec[2], vec[3]);
}

void print_matrix_fixed_point(void* mat_ptr) {
    int32_t (*mat)[4][4] = (int32_t (*)[4][4])mat_ptr;

    // Convert to float
    float fmat[4][4];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            float f = FixedPoint<int32_t>((*mat)[i][j], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).toFloat();
            fmat[i][j] = f;
        }
    }

    print_matrix(fmat);
}
