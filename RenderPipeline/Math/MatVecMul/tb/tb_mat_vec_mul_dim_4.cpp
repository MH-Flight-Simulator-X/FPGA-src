#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vmat_vec_mul_dim_4.h"

#define MAX_SIM_TIME 40
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void reset_dut(Vmat_vec_mul_dim_4* dut, vluint64_t& sim_time) {
    dut->rstn = 1;
    if (sim_time >= 2 && sim_time <= 8) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->A[i][j] = 0;
            }
        }
        for (int i = 0; i < 4; i++) {
            dut->x[i] = 0;
        }
        dut->i_dv = 0;
        dut->rstn = 0;
    }
}

void assign_matrix_data(Vmat_vec_mul_dim_4* dut, vluint32_t data[4][4]) {
    dut->A[0][0] = data[0][0]; dut->A[0][1] = data[0][1]; dut->A[0][2] = data[0][2]; dut->A[0][3] = data[0][3];
    dut->A[1][0] = data[1][0]; dut->A[1][1] = data[1][1]; dut->A[1][2] = data[1][2]; dut->A[1][3] = data[1][3];
    dut->A[2][0] = data[2][0]; dut->A[2][1] = data[2][1]; dut->A[2][2] = data[2][2]; dut->A[2][3] = data[2][3];
    dut->A[3][0] = data[3][0]; dut->A[3][1] = data[3][1]; dut->A[3][2] = data[3][2]; dut->A[3][3] = data[3][3];
};

void assign_vector_data(Vmat_vec_mul_dim_4* dut, vluint32_t data[4]) {
    dut->x[0] = data[0]; dut->x[1] = data[1]; dut->x[2] = data[2]; dut->x[3] = data[3];
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmat_vec_mul_dim_4* dut = new Vmat_vec_mul_dim_4;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    vluint32_t matrix_data[4][4] = {
        {  1,  2,  3,  4 },
        {  5,  6,  7,  8 },
        {  9, 10, 11, 12 },
        { 13, 14, 15, 16 },
    };

    vluint32_t vector_data[4] = {
        1, 1, 1, 1
    };

    while (sim_time < MAX_SIM_TIME) {
        reset_dut(dut, sim_time);

        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_dv = 0;

            if (posedge_cnt == 6) {
                assign_matrix_data(dut, matrix_data);
                assign_vector_data(dut, vector_data);
                dut->i_dv = 1;

                for (int i = 0; i < 4; i++) {
                    vector_data[i] *= 2;
                }
            }
            if (posedge_cnt == 7) {
                assign_matrix_data(dut, matrix_data);
                assign_vector_data(dut, vector_data);
                dut->i_dv = 1;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
