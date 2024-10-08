#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vbounding_box.h"


void test_case(Vbounding_box* dut, int x0, int y0, int x1, int y1, int x2, int y2) {
    dut->x0 = x0;
    dut->y0 = y0;
    dut->x1 = x1;
    dut->y1 = y1;
    dut->x2 = x2;
    dut->y2 = y2;

    dut->eval();

    std::cout << "Test case: (" << x0 << ", " << y0 << "), (" << x1 << ", " << y1 << "), (" << x2 << ", " << y2 << ")\n";
    std::cout << "  min_x: " << dut->min_x << " max_x: " << dut->max_x << " min_y: " << dut->min_y << " max_y: " << dut->max_y << "\n";
    std::cout << "  valid: " << int(dut->valid) << "\n\n";
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vbounding_box* dut = new Vbounding_box;

    test_case(dut, 1, 1, 10, 10, 5, 5);
    test_case(dut, -5, -5, 10, 10, 20, 20);
    test_case(dut, 35, 5, 40, 10, 30, 8);
    test_case(dut, -35, -5, -40, -10, -30, -8);
    test_case(dut, 0, 0, 0, 0, 0, 0);

    delete dut;
    return 0;
}
