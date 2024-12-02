#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vmodel_reader.h"

#define MAX_SIM_TIME 1024

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
        
    dut->index_read_en = 0;
    dut->vertex_read_en = 0;
    dut->model_index = 0;

    vluint64_t posedge_cnt = 0;

    while (sim_time < MAX_SIM_TIME) { 
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk) {
            posedge_cnt++;
            dut->reset = 0;

            if (posedge_cnt == 4) {
                dut->reset = 1;
                dut->vertex_read_en = 0;
            }

            static int vertex_read = 0;
            static int vertex_valid_last = 0;
            if (vertex_valid_last && dut->vertex_read_en) {
                dut->vertex_read_en = 0;
                vertex_read++;
            } else if (vertex_read < 8 && (posedge_cnt % 8) == 0) {
                dut->vertex_read_en = 1;
            }

            static int index_read = 0;
            static int index_valid_last = 0;
            if (vertex_read == 8) {
                if (index_valid_last && dut->index_read_en) {
                    dut->index_read_en = 0;
                    index_read++;
                } else if (index_read < 12 && (posedge_cnt % 8) == 0) {
                    dut->index_read_en = 1;
                }
            }

            static int wait_clks = 0;
            if (vertex_read == 12) {
                wait_clks++;
                if (wait_clks >= 24)
                    break;
            }

            vertex_valid_last = dut->vertex_o_dv;
            index_valid_last = dut->index_o_dv;
        }

        dut->eval(); 

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    delete dut;

    exit(EXIT_SUCCESS);
}

