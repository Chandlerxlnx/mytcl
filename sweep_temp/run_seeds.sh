#!/bin/sh
# scripts to launch vivado runs
#
echo args is $1;

#pp_directive="Explore ExtraTimingOpt";
pp_directive="SSI_SpreadLogic_high Explore ExtraTimingOpt WLDrivenBlockPlacement AltSpreadLogic_low AltSpreadLogic_medium ExtraNetDelay_high AltSpreadLogic_high ExtraPostPlacementOpt";

for directive in $pp_directive; do
   echo directive is ${directive};
    direct_arg=$directive;
   ./run_1direct.sh ${direct_arg} ;
done
