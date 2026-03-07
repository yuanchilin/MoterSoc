# Create Vivado Project for RISC-V SoC on DaVinci FPGA
# Run this script in Vivado tcl console

create_project riscv_davinci ./riscv_davinci -part xc7a35tfgg484-2

# Add source files
add_files -fileset sources_1 {
    rtl/cpu/riscv_core.v
    rtl/peripheral/gpio.v
    rtl/peripheral/pwm.v
    rtl/peripheral/uart.v
    rtl/soc/riscv_soc.v
    rtl/soc/inst_rom.v
    rtl/top.v
}

# Add constraints
add_files -fileset constrs_1 {
    constraints/daVinci.xdc
}

# Set top module
set_property top top [current_fileset]

# Run synthesis and implementation
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
