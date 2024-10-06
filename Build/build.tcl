set design_name "MH_FPGA"
set board_name "Arty-A7"
set fpga_part "xc7a35ticsg324-1L"

set lib_dir [file normalize "./../lib"]
set origin_dir [file normalize "./../"]

# Create log directory
file mkdir logs

# Read lib files
read_verilog -sv "${lib_dir}/Memory/BRAM_DP/src/bram_dp.sv"
read_verilog -sv "${lib_dir}/Memory/CLUT/src/clut.sv"
read_verilog -sv "${lib_dir}/Memory/Framebuffer/src/framebuffer.sv"
read_verilog -sv "${lib_dir}/Clock/clock_480p.sv"
read_verilog -sv "${lib_dir}/Display/projectf_display_480p.sv"

# Read src files
add_files "${origin_dir}/src/image.mem"
add_files "${origin_dir}/src/palette.mem"
read_verilog -sv "${origin_dir}/src/top_${design_name}.sv"

# Read constraints
read_xdc "${origin_dir}/Constraints/${board_name}.xdc"

# Synthesis
synth_design -top "top_${design_name}" -part ${fpga_part}

# Optimize design
opt_design

# Place design
place_design

# Route design
route_design

# Write bitstream
write_bitstream -force "${origin_dir}/Build/${design_name}.bit"
