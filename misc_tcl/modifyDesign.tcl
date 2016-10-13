#######################################################################
# Name:  removeBuffer
# Usage: removeBuffer cellObj
# Descr: remove buffer from netlist and connect output load to input
#        net if not connected to an output port
#######################################################################
proc removeBuffer {cell} {
    set inet [get_nets -of [get_pins -of $cell -filter {DIRECTION == IN}]]
    if {[llength $inet] != 1} {
        puts "Error - invalid input pin or net found - $cell"
        return 1
    }
    set onet [get_nets -of [get_pins -of $cell -filter {DIRECTION == OUT}]]
    if {[llength $onet] != 1} {
        puts "Error - invalid output pin or net found - $cell"
        return 1
    }
    set cellname [get_property name $cell]
    debug::remove_cell $cell

    if {[llength [get_ports -of $onet]] > 1} { ; # Keeping output net which is connected to a port
        set ipinloads [get_pins -of $inet -filter {NAME != $cell/*}]
        debug::remove_net $inet
        debug::connect_net -net $onet -objects $ipinloads
    } else { ; # Removing output net which is not connected to a port
        set opinloads [get_pins -of $onet]
        debug::remove_net $onet
        debug::connect_net -net $inet -objects $opinloads
    }

    return 0
}

#######################################################################
# Name:  insertBuffer
# Usage: insertBuffer netName libCellName [bufName]
# Descr: insert a buffer (primitive = libCellName) on a net. All fanout
#        of original net is moved to the fanout of the new buffer.
#######################################################################
proc insertBuffer {netName libCellName {bufName ""}} {
    set net [get_nets $netName]
    if {[llength $net] != 1} {
        puts "Error - invalid net argument - $netName"
        return 1
    }
    set opin [get_pins -leaf -of $net -filter {DIRECTION == OUT}]
    if {[llength $opin] != 1} {
        set opin [get_ports -of $net -filter {DIRECTION =~ in*}]
        if {[llength $opin] != 1} {
            puts "Error - could not find valid driver - $netName"
            return 1
        }
    }
    if {![regexp {(.*)/(.*)} $libCellName dum lib prim]} {
        set lib [get_libs]
        set prim $libCellName
    }
    if {[llength [get_lib_cells $lib/$prim]] != 1} {
        puts "Error - invalid lib cell name - $libCellName"
        return 1
    }
    set netName [get_property NAME $net]
    if {$bufName == ""} {
        set bufName ${netName}_$prim
    } elseif {[regexp {(.*)/(.*)} $bufName dum rootName leafCellName]} {
        set parentCell [getParentCell $net]
        if {[llength $parentCell] == 1} {
           if {$rootName != $parentCell} {
                puts "Error - invalid buffer name $bufName. Buffer should be in the same hierarchical level as the net $net, i.e. $parentCell"
                return ""
            } 
        } else {
            puts "Error - invalid buffer name $bufName. Buffer should be in the same hierarchical level as the net $net, i.e. $parentCell"
            return ""
        }
    }
    if {[llength [get_cells -quiet $bufName]] != 0} {
        puts "Warning - cell name $bufName already exists. Looking for a new name..."
        set ind 0
        while {[llength [get_cells -quiet $bufName\_$ind]] != 0} { incr ind }
        set bufName $bufName\_$ind
    }
    puts "Creating cell $bufName ($prim)"
    debug::create_cell -reference $prim $bufName

    set newnetname $bufName\_inet
    puts "Creating net $newnetname"
    debug::create_net $newnetname

    debug::disconnect_net -net $net -objects $opin
    debug::connect_net -net $newnetname -objects $opin
    debug::connect_net -net $newnetname -objects [get_pins $bufName/I]
    debug::connect_net -net $net -objects [get_pins $bufName/O]
    
    return $bufName
}

#######################################################################
# Name:  getParentCell
# Usage: getParentCell obj (obj = cell or net)
# Descr: Return cell obj of parent hierarchical module. Empty list if
#        obj is at the top-level
#######################################################################
proc getParentCell {obj} {
    while {[regexp {(.*)/(.*)} $obj dum parentCellName leafCellName]} {
        set parentCell [get_cells -quiet $parentCellName]
        if {[llength $parentCell] == 1} {
            return $parentCell
        } else {
            set obj $parentCellName
        }
    }
    return {}
}