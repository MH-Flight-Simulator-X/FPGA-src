#include <deque>
#include <stdlib.h>
#include <iostream>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vframebuffer.h"

#define MAX_SIM_TIME 40
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;


class FrameBufferInTx {
public:
    uint32_t addr_write;
    uint32_t addr_read;
    uint32_t data_in;
    bool write_enable;
    bool rst;
};


class FrameBufferOutTx {
public:
    uint32_t data_out;
};


class FrameBufferScb {
private:
    std::deque<FrameBufferInTx*> in_q;
    vluint64_t* sim_time;

public:
    FrameBufferScb(vluint64_t* sim_time) {
        this->sim_time = sim_time;
    }

    void writeIn(FrameBufferInTx* in_tx) {
        in_q.push_back(in_tx);
    }

    void writeOut(FrameBufferOutTx* out_tx) {
        if (in_q.empty()) {
            std::cerr << "Empty transaction queue!" << std::endl;
            exit(1);
        }

        FrameBufferInTx* in_tx = in_q.front();
        in_q.pop_front();

        if (in_tx->rst) {
            if (out_tx->data_out != 0) {
                std::cerr << "Reset signal not working!" << std::endl;
            }
        }
        else if (in_tx->data_in != out_tx->data_out) {
            if (in_q.empty()) {
                std::cerr << "Empty transaction queue!" << std::endl;
                exit(1);
            }
            // Framebuffer might have been reset between writing and reading data
            if (in_q.front()->rst == 1) {
                if (out_tx->data_out != 0) {
                    std::cerr << "Reset signal not working!" << std::endl;
                }
            }
            else {
                std::cerr << "Data mismatch at sim_time: " << *sim_time << std::endl;
                std::cerr << "Expected: " << in_tx->data_in << ", but got: " << out_tx->data_out << std::endl;
                std::cerr << "addr_write: " << in_tx->addr_write << std::endl;
                std::cerr << "addr_read: " << in_tx->addr_read << std::endl;
                std::cerr << "data_in: " << in_tx->data_in << std::endl;
                std::cerr << "rst: " << in_tx->rst << std::endl;
            }
        }

        delete in_tx;
        delete out_tx;
    }
};


class FrameBufferInDrv {
private:
    Vframebuffer* dut;

public:
    FrameBufferInDrv(Vframebuffer* dut) {
        this->dut = dut;
    }

    void drive(FrameBufferInTx* tx) {
        dut->addr_write = tx->addr_write;
        dut->addr_read = tx->addr_read;
        dut->data_in = tx->data_in;
        dut->write_enable = tx->write_enable;
        dut->rst = tx->rst;
    }
};


class FrameBufferInMon {
private:
    Vframebuffer* dut;
    FrameBufferScb* scb;

public:
    FrameBufferInMon(Vframebuffer* dut, FrameBufferScb* scb) {
        this->dut = dut;
        this->scb = scb;
    }

    void monitor() {
        if (dut->write_enable == 1) {
            FrameBufferInTx* tx = new FrameBufferInTx();
            tx->addr_write = dut->addr_write;
            tx->addr_read = dut->addr_read;
            tx->data_in = dut->data_in;
            tx->write_enable = dut->write_enable;
            tx->rst = dut->rst;
            scb->writeIn(tx);
        }
    }
};


class FrameBufferOutMon {
private:
    Vframebuffer* dut;
    FrameBufferScb* scb;

public:
    FrameBufferOutMon(Vframebuffer* dut, FrameBufferScb* scb) {
        this->dut = dut;
        this->scb = scb;
    }

    void monitor() {
        FrameBufferOutTx* tx = new FrameBufferOutTx();
        tx->data_out = dut->data_out;
        scb->writeOut(tx);
    }
};


FrameBufferInTx* randomFrameBufferInTx(Vframebuffer* dut, vluint64_t& sim_time) {
    FrameBufferInTx* tx = new FrameBufferInTx();
    tx->addr_read = dut->addr_write;
    tx->addr_write = rand() % 1024;
    tx->data_in = rand() % 8;
    tx->write_enable = true;
    tx->rst = rand() % 10 == 0;
    return tx;
}


int main(int argc, char** argv) {
    srand(time(NULL));
    Verilated::commandArgs(argc, argv);

    Vframebuffer* dut = new Vframebuffer;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    FrameBufferInDrv* drv = new FrameBufferInDrv(dut);
    FrameBufferScb* scb = new FrameBufferScb(&sim_time);
    FrameBufferInMon* inMon = new FrameBufferInMon(dut, scb);
    FrameBufferOutMon* outMon = new FrameBufferOutMon(dut, scb);

     

    while (sim_time < MAX_SIM_TIME) {
        dut->clk_write ^= 1;
        dut->clk_read ^= 1;
        dut->eval();

        if (dut->clk_write == 1) {
            FrameBufferInTx* tx = randomFrameBufferInTx(dut, sim_time);
            drv->drive(tx);
            inMon->monitor();
            if (sim_time >= 4) { // It takes two cycles before data written should be available
                outMon->monitor();
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();

    delete dut;
    delete drv;
    delete inMon;
    delete outMon;
    delete scb;

    exit(EXIT_SUCCESS);
}
