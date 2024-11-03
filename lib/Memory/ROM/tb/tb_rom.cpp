#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vrom.h"


#define MAX_SIM_TIME 32
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vrom* dut = new Vrom;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    dut->addr = 0;

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1; 
        dut->eval();

        if (dut->clk == 1 && sim_time > 1) {
            dut->addr += 1; 
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    exit(EXIT_SUCCESS);
}

