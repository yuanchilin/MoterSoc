# Program RISC-V SoC to DaVinci FPGA
# Usage: vivado.bat -mode batch -source program.tcl

# Open hardware manager (required for batch mode)
open_hw_manager

# Connect to hardware server
connect_hw_server -url localhost:3121

# Open hardware target (adjust based on your JTAG programmer)
current_hw_target [get_hw_targets */xilinx_tcf/*]
open_hw_target

# Select the FPGA device (relative to Vivado project directory)
set_property PROGRAM.FILE {riscv_davinci/riscv_davinci.runs/impl_1/top.bit} [current_hw_device]

# Program the device
program_hw_devices [current_hw_device]

# Refresh device to confirm programming
refresh_hw_device [current_hw_device]

# Close connection
close_hw_target
disconnect_hw_server

puts "Programming completed successfully!"