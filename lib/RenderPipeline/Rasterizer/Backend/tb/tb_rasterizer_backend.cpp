#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vrasterizer_backend.h"


#define MAX_SIM_TIME 32*16
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vrasterizer_backend* dut = new Vrasterizer_backend;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1; 
        dut->eval();

        dut->bb_tl[0] = 4;
        dut->bb_tl[1] = 4;
        dut->bb_br[0] = 9;
        dut->bb_br[1] = 7;

        if (dut->clk == 1) {
            posedge_cnt++;
            if (posedge_cnt < 4) {
                dut->rstn = 0;
            }
            else {
                dut->rstn = 1;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    exit(EXIT_SUCCESS);
}


