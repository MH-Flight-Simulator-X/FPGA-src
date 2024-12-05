#include <verilated.h>
#include <verilated_vcd_c.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include "../../../../verilator_utils/fixed_point.h"
#include "obj_dir/Vrot_z.h"

int main(int argc, char* argv[]) {
    printf("Program started\n");
    Verilated::commandArgs(argc, argv);
    Vrot_z* dut = new Vrot_z;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    int read = 0;

    dut->clk = 0;
    for (int i = 0; i < 4; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->angle = read++;
    }

    vluint64_t sim_time = 0;
    while (1) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk) {
            float matrix[4][4];
            for (int i = 0; i < 4; i++) {
                for (int j = 0; j < 4; j++) {
                    matrix[i][j] = FixedPoint<int>(dut->rot_z_mat[i][j], 13, 24).toFloat();
                }
            }

            float t = 2 * M_PI * (float)(read-1) / (1 << 12);
            glm::mat4 exp_rot = glm::rotate(glm::mat4(1.0f), t, glm::vec3(0.0f, 0.0f, 1.0f));

            printf("Time: %f\n", t);
            printf("Expected:\n");
            for (int i = 0; i < 4; i++) {
                for (int j = 0; j < 4; j++) {
                    printf("%f\t", exp_rot[j][i]);
                }
                printf("\n");
            }

            printf("Got:\n");
            for (int i = 0; i < 4; i++) {
                for (int j = 0; j < 4; j++) {
                    printf("%f\t", matrix[i][j]);
                }
                printf("\n");
            }
            printf("\n");
            printf("\n");

            dut->angle = read++;
        }

        if (read == 512) {
            break;
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
