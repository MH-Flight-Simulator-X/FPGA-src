#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vfixed_point_divide.h"

#define FIXED_POINT_WIDTH 18
#define FIXED_POINT_FRAC_WIDTH 12

#define RESET_CLKS 8

void print_vector4(float v[4]);
void print_vector3(float v[3]);

#define MAX_SIM_TIME 120
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void assign_dividend_and_divisor(Vfixed_point_divide* dut, float dividend, float divisor) {
    dut->a = FixedPoint<int32_t>::fromFloat(dividend, FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
    dut->b = FixedPoint<int32_t>::fromFloat(divisor, FIXED_POINT_FRAC_WIDTH, FIXED_POINT_WIDTH).get();
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
    
}

void print_vector4(float v[4]) {
    printf("[%.4f, %.4f, %.4f, %.4f]\n", v[0], v[1], v[2], v[3]);
}

void print_vector3(float v[3]) {
    printf("[%.4f, %.4f, %.4f]\n", v[0], v[1], v[2]);
}
