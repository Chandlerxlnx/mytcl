#XILINX INC
#sort the pin assignment XDC by order of pad name
#procedure
#  4) run cmd 
#      pin_sort ifilename ofilename ononpin_filename tabfilename
#      > ifilename: the csv file exported by planAhead
#      > ofilename: the new xdc file sorting the pin related constraints by pad name


proc pin_csv2xdc {ifilename ofilename } {
  #set ifilename pin_assignment.xdc;
  #set ofilename pin_out.txt;
  #set tabfilename  pin_tab.txt
  puts " opening files $ifilename, $ofilename";
  set fin [open $ifilename r];
  set fout [open $ofilename w];
  #skip the comments in the head of file
  #read the column header
  set head_detected 0 ;

 while { [gets $fin line] >=0 } {
    # puts $line;
    if { [regexp {^#.*} $line] }  {
	    puts "$line --> header comments";
	    continue;
    }  elseif { [regexp {\S+\s*\,} $line] } {

       set tmp_string $line
       regsub -all (\,)+ $tmp_string "" tmp_string
       set tmp_string  [string trim $tmp_string]
       if {$tmp_string==""} { continue }

       set column_head [split [string trim $line] \,];
       set pad_idx [lsearch $column_head "*Pin Number*"];
       puts "pad_idx $pad_idx";
       set port_idx [lsearch $column_head "*Signal Name*"];
       set stand_idx [lsearch $column_head "*IO Standard*"];
       set slew_idx [lsearch $column_head "*Slew Rate*"];
       set head_detected 1;
       puts "Header :$line";
       break;
    }
  }

  if {$head_detected ==0} {
	  puts "ERROR: csv column head is not ";
	  return -1;
  }

   #debug

  #read the content
  while { [gets $fin line] >=0 } {
    # puts $line;
       set tmp_string $line;
       regsub -all (\,)+ $tmp_string "" tmp_string;
       set tmp_string  [string trim $tmp_string];
       if {$tmp_string==""} { continue; }

       set pad_row [split [string trim $line] \,];
       #puts "\{[lindex $pad_row $port_idx]\}";
       
       puts $fout  "set_property LOC [lindex $pad_row $pad_idx]  \[get_ports \{[string trim [lindex $pad_row $port_idx]]\}\]"; 
       #puts $fout [concat "set_property PACKAGE_PIN " [lindex $pad_row $pad_idx] "  " [lindex $pad_row $port_idx] {;}]; 
       puts $fout "set_property IOSTANDARD [lindex $pad_row $stand_idx] \[get_ports \{[lindex $pad_row $port_idx]\}\]"; 
       if { $slew_idx >0 && [string trim  [lindex $pad_row $slew_idx]] !="" } {
	       puts $fout "set_property SLEW [lindex $pad_row $slew_idx]  \[get_ports \{[lindex $pad_row $port_idx]\}\]"; 
       }

    
  }
  #- while gets $fin

 
 close $fin;
 close $fout;
 return 1;
# array get $property_name;
}
