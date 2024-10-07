#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vmat_vec_mul.h"

#define FIXED_POINT_WIDTH 32
#define FIXED_POINT_FRAC_WIDTH 16

#define RESET_CLKS 8

float matrix_data[4][4] = {
    {1.0, 2.1, 3.0, 4.0},
    {2.9, 3.0, 4.0, -5.0},
    {3.0, 4.3, 5.0, 6.0},
    {4.2, 5.0, 6.2, -7.0}
};

float vector_data[4] = {
    20.2, -0.001, -1.1, 1.00001
};

void print_matrix(float mat[4][4]);
void print_vector(float vec[4]);

#define MAX_SIM_TIME 40
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void reset_dut(Vmat_vec_mul* dut, vluint64_t& sim_time) {
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

void assign_matrix_data(Vmat_vec_mul* dut, float A[4][4]) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            dut->A[i][j] = FixedPoint<int32_t>::fromFloat(A[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
        }
    }
}

void assign_vector_data(Vmat_vec_mul* dut, float x[4]) {
    for (int i = 0; i < 4; i++) {
        dut->x[i] = FixedPoint<int32_t>::fromFloat(x[i], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
    }
}

void check_output_data(Vmat_vec_mul* dut) {
    static float x0[4], x1[4], x2[4], x3[4];
    static float A0[4][4], A1[4][4], A2[4][4], A3[4][4];

    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            A1[i][j] = A0[i][j];
            A2[i][j] = A1[i][j];
            A3[i][j] = A2[i][j];
        }
        x1[i] = x0[i];
        x2[i] = x1[i];
        x3[i] = x2[i];
    }

    if (dut->i_dv) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                A0[i][j] = FixedPoint<int32_t>(dut->A[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat();
            }
            x0[i] = FixedPoint<int32_t>(dut->x[i], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat();
        }
    }

    if (dut->o_dv) {
        float y[4];
        for (int i = 0; i < 4; i++) {
            y[i] = FixedPoint<int32_t>(dut->y[i], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat();
        }

        printf("\n================\nClock: %ld \n================\n", posedge_cnt);
        printf("Sendt in matrix A:\n");
        print_matrix(A3);
        printf("Sendt in vector x:\n");
        print_vector(x3);
        printf("Received vector y:\n");
        print_vector(y);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmat_vec_mul* dut = new Vmat_vec_mul;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;
        dut->i_dv = 0;
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->A[i][j] = 0;
            }
            dut->x[i] = 0;
        }

        m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rstn = 1;

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_dv = 0;

            if (posedge_cnt == 2) {
                assign_matrix_data(dut, matrix_data);
                assign_vector_data(dut, vector_data);
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
