open_checkpoint top_synth.dcp
opt_design -directive Explore;# or your own directive used in project
source ./tcl/pre_uncertainty.tcl;# overconstraints
place_design directive Explore -fanout_opt;
report_timing_summary -max_paths 10 -report_unconstrained -check_timing_verbose -file rpt/top_tspl.rpt
write_checkpoint -force top_place.dcp; #save the intermedia dcp
phys_opt_design -retime;# retiming
phys_opt_design -directive AggressiveExplore ;
phys_opt_design -directive AggressiveFanoutOpt;
phys_opt_design -directive AlternateReplication ;
report_timing_summary -max_paths 10 -report_unconstrained -check_timing_verbose -file rpt/top_tspph1.rpt
write_checkpoint -force top_phys1.dcp

source ./tcl/pre_route.tcl; #remove overconstraints
route_design -directive Explore; #this directive can cover most case, choose other directive if you find it is better.
write_checkpoint -force top_route.dcp
report_timing_summary -file top_timing.rpt -name tms -max_paths 100;
write_bitstream -force -bin_file top.bit;# write out the bitstream.
report_qor_suggestions -output_dir . -max_paths 1000 -all_checks -strategy -evaluate_pipelineing -force -file top_qor_suggestion.rpt; #get the suggestions  on synthesis,implementation and RTL.

