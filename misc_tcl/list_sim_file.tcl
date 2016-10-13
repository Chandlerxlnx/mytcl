# create a new file and list all files in the file.
proc list_sim_file { filelist} {
  set fl [open $filelist w+];
  foreach fxci [get_files *.xci] {
    puts $fl [join [get_files -compile_order sources -used_in simulation -of_objects [get_files $fxci]] "\n"]; 
  }

  close $fl;
}
