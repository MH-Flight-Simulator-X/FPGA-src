#include <deque>
#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vframebuffer.h"

#define MAX_SIM_TIME 300
#define FB_WIDTH 8
#define FB_HEIGHT 4
#define DATA_WIDTH 4
#define FB_SIZE FB_WIDTH*FB_HEIGHT

vluint64_t sim_time = 0;
vluint64_t posedge_cnt_write = 0;


int main(int argc, char** argv) {
    srand(time(NULL));
    Verilated::commandArgs(argc, argv);

    Vframebuffer* dut = new Vframebuffer;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    dut->addr_read = 0;
    dut->clear_value = rand() % (1 << DATA_WIDTH);

    while (sim_time < MAX_SIM_TIME) {
        dut->clk_write ^= 1;
        dut->clk_read ^= 1;
        dut->eval();


        if (dut->clk_write == 1) {
            posedge_cnt_write++;

            dut->clear = 1;
            if (posedge_cnt_write > 1) {
                dut->clear = 0;
            }

            dut->addr_read += 1; 

            if (posedge_cnt_write >= FB_SIZE*2 - 1) {
                dut->addr_write = (dut->addr_read + 1);
                if (dut->addr_write >= FB_SIZE) {
                    dut->addr_write -= FB_SIZE;
                } 
                dut->data_in = rand() % (1 << DATA_WIDTH);
                dut->write_enable = 1; 
            }
            
            if (dut->addr_read == FB_SIZE) {
                dut->addr_read = 0;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    delete dut;

    exit(EXIT_SUCCESS);
}
