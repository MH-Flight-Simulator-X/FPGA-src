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

    int x0 = 12;
    int y0 = 4;
    int z0 = 3277;
    int x1 = 20;
    int y1 = 30;
    int z1 = 6554;
    int x2 = 40;
    int y2 = 20;
    int z2 = 16384;

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1; 
        dut->eval();

        dut->vertex[0][0] = x0;
        dut->vertex[0][1] = y0;
        dut->vertex[0][2] = z0;
        dut->vertex[1][0] = x1;
        dut->vertex[1][1] = y1;
        dut->vertex[1][2] = z1;
        dut->vertex[2][0] = x2;
        dut->vertex[2][1] = y2;
        dut->vertex[2][2] = z2;

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


