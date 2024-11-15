# set_property -dict {PACKAGE_PIN __PIN_ID__ IOSTANDARD LVCMOS33} [get_ports {__PIN_NAME__}];

## EMPTY FOR NOW 
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

set_property -dict {PACKAGE_PIN N11 IOSTANDARD LVCMOS33} [get_ports {clk}];
create_clock -name clk -period 50.00 [get_ports {clk}];

set_property -dict { PACKAGE_PIN H13 IOSTANDARD LVCMOS33 } [get_ports { led }];

## VGA pins
#set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {vga_hsync}];
#set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {vga_vsync}];
#set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {vga_r[0]}];
#set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports {vga_r[1]}];
#set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS33} [get_ports {vga_r[2]}];
#et_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS33} [get_ports {vga_r[3]}];
#set_property -dict {PACKAGE_PIN P8 IOSTANDARD LVCMOS33} [get_ports {vga_g[0]}];
#set_property -dict {PACKAGE_PIN R8 IOSTANDARD LVCMOS33} [get_ports {vga_g[1]}];
#set_property -dict {PACKAGE_PIN T7 IOSTANDARD LVCMOS33} [get_ports {vga_g[2]}];
#set_property -dict {PACKAGE_PIN T8 IOSTANDARD LVCMOS33} [get_ports {vga_g[3]}];
#set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {vga_b[0]}];
#set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports {vga_b[1]}];
#set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS33} [get_ports {vga_b[2]}];
#set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports {vga_b[3]}];

## SPI
set_property -dict {PACKAGE_PIN N12 IOSTANDARD LVCMOS33} [get_ports {SCK}];
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {MISO}];
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports {MOSI}];
set_property -dict {PACKAGE_PIN R11 IOSTANDARD LVCMOS33} [get_ports {CSn}];
