#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vvertex_post_processor.h"

#define FIXED_POINT_WIDTH 24
#define FIXED_POINT_FRAC_WIDTH 13

#define Z_BITS 12
#define Z_FRAC_BITS 11

#define RESET_CLKS 8

void print_vector3(float vec[3]);
void print_vector4(float vec[4]);

#define MAX_SIM_TIME 240
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void assign_input_vertex(Vvertex_post_processor* dut, float vertex[4]) {
    dut->i_vertex[0] = FixedPoint<int32_t>::fromFloat(vertex[0], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
    dut->i_vertex[1] = FixedPoint<int32_t>::fromFloat(vertex[1], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
    dut->i_vertex[2] = FixedPoint<int32_t>::fromFloat(vertex[2], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
    dut->i_vertex[3] = FixedPoint<int32_t>::fromFloat(vertex[3], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();

    dut->i_vertex_dv = 1;
}

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv);
    Vvertex_post_processor* dut = new Vvertex_post_processor;
    
    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
    
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();
    
        dut->rstn = 0;
        dut->i_vertex_dv = 0;
    
        for (int i = 0; i < 4; i++) {
            dut->i_vertex[i] = 0;
        }
    }
    dut->rstn = 1;

    float znear = 0.1f;
    float zfar = 100.0f;
    int screen_width = 320;
    int screen_height = 320;

    float test_vector[4] = {
        -2.3, -1.635, 0.8875, 3.23302
    };

    float expected_ndc[3] = {0.0f};
    expected_ndc[0] = (test_vector[0] / test_vector[3]);
    expected_ndc[1] = (test_vector[1] / test_vector[3]);
    expected_ndc[2] = (test_vector[2] / test_vector[3]);

    float expected_depth = 0.0f;
    int expected_screen_pixels[2] = {0};
    expected_screen_pixels[0] = int((1 + expected_ndc[0]) * screen_width / 2);
    expected_screen_pixels[1] = int((1 - expected_ndc[1]) * screen_height / 2);
    expected_depth = expected_ndc[2];

    printf("Expected: \n");
    printf("\tNDC: ");
    print_vector3(expected_ndc);
    printf("\tResult:\n");
    printf("\t\tDepth: %f\n", expected_depth);
    printf("\t\tScreen Pixels: (%d, %d)\n", expected_screen_pixels[0], expected_screen_pixels[1]);
    
    printf("========== STARTING SIMULATION ==========\n");
    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();
    
        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_vertex_dv = 0;

            if (posedge_cnt == 4) {
                assign_input_vertex(dut, test_vector);
            }

            if (dut->o_vertex_dv) {
                int32_t vertex_pix[2] = {0};
                vertex_pix[0] = dut->o_vertex_pixel[0];
                vertex_pix[1] = dut->o_vertex_pixel[1];

                float vertex_z = 0.0f;
                vertex_z = FixedPoint<int32_t>(dut->o_vertex_z, Z_FRAC_BITS, Z_BITS).toFloat();

                printf("\n\nGot: \n");
                printf("\tPixel: (%d, %d)\t Depth: %f\n", vertex_pix[0], vertex_pix[1], vertex_z);
            }
        }
    
        m_trace->dump(sim_time);
        sim_time++;
    }
    
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

void print_vector3(float vec[3]) {
    printf("%f, %f, %f\n", vec[0], vec[1], vec[2]);
}

void print_vector4(float vec[4]) {
    printf("%f, %f, %f, %f\n", vec[0], vec[1], vec[2], vec[3]);
}
