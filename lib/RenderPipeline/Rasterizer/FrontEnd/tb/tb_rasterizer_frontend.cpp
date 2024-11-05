#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vrasterizer_frontend.h"

#define DATAWIDTH 12

#define RESET_CLKS 8
#define MAX_SIM_TIME 120
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

typedef struct {
    int32_t x;
    int32_t y;
    float z;
} Vertex;

Vertex test_data[3] = {
    {12, 4, 0},
    {20, 200, 0.5},
    {40, 200, 0.8}
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
    dut->i_v0[0] = v0.x;
    dut->i_v0[1] = v0.y;
    dut->i_v0[2] = FixedPoint<uint32_t>::fromFloat(v0.z, DATAWIDTH, DATAWIDTH).get();

    dut->i_v1[0] = v1.x;
    dut->i_v1[1] = v1.y;
    dut->i_v1[2] = FixedPoint<uint32_t>::fromFloat(v1.z, DATAWIDTH, DATAWIDTH).get();

    dut->i_v2[0] = v2.x;
    dut->i_v2[1] = v2.y;
    dut->i_v2[2] = FixedPoint<uint32_t>::fromFloat(v2.z, DATAWIDTH, DATAWIDTH).get();
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
                printf("Assigning data\n");
                assign_data(dut, test_data[0], test_data[1], test_data[2]);
                dut->i_triangle_dv = 1;
            }

            if (dut->o_dv) {
                printf("Got:\n");

                int32_t bb_br[2];
                int32_t bb_tl[2];

                int32_t edge_coeffs[3];
                int32_t edge_delta0[2];
                int32_t edge_delta1[2];
                int32_t edge_delta2[2];

                int32_t area;
                float area_inv;

                bb_tl[0] = sign_extend(dut->bb_tl[0], DATAWIDTH);
                bb_tl[1] = sign_extend(dut->bb_tl[1], DATAWIDTH);
                bb_br[0] = sign_extend(dut->bb_br[0], DATAWIDTH);
                bb_br[1] = sign_extend(dut->bb_br[1], DATAWIDTH);

                edge_coeffs[0] = sign_extend(dut->edge_val0, 2*DATAWIDTH);
                edge_coeffs[1] = sign_extend(dut->edge_val1, 2*DATAWIDTH);
                edge_coeffs[2] = sign_extend(dut->edge_val2, 2*DATAWIDTH);

                edge_delta0[0] = sign_extend(dut->edge_delta0[0], DATAWIDTH);
                edge_delta0[1] = sign_extend(dut->edge_delta0[1], DATAWIDTH);

                edge_delta1[0] = sign_extend(dut->edge_delta1[0], DATAWIDTH);
                edge_delta1[1] = sign_extend(dut->edge_delta1[1], DATAWIDTH);

                edge_delta2[0] = sign_extend(dut->edge_delta2[0], DATAWIDTH);
                edge_delta2[1] = sign_extend(dut->edge_delta2[1], DATAWIDTH);

                area = sign_extend(dut->o_area, 2*DATAWIDTH);
                area_inv = FixedPoint<uint32_t>(dut->area_inv, 2*DATAWIDTH, 2*DATAWIDTH, false).toFloat();

                printf("Bounding Box:\n");
                printf("Top Left: (%d, %d)\n", bb_tl[0], bb_tl[1]);
                printf("Bottom Right: (%d, %d)\n", bb_br[0], bb_br[1]);
                printf("\n");

                printf("Edge Coefficients:\n");
                printf("Edge 0: %d\n", edge_coeffs[0]);
                printf("Edge 1: %d\n", edge_coeffs[1]);
                printf("Edge 2: %d\n", edge_coeffs[2]);
                printf("\n");

                printf("Edge Deltas:\n");
                printf("Edge 0: (%d, %d)\n", edge_delta0[0], edge_delta0[1]);
                printf("Edge 1: (%d, %d)\n", edge_delta1[0], edge_delta1[1]);
                printf("Edge 2: (%d, %d)\n", edge_delta2[0], edge_delta2[1]);
                printf("\n");

                printf("Area Stuff:\n");
                printf("Area: %d\n", area);
                printf("Area inverse: %f\n", area_inv);

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

