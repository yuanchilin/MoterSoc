# DaVinci FPGA XDC Constraints
# ALIENTEK DaVinci Artix-7 FPGA Development Board

# System Clock - 50MHz
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports sys_clk]

# System Reset
set_property -dict {PACKAGE_PIN U2 IOSTANDARD LVCMOS33} [get_ports sys_rst_n]

# Keys (4 push buttons)
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports {key[0]}]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD LVCMOS33} [get_ports {key[1]}]
set_property -dict {PACKAGE_PIN W2 IOSTANDARD LVCMOS33} [get_ports {key[2]}]
set_property -dict {PACKAGE_PIN T3 IOSTANDARD LVCMOS33} [get_ports {key[3]}]

# LEDs (4 LEDs)
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN R3 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN V2 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN Y2 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# PWM Output (Buzzer)
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports pwm_out]

# UART
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS33} [get_ports uart_txd]

# Configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
