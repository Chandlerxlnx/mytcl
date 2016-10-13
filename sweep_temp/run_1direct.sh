#!/bin/sh
# scripts to launch vivado runs
#

run_dir="Run_$1"
echo $run_dir
if [ -e $run_dir ] ; then 
    rm -rf $run_dir
     mkdir $run_dir
else 
     mkdir $run_dir
fi
 
  cd $run_dir 
  ln -s ../top.dcp .

  ln -s ../tcl .
  ln -s ../xdc .
  mkdir rpt
  
  vivado -mode tcl -source ./tcl/run_directive.tcl -tclargs -place $1
  
  cd ..
  exit ;

