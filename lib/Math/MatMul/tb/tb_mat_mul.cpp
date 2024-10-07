#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vmat_mul.h"
#include "obj_dir/Vmat_mul___024unit.h"

#define FIXED_POINT_WIDTH 18
#define FIXED_POINT_FRAC_WIDTH 12

#define RESET_CLKS 8

float test_A[4][4] = {
    {-1.0, 2.0, 3.0, 4.0},
    {1.0, 2.0, 3.0, 4.0},
    {1.0, 2.0, 3.0, 4.0},
    {1.0, 2.0, 3.0, 4.0}
};

float test_B[4][4] = {
    {2.0, 0.0, 0.0, 0.0},
    {0.0, -0.5, 0.0, 0.0},
    {0.0, 0.0, 0.25, 0.0},
    {0.0, 0.0, 0.0, -4.765}
};

void print_matrix(float mat[4][4]);

#define MAX_SIM_TIME 40
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void populate_matrix_random(float mat[4][4], float max_val) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
        }
    }
}

void assign_matrix_data(Vmat_mul* dut, float A[4][4], float B[4][4]) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            dut->A[i][j] = FixedPoint<int32_t>::fromFloat(A[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
            dut->B[i][j] = FixedPoint<int32_t>::fromFloat(B[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
        }
    }
};

void get_matrix_data_input(Vmat_mul* dut, float A[4][4], float B[4][4]) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            A[i][j] = FixedPoint<int32_t>(dut->A[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat();
            B[i][j] = FixedPoint<int32_t>(dut->B[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat();
        }
    }
};

void get_matrix_data_output(Vmat_mul* dut, float C[4][4]) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            C[i][j] = FixedPoint<int32_t>(dut->C[i][j], FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat();
        }
    }
}

void check_matrix_data(Vmat_mul* dut) {
    static float A[4][4];
    static float B[4][4];

    if (dut->o_dv == 1) {
        float C[4][4];
        get_matrix_data_output(dut, C);

        printf("\n================\nClock: %ld \n================\n", posedge_cnt);
        printf("Sendt in matrix A:\n");
        print_matrix(A);
        printf("Sendt in matrix B:\n");
        print_matrix(B);
        printf("Received matrix C:\n");
        print_matrix(C);
    }

    if (dut->i_dv == 1) {
        get_matrix_data_input(dut, A, B);
    }

};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmat_mul* dut = new Vmat_mul;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    printf("=======================\n");
    printf("# Starting simulation #\n");
    printf("=======================\n");

    // Reset DUT
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;
        dut->i_dv = 0;
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->A[i][j] = 0;
                dut->B[i][j] = 0;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rstn = 1;

    // Start sim
    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_dv = 0;

            if (posedge_cnt == 2) {
                assign_matrix_data(dut, test_A, test_B);
                dut->i_dv = 1;
            }

            check_matrix_data(dut);
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
