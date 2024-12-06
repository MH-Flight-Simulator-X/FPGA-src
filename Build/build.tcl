set design_name "top_MH_FPGA"
set board_name "MH-FPGA"

# MH FPGA
set fpga_part "xc7a100tftg256-1"

# Arty A7 100T FPGA
# set fpga_part "xc7a100tcsg324-1"

set lib_dir [file normalize "./../lib"]
set src_dir [file normalize "./../src"]
set origin_dir [file normalize "./../"]

# Create log directory
file mkdir logs

# Read lib files
read_verilog -sv "${lib_dir}/Clock/clock_480p.sv"
read_verilog -sv "${lib_dir}/Clock/clock_100Mhz.sv"

read_verilog -sv "${lib_dir}/Math/MatVecMul/src/mat_vec_mul_new.sv"
read_verilog -sv "${lib_dir}/Math/MatMul/src/mat_mul.sv"
read_verilog -sv "${lib_dir}/Math/FastInverse/src/fast_inverse.sv"
read_verilog -sv "${lib_dir}/Math/FixedPointDivide/src/fixed_point_divide.sv"
read_verilog -sv "${lib_dir}/Math/TrigLUT/src/sin_cos_lu.sv"
read_verilog -sv "${lib_dir}/Math/RotMat/src/rot_y.sv"
read_verilog -sv "${lib_dir}/Memory/BRAM_SP/src/bram_sp.sv"
read_verilog -sv "${lib_dir}/Memory/BRAM_DP/src/bram_dp.sv"
read_verilog -sv "${lib_dir}/Memory/Buffer/src/buffer.sv"
read_verilog -sv "${lib_dir}/Memory/G-Buffer/src/g_buffer.sv"
read_verilog -sv "${lib_dir}/Memory/ROM/src/rom.sv"
read_verilog -sv "${lib_dir}/Memory/ModelReader/src/model_reader.sv"
read_verilog -sv "${lib_dir}/Display/DisplaySignals/projectf_display_480p.sv"
read_verilog -sv "${lib_dir}/Display/display_new.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/VertexShader/src/vertex_shader_new.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/VertexPostProcessor/src/vertex_post_processor.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/PrimitiveAssembler/src/primitive_assembler.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/TransformPipeline/src/transform_pipeline.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/Rasterizer/BoundingBox/src/bounding_box.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/Rasterizer/Frontend/src/rasterizer_frontend.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/Rasterizer/Backend/src/rasterizer_backend.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/Rasterizer/src/rasterizer.sv"
read_verilog -sv "${lib_dir}/RenderPipeline/src/render_pipeline.sv"

# Read src files
add_files "${src_dir}/image.mem"
add_files "${src_dir}/palette.mem"
add_files "${src_dir}/reciprocal.mem"
add_files "${src_dir}/sine_lut.mem"
add_files "${src_dir}/cosine_lut.mem"
add_files "${src_dir}/model_headers.mem"
add_files "${src_dir}/model_vertex.mem"
add_files "${src_dir}/model_faces.mem"
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

set_property BITSTREAM.Config.SPI_buswidth 4 [current_design]

# Write bitstream
write_bitstream -force "${origin_dir}/Build/output/${design_name}.bit"

write_cfgmem -format bin -force \
  -size 16 \
  -interface spix4 \
  -loadbit "up 0x0 ${origin_dir}/Build/output/${design_name}.bit" \
  -file "${origin_dir}/Build/output/${design_name}.bin"
