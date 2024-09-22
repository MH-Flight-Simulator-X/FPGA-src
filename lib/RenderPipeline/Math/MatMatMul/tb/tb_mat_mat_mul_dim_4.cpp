#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vmat_mat_mul_dim_4.h"
#include "obj_dir/Vmat_mat_mul_dim_4___024unit.h"

typedef int32_t fixed_point_t;

// Currently configured for Q10.8
const uint32_t fixed_point_frac_bits = 8;
const double max_fixed_point_error = std::exp2(-((double)fixed_point_frac_bits + 1));
const double max_random_value = 100.0;

double fixed_to_double(fixed_point_t input);
fixed_point_t double_to_fixed(double input);

void print_matrix(double mat[4][4]);

#define MAX_SIM_TIME 40
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void reset_dut(Vmat_mat_mul_dim_4* dut, vluint64_t& sim_time) {
    dut->rstn = 1;
    if (sim_time >= 2 && sim_time <= 8) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                dut->A[i][j] = 0;
                dut->B[i][j] = 0;
                dut->C[i][j] = 0;
            }
        }
        dut->i_dv = 0;
        dut->rstn = 0;
    }
}

void populate_matrix_random(double mat[4][4], float max_val) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            mat[i][j] = 2.0 * (static_cast<double>(rand()) / RAND_MAX) - 1.0;
            mat[i][j] *= max_val;
        }
    }
}

void assign_matrix_data(Vmat_mat_mul_dim_4* dut, double A[4][4], double B[4][4]) {
    fixed_point_t A_fixed[4][4] = {};
    fixed_point_t B_fixed[4][4] = {};
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            A_fixed[i][j] = double_to_fixed(A[i][j]);
            B_fixed[i][j] = double_to_fixed(B[i][j]);
        }
    }

    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            dut->A[i][j] = A_fixed[i][j];
            dut->B[i][j] = B_fixed[i][j];
        }
    }
};

void check_output_data(Vmat_mat_mul_dim_4* dut) {
    srand(time(NULL));
    constexpr int pipeline_depth = 4;
    static double i_A[4][4][pipeline_depth], i_B[4][4][pipeline_depth], o_C[4][4];
    static fixed_point_t o_C_fixed[4][4];
    static int i_dv_r[4] = {0, 0, 0, 0};

    i_dv_r[1] = i_dv_r[0];
    i_dv_r[2] = i_dv_r[1];
    i_dv_r[3] = i_dv_r[2];

    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            i_A[i][j][1] = i_A[i][j][0];
            i_A[i][j][2] = i_A[i][j][1];
            i_A[i][j][3] = i_A[i][j][2];

            i_B[i][j][1] = i_B[i][j][0];
            i_B[i][j][2] = i_B[i][j][1];
            i_B[i][j][3] = i_B[i][j][2];
        }
    }

    if (dut->i_dv) {
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                i_A[i][j][0] = fixed_to_double(dut->A[i][j]);
                i_B[i][j][0] = fixed_to_double(dut->B[i][j]);
            }
        }

        i_dv_r[0] = 1;
    }

    if (dut->o_dv) {
        if (i_dv_r[3] != dut->o_dv) {
            printf("Error: o_dv did not match expected value\n");
        }
    }

    if (dut->o_dv) {
        double data_out[4][4];
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                data_out[i][j] = fixed_to_double(dut->C[i][j]);
            }
        }

        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                o_C[i][j] = 0;
                for (int k = 0; k < 4; k++) {
                    o_C[i][j] += i_A[i][k][3] * i_B[k][j][3];
                }
                o_C_fixed[i][j] = double_to_fixed(o_C[i][j]);
            }
        }

        double pipeline_max_fixed_point_error = max_fixed_point_error;
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                if (!(data_out[i][j] < o_C_fixed[i][j] + pipeline_max_fixed_point_error && data_out[i][j] > o_C_fixed[i][j] - pipeline_max_fixed_point_error)) {
                    printf("Error: Output data not within maximum fixed-point error\n Got: \n");
                    print_matrix(data_out);
                    printf("Expected: \n");
                    print_matrix(o_C);
                    return;
                }
            }
        }
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmat_mat_mul_dim_4* dut = new Vmat_mat_mul_dim_4;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    printf("Max fixed-point error: %f\n", (double)max_fixed_point_error);
    double test_A[4][4] = {
        {1.0, 2.0, 3.0, 4.0},
        {2.2, 3.2, 2.6, 1.8},
        {2.9, 4.8, 5.6, 2.4},
        {0.1, 0.8, 8.2, 6.3}
    };
    double test_B[4][4] = {
        {8.8, 9.2, 5.2, 1.5},
        {9.3, 6.3, 7.3, 6.1}, 
        {4.4, 3.2, 2.2, 5.6},
        {7.9, 1.2, 4.5, 6.2}
    };
    // populate_matrix_random(test_A, max_random_value);
    // populate_matrix_random(test_B, max_random_value);

    printf("Testing for random matrix:\n");
    print_matrix(test_A);
    printf("And:\n");
    print_matrix(test_B);
    printf("\n\n");
    
    printf("=======================\n");
    printf("# Starting simulation #\n");
    printf("=======================\n");

    while (sim_time < MAX_SIM_TIME) {
        reset_dut(dut, sim_time);

        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->i_dv = 0;

            if (posedge_cnt == 6) {
                assign_matrix_data(dut, test_A, test_B);
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
    return ((double)input / (double)(1 << fixed_point_frac_bits));
}

fixed_point_t double_to_fixed(double input) {
    return (fixed_point_t)(round((double)(input * (1 << fixed_point_frac_bits))));
}

void print_matrix(double mat[4][4]) {
    printf("%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n%f, %f, %f, %f\n", 
        mat[0][0], mat[0][1], mat[0][2], mat[0][3],
        mat[1][0], mat[1][1], mat[1][2], mat[1][3],
        mat[2][0], mat[2][1], mat[2][2], mat[2][3],
        mat[3][0], mat[3][1], mat[3][2], mat[3][3]
    );
}
