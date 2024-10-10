#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vvertex_shader.h"

#define FIXED_POINT_WIDTH 18
#define FIXED_POINT_FRAC_WIDTH 12

#define RESET_CLKS 8

float mvp[4][4] = {
    {-1.0f, 0.0f, 0.0f, 0.0f},
    {0.0f, -1.0f, 0.0f, 0.0f},
    {0.0f, 0.0f, -1.0f, 0.0f},
    {0.0f, 0.0f, 0.0f, -1.0f}
};

float (*vertex_data)[3];

void print_matrix(float mat[4][4]);
void print_vector(float vec[4]);

#define MAX_SIM_TIME 120
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void populate_vertex_data(float (*vd_ptr)[3], size_t size) {
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < 3; j++) {
            constexpr float max_val = (float)(1 << (FIXED_POINT_WIDTH - FIXED_POINT_FRAC_WIDTH - 1))/2 - 1;
            constexpr float min_val = -(float)(1 << (FIXED_POINT_WIDTH - FIXED_POINT_FRAC_WIDTH - 1))/2;

            float r = (float)rand() / (float)RAND_MAX;
            vd_ptr[i][j] = min_val + r * (max_val - min_val);
        }
    } 
}

void assign_mvp_data(Vvertex_shader* dut, float mvp[4][4]) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            dut->i_mvp_mat[i][j] = FixedPoint<int32_t>::fromFloat(mvp[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
        }
    }
};

void assign_vertex_data(Vvertex_shader* dut, float vertex[3]) {
    for (int i = 0; i < 3; i++) {
        dut->i_vertex[i] = FixedPoint<int32_t>::fromFloat(vertex[i], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
    }
};

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv);
    Vvertex_shader* dut = new Vvertex_shader;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    printf("MVP Matrix:\n");
    print_matrix(mvp);

    // Allocate memory for vertex_data
    size_t vertex_data_size = 8;
    vertex_data = (float(*)[3])malloc(vertex_data_size * sizeof(float[3]));
    populate_vertex_data(vertex_data, vertex_data_size);

    printf("Input Vertex Data:\n");
    for (int i = 0; i < vertex_data_size; i++) {
        printf("Vertex %d: %f, %f, %f\n", i, vertex_data[i][0], vertex_data[i][1], vertex_data[i][2]);
    }

    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;
        dut->i_mvp_dv = 0;
        dut->i_vertex_dv = 0;

        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->i_mvp_mat[i][j] = 0; 
            }
        }
        for (int i = 0; i < 3; i++) {
            dut->i_vertex[i] = 0;
        }

        dut->i_vertex_last = 0;
    }
    dut->rstn = 1;


    int current_vertex_index = 0;

    printf("========== STARTING SIMULATION ==========\n");
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

            // Assign vertex data
            if (dut->o_ready) {
                if (current_vertex_index < vertex_data_size) {
                    assign_vertex_data(dut, vertex_data[current_vertex_index]);
                    dut->i_vertex_dv = 1;
                    if (current_vertex_index == vertex_data_size - 1) {
                        dut->i_vertex_last = 1;
                    }
                    current_vertex_index++;
                } 
            }

            if (dut->o_vertex_dv) {
                static int vertex_cnt = 0;
                printf("Vertex %d: %f, %f, %f, %f\n", vertex_cnt++, 
                    FixedPoint<int32_t>(dut->o_vertex[0], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat(),
                    FixedPoint<int32_t>(dut->o_vertex[1], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat(),
                    FixedPoint<int32_t>(dut->o_vertex[2], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat(),
                    FixedPoint<int32_t>(dut->o_vertex[3], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat()
                );
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }
    
    free(vertex_data);
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
