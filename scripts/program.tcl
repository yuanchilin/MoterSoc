# Program RISC-V SoC to DaVinci FPGA
# Usage: vivado -mode batch -source scripts/program.tcl

# 计算项目根目录（基于脚本自身位置）
set script_dir [file dirname [info script]]
set project_root [file normalize [file join $script_dir ..]]
set build_dir [file join $project_root build]

# 切换到 build 目录，避免 vivado.jou/log 等中间文件落在项目根目录
cd $build_dir

# Open hardware manager (required for batch mode)
open_hw_manager

# Connect to hardware server
connect_hw_server -url localhost:3121

# Open hardware target (adjust based on your JTAG programmer)
current_hw_target [get_hw_targets */xilinx_tcf/*]
open_hw_target

# Select the FPGA device
set_property PROGRAM.FILE [file join $build_dir riscv_davinci riscv_davinci.runs impl_1 top.bit] [current_hw_device]

# Program the device
program_hw_devices [current_hw_device]

# Refresh device to confirm programming
refresh_hw_device [current_hw_device]

# Close connection
close_hw_target
disconnect_hw_server

# 清理 Vivado 在项目根目录可能遗留的临时文件
catch { file delete -force [file join $project_root vivado.jou] }
catch { file delete -force [file join $project_root vivado.log] }
catch { file delete -force [file join $project_root vivado_pid*.str] }
catch { file delete -force [file join $project_root .Xil] }

puts "Programming completed successfully!"