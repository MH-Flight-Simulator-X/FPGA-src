#include <verilated.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include "../../../../verilator_utils/fixed_point.h"
#include "obj_dir/Vrot_z.h"

int main(int argc, char* argv[]) {
    printf("Program started\n");
    Verilated::commandArgs(argc, argv);
    Vrot_z* dut = new Vrot_z;

    int read = 0;

    dut->clk = 0;
    for (int i = 0; i < 4; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->angle = 500;
    }

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

            float t = 2 * M_PI * (float)read / (1 << 12);
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

            dut->angle = ++read;
        }

        if (read == 512) {
            break;
        }
    }

    delete dut;
    exit(EXIT_SUCCESS);
}
