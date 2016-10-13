#Read Me
= Script to sweep the strategies.

Usage:
    1) ln -s <your dcp file> top.dcp;
    2) run_seeds.sh;
    3) ./tns_grep.sh; to check the TNS/WNS

=Note:
   this is a template script to sweep the strategies. the current version will just sweep the placement strategies. feel free to modify to sweep other strategies. and the scripts is for Linux.
   files:
    1) top.dcp : the design file, it is opt_design dcp in current version
    2) run_1direct.sh: shell script to run single directive. called by run_seeds.sh;
    3) run_seeds.sh: shell script to  sweep all strategies listed in script.
    4) tns_grep.sh: small script to check the result
    5) tcl: folder to contain the tcl scripts
          a) tcl/run_directive.tcl: tcl script to run 1 implementation
    6) xdc: folder to contain the xdc.
    7) Run*: the generated folder which the implementation will run at.

==Attention==
  This is verified on ultrascale devices and vivado 2016.3. please remove the strategies which is not supported by your device and vivado.
