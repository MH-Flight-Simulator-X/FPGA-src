#include <cstdlib>
#include <iterator>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "obj_dir/Vg_buffer.h"

#define DATAWIDTH 36
#define DEPTH 36

#define RESET_CLKS 8
#define MAX_SIM_TIME 512
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

typedef struct {
    vluint64_t vert0;
    vluint64_t vert1;
    vluint64_t vert2;
} Triangle_t;

void write_data(Vg_buffer* dut, vluint64_t addr, vluint64_t data) {
    dut->addr_write = addr;
    dut->data_write = data;
    dut->en = 1;
    dut->rw = 1;
}

void write_random_data(Vg_buffer* dut, unsigned long long addr) {
    unsigned long long max_write = ((long long)1 << 36) - 1;
    unsigned long long min_write = 1;

    unsigned long long data = (unsigned long long)((float)rand() / RAND_MAX * (max_write - min_write) + min_write);
    write_data(dut, addr, data);
    printf("-- Wrote data: %lld -> 0x%llx\n", addr, data);
}

int main(int argc, char** argv) {
    srand(time(NULL));

    Verilated::commandArgs(argc, argv);
    Vg_buffer* dut = new Vg_buffer;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    printf("==== STARTING SIMULATION ====\n");
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;

        dut->en = 0;
        dut->rw = 0;
        dut->data_write = 0;
        dut->addr_write = 0;
        dut->addr_read_port0 = 0;
        dut->addr_read_port1 = 0;
        dut->addr_read_port2 = 0;

        m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rstn = 1;

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk) {
            posedge_cnt++;
            dut->en = 0;
            dut->rw = 0;
            dut->data_write = 0;
            dut->addr_write = 0;
            dut->addr_read_port0 = 0;
            dut->addr_read_port1 = 0;
            dut->addr_read_port2 = 0;

            static unsigned long addr_write = 0;
            static unsigned long write_finished = 0;

            static unsigned long addr_read_port0 = (unsigned long)((float)rand() / RAND_MAX * (DEPTH - 1));
            static unsigned long addr_read_port1 = (unsigned long)((float)rand() / RAND_MAX * (DEPTH - 1));
            static unsigned long addr_read_port2 = (unsigned long)((float)rand() / RAND_MAX * (DEPTH - 1));

            if (addr_write < DEPTH & posedge_cnt >= 4) {
                write_random_data(dut, addr_write++);
            } else if (addr_write == DEPTH) {
                write_finished = 1;
            }

            if (write_finished) {
                static int num_reads = 0;

                if (dut->dv) {
                    printf("%4ld: (%2ld, %2ld, %2ld) -> (0x%05lx, 0x%05lx, 0x%05lx)\n", 
                                                                posedge_cnt,
                                                                addr_read_port0, 
                                                                addr_read_port1, 
                                                                addr_read_port2, 
                                                                dut->data_read_port0, 
                                                                dut->data_read_port1, 
                                                                dut->data_read_port2);

                    // Assign random addresses to read
                    addr_read_port0 = (unsigned long)((float)rand() / RAND_MAX * (DEPTH - 1));
                    addr_read_port1 = (unsigned long)((float)rand() / RAND_MAX * (DEPTH - 1));
                    addr_read_port2 = (unsigned long)((float)rand() / RAND_MAX * (DEPTH - 1));

                    num_reads++;
                    if (num_reads == 12) {
                        break;
                    }
                } else {
                    dut->en = 1;
                    dut->rw = 0;
                    dut->addr_read_port0 = addr_read_port0;
                    dut->addr_read_port1 = addr_read_port1;
                    dut->addr_read_port2 = addr_read_port2;
                }
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

