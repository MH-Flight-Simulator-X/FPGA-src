#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vmodel_reader.h"

#define MAX_SIM_TIME 100

vluint64_t sim_time = 0;
vluint64_t posedge_cnt_write = 0;

int main(int argc, char** argv) {
    srand(time(NULL));
    Verilated::commandArgs(argc, argv);

    Vmodel_reader* dut = new Vmodel_reader;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
        
    dut->index_read_en = 1;
    dut->vertex_read_en = 1;
    dut->model_index = 1;

    while (sim_time < MAX_SIM_TIME) { 
        dut->clk ^= 1;
        dut->eval(); 

        if (sim_time < 4) {
            dut->rstn = 0;
        }
        else if (43 <= sim_time && sim_time <= 45) {
            dut->rstn = 0;
            dut->model_index = 0;
        }
        else {
            dut->rstn = 1;
        }

        if (17 < sim_time && sim_time < 22) {
            dut->vertex_read_en = 0;
            dut->index_read_en = 0;
        }
        else {
            dut->vertex_read_en = 1;
            dut->index_read_en = 1;
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    delete dut;

    exit(EXIT_SUCCESS);
}

