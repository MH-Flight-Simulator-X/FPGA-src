#include <cstdlib>
#include <iterator>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vrasterizer_frontend.h"

#define DATAWIDTH 24
#define FRACBITS 13

#define RESET_CLKS 8
#define MAX_SIM_TIME 4096
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

typedef struct {
    float x;
    float y;
    float z;
} Vertex;

Vertex test_data[3] = {
    {25.0f,  50.0f, 0.9f},
    {55.0f, 190.0f, 0.2f},
    {60.0f, 170.0f, 0.3f}
};

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

// Turn int32_t into lower datawidth
int32_t truncate(int32_t a, int data_width) {
    int32_t truncated = a & ((1 << data_width) - 1);
    return truncated;
}

void assign_data(Vrasterizer_frontend* dut, Vertex& v0, Vertex& v1, Vertex& v2) {
    dut->i_v0[0] = FixedPoint<int32_t>::fromFloat(v0.x, FRACBITS, DATAWIDTH).get();
    dut->i_v0[1] = FixedPoint<int32_t>::fromFloat(v0.y, FRACBITS, DATAWIDTH).get();
    dut->i_v0[2] = FixedPoint<int32_t>::fromFloat(v0.z, FRACBITS, DATAWIDTH).get();

    dut->i_v1[0] = FixedPoint<int32_t>::fromFloat(v1.x, FRACBITS, DATAWIDTH).get();
    dut->i_v1[1] = FixedPoint<int32_t>::fromFloat(v1.y, FRACBITS, DATAWIDTH).get();
    dut->i_v1[2] = FixedPoint<int32_t>::fromFloat(v1.z, FRACBITS, DATAWIDTH).get();

    dut->i_v2[0] = FixedPoint<int32_t>::fromFloat(v2.x, FRACBITS, DATAWIDTH).get();
    dut->i_v2[1] = FixedPoint<int32_t>::fromFloat(v2.y, FRACBITS, DATAWIDTH).get();
    dut->i_v2[2] = FixedPoint<int32_t>::fromFloat(v2.z, FRACBITS, DATAWIDTH).get();
}

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv);
    Vrasterizer_frontend* dut = new Vrasterizer_frontend;
    
    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
    
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();
    
        dut->i_triangle_dv = 0;
        for (int i = 0; i < 3; i++) {
            dut->i_v0[i] = 0;
            dut->i_v1[i] = 0;
            dut->i_v2[i] = 0;
        }

        dut->rstn = 0;
    
        m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rstn = 1;
    
    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();
    
        if (dut->clk == 1) {
            posedge_cnt++;
            dut->next = 1;
            dut->i_triangle_dv = 0;

            if (posedge_cnt == 4 && dut->ready) {
                printf("Assigning data (%ld)\n", posedge_cnt);
                assign_data(dut, test_data[0], test_data[1], test_data[2]);
                dut->i_triangle_dv = 1;
            }

            if (dut->finished_with_cull) {
                perror("Finished with cull");
                break;
            }

            if (dut->o_dv) {
                printf("Got:\n");

                float bb_br[2];
                float bb_tl[2];

                float edge_coeffs[3];
                float edge_delta0[2];
                float edge_delta1[2];
                float edge_delta2[2];

                float area;
                float area_reciprocal;

                float barycentric_weight[3];
                float barycentric_weight_delta[3][2];

                float z_coeff;
                float z_coeff_delta[2];

                bb_tl[0] = FixedPoint<int32_t>(dut->bb_tl[0], FRACBITS, DATAWIDTH).toFloat();
                bb_tl[1] = FixedPoint<int32_t>(dut->bb_tl[1], FRACBITS, DATAWIDTH).toFloat();
                bb_br[0] = FixedPoint<int32_t>(dut->bb_br[0], FRACBITS, DATAWIDTH).toFloat();
                bb_br[1] = FixedPoint<int32_t>(dut->bb_br[1], FRACBITS, DATAWIDTH).toFloat();

                edge_coeffs[0] = FixedPoint<long long>(dut->edge_val0, 2*FRACBITS, 2*DATAWIDTH).toFloat();
                edge_coeffs[1] = FixedPoint<long long>(dut->edge_val1, 2*FRACBITS, 2*DATAWIDTH).toFloat();
                edge_coeffs[2] = FixedPoint<long long>(dut->edge_val2, 2*FRACBITS, 2*DATAWIDTH).toFloat();

                edge_delta0[0] = FixedPoint<int32_t>(dut->edge_delta0[0], FRACBITS, DATAWIDTH).toFloat();
                edge_delta0[1] = FixedPoint<int32_t>(dut->edge_delta0[1], FRACBITS, DATAWIDTH).toFloat();

                edge_delta1[0] = FixedPoint<int32_t>(dut->edge_delta1[0], FRACBITS, DATAWIDTH).toFloat();
                edge_delta1[1] = FixedPoint<int32_t>(dut->edge_delta1[1], FRACBITS, DATAWIDTH).toFloat();

                edge_delta2[0] = FixedPoint<int32_t>(dut->edge_delta2[0], FRACBITS, DATAWIDTH).toFloat();
                edge_delta2[1] = FixedPoint<int32_t>(dut->edge_delta2[1], FRACBITS, DATAWIDTH).toFloat();

                area = FixedPoint<long long>(dut->rasterizer_frontend__DOT__r_area, 2*FRACBITS, 2*DATAWIDTH).toFloat();
                area_reciprocal = FixedPoint<int32_t>(dut->rasterizer_frontend__DOT__r_area_reciprocal, FRACBITS, FRACBITS, false).toFloat();

                barycentric_weight[0] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight[0], 2*FRACBITS, 2*DATAWIDTH).toFloat();
                barycentric_weight[1] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight[1], 2*FRACBITS, 2*DATAWIDTH).toFloat();
                barycentric_weight[2] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight[2], 2*FRACBITS, 2*DATAWIDTH).toFloat();

                barycentric_weight_delta[0][0] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight_delta[0][0], FRACBITS, DATAWIDTH).toFloat();
                barycentric_weight_delta[0][1] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight_delta[0][1], FRACBITS, DATAWIDTH).toFloat();

                barycentric_weight_delta[1][0] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight_delta[1][0], FRACBITS, DATAWIDTH).toFloat();
                barycentric_weight_delta[1][1] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight_delta[1][1], FRACBITS, DATAWIDTH).toFloat();

                barycentric_weight_delta[2][0] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight_delta[2][0], FRACBITS, DATAWIDTH).toFloat();
                barycentric_weight_delta[2][1] = FixedPoint<int>(dut->rasterizer_frontend__DOT__barycentric_weight_delta[2][1], FRACBITS, DATAWIDTH).toFloat();

                z_coeff = FixedPoint<int32_t>(dut->z_coeff, DATAWIDTH, DATAWIDTH, false).toFloat();
                z_coeff_delta[0] = FixedPoint<int16_t>(dut->z_coeff_delta[0], DATAWIDTH-1, DATAWIDTH, true).toFloat();
                z_coeff_delta[1] = FixedPoint<int16_t>(dut->z_coeff_delta[1], DATAWIDTH-1, DATAWIDTH, true).toFloat();

                printf("Bounding Box:\n");
                printf("Top Left: (%f, %f)\n", bb_tl[0], bb_tl[1]);
                printf("Bottom Right: (%f, %f)\n", bb_br[0], bb_br[1]);
                printf("\n");

                printf("Edge Coefficients:\n");
                printf("Edge 0: %f\n", edge_coeffs[0]);
                printf("Edge 1: %f\n", edge_coeffs[1]);
                printf("Edge 2: %f\n", edge_coeffs[2]);
                printf("\n");

                printf("Edge Deltas:\n");
                printf("Edge 0: (%f, %f)\n", edge_delta0[0], edge_delta0[1]);
                printf("Edge 1: (%f, %f)\n", edge_delta1[0], edge_delta1[1]);
                printf("Edge 2: (%f, %f)\n", edge_delta2[0], edge_delta2[1]);
                printf("\n");

                printf("Area stuff:\n");
                printf("Area: %f\n", area);
                printf("Area reciprocal: %f\n", area_reciprocal);
                printf("\n");

                printf("Barycentric Weights:\n");
                printf("Weight 0: %f\n", barycentric_weight[0]);
                printf("Weight 1: %f\n", barycentric_weight[1]);
                printf("Weight 2: %f\n", barycentric_weight[2]);
                printf("\n");
                
                printf("Barycentric Weight Deltas:\n");
                printf("Delta 0: (%f, %f)\n", barycentric_weight_delta[0][0], barycentric_weight_delta[0][1]);
                printf("Delta 1: (%f, %f)\n", barycentric_weight_delta[1][0], barycentric_weight_delta[1][1]);
                printf("Delta 2: (%f, %f)\n", barycentric_weight_delta[2][0], barycentric_weight_delta[2][1]);
                printf("\n");

                printf("Z coeffs:\n");
                printf("z_coeff: %f\n", z_coeff);
                printf("z_coeff_delta[0]: %f\n", z_coeff_delta[0]);
                printf("z_coeff_delta[1]: %f\n", z_coeff_delta[1]);
                printf("\n");

                printf("Finished (%ld)\n", posedge_cnt);
                printf("\n");
            }
        }

    
        m_trace->dump(sim_time);
        sim_time++;
    }
    
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

