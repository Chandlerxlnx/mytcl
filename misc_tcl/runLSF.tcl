set runDir [lindex $argv 0]
set directive [lindex $argv 1]
set writeDCP 1

#set overconstrain(clk1) 0.200
#set overconstrain(clk2) 0.150


proc runPPO { {numIters 3} {enablePhysOpt 1} {runDir "./"} {writeDCP 0} {directive "Default"}} {
  for {set i 0} {$i < $numIters} {incr i} {

    route_design -directive Explore
    report_timing
    report_timing_summary -file $runDir/rts_postroute$i.rpt
    report_clock_utilization -file $runDir/rcu_postroute$i.rpt
    report_design_analysis -timing -max_paths 100 -file $runDir/rda_postroute$i.rpt
    report_design_analysis -congestion -file $runDir/rda_congestion$i.rpt
    report_high_fanout_nets -fanout_greater_than 500 -max_nets 2000 -file ./rda_fanout$i.rpt
    if {$writeDCP} {
      write_checkpoint postroute_${directive}$i.dcp -force
    }
    if {[llength [get_nets -hier -top_net_of_hierarchical_group -filter {ROUTE_STATUS==CONFLICTS}]] > 0} {
      puts "Routing conflicts - exiting"
      exit
    }

    if {$enablePhysOpt != 0} {
      phys_opt_design -directive Explore
      report_timing
      report_timing_summary -file $runDir/rts_postroutephysopt$i.rpt
      report_clock_utilization -file $runDir/rcu_postroutephysopt$i.rpt
      report_design_analysis -setup -max 200 -file $runDir/rda_postroutephysopt$i.rpt
    }
	  if {$writeDCP} {
	    write_checkpoint postprphysopt_${directive}$i.dcp -force
	  }

    if {[get_property SLACK [get_timing_paths ]] >= 0} {break}; #stop if timing is met
  }
}


open_checkpoint ../../../superVE_15mar16/falcon_top_pre_opt.dcp


#delete_pblocks [get_pblocks]

# OVERCONSTRAINING SOME CLOCKS ##
if {[info exist overconstrain]} {
  foreach {clk val} [array get overconstrain] {
    set_clock_uncertainty -setup $val [get_clocks $clk]
  }
}


#implHighVerb

opt_design
report_timing
report_timing_summary -file $runDir/rts_postopt.rpt
report_utilization -file $runDir/util_postopt.rpt
if {$writeDCP} {
  write_checkpoint postopt_${directive}.dcp -force
}

#set_clock_uncertainty -setup 0.100 [get_clocks sys_clk_491]

#set_property LOC MMCME3_ADV_X0Y2 [get_cells u_rtesi_top/U_rtesi_fpga/U_rtesi_clock/u_fcn_core_clk_mmcm_clk_wiz/mmcme3_adv_inst]

## PLACER ##
place_design -directive $directive
report_timing
report_timing_summary -file $runDir/rts_postplace.rpt
report_utilization -file $runDir/util_postplace.rpt
#report_clock_utilization -file $runDir/rcu_postplace.rpt
report_design_analysis -timing -max_paths 100 -file $runDir/rda_postplace.rpt
report_design_analysis -congestion -file $runDir/rda_congestion.rpt
if {$writeDCP} {
  write_checkpoint postplace_${directive}.dcp -force
}

## phys_opt looping ##
#if {[physoptautoloop 2 "" 0.010 0.010] > 0} {
#  # If post-place phys_opt_design is run at least once, generate the reports
#  report_timing
#  report_timing_summary -file $runDir/rts_postphysopt.rpt
#  report_clock_utilization -file $runDir/rcu_postphysopt.rpt
#  report_design_analysis -setup -max 200 -file $runDir/rda_postphysopt.rpt
#  if {$writeDCP} {
#    write_checkpoint postphysopt_${directive}.dcp -force
#  }
#}
phys_opt_design -directive AggressiveExplore
  report_timing
  report_timing_summary -file $runDir/rts_postphysopt.rpt
  report_clock_utilization -file $runDir/rcu_postphysopt.rpt
  report_design_analysis -timing -max_paths 100 -file $runDir/rda_postphysopt.rpt
#phys_opt_design -directive AggressiveFanoutOpt
#  report_timing
#  report_timing_summary -file $runDir/rts_postphysopt1.rpt
#  report_clock_utilization -file $runDir/rcu_postphysopt1.rpt
#  report_design_analysis -timing -max_paths 100 -file $runDir/rda_postphysopt1.rpt
#phys_opt_design -directive ExploreWithHoldFix
#  report_timing
#  report_timing_summary -file $runDir/rts_postphysopt2.rpt
#  report_clock_utilization -file $runDir/rcu_postphysopt2.rpt
#  report_design_analysis -timing -setup -hold -max_paths 50 -file $runDir/rda_postphysopt2.rpt
write_checkpoint postphysopt_${directive}.dcp -force

# REMOVING OVERCONSTRAINING ##
if {[info exist overconstrain]} {
  foreach {clk val} [array get overconstrain] {
    set_clock_uncertainty -setup 0 [get_clocks $clk]
  }
}

#set_clock_uncertainty -setup 0.000 [get_clocks sys_clk_491]
## ROUTER ##

runPPO 3 1 $runDir $writeDCP $directive

exit
