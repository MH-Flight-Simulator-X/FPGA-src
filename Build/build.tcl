set design_name "spi_test"
set board_name "Basys3"
set fpga_part "xc7a35tcpg236-1" 
# xc7a35ticsg324-1L for Arty-A7

set lib_dir [file normalize "./../lib"]
set src_dir [file normalize "./../src"]
set origin_dir [file normalize "./../"]

# Create log directory
file mkdir logs

# Read lib files
# read_verilog -sv "${lib_dir}/Memory/BRAM_DP/src/bram_dp.sv"
# read_verilog -sv "${lib_dir}/Memory/CLUT/src/clut.sv"
# read_verilog -sv "${lib_dir}/Memory/Framebuffer/src/framebuffer.sv"
# read_verilog -sv "${lib_dir}/Clock/clock_480p.sv"
# read_verilog -sv "${lib_dir}/Display/projectf_display_480p.sv"
read_verilog -sv "${lib_dir}/Utils/hex_display.sv"
read_verilog -sv "${lib_dir}/SPI/src/spi_slave.sv"

# Read src files
read_verilog -sv "${src_dir}/spi_test.sv"

# Read constraints
read_xdc "${origin_dir}/Constraints/${board_name}.xdc"

# Synthesis
synth_design -top "${design_name}" -part ${fpga_part}

# Optimize design
opt_design

# Place design
place_design

# Route design
route_design

# Write bitstream
write_bitstream -force "${origin_dir}/Build/output/${design_name}.bit"
