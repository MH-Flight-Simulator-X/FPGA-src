## EMPTY FOR NOW 
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

set_property -dict {PACKAGE_PIN N11 IOSTANDARD LVCMOS33} [get_ports {clk}];
create_clock -name clk -period 50.00 [get_ports {clk}];

set_property -dict { PACKAGE_PIN H13 IOSTANDARD LVCMOS33 } [get_ports { led }];
