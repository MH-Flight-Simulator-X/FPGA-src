set design_name "top_MH_FPGA"
set board_name "MH-FPGA"

# MH FPGA
set fpga_part "xc7a100tftg256-1"

set lib_dir [file normalize "./../lib"]
set src_dir [file normalize "./../src"]
set origin_dir [file normalize "./../"]

# Create log directory
file mkdir logs

# Read lib files
# read_verilog -sv "${lib_dir}/Memory/BRAM_DP/src/bram_dp.sv"
# read_verilog -sv "${lib_dir}/Memory/CLUT/src/clut.sv"
# read_verilog -sv "${lib_dir}/Memory/Framebuffer/src/framebuffer.sv"
read_verilog -sv "${lib_dir}/Clock/clock_480p.sv"
read_verilog -sv "${lib_dir}/Clock/clock_100Mhz.sv"
read_verilog -sv "${lib_dir}/Display/projectf_display_480p.sv"
# read_verilog -sv "${lib_dir}/RenderPipeline/Rasterizer/BoundingBox/src/bounding_box.sv"
# read_verilog -sv "${lib_dir}/RenderPipeline/Rasterizer/src/rasterizer.sv"

# Read src files
add_files "${src_dir}/image.mem"
add_files "${src_dir}/palette.mem"
add_files "${src_dir}/reciprocal.mem"
read_verilog -sv "${src_dir}/${design_name}.sv"

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

# Generate Timing Reports

# 1. Generate Timing Summary Report
report_timing_summary -file logs/timing_summary.txt

# 2. Generate Detailed Timing Report (Top 10 Critical Paths)
report_timing -delay_type max -sort_by slack -max_paths 10 -file logs/detailed_timing_report.txt

# Write bitstream
write_bitstream -force "${origin_dir}/Build/output/${design_name}.bit"
