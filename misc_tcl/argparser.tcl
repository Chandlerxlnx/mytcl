#tcl parser, parsing args
#reference

###############################
# set default value
###############################
array set args {
  -place  Explore
  -phys   AggressiveExplore
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
