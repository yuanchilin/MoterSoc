# Rebuild RISC-V SoC Project
# Run this script to rebuild after RTL modifications
# Usage: vivado -mode batch -source scripts/rebuild.tcl

# 计算项目根目录（基于脚本自身位置）
set script_dir [file dirname [info script]]
set project_root [file normalize [file join $script_dir ..]]
set build_dir [file join $project_root build]

# 切换到 build 目录，使 Vivado 中间文件 (vivado.jou/log/.Xil) 落在 build/ 而非项目根目录
cd $build_dir

# Open existing project
open_project [file join $build_dir riscv_davinci riscv_davinci.xpr]

# Update compile order to pick up new files
update_compile_order -fileset sources_1

# Reset and re-run synthesis
reset_run synth_1
launch_runs synth_1 -jobs 32
wait_on_run synth_1

# Reset and re-run implementation  
reset_run impl_1
launch_runs impl_1 -jobs 32
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 32
wait_on_run impl_1

# 清理 Vivado 在项目根目录可能遗留的临时文件
catch { file delete -force [file join $project_root vivado.jou] }
catch { file delete -force [file join $project_root vivado.log] }
catch { file delete -force [file join $project_root vivado_pid*.str] }
catch { file delete -force [file join $project_root .Xil] }

puts "Build completed successfully!"