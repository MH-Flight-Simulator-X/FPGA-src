#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vbram_sp.h"

#define WIDTH 36
#define DEPTH 1024

#define RESET_CLKS 8

#define MAX_SIM_TIME 240
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

void read_data(Vbram_sp* dut) {
}

void write_data(Vbram_sp* dut) {
}

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv);
    Vbram_sp* dut = new Vbram_sp;
    
    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
    
    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();
    
        if (dut->clk == 1) {
            posedge_cnt++;
        }
    
        m_trace->dump(sim_time);
        sim_time++;
    }
    
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

