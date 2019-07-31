# this script will find out the F2F path with large slack. this will help reduce register utilization

set pipes {}
foreach din [get_pins -filter “REF_PIN_NAME==D && SETUP_SLACK>1.0” -of [get_cells -hier -filter REF_NAME=~FD*]] {
  set dout [get_pins -quiet -leaf -quiet -filter “REF_PIN_NAME==Q && REF_NAME=~FD*” -of [get_nets -of $din]]
  if {$dout == {}} { continue }
 lappend pipes $din
}
report_timing -to $pipes -max 1000 -input_pins -name pipes

#Make sure to look at the slack before and after the pipeline stage, which report_design_analysis can help you do.
