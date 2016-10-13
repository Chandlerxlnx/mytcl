proc create_fifo {FIFO_NAME ip_path {fifo_dwidth 18} {fifo_depth 512} {ecc true} } {
  update_compile_order -fileset sources_1
  create_ip -name fifo_generator -version 10.0 -vendor xilinx.com -library ip -module_name $FIFO_NAME;
  set_property -dict [list CONFIG.Performance_Options {Standard_FIFO} CONFIG.Enable_ECC {$ecc} CONFIG.Almost_Full_Flag {true} CONFIG.Almost_Empty_Flag {true} CONFIG.Inject_Sbit_Error {false} CONFIG.Inject_Dbit_Error {false} CONFIG.Input_Data_Width {$fifo_dwidth} CONFIG.Input_Depth {$fifo_depth}  CONFIG.Use_Embedded_Registers {true}] [get_ips $FIFO_NAME]
  generate_target  {synthesis instantiation_template}  [get_files  ${ip_path}/${FIFO_NAME}.xci] -force
}

