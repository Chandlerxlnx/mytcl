## ==============================================================
## This script is fro Vivado tcl based implementation 
## Version: controled by ~/vivado_env.tcl 
## the post synthesis checkpoint called post_synth.dcp 
## $outputDir control the output files directory
## ==============================================================

# define output files directory
set outputDir ./report 
file mkdir $outputDir
# start implementation
read_checkpoint ./post_synth.dcp
report_utilization -file $outputDir/post_synth.uti
report_timing -delay_type min_max -max_paths 10 -sort_by group -input_pins -name timing_1 -file $outputDir/post_synth.twr

opt_design 
write_checkpoint -force $outputDir/post_logicopt.dcp
report_utilization -file $outputDir/post_logicopt.uti
place_design -effort_level high
write_checkpoint -force $outputDir/post_place.dcp
report_utilization -file $outputDir/post_place.uti
report_timing -delay_type min_max -max_paths 10 -sort_by group -input_pins -name timing_2 -file $outputDir/post_place.twr
#phys_opt_design
phys_opt_design -verbose -replace
report_timing_summary -file $outputDir/popt_replace_timing.rpt
phys_opt_design -verbose -effort_level high
report_timing_summary -file $outputDir/popt_high_timing.rpt

route_design -effort_level high
write_checkpoint -force $outputDir/post_route.dcp
report_utilization -file $outputDir/post_route.uti
report_timing -delay_type min_max -max_paths 10 -sort_by group -input_pins -name timing_3 -file $outputDir/post_route.twr

write_checkpoint ./mydesign_routed.dcp


