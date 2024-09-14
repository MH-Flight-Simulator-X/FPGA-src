#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vmat_vec_mul_dim_4.h"
#include "obj_dir/Vmat_vec_mul_dim_4___024unit.h"

#define MAX_SIM_TIME 40
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmat_vec_mul_dim_4* dut = new Vmat_vec_mul_dim_4;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
