#include <cstdlib>
#include <iterator>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "obj_dir/Vsync_fifo.h"

#define RESET_CLKS 8
#define MAX_SIM_TIME 120
vluint64_t sim_time = 0;
vluint64_t posedge_cnt_write = 0;
vluint64_t posedge_cnt_read = 0;

void write_data(Vsync_fifo* dut, vluint32_t data) {
    dut->data_in = data;
    dut->write_en = 1;
}

void write_random_data(Vsync_fifo* dut) {
    constexpr int max_write = 1024;
    constexpr int min_write = 1;

    vluint32_t data = (vluint32_t)((float)rand() / RAND_MAX * (max_write - min_write) + min_write);
    write_data(dut, data);
    printf("Wrote data: %d (%ld / %ld)\n", data, posedge_cnt_write, sim_time);
}

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv);
    Vsync_fifo* dut = new Vsync_fifo;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    printf("==== STARTING SIMULATION ====\n");
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->write_clk ^= 1;

        // Iterate read clock at half clockrate
        if (sim_time % 2) {
            dut->read_clk ^= 1;
        }
        dut->eval();

        dut->rstn = 0;

        dut->read_en = 0;
        dut->write_en = 0;
        dut->data_in = 0;
        dut->data_out = 0;

        m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rstn = 1;

    while (sim_time < MAX_SIM_TIME) {
        dut->write_clk ^= 1;

        // Iterate read clock at half clockrate
        if (sim_time % 2) {
            dut->read_clk ^= 1;
        }
        dut->eval();

        if (dut->write_clk) {
            posedge_cnt_write++;
            dut->write_en = 0;

            static vluint32_t data = 10;
            if (posedge_cnt_write >= 4 && !dut->full) {
                write_random_data(dut);
            }
        }
        
        static int read_clk_last = 0;
        if (dut->read_clk == 1 && read_clk_last == 0) {
            posedge_cnt_read++;

            if (!dut->empty) {
                dut->read_en = 1;
            } else {
                dut->read_en = 0;
            }

            if (dut->read_prev) {
                printf("Read data: %d (%ld / %ld)\n", dut->data_out, posedge_cnt_read, sim_time);
            }
        }
        read_clk_last = dut->read_clk;

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
