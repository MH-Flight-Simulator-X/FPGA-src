#include <math.h>
#include <verilated.h>
#include "../../../../verilator_utils/fixed_point.h"
#include "obj_dir/Vsin_cos_lu.h"

vluint64_t posedge_cnt = 0;

int main(int argc, char* argv[]) {
    printf("Program started\n");
    Verilated::commandArgs(argc, argv);
    Vsin_cos_lu* dut = new Vsin_cos_lu;

    int read = 0;

    dut->clk = 0;
    for (int i = 0; i < 4; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->angle = 0;
    }

    while (1) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk) {
            int sine_i = dut->sine;
            int cosine_i = dut->cosine;

            float sine_f = FixedPoint<int>(sine_i, 13, 24).toFloat();
            float cosine_f = FixedPoint<int>(cosine_i, 13, 24).toFloat();

            float t = 2 * M_PI * (float)read / (1 << 12);

            float sine_exp = sin(t);
            float cosine_exp = cos(t);
            printf("Expected:\n sin(%f) = %f\t cos(%f) = %f\n", 
                    t, sine_exp, 
                    t, cosine_exp);

            printf("Got:\n sin(%f) = %f\t cos(%f) = %f\n\n", 
                    t, sine_f, 
                    t, cosine_f);


            dut->angle = ++read;
        }

        if (read == 128) {
            break;
        }
    }

    delete dut;
    exit(EXIT_SUCCESS);
}
