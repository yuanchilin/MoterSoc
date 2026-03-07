# Rebuild RISC-V SoC Project
# Run this script to rebuild after RTL modifications

# Open existing project
open_project D:/Downloads/Agent/Riscv/riscv_davinci/riscv_davinci.xpr

# Update compile order to pick up new files
update_compile_order -fileset sources_1

# Reset and re-run synthesis
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Reset and re-run implementation  
reset_run impl_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Build completed successfully!"