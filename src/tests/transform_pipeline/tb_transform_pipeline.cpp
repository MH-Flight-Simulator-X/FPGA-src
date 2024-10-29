#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>

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
#define OUTPUT_DEPTH_FRACBITS 12

#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 320
#define ZFAR 100.0f
#define ZNEAR 0.1f

typedef struct {
    glm::ivec2 v0;
    float v0_z;
    glm::ivec2 v1;
    float v1_z;
    glm::ivec2 v2;
    float v2_z;
} Triangle_t;

std::vector<glm::vec3> read_vertex_data(const std::string& filename) {
    std::ifstream infile(filename);
    std::vector<glm::vec3> vertices;
    std::string line;

    if (!infile.is_open()) {
        std::cerr << "Error opening file: " << filename << std::endl;
        return vertices;
    }

    while (std::getline(infile, line)) {
        std::stringstream ss(line);
        float x, y, z;
        char comma1, comma2;

        // Parsing the "x, y, z" format
        ss >> x >> comma1 >> y >> comma2 >> z;
        if (ss.fail() || comma1 != ',' || comma2 != ',') {
            std::cerr << "Error parsing line: " << line << std::endl;
            continue;
        }

        vertices.emplace_back(x, y, z);  // Store as glm::vec3
    }

    infile.close();
    return vertices;
}

std::vector<glm::ivec3> read_index_data(const std::string& filename) {
    std::ifstream infile(filename);
    std::vector<glm::ivec3> indices;
    std::string line;

    if (!infile.is_open()) {
        std::cerr << "Error opening file: " << filename << std::endl;
        return indices;
    }

    while (std::getline(infile, line)) {
        std::stringstream ss(line);
        int x, y, z;
        char comma1, comma2;

        // Parsing the "x, y, z" format
        ss >> x >> comma1 >> y >> comma2 >> z;
        if (ss.fail() || comma1 != ',' || comma2 != ',') {
            std::cerr << "Error parsing line: " << line << std::endl;
            continue;
        }

        x--; y--; z--;  // Convert to 0-based indexing
        indices.emplace_back(x, y, z);  // Store as glm::ivec3
    }

    infile.close();
    return indices;
}

void write_triangle_data(const std::string& filename, std::vector<Triangle_t>& triangles) {
    std::ofstream outfile(filename);
    if (!outfile.is_open()) {
        std::cerr << "Error opening file: " << filename << std::endl;
        return;
    }

    for (const auto& tri : triangles) {
        outfile << tri.v0.x << ", " << tri.v0.y << ", " << tri.v0_z << ", " << tri.v1.x << ", " << tri.v1.y  << ", " <<  tri.v1_z << ", " << tri.v2.x << ", " << tri.v2.y  << ", " <<  tri.v2_z << std::endl;
    }

    outfile.close();
}

glm::mat4 generate_mvp() {
    // Generate matrix and vector data using GLM
    glm::mat4 model = glm::mat4(1.0f);
    model = glm::translate(model, glm::vec3(0.0f, -2.5f, -95.0f));
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
    glm::mat4 mvp = projection * view * model;

    return mvp;
}

#define RESET_CLKS 8
#define MAX_SIM_TIME 1152921504606846976
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;


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

void assign_vertex_data(Vtb_transform_pipeline* dut, glm::vec3 vertex) {
    for (int i = 0; i < 3; i++) {
        dut->i_vertex[i] = FixedPoint<int32_t>::fromFloat(vertex[i], INPUT_VERTEX_FRACBITS, INPUT_VERTEX_DATAWIDTH).get();
    }
};

void assign_input_index(Vtb_transform_pipeline* dut, std::vector<glm::ivec3>& index_data) {
    if (dut->o_index_buff_read_en) {
        if (dut->o_index_buff_addr >= index_data.size()) {
            return;
        }

        printf("Index: %d\n", dut->o_index_buff_addr);
        printf("Index data: %d, %d, %d\n", index_data[dut->o_index_buff_addr].x, index_data[dut->o_index_buff_addr].y, index_data[dut->o_index_buff_addr].z);

        dut->i_vertex_idxs[0] = index_data[dut->o_index_buff_addr].x;
        dut->i_vertex_idxs[1] = index_data[dut->o_index_buff_addr].y;
        dut->i_vertex_idxs[2] = index_data[dut->o_index_buff_addr].z;
    } else {
        dut->i_vertex_idxs[0] = 0;
        dut->i_vertex_idxs[1] = 0;
        dut->i_vertex_idxs[2] = 0;
    }
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtb_transform_pipeline* dut = new Vtb_transform_pipeline;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    std::vector<glm::vec3> vertex_buffer = read_vertex_data("model.vert");
    std::vector<glm::ivec3> index_buffer = read_index_data("model.face");
    glm::mat4 mvp = generate_mvp();

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

        dut->i_num_triangles = 0;
        dut->i_vertex_idxs[0] = 0;
        dut->i_vertex_idxs[1] = 0;
        dut->i_vertex_idxs[2] = 0;
        dut->i_triangle_ready = 1;

        dut->i_vertex_last = 0;
    }
    dut->rstn = 1;
    dut->i_triangle_ready = 0;

    // Run simulation while (sim_time < MAX_SIM_TIME) {
    long long vertex_index = 0;
    std::vector<Triangle_t> output_triangles = {};

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_vertex_dv = 0;
            dut->i_mvp_dv = 0;
            dut->i_vertex_last = 0;

            // Set input data size
            dut->i_num_triangles = index_buffer.size();

            // Assign mvp matrix
            if (posedge_cnt == 2) {
                assign_mvp_data(dut, mvp);
                dut->i_mvp_dv = 1;
            }

            if (posedge_cnt >= 4) {
                if (dut->vertex_ready && vertex_index < vertex_buffer.size()) {
                    if (vertex_index == vertex_buffer.size() - 1) {
                        dut->i_vertex_last = 1;
                    }
                    assign_vertex_data(dut, vertex_buffer[vertex_index++]);                    
                    dut->i_vertex_dv = 1;
                }
            }

            if (dut->debug_o_vertex_dv) {
                int32_t vertex[2];
                vertex[0] = sign_extend(dut->debug_o_vertex[0], OUTPUT_VERTEX_DATAWIDTH);
                vertex[1] = sign_extend(dut->debug_o_vertex[1], OUTPUT_VERTEX_DATAWIDTH);

                printf("Vertex: (%d, %d)\n", vertex[0], vertex[1]);
            }

            static int num_triangles_rec = 0;
            if (dut->o_triangle_dv) {
                int32_t v0[2]; int32_t v1[2]; int32_t v2[2];
                float v0_z; float v1_z; float v2_z;

                v0[0] = sign_extend(dut->o_vertex_pixel[0][0], OUTPUT_VERTEX_DATAWIDTH);
                v0[1] = sign_extend(dut->o_vertex_pixel[0][1], OUTPUT_VERTEX_DATAWIDTH);
                v0_z = FixedPoint<uint32_t>(dut->o_vertex_z[0], OUTPUT_DEPTH_FRACBITS, OUTPUT_DEPTH_FRACBITS, false).toFloat();

                v1[0] = sign_extend(dut->o_vertex_pixel[1][0], OUTPUT_VERTEX_DATAWIDTH);
                v1[1] = sign_extend(dut->o_vertex_pixel[1][1], OUTPUT_VERTEX_DATAWIDTH);
                v1_z = FixedPoint<uint32_t>(dut->o_vertex_z[1], OUTPUT_DEPTH_FRACBITS, OUTPUT_DEPTH_FRACBITS, false).toFloat();

                v2[0] = sign_extend(dut->o_vertex_pixel[2][0], OUTPUT_VERTEX_DATAWIDTH);
                v2[1] = sign_extend(dut->o_vertex_pixel[2][1], OUTPUT_VERTEX_DATAWIDTH);
                v2_z = FixedPoint<uint32_t>(dut->o_vertex_z[2], OUTPUT_DEPTH_FRACBITS, OUTPUT_DEPTH_FRACBITS, false).toFloat();

                // Print output data
                printf("Triangle (%d / %ld): (%d, %d, %f), (%d, %d, %f), (%d, %d, %f)\n", ++num_triangles_rec, index_buffer.size(), v0[0], v0[1], v0_z, v1[0], v1[1], v1_z, v2[0], v2[1], v2_z);

                // Store triangle data
                Triangle_t tri = {glm::ivec2(v0[0], v0[1]), v0_z,
                                  glm::ivec2(v1[0], v1[1]), v1_z, 
                                  glm::ivec2(v2[0], v2[1]), v2_z};
                output_triangles.push_back(tri);
            }

            static int vpp_has_finished = 0;
            if (dut->o_vpp_finished) {
                vpp_has_finished = 1;
            }

            if (vpp_has_finished) {
                if (dut->i_triangle_ready == 0) {
                    if (posedge_cnt % 64 == 0) {
                        dut->i_triangle_ready = 1;
                    }
                }

                if (dut->o_triangle_dv) {
                    dut->i_triangle_ready = 0;
                }
            }

            if (dut->finished) {
                printf("Finished! (%ld)\n", posedge_cnt);
                break;
            }
            
            // Assign index data
            assign_input_index(dut, index_buffer);
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    write_triangle_data("model.tri", output_triangles);
    
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
