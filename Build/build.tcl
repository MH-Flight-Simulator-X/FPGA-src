set design_name "MH-FPGA"
set board_name "MH-Flight-Simulator-X-PCB"
set fpga_part "xc7a100t-1ftg256i"

set lib_dir [file normalize "./../lib"]
set origin_dir [file normalize "./../"]

# Read design sources
read_verilog -sv "${lib_dir}/"
read_verilog -sv "${origin_dir}/src/"

# Read constraints
read_xdc "${origin_dir}/Constraints/${board_name}.xdc"

# Synthesis
synth_design -top "top_${design_name}" -part ${fpga_part}

# Place and route
opt_design
place_design
route_design

# Write bitstream
write_bitstream -froce "${origin_dir}/Build/${design_name.bit}"
