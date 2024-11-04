#include <verilated.h>
#include <verilated_vcd_c.h>
#include "../../../../verilator_utils/fixed_point.h"

#include "obj_dir/Vfast_inverse.h"

#define DATAWIDTH 24 

#define RESET_CLKS 8
#define MAX_SIM_TIME 1152921504606846976
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vfast_inverse* dut = new Vfast_inverse;

    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    // Reset
    for (int i = 0; i < RESET_CLKS; i++) {
        dut->clk ^= 1;
        dut->eval();

        dut->rstn = 0;
        dut->A = 0;
        dut->A_dv = 0;

        m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rstn = 1;

    int32_t max_num_iterations = 320*320;
    std::vector<float> deltas;

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            dut->A_dv = 0;

            static int i = 0;
            static int32_t test_val = 1;

            if (dut->A_inv_dv) {
                float A_inv = FixedPoint<uint32_t>(dut->A_inv, DATAWIDTH, DATAWIDTH, false).toFloat(); 

                float delta = fabs(A_inv - (1.0f / test_val));
                deltas.push_back(delta);
                test_val++;
                i++;
                
                if (i >= max_num_iterations) {
                    printf("Finished! (%ld)\n", posedge_cnt);
                    break;
                }
            }

            if (posedge_cnt >= 2 && dut->ready) {
                dut->A = test_val;
                dut->A_dv = 1;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    float mean_delta = 0;
    for (int i = 0; i < max_num_iterations - 1; i++) {
        mean_delta += deltas[i];
    }
    mean_delta /= max_num_iterations - 1;
    printf("Mean delta: %f\n", mean_delta);
    
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
