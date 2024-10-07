#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vmat_vec_mul_dim_4.h"

#define FIXED_POINT_FRAC_BITS 16
typedef uint32_t fixed_point_t;

double fixed_to_double(fixed_point_t input);
fixed_point_t double_to_fixed(double input);

#define MAX_SIM_TIME 40
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

vluint32_t matrix_data_fixed[4][4];
double matrix_data[4][4] = {
    {  1.5,  2.5,  3.2,  4.1    },
    {  5.2,  6.1,  7.5,  8.0125 },
    {  9.1, 10.2, 11.3, 12.4    },
    { 13.2, 14.2, 15.2, 16.1    },
};

vluint32_t vector_data_fixed[4];
double vector_data[4] = {
    1.0, 1.0, 1.0, 1.0
};

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
    dut->x[0] = data[0]; 
    dut->x[1] = data[1]; 
    dut->x[2] = data[2]; 
    dut->x[3] = data[3];
}

void check_output_data(Vmat_vec_mul_dim_4* dut) {
    if (dut->o_dv) {
        printf("Output data valid:\n");

        double data_out[4];
        data_out[0] = fixed_to_double(dut->y[0]);
        data_out[1] = fixed_to_double(dut->y[1]);
        data_out[2] = fixed_to_double(dut->y[2]);
        data_out[3] = fixed_to_double(dut->y[3]);

        printf("\tData: (%f, %f, %f, %f)\n", data_out[0], data_out[1], data_out[2], data_out[3]);
    }
}


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmat_vec_mul_dim_4* dut = new Vmat_vec_mul_dim_4;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    while (sim_time < MAX_SIM_TIME) {
        reset_dut(dut, sim_time);

        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_dv = 0;

            if (posedge_cnt == 6) {
                // Generate input
                for (int i = 0; i < 4; i++) {
                    for (int j = 0; j < 4; j++) {
                        matrix_data_fixed[i][j] = double_to_fixed(matrix_data[i][j]);
                    }
                }

                for (int i = 0; i < 4; i++) {
                    vector_data_fixed[i] = double_to_fixed(vector_data[i]);
                }

                assign_matrix_data(dut, matrix_data_fixed);
                assign_vector_data(dut, vector_data_fixed);
                dut->i_dv = 1;
            }

            check_output_data(dut);
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

double fixed_to_double(fixed_point_t input) {
    return ((double)input / (double)(1 << FIXED_POINT_FRAC_BITS));
}

fixed_point_t double_to_fixed(double input) {
    return (fixed_point_t)(round(input * (1 << FIXED_POINT_FRAC_BITS)));
}
