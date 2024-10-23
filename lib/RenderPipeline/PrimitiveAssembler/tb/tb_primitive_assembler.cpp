#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vprimitive_assembler.h"

#define IV_DATAWIDTH 24
#define IV_FRACBITS 13

#define OV_DATAWIDTH 12
#define O_DEPTH_FRACBITS 12 // Q0.12

#define RESET_CLKS 8

#define MAX_SIM_TIME 240
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

typedef struct {
    int32_t x;
    int32_t y;
    float z;
    int invalid;
} Vertex;

typedef struct {
    int32_t i0;
    int32_t i1;
    int32_t i2;
} Triangle;

int32_t vertex_pixel_data_size = 8;
Vertex vertex_pixel_data[] = {
    {148, 160, 0.981378f, 0},
    {191, 222, 0.979009f, 0},
    {122, 234, 0.974551f, 0},
    {80,  160, 0.977861f, 0},
    {191,  97, 0.979009f, 0},
    {245, 160, 0.976026f, 0},
    {177, 160, 0.970188f, 0},
    {122,  85, 0.974551f, 0},
};

int32_t index_data_size = 12;
Triangle index_data[] = {
    {1, 3, 0}, 
    {7, 5, 4}, 
    {4, 1, 0}, 
    {5, 2, 1}, 
    {2, 7, 3}, 
    {0, 7, 4}, 
    {1, 2, 3}, 
    {7, 6, 5}, 
    {4, 5, 1}, 
    {5, 6, 2}, 
    {2, 6, 7}, 
    {0, 3, 7}
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

void assign_input_index(Vprimitive_assembler* dut) {
    if (dut->o_index_buff_read_en) {
        if (dut->o_index_buff_addr >= index_data_size) {
            return;
        }

        dut->i_vertex_idxs[0] = index_data[dut->o_index_buff_addr].i0;
        dut->i_vertex_idxs[1] = index_data[dut->o_index_buff_addr].i1;
        dut->i_vertex_idxs[2] = index_data[dut->o_index_buff_addr].i2;
    } else {
        dut->i_vertex_idxs[0] = 0;
        dut->i_vertex_idxs[1] = 0;
        dut->i_vertex_idxs[2] = 0;
    }
}

void assign_input_vertex(Vprimitive_assembler* dut) {
    if (dut->o_vertex_read_en) {
        if (dut->o_vertex_addr[0] >= vertex_pixel_data_size || dut->o_vertex_addr[1] >= vertex_pixel_data_size || dut->o_vertex_addr[2] >= vertex_pixel_data_size) {
            return;
        }

        dut->i_v0[0] = truncate(vertex_pixel_data[dut->o_vertex_addr[0]].x, IV_DATAWIDTH);
        dut->i_v0[1] = truncate(vertex_pixel_data[dut->o_vertex_addr[0]].y, IV_DATAWIDTH);
        dut->i_v0_z = FixedPoint<int32_t>::fromFloat(vertex_pixel_data[dut->o_vertex_addr[0]].z, O_DEPTH_FRACBITS, O_DEPTH_FRACBITS+1).get();
        dut->i_v0_invalid = vertex_pixel_data[dut->o_vertex_addr[0]].invalid;

        dut->i_v1[0] = truncate(vertex_pixel_data[dut->o_vertex_addr[1]].x, IV_DATAWIDTH);
        dut->i_v1[1] = truncate(vertex_pixel_data[dut->o_vertex_addr[1]].y, IV_DATAWIDTH);
        dut->i_v1_z = FixedPoint<int32_t>::fromFloat(vertex_pixel_data[dut->o_vertex_addr[1]].z, O_DEPTH_FRACBITS, O_DEPTH_FRACBITS+1).get();
        dut->i_v1_invalid = vertex_pixel_data[dut->o_vertex_addr[1]].invalid;

        dut->i_v2[0] = truncate(vertex_pixel_data[dut->o_vertex_addr[2]].x, IV_DATAWIDTH);
        dut->i_v2[1] = truncate(vertex_pixel_data[dut->o_vertex_addr[2]].y, IV_DATAWIDTH);
        dut->i_v2_z = FixedPoint<int32_t>::fromFloat(vertex_pixel_data[dut->o_vertex_addr[2]].z, O_DEPTH_FRACBITS, O_DEPTH_FRACBITS+1).get();
        dut->i_v2_invalid = vertex_pixel_data[dut->o_vertex_addr[2]].invalid;
    } else {
        dut->i_v0[0] = 0;
        dut->i_v0[1] = 0;
        dut->i_v0_z = 0;

        dut->i_v1[0] = 0;
        dut->i_v1[1] = 0;
        dut->i_v1_z = 0;

        dut->i_v2[0] = 0;
        dut->i_v2[1] = 0;
        dut->i_v2_z = 0;
    }
}

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv);
    Vprimitive_assembler* dut = new Vprimitive_assembler;
    
    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
    
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();
    
        dut->start = 0;

        dut->i_vertex_idxs[0] = 0;
        dut->i_vertex_idxs[1] = 0;
        dut->i_vertex_idxs[2] = 0;

        dut->i_v0[0] = 0;
        dut->i_v0[1] = 0;
        dut->i_v0_z = 0;

        dut->i_v1[0] = 0;
        dut->i_v1[1] = 0;
        dut->i_v1_z = 0;

        dut->i_v2[0] = 0;
        dut->i_v2[1] = 0;
        dut->i_v2_z = 0;

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
            dut->start = 0;
            dut->i_ready = 1;

            assign_input_index(dut);
            assign_input_vertex(dut);

            if (dut->o_ready) {
                dut->i_num_triangles = index_data_size;
                dut->start = 1;
            }

            if (dut->o_dv) {
                printf("Triangle: \n");
                printf("Vertex 0: (%d, %d, %f)\n", dut->o_vertex_pixel[0][0], dut->o_vertex_pixel[0][1], FixedPoint<int32_t>(dut->o_vertex_z[0], O_DEPTH_FRACBITS, O_DEPTH_FRACBITS + 1).toFloat());
                printf("Vertex 1: (%d, %d, %f)\n", dut->o_vertex_pixel[1][0], dut->o_vertex_pixel[1][1], FixedPoint<int32_t>(dut->o_vertex_z[1], O_DEPTH_FRACBITS, O_DEPTH_FRACBITS + 1).toFloat());
                printf("Vertex 2: (%d, %d, %f)\n", dut->o_vertex_pixel[2][0], dut->o_vertex_pixel[2][1], FixedPoint<int32_t>(dut->o_vertex_z[2], O_DEPTH_FRACBITS, O_DEPTH_FRACBITS + 1).toFloat());

                printf("Bounding Box:\t");
                printf("X: %d - %d\t", dut->bb_tl[0], dut->bb_br[0]);
                printf("Y: %d - %d\n", dut->bb_tl[1], dut->bb_br[1]);

                printf("\n");
            }

            if (dut->finished) {
                printf("Finished\n");
                break;
            }
        }
    
        m_trace->dump(sim_time);
        sim_time++;
    }
    
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
