#include <verilated.h>
#include <verilated_vcd_c.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include "../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vtb_transform_pipeline.h"

#define INPUT_VERTEX_DATAWIDTH 24
#define INPUT_VERTEX_FRACBITS 13
#define OUTPUT_VERTEX_DATAWIDTH 12
#define OUTPUT_DEPTH_FRACBITS 11

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 320
#define ZFAR 100.0f
#define ZNEAR 0.1f

const int cube_verticies_size = 8;
glm::vec4 cube_verticies[] = {
    glm::vec4( 1.0,-1.0,-1.0, 1.0f),
    glm::vec4( 1.0,-1.0, 1.0, 1.0f),
    glm::vec4(-1.0,-1.0, 1.0, 1.0f),
    glm::vec4(-1.0,-1.0,-1.0, 1.0f),
    glm::vec4( 1.0, 1.0,-1.0, 1.0f),
    glm::vec4( 1.0, 1.0, 1.0, 1.0f),
    glm::vec4(-1.0, 1.0, 1.0, 1.0f),
    glm::vec4(-1.0, 1.0,-1.0, 1.0f)
};

#define RESET_CLKS 8
#define MAX_SIM_TIME 2048
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void print_matrix_glm(glm::mat4 m);
void print_matrix(float mat[4][4]);
void print_vector(float vec[4]);
void print_matrix_fixed_point(void* mat);

int32_t sign_extend(int32_t a, int data_width) {
    int32_t sign = (a >> (data_width - 1)) & 1;
    int32_t sign_extended = a;
    if (sign) {
        for (int i = sizeof(int32_t) * 8 - 1; i >= data_width; i--) {
            sign_extended |= (1 << i);
        }
    }
    return sign_extended; 
}

void assign_mvp_data(Vtb_transform_pipeline* dut, glm::mat4 mvp) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int32_t fixed_point = FixedPoint<int32_t>::fromFloat(mvp[j][i], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
            dut->i_mvp_matrix[i][j] = fixed_point;
        }
    }
};

void assign_vertex_data(Vtb_transform_pipeline* dut, glm::vec4 vertex) {
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
    model = glm::rotate(model, glm::radians(45.0f), glm::vec3(1.0f, 0.0f, 0.0f));
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

    printf("Expecting:\n");
    for (int i = 0; i < cube_verticies_size; i++) {
        glm::vec4 vertex_projected = mvp * cube_verticies[i];
        // printf("Vertex projected: %f, %f, %f, %f\n", vertex_projected.x, vertex_projected.y, vertex_projected.z, vertex_projected.w);

        glm::vec4 vertex_ndc = vertex_projected / vertex_projected.w;
        printf("Vertex NDC: %f, %f, %f\n", vertex_ndc.x, vertex_ndc.y, vertex_ndc.z);

        int vertex_pixel[2];
        vertex_pixel[0] = (vertex_ndc.x + 1.0f) * SCREEN_WIDTH / 2.0f;
        vertex_pixel[1] = (1 - vertex_ndc.y) * SCREEN_HEIGHT / 2.0f;

        float vertex_depth = vertex_ndc.z;
        printf("(%d, %d),\n", vertex_pixel[0], vertex_pixel[1]);
    }

    printf("Staring simulation...\n");
    printf("Got: \n");

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

            // if (dut->o_vs_vertex_dv) {
            //     float vs_vertex[4];
            //     for (int i = 0; i < 4; i++) {
            //         vs_vertex[i] = FixedPoint<int32_t>(dut->o_vs_vertex[i], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).toFloat();
            //     }
            //
            //     printf("Vertex: %f, %f, %f, %f\n", vs_vertex[0], vs_vertex[1], vs_vertex[2], vs_vertex[3]);
            // }

            if (dut->o_vertex_dv) {
                int32_t vertex_pixel[2];
                float vertex_depth;

                vertex_pixel[0] = sign_extend(dut->o_vertex_pixel[0], OUTPUT_VERTEX_DATAWIDTH);
                vertex_pixel[1] = sign_extend(dut->o_vertex_pixel[1], OUTPUT_VERTEX_DATAWIDTH);
                vertex_depth = FixedPoint<int32_t>(dut->o_vertex_z, OUTPUT_DEPTH_FRACBITS, OUTPUT_DEPTH_FRACBITS+1).toFloat();

                printf("(%d, %d),\n", vertex_pixel[0], vertex_pixel[1]);
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }
    
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

void print_matrix_glm(glm::mat4 m) {
    float* mat = glm::value_ptr(m);
    printf("%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n", 
        mat[0], mat[1], mat[2], mat[3],
        mat[4], mat[5], mat[6], mat[7],
        mat[8], mat[9], mat[10], mat[11],
        mat[12], mat[13], mat[14], mat[15]
    );
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
