set design_name "MH_FPGA"
set board_name "Arty-A7"
set fpga_part "xc7a35ticsg324-1L"

set lib_dir [file normalize "./../lib"]
set origin_dir [file normalize "./../"]

# Create log directory
file mkdir logs

# Read design sources
read_verilog -sv "${lib_dir}/RenderPipeline/Math/MatMatMul/src/mat_mat_mul_dim_4.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/Math/MatVecMul/src/mat_vec_mul_dim_4.sv"
read_verilog -sv "${origin_dir}/src/top_${design_name}.sv"

# Read constraints
read_xdc "${origin_dir}/Constraints/${board_name}.xdc"

# Synthesis
synth_design -top "top_${design_name}" -part ${fpga_part}

# Place and route
opt_design
place_design
route_design

# Write bitstream
write_bitstream -force "${origin_dir}/Build/output/${design_name.bit}"
