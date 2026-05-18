# Create Vivado Project for RISC-V SoC on DaVinci FPGA
# Usage: vivado -mode batch -source scripts/create_project.tcl

# 计算项目根目录（基于脚本自身位置）
set script_dir [file dirname [info script]]
set project_root [file normalize [file join $script_dir ..]]
set build_dir [file join $project_root build]

# 切换到 build 目录，使 Vivado 中间文件 (vivado.jou/log/.Xil) 落在 build/ 而非项目根目录
cd $build_dir

create_project riscv_davinci [file join $build_dir riscv_davinci] -part xc7a35tfgg484-2 -force

# Add source files
add_files -fileset sources_1 [list \
    [file join $project_root rtl cpu riscv_core.v] \
    [file join $project_root rtl peripheral gpio.v] \
    [file join $project_root rtl peripheral pwm.v] \
    [file join $project_root rtl peripheral uart.v] \
    [file join $project_root rtl soc riscv_soc.v] \
    [file join $project_root rtl soc inst_rom.v] \
    [file join $project_root rtl top.v] \
]

# Add constraints
add_files -fileset constrs_1 [list \
    [file join $project_root constraints daVinci.xdc] \
]

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

# 清理 Vivado 在项目根目录可能遗留的临时文件
catch { file delete -force [file join $project_root vivado.jou] }
catch { file delete -force [file join $project_root vivado.log] }
catch { file delete -force [file join $project_root vivado_pid*.str] }
catch { file delete -force [file join $project_root .Xil] }

puts "Project creation completed successfully!"