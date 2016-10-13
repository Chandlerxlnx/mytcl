#tcl parser, parsing args
#reference

###############################
# set default value
###############################
array set args {
  -place  Explore
  -phys   AggressiveExplore
  -route  Explore
}

##########################################
 if {[expr $argc %2 ] ==1} {
  puts " Error: wrong args!";
  helplog;#puts help
 }
 
 for {set i 0} {$i < $argc } {incr i} {
  set arg [lindex $argv $i]
  set args([lindex $argv $i]) \
        [lindex $argv [expr $i +1]]
  incr i
 }

###########################
proc helplog {
  puts "help:\n"
  puts "the args formate is -arg1 value1 -arg2 valu2"
}

puts "-place: ${-place}";
puts "-phys: ${-phys}";
puts "-route: ${-route}";

open_checkpoint ./synth_top.dcp

opt_design ;
source ./tcl/pre_phys.tcl
place_design -directive ${-place};
report_timing_summary -max_paths 10 -report_unconstrained -check_timing_verbose -file top_tspl.rpt
phys_opt_design -directive ${-phys};
report_timing_summary -max_paths 10 -report_unconstrained -check_timing_verbose -file top_tspph1.rpt
write_checkpoint -force top_phys1.dcp

source ./tcl/pre_route.tcl
route_design -directive ${-route};
report_timing_summary -max_paths 10 -report_unconstrained -check_timing_verbose -file top_tsrt.rpt

write_checkpoint -force top_route.dcp
quit;


