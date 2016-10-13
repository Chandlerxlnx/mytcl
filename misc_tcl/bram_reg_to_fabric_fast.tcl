########################################################################################
##
## Company:        Xilinx, Inc.
## Created by:     David Pefourque
##
## Version:        2015.11.20
## Tool Version:   Vivado 2014.1
## Description:    Script to replace BRAMs with DOA_REG/DOB_REG=1 with fabric flip flops
##                 The script can also move out the register out of registered FIFOs to
##                 the fabric
##
########################################################################################

# proc [file tail [info script]] {} " source [info script]; puts \" [info script] reloaded\" "
# proc reload {} " source [info script]; puts \" [info script] reloaded\" "

########################################################################################
## 2015.11.20 - Added support for UltraScale RAMB output port naming
##            - Improved runtime by processing all the RAMBs or FIFOs in a
##              single pass (unsafe mode)
##            - Force connection of R/CE pins to ground/power for all created FDRE
##            - Misc code improvements
## 2015.11.19 - Improved runtime by connecting/disconnecting all pins at once
##            - Added unsafe mode to create multiple FD in a single pass instead of 
##              one by one
##            - Added fifoRegToFabric to move registers from FIFOs to the fabric
##            - Cleaned up code
## 2014.07.10 - Refactorized the code
##            - Fixed some issues
## xxxx-xx-xx - Initial release by John Bieker
########################################################################################

## PLEASE READ:
## ============
## The script runs in 2 modes: safe and unsafe (boolean passed as last argument of
## bramRegToFabric and fifoRegToFabric.
## For example:
##   Safe mode:
##     bramRegToFabric $brams
##     bramRegToFabric $brams 1
##   Unsafe mode:
##     bramRegToFabric $brams 0
##
## Safe mode:
## ----------
## The BRAMs/FIFOs are processed sequentially and FDRE created sequentially. This
## mode ensure that FDRE cells can be created once at a time and is able to recover
## when reaching protected IPs. However, the runtime is much longer.
##
## Unsafe mode:
## ------------
## All the BRAMs/FIFOs are processed at once. This means that all the FDRE and extra
## nets are created at once, in a single command call. The runtime is much faster but
## the cells or nets creation could fail in the middle and leave the design in an
## undetermined state.
##
## Targeted pins for BRAMs:
## ------------------------
## Output ports DOA* & DOPA* & DOUTA* when DOA_REG==1
## Output ports DOB* & DOPB* & DOUTB* when DOB_REG==1
## The clock pin of inserted FDRE is connected to the BRAM's read clock pin
##
## Targeted pins for FIFOs:
## ------------------------
## Output ports DOUT* when REGISTER_MODE==REGISTERED
## The clock pin of inserted FDRE is connected to the FIFO's read clock pin
##
## Example runtime (unsafe mode):
## ------------------------------
## 128 FIFOs processed in 12mns (8195 added FDRE)
## 1118 BRAMs processed in 77mns (50K added FDRE with 100K nets)
## 

# BE CAREFUL: will fail on protected IPs:
# ERROR: [Coretcl 2-76] Netlist change for element 'u_clt_to_bk_top0/u_map_sar_oh_wrapper/map_sar_oh_i/sar_100g_0/U0/SAR17_5_GEN.sar_100_1/SG/p_60_in[4]' is forbidden by security attributes.  Command failed.
# When this happens, the script skip the BRAM.

# How to use:
# ===========
# set brams [get_selected_objects]
# set brams [get_cells -hier -filter {NAME=~A/B/C/*}]
# set brams [filter [get_cells -hier -filter {PRIMITIVE_GROUP==BMEM}] {DOA_REG==1 || DOB_REG==1}]
# # SAFE mode:
#   bramRegToFabric $brams
#   bramRegToFabric $brams 1
# # UNSAFE mode:
#   bramRegToFabric $brams 0
#
# set fifos [get_cells -hier -filter {REF_NAME=~FIFO36* && REGISTER_MODE==REGISTERED}]
# # SAFE mode:
#   fifoRegToFabric $fifos
#   fifoRegToFabric $fifos 1
# # UNSAFE mode:
#   fifoRegToFabric $fifos 0

proc bramInsertRegOnNets { nets &arDisconnect &arConnect {tag {}} {safe 1} } {

  upvar ${&arDisconnect} disconnect
  upvar ${&arConnect} connect

  # Unsafe mode: list of cells and nets to be created
  set createNets [list]
  set createCells [list]
  
  # In unsafe mode, the FD/net names must be uniquified. This is done by using
  # a unique tag for each call to bramInsertRegOnNets. An index is also added
  # as suffix during the iteration over the nets.

  # If not empty, append '_'
  if {$tag != {}} { set tag [format {%s_} $tag] }

  proc genUniqueName {name {safe 1} } {
  	# In unsafe mode, assume the name has been uniquified and return it
  	if {!$safe} {
  		return $name
  	}
    # In safe mode, names must be unique among the net and cell names
    if {([get_cells -quiet $name] == {}) && ([get_nets -quiet $name] == {})} { return $name }
    set index 0
    while {([get_cells -quiet ${name}_${index}] != {}) || ([get_nets -quiet ${name}_${index}] != {})} { incr index }
    return ${name}_${index}
  }

  # WARNING: [Coretcl 2-1024] Master cell 'FD' is not supported by the current part and has been retargeted to 'FDRE'.
  set_msg_config -id {Coretcl 2-1024} -limit 0

  set index 0
  ### For every net that exists in the list named $nets, loop
  foreach net $nets {
    incr index
    ### Get the driver pin of the net
    set x [get_pins -quiet -of $net -filter {DIRECTION==OUT && IS_LEAF ==1}]
    ### Add an element to the associative array called opin that contains the driver pin of the net
    set opin($net) $x
    set parent [get_property -quiet PARENT [get_cells -quiet -of $x]]
    ### For readability, create the name of the new flop based on the hierarchy of the bram and append the string fd_#
    if {$parent != {}} {
      set ff_name [genUniqueName $parent/fd_${tag}${index} $safe]
    } else {
      set ff_name [genUniqueName fd_${tag}${index} $safe]
    }
    ### For readability, create the name of the new net based on the hierarchy of the bram and append the string ram_to_fd_#
    if {$parent != {}} {
      set net_name [genUniqueName $parent/ram_to_fd_${tag}${index} $safe]
    } else {
      set net_name [genUniqueName ram_to_fd_${tag}${index} $safe]
    }
    ### Create the new FD cell
    if {$safe} {
    	# In safe mode, each FD is created sequentially
      if {[catch {create_cell -quiet -reference FDRE $ff_name} errorstring]} {
        # Did the following error happened for protected IPs?
        # ERROR: [Coretcl 2-76] Netlist change for element 'u_clt_to_bk_top0/u_map_sar_oh_wrapper/map_sar_oh_i/sar_100g_0/U0/SAR17_5_GEN.sar_100_1/SG' is forbidden by security attributes.  Command failed.
        if {[regexp -nocase {is forbidden by security attributes} $errorstring]} {
          # Yes. Do not genereate a TCL_ERROR but a warning
          puts " -W- Cannot modify the netlist of a protected IP. No register inserted on net $net . Other nets are skipped."
          # Before exiting, create nets that should be created
          if {[llength $createNets]} {
            puts " -I- Creating [llength $createNets] net(s)"
            create_net -quiet $createNets
          }
          return 1
        } else {
          # Before exiting, create nets that should be created
          if {[llength $createNets]} {
            puts " -I- Creating [llength $createNets] net(s)"
            create_net -quiet $createNets
          }
          # No, then return the TCL_ERROR
          error $string
        }
      }
      puts " -I- Creating FDRE $ff_name"
    } else {
    	# In unsafe mode, all FDs are created at once
      lappend createCells $ff_name
    }
    ### Create the new net to connect from output of bram to D pin of the new FD
    lappend createNets $net_name
    ### Disconnect the driver net from the bram because the new driver comes from the Q of the FD
    if {[info exists disconnect($net)]} {
    	set disconnect($net) [lsort -unique [concat $disconnect($net) $opin($net)]]
    } else {
    	set disconnect($net) $opin($net)
    }
    ### Connect the old net to the new driver (FD/Q)
    if {[info exists connect($net)]} {
  	  set connect($net) [lsort -unique [concat $connect($net) $ff_name/Q ]]
    } else {
    	set connect($net) $ff_name/Q
    }
    ### Connect the driver side of the new net to the output of the BRAM
    if {[info exists connect($net_name)]} {
    	set connect($net_name) [lsort -unique [concat $connect($net_name) [list $ff_name/D $opin($net) ] ]]
    } else {
    	set connect($net_name) [list $ff_name/D $opin($net) ]
    }
    ### Connect the load side of the new net to the D input of the new FD
    ### Connect the clock of the new FD to the clock input of the BRAM/FIFO that contains the string *RD* (ie the read clock)
    set clockNet [get_nets -quiet -of [get_pins -quiet -of [get_cells -quiet -of [get_nets -quiet $net]] -filter {IS_CLOCK == 1 && NAME =~ *RD*}]]
    if {[info exists connect($clockNet)]} {
    	set connect($clockNet) [lsort -unique [concat $connect($clockNet) $ff_name/C ]]
    } else {
    	set connect($clockNet) $ff_name/C
    }
    ### Local ground/power nets
#     set parent [join [lrange [split $ff_name /] 0 end-1] /]
    if {$parent != {}} {
    	set groundNet [format {%s/<const0>} $parent]
    	set powerNet [format {%s/<const1>} $parent]
    } else {
     	set groundNet {<const0>}
    	set powerNet {<const1>}
    }
    if {[get_nets -quiet $groundNet] == {}} {
    	# Ground net does not exist. Create it:
      if {$parent != {}} {
        puts " -I- Creating ground net $parent/<const0>"
      	create_cell -quiet -reference GND $parent/GND
        create_net -quiet $parent/<const0>
        connect_net -hier -net $parent/<const0> -obj [get_pins -quiet $parent/GND/G]
      } else {
        puts " -I- Creating ground net <const0>"
      	create_cell -quiet -reference GND GND
        create_net -quiet <const0>
        connect_net -hier -net <const0> -obj [get_pins -quiet GND/G]
      }
    }
    if {[get_nets -quiet $powerNet] == {}} {
    	# Power net does not exist. Create it:
      if {$parent != {}} {
        puts " -I- Creating power net $parent/<const1>"
      	create_cell -quiet -reference VCC $parent/VCC
        create_net -quiet $parent/<const1>
        connect_net -quiet -hier -net $parent/<const1> -obj [get_pins -quiet $parent/VCC/P]
      } else {
        puts " -I- Creating power net <const1>"
      	create_cell -quiet -reference VCC VCC
        create_net -quiet <const1>
        connect_net -quiet -hier -net <const1> -obj [get_pins -quiet VCC/P]
      }
    }
    ### Connect FDRE/R to ground
    if {[info exists connect($groundNet)]} {
    	set connect($groundNet) [lsort -unique [concat $connect($groundNet) [list $ff_name/R ] ]]
    } else {
    	set connect($groundNet) [list $ff_name/R ]
    }
    ### Connect FDRE/CE to power
    if {[info exists connect($powerNet)]} {
    	set connect($powerNet) [lsort -unique [concat $connect($powerNet) [list $ff_name/CE ] ]]
    } else {
    	set connect($powerNet) [list $ff_name/CE ]
    }
  }

  # WARNING: [Coretcl 2-1024] Master cell 'FD' is not supported by the current part and has been retargeted to 'FDRE'.
  reset_msg_config -id {Coretcl 2-1024} -limit

  # Create registers
  if {[llength $createCells]} {
    puts " -I- Creating [llength $createCells] FDRE(s) (fd_${tag}*)"
    set startTime [clock seconds]
    create_cell -quiet -reference FDRE $createCells
    set stopTime [clock seconds]
    puts " -I- Completed in [expr $stopTime - $startTime] secs"
  }

  # Create nets
  if {[llength $createNets]} {
    puts " -I- Creating [llength $createNets] net(s) (ram_to_fd_${tag}*)"
    set startTime [clock seconds]
    create_net -quiet $createNets
    set stopTime [clock seconds]
    puts " -I- Completed in [expr $stopTime - $startTime] secs"
  }

  return 0
}

proc bramRegToFabric { cells { safe 1 } } {

# proc bramRegToFabric { cells &arDisconnect &arConnect } {}
#   upvar ${&arDisconnect} arDisconnect
#   upvar ${&arConnect} arConnect

  catch { unset arDisconnect }
  catch { unset arConnect }

  set debug 0

  # Generate a 5-digits random tag (unsafe mode)
  set tag {}
  if {!$safe} {
  	# Force the tag to NOT start with 0, otherwise 'incr tag' does not work
    set tag [format {%d%d} [subst [string repeat {[format %c [expr {int(rand() * 9) + 49}]]} 1] ] \
                           [subst [string repeat {[format %c [expr {int(rand() * 10) + 48}]]} 4] ] ]
    if {$debug} {
      puts " -D- tag: $tag"
    }
  }

  set startTime [clock seconds]
  if {$safe} {
    puts " -I- Started on [clock format $startTime] (SAFE MODE)"
  } else {
    puts " -I- Started on [clock format $startTime] (UNSAFE MODE)"
  }

  set brams [filter -quiet [get_cells -quiet $cells] {REF_NAME=~RAMB* && DOA_REG==1}]
#   set brams [filter -quiet [get_cells -quiet $cells] {(PRIMITIVE_GROUP==BMEM || PRIMITIVE_GROUP==BLOCKRAM) && DOA_REG==1}]
  if {$brams != {}} {

    if {!$safe} {
    	# Unsafe mode: all the BRAMs are processed in a single pass
#       set pins [get_pins -quiet -of [get_cells -quiet $brams] -filter {(REF_PIN_NAME=~DOA* || REF_PIN_NAME=~DOPA*) && DIRECTION==OUT && IS_CONNECTED}]
      set pins [get_pins -quiet -of [get_cells -quiet $brams] -filter {(REF_PIN_NAME=~DOA* || REF_PIN_NAME=~DOPA* || REF_PIN_NAME=~DOUTA*) && DIRECTION==OUT && IS_CONNECTED}]
      if {$pins == {}} {
      	puts " -I- No candidate pin found for FDRE insertion (DOA_REG)"
      } else {
        set nets [get_nets -quiet -of $pins]
        if {[catch {set res [bramInsertRegOnNets $nets arDisconnect arConnect $tag $safe]} errorstring]} {
          puts " -E- bramInsertRegOnNets: $errorstring"
        } else {
          if {$res == 0} {
            set_property {DOA_REG} 0 [get_cells -quiet $brams]
          }
        }
      }
    } else {
    	# Safe mode: all the BRAMs are processed sequentially
      set i 0
      foreach ram $brams {
        puts " -I- Processing ([incr i]/[llength $brams]) $ram (DOA_REG)"
        ### Create a list called nets of all of the nets connected to output pins of the BRAMs
#         set pins [get_pins -quiet -of [get_cells -quiet $ram] -filter {(REF_PIN_NAME=~DOA* || REF_PIN_NAME=~DOPA*) && DIRECTION==OUT && IS_CONNECTED}]
        set pins [get_pins -quiet -of [get_cells -quiet $brams] -filter {(REF_PIN_NAME=~DOA* || REF_PIN_NAME=~DOPA* || REF_PIN_NAME=~DOUTA*) && DIRECTION==OUT && IS_CONNECTED}]
        if {$pins == {}} { continue }
        set nets [get_nets -quiet -of $pins]
        puts " -I- Inserting FDRE on [llength $pins] pin(s): $pins"
        if {[catch {set res [bramInsertRegOnNets $nets arDisconnect arConnect $safe]} errorstring]} {
          puts " -E- bramInsertRegOnNets: $errorstring"
        } else {
          if {$res == 0} {
            set_property {DOA_REG} 0 [get_cells -quiet $ram]
          }
        }
      }
    }

  }

  # Create a new tag to prevent name collision (unsafe mode)
  if {!$safe} {
    incr tag
    if {$debug} {
      puts " -D- tag: $tag"
    }
  }

  set brams [filter -quiet [get_cells -quiet $cells] {REF_NAME=~RAMB* && DOB_REG==1}]
#   set brams [filter -quiet [get_cells -quiet $cells] {(PRIMITIVE_GROUP==BMEM || PRIMITIVE_GROUP==BLOCKRAM) && DOB_REG==1}]
  if {$brams != {}} {

    if {!$safe} {
    	# Unsafe mode: all the BRAMs are processed in a single pass
#       set pins [get_pins -quiet -of [get_cells -quiet $brams] -filter {(REF_PIN_NAME=~DOB* || REF_PIN_NAME=~DOPB*) && DIRECTION==OUT && IS_CONNECTED}]
      set pins [get_pins -quiet -of [get_cells -quiet $brams] -filter {(REF_PIN_NAME=~DOB* || REF_PIN_NAME=~DOPB* || REF_PIN_NAME=~DOUTB*) && DIRECTION==OUT && IS_CONNECTED}]
      if {$pins == {}} {
      	puts " -I- No candidate pin found for FDRE insertion (DOB_REG)"
      } else {
        set nets [get_nets -quiet -of $pins]
        if {[catch {set res [bramInsertRegOnNets $nets arDisconnect arConnect $tag $safe]} errorstring]} {
          puts " -E- bramInsertRegOnNets: $errorstring"
        } else {
          if {$res == 0} {
            set_property {DOB_REG} 0 [get_cells -quiet $brams]
          }
        }
      }
    } else {
    	# Safe mode: all the BRAMs are processed sequentially
      set i 0
      foreach ram $brams {
        puts " -I- Processing ([incr i]/[llength $brams]) $ram (DOB_REG)"
        ### Create a list called nets of all of the nets connected to output pins of the BRAMs
#         set pins [get_pins -quiet -of [get_cells -quiet $ram] -filter {(REF_PIN_NAME=~DOB* || REF_PIN_NAME=~DOPB*) && DIRECTION==OUT && IS_CONNECTED}]
        set pins [get_pins -quiet -of [get_cells -quiet $brams] -filter {(REF_PIN_NAME=~DOB* || REF_PIN_NAME=~DOPB* || REF_PIN_NAME=~DOUTB*) && DIRECTION==OUT && IS_CONNECTED}]
        if {$pins == {}} { continue }
        set nets [get_nets -quiet -of $pins]
        puts " -I- Inserting FDRE on [llength $pins] pin(s): $pins"
        if {[catch {set res [bramInsertRegOnNets $nets arDisconnect arConnect $safe]} errorstring]} {
          puts " -E- bramInsertRegOnNets: $errorstring"
        } else {
          if {$res == 0} {
            set_property {DOB_REG} 0 [get_cells -quiet $ram]
          }
        }
      }
    }

  }

  # Debug
#   catch { parray arDisconnect }
#   catch { parray arConnect }

  # Disconnect all the loads in a single call
  set loads [list]
  foreach net [array names arDisconnect] {
  	set loads [concat $loads $arDisconnect($net)]
  }
  set loads [get_pins -quiet [lsort -unique $loads]]
  if {[llength $loads]} {
    puts " -I- Disconnecting [llength $loads] load(s)"
    foreach el $loads {
    	if {$debug} { puts " -D-      $el" }
    }
  	disconnect_net -objects $loads
  }

#   foreach net [array names arDisconnect] {
#   	puts " -I- Disconnecting net $net from [llength $arDisconnect($net)] load(s)"
#   	disconnect_net -net $net -objects [get_pins -quiet $arDisconnect($net)]
#   }

  # Connect all the pins and nets in a single call
  if {[llength [array names arConnect]]} {
    puts " -I- Connecting [llength [array names arConnect]] net(s)"
    foreach el [lsort [array names arConnect]] {
    	if {$debug} { puts " -D-      $el \t [lsort $arConnect($el)]" }
    }
  	connect_net -hier -net_object_list [array get arConnect]
  }

#   foreach net [array names arConnect] {
#   	puts " -I- Disconnecting net $net from [llength $arDisconnect($net)] load(s)"
#   	connect_net -hier -net_object_list [array get arConnect]
#   }

  set stopTime [clock seconds]
  puts " -I- Completed on [clock format $stopTime]"
  puts " -I- Completed in [expr $stopTime - $startTime] seconds"

  return -code ok
}

proc fifoRegToFabric { cells { safe 1 } } {

  catch { unset arDisconnect }
  catch { unset arConnect }

  set debug 0

  # Generate a 5-digits random tag (unsafe mode)
  set tag {}
  if {!$safe} {
  	# Force the tag to NOT start with 0, otherwise 'incr tag' does not work
    set tag [format {%d%d} [subst [string repeat {[format %c [expr {int(rand() * 9) + 49}]]} 1] ] \
                           [subst [string repeat {[format %c [expr {int(rand() * 10) + 48}]]} 4] ] ]
    if {$debug} {
      puts " -D- tag: $tag"
    }
  }

  set startTime [clock seconds]
  if {$safe} {
    puts " -I- Started on [clock format $startTime] (SAFE MODE)"
  } else {
    puts " -I- Started on [clock format $startTime] (UNSAFE MODE)"
  }

  set fifos [filter -quiet [get_cells -quiet $cells] {(REF_NAME=~FIFO36* || REF_NAME=~FIFO18*) && (REGISTER_MODE=={REGISTERED})}]
  if {$fifos != {}} {

    if {!$safe} {
    	# Unsafe mode: all the FIFOs are processed in a single pass
      set pins [get_pins -quiet -of [get_cells -quiet $fifos] -filter {REF_PIN_NAME=~DOUT* && DIRECTION==OUT && IS_CONNECTED}]
      if {$pins == {}} {
      	puts " -I- No candidate pin found for FDRE insertion"
      } else {
        set nets [get_nets -quiet -of $pins]
        if {[catch {set res [bramInsertRegOnNets $nets arDisconnect arConnect $tag $safe]} errorstring]} {
          puts " -E- fifoRegToFabric: $errorstring"
        } else {
          if {$res == 0} {
            set_property {REGISTER_MODE} {UNREGISTERED} [get_cells -quiet $fifos]
          }
        }
      }
    } else {
    	# Safe mode: all the FIFOs are processed sequentially
      set i 0
      foreach fifo $fifos {
        puts " -I- Processing ([incr i]/[llength $fifos]) $fifo (REGISTER_MODE)"
        ### Create a list called nets of all of the nets connected to output pins of the FIFO36
        set pins [get_pins -quiet -of [get_cells -quiet $fifo] -filter {REF_PIN_NAME=~DOUT* && DIRECTION==OUT && IS_CONNECTED}]
        if {$pins == {}} { continue }
        set nets [get_nets -quiet -of $pins]
        puts " -I- Inserting FDRE on [llength $pins] pin(s): $pins"
        if {[catch {set res [bramInsertRegOnNets $nets arDisconnect arConnect $safe]} errorstring]} {
          puts " -E- fifoRegToFabric: $errorstring"
        } else {
          if {$res == 0} {
            set_property {REGISTER_MODE} {UNREGISTERED} [get_cells -quiet $fifo]
          }
        }
      }
    }

  }

  # Disconnect all the loads in a single call
  set loads [list]
  foreach net [array names arDisconnect] {
  	set loads [concat $loads $arDisconnect($net)]
  }
  set loads [get_pins -quiet [lsort -unique $loads]]
  if {[llength $loads]} {
    puts " -I- Disconnecting [llength $loads] load(s)"
    foreach el $loads {
    	if {$debug} { puts " -D-      $el" }
    }
  	disconnect_net -objects $loads
  }

  # Connect all the pins and nets in a single call
  if {[llength [array names arConnect]]} {
    puts " -I- Connecting [llength [array names arConnect]] net(s)"
    foreach el [lsort [array names arConnect]] {
    	if {$debug} { puts " -D-      $el \t [lsort $arConnect($el)]" }
    }
  	connect_net -hier -net_object_list [array get arConnect]
  }

  set stopTime [clock seconds]
  puts " -I- Completed on [clock format [clock seconds]]"
  puts " -I- Completed in [expr $stopTime - $startTime] seconds"

  return -code ok
}
