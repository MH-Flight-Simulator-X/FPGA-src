set design_name "top_MH_FPGA"
# set design_name "design_1_wrapper"

open_hw_manager
connect_hw_server
current_hw_target
open_hw_target
set_property PROGRAM.FILE "./output/${design_name}.bit" [current_hw_device]
program_hw_devices [current_hw_device]
