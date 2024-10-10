#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vfixed_point_divide.h"

#define FIXED_POINT_WIDTH 18
#define FIXED_POINT_FRAC_WIDTH 12
#define FIXED_POINT_INT_WIDTH (FIXED_POINT_WIDTH - FIXED_POINT_FRAC_WIDTH)
#define FIXED_POINT_MAX ((1 << FIXED_POINT_INT_WIDTH) - 1)
#define FIXED_POINT_MIN (-(1 << FIXED_POINT_INT_WIDTH))

#define RESET_CLKS 8
#define MAX_SIM_TIME 500
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void assign_dividend_and_divisor(Vfixed_point_divide* dut, float dividend, float divisor) {
    dut->a = FixedPoint<int32_t>::fromFloat(dividend, FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
    dut->b = FixedPoint<int32_t>::fromFloat(divisor, FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
}

float generate_random_in_range(int min, int max) {
    return (float)rand() / RAND_MAX * (max - min) + min;
}

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv); 
    Vfixed_point_divide* dut = new Vfixed_point_divide;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;
        dut->a = 0;
        dut->b = 0;
    }
    dut->rstn = 1;

    printf("Starting simulation\n");
    while (!Verilated::gotFinish() && sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->start = 0;

            if (dut->done) {
                float result = FixedPoint<int32_t>(dut->val, FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).toFloat();
                printf("Result: %.4f\n", result);
            }
            if (!dut->busy) {
                float dividend = generate_random_in_range(FIXED_POINT_MIN/4, FIXED_POINT_MAX/4);
                float divisor = generate_random_in_range(FIXED_POINT_MIN/4, FIXED_POINT_MAX/4);
                printf("Dividing %.4f / %.4f\n", dividend, divisor);
                printf("Expected: %.4f\n", dividend / divisor);

                assign_dividend_and_divisor(dut, dividend, divisor);
                dut->start = 1;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    dut->final();
    delete dut;
    exit(EXIT_SUCCESS);
}
