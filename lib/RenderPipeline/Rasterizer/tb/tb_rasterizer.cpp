#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vrasterizer.h"


#define MAX_SIM_TIME 32*16
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vrasterizer* dut = new Vrasterizer;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    int x0 = 3;
    int y0 = 4;
    int x1 = 21;
    int y1 = 8;
    int x2 = 17;
    int y2 = 14;

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1; 
        dut->eval();

        dut->x0 = x0;
        dut->y0 = y0;
        dut->x1 = x1;
        dut->y1 = y1;
        dut->x2 = x2;
        dut->y2 = y2;

        if (dut->clk == 1) {
            posedge_cnt++;
            if (posedge_cnt < 4) {
                dut->rst = 1;
            }
            else {
                dut->rst = 0;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    exit(EXIT_SUCCESS);
}

