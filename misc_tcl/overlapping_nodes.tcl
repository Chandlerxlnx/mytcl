proc get_overlapping_nodes {} {
  
   set nets [get_nets -hier -filter ROUTE_STATUS==CONFLICTS]
   puts "Found [llength $nets] nets with Conflicts."
   set nodes [get_nodes -of $nets]
   puts "Parsing [llength $nodes] nodes for potential overlaps."
   set nodeOverlaps {}
   set count 0
   set lineCount 1
   puts -nonewline $lineCount
   foreach node $nodes {
      set nodeNets [get_nets -of $node]
      if {[llength $nodeNets] > 1} {
         lappend nodeOverlaps $node
      }
      incr count
      if {$count == 100} {
         set count 0
         incr lineCount
         puts ""
         puts -nonewline $lineCount
      }
      puts -nonewline "."
   }
   select_objects $nodeOverlaps
   highlight_objects -color red [get_selected_objects]
}
