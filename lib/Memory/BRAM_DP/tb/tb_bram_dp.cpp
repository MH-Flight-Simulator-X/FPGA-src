#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vbram_dp.h"

#define MAX_SIM_TIME 32
#define DATA_WIDTH 4
#define DEPTH 16

vluint64_t sim_time = 0;
vluint64_t posedge_cnt_write = 0;


int main(int argc, char** argv) {
    srand(time(NULL));
    Verilated::commandArgs(argc, argv);

    Vbram_dp* dut = new Vbram_dp;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    dut->write_enable = 1;
    dut->addr_write = 1;
    dut->addr_read = 0;

    while (sim_time < MAX_SIM_TIME) {
        dut->clk_write ^= 1;
        dut->clk_read ^= 1;
        dut->eval();

        if (dut->clk_write == 1) {
            dut->addr_write++;
            dut->addr_read++;
            dut->data_in = rand() % (1 << DATA_WIDTH);
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    delete dut;

    exit(EXIT_SUCCESS);
}
