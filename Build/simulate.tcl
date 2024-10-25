set fpga_part "xc7a35ticsg324-1L"

set lib_dir [file normalize "./../lib"]
set src_dir [file normalize "./../src"]
set origin_dir [file normalize "./../"]

# Create log directory
file mkdir logs
file mkdir sim_files

# Create a new project with the specified FPGA part
create_project -force my_project ./my_project -part $fpga_part

# Add SystemVerilog source files from specified directories
add_files "${lib_dir}/Memory/BRAM_QP/src/bram_qp.sv"
add_files "${src_dir}/tests/bram_qp/tb_bram_qp.sv"

# Use the existing simulation set 'sim_1'
# Add files to the simulation set
add_files -fileset sim_1 "${lib_dir}/Memory/BRAM_QP/src/bram_qp.sv"
add_files -fileset sim_1 "${src_dir}/tests/bram_qp/tb_bram_qp.sv"

# Set the top module of the testbench for simulation
set_property top tb_bram_qp [get_fileset sim_1]

# Set the file type to SystemVerilog
set_property file_type {SystemVerilog} [get_files "${lib_dir}/Memory/BRAM_QP/src/bram_qp.sv"]
set_property file_type {SystemVerilog} [get_files "${src_dir}/tests/bram_qp/tb_bram_qp.sv"]

# Launch simulation (use xsim as the simulator)
launch_simulation

# Run the simulation for a specific time, e.g., 1 microsecond
run 10us

# Exit Vivado after simulation is complete
quit

