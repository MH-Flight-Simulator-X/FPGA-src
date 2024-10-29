set design_name "mh_fpga_test"
set board_name "MH-FPGA"

# MH FPGA
set fpga_part "xc7a100tftg256-2"

set lib_dir [file normalize "./../lib"]
set src_dir [file normalize "./../src"]
set origin_dir [file normalize "./../"]

# Create log directory
file mkdir logs

read_verilog -sv "${src_dir}/tests/MH-FPGA-TEST/mh_fpga_test.sv"

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
set_property BITSTREAM.Config.SPI_buswidth 4 [current_design]

write_bitstream -force "${origin_dir}/Build/output/${design_name}.bit"

write_cfgmem -format bin -force \
  -size 16 \
  -interface spix4 \
  -loadbit "up 0x0 ${origin_dir}/Build/output/${design_name}.bit" \
  -file "${origin_dir}/Build/output/${design_name}.bin"
