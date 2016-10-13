################################################################################
# -------------------------------------------------------------------------
# Target device : Any family
#
# Description : 
#   This script finds the total number of nets using node resources in
#   all occupied tiles.
#   The routing resources must be turned on. 
# 
# Assumptions :
#   - None
#
# -------------------------------------------------------------------------
#
# Calling syntax:
#   source routing_overlay.tcl
#
# -------------------------------------------------------------------------
# Author  : Tony Scarangella, Xilinx 
# Revison : 0.1 - initial release
################################################################################
proc routing_overlay {} {

  set start [clock seconds] 
  set systemTime [clock seconds]

  # CREATE A NODE LIST FOR ALL SIGNAL NETS
  set tile_list {}
  #set routed_nets [get_nets -hierarchical * -top_net_of_hierarchical_group -filter {ROUTE_STATUS == CONFLICTS && TYPE != POWER && TYPE != GROUND}]
  set routed_nets [get_nets -hierarchical * -top_net_of_hierarchical_group -filter {TYPE != POWER && TYPE != GROUND}]
  foreach ins $routed_nets {
    set net_nodes [get_nodes -of_objects $ins -filter {NAME=~INT_*}]
    foreach nod $net_nodes {
       lappend tile_list [lindex [split $nod /] 0]
    }
  }

  # COUNT THE NUMBER OF NODES IN EACH TILE AND APPEND IT TO THE ARRAY
  set node_per_tile {}
  foreach item $tile_list {
    lappend arr($item) {}
  }
  set node_per_tile {}
  foreach name [array names arr] {
    lappend node_per_tile [list $name [llength $arr($name)]]
  }

  # SORT ARRAY MAX NODES PER TILE FIRST
  set x $node_per_tile
  foreach {k v} [array get a] {
      lappend x [list $k $v]
  }
  set tile_sort_max {}
  set tile_sort_max [lsort -decreasing -integer -index 1 $x]

  # FIND THE TILE WITH THE HIGHEST UTILIZED NODES
  set max ""
  set max [lindex [lindex $tile_sort_max 0] 1]

  # CREATE 10 BINS USING THE # OF NODES IN THE TILE 
  # TO CREATE 10 BIN RANGES
  for {set i 0} {$i < 10} {incr i 1} {set bin_color_$i ""}

  #set grade [expr {double(round(100*[expr $total]/$max))/10}]
  # grade = total_nodes_per_tile/max_nodes
  # EXAMPLE MAX 166, TOTAL NODES PER TILE IS 166 = GRADE = 10.0
  # EXAMPLE MAX 166, TOTAL NODES PER TILE IS 165 = GRADE = 9.9
  # EXAMPLE MAX 166, TOTAL NODES PER TILE IS 25 = GRADE = 1.5
  # bin_color_9 highest congested, bin_color_0 least congested, 
  foreach {tile} $tile_sort_max {
    set grade [expr {double(round(100*[lindex $tile 1]/$max))/10}]
    if {$grade >= 0 && $grade < 1} {
  		  lappend  bin_color_0 [lindex $tile 0]
       set color_grade_0 [expr (round(0.1*$max))]
		  } elseif {$grade >= 1 && $grade < 2} {
  		  lappend  bin_color_1 [lindex $tile 0]
       set color_grade_1 [expr (round(0.2*$max))]
		  } elseif {$grade >= 2 && $grade < 3} {
  		  lappend  bin_color_2 [lindex $tile 0]
       set color_grade_2 [expr (round(0.3*$max))]
		  } elseif {$grade >= 3 && $grade < 4} {
  		  lappend  bin_color_3 [lindex $tile 0]
       set color_grade_3 [expr (round(0.4*$max))]
		  } elseif {$grade >= 4 && $grade < 5} {
  		  lappend  bin_color_4 [lindex $tile 0]
       set color_grade_4 [expr (round(0.5*$max))]
		  } elseif {$grade >= 5 && $grade < 6} {
  		  lappend  bin_color_5 [lindex $tile 0]
       set color_grade_5 [expr (round(0.6*$max))]
		  } elseif {$grade >= 6 && $grade < 7} {
  		  lappend  bin_color_6 [lindex $tile 0]
       set color_grade_6 [expr (round(0.7*$max))]
		  } elseif {$grade >= 7 && $grade < 8} {
  		  lappend  bin_color_7 [lindex $tile 0]
       set color_grade_7 [expr (round(0.8*$max))]
		  } elseif {$grade >= 8 && $grade < 9} {
  		  lappend  bin_color_8 [lindex $tile 0]
       set color_grade_8 [expr (round(0.9*$max))]
		  } elseif {$grade >= 9 } {
  		  lappend  bin_color_9 [lindex $tile 0]
       set color_grade_9 $max
    }
  }

  show_objects -name RteCong_$color_grade_9 [get_tiles -quiet $bin_color_9] 
  highlight_objects -rgb {255 0 0 }  [get_tiles -quiet $bin_color_9] ;#RED
  show_objects -name RteCong_$color_grade_8 [get_tiles -quiet $bin_color_8] 
  highlight_objects -rgb {255 45 45 }  [get_tiles -quiet $bin_color_8]
  show_objects -name RteCong_$color_grade_7 [get_tiles -quiet $bin_color_7] 
  highlight_objects -rgb {255 68 68 }  [get_tiles -quiet $bin_color_7]
  show_objects -name RteCong_$color_grade_6 [get_tiles -quiet $bin_color_6] 
  highlight_objects -rgb {255 90 90 }  [get_tiles -quiet $bin_color_6]
  show_objects -name RteCong_$color_grade_5 [get_tiles -quiet $bin_color_5] 
  highlight_objects -rgb {255 112 112 }  [get_tiles -quiet $bin_color_5]
#   show_objects -name RteCong_$color_grade_4 [get_tiles -quiet -quiet $bin_color_4] 
#   highlight_objects -rgb {255 135 135 }  [get_tiles -quiet $bin_color_4]
#   show_objects -name RteCong_$color_grade_3 [get_tiles -quiet $bin_color_3] 
#   highlight_objects -rgb {255 158 158 }  [get_tiles -quiet $bin_color_3]
#   show_objects -name RteCong_$color_grade_2 [get_tiles -quiet $bin_color_2] 
#   highlight_objects -rgb {255 180 180 }  [get_tiles -quiet $bin_color_1]
#   show_objects -name RteCong_$color_grade_1 [get_tiles -quiet $bin_color_1] 
#   highlight_objects -rgb {255 203 203 }  [get_tiles -quiet $bin_color_1]
#   show_objects -name RteCong_$color_grade_0 [get_tiles -quiet $bin_color_0] 
#   highlight_objects -rgb {255 255 255 }  [get_tiles -quiet $bin_color_0]

  puts "|            | Number of | Number of nodes |"
  puts "| Percentage |   Tiles   |    per tile     |"
  puts [format "|   90-100   |%-10d |%-16d |" [llength $bin_color_9] $color_grade_9]
  puts [format "|   80-89    |%-10d |%-16d |" [llength $bin_color_8] $color_grade_8]   
  puts [format "|   70-79    |%-10d |%-16d |" [llength $bin_color_7] $color_grade_7]   
  puts [format "|   60-69    |%-10d |%-16d |" [llength $bin_color_6] $color_grade_6]   
  puts [format "|   50-59    |%-10d |%-16d |" [llength $bin_color_5] $color_grade_5]   
  puts [format "|   40-49    |%-10d |%-16d |" [llength $bin_color_4] $color_grade_4]   
  puts [format "|   30-39    |%-10d |%-16d |" [llength $bin_color_3] $color_grade_3]   
  puts [format "|   20-29    |%-10d |%-16d |" [llength $bin_color_2] $color_grade_2]   
  puts [format "|   10-19    |%-10d |%-16d |" [llength $bin_color_1] $color_grade_1]   
  puts [format "|    0-9     |%-10d |%-16d |" [llength $bin_color_0] $color_grade_0]   
  puts "Date: [clock format $systemTime -format %D] Compile time: [expr ([clock seconds]-$start)/3600] hour(h), [expr (([clock seconds]-$start)%3600)/60] minute(m) and [expr (([clock seconds]-$start)%3600)%60] second(s)."

  

}