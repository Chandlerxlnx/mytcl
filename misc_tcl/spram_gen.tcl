proc spram_gen { bram_name ip_path {bitwithW 32} {depthW 512} {bitwithR 8} {bytewe false} {CoreReg true}} {
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name ${bram_name};
set_property -dict [list CONFIG.Use_Byte_Write_Enable $bytewe \
            CONFIG.Byte_Size {8} \
            CONFIG.Write_Width_A $bitwithW \
            CONFIG.Write_Depth_A $depthW CONFIG.Read_Width_A $bitwithR \
               CONFIG.Register_PortA_Output_of_Memory_Core $CoreReg ] \
               [get_ips ${bram_name}];
puts "set property";
#generate_target {instantiation_template} [get_files ${ip_path}/${bram_name}/${bram_name}.xci]
#update_compile_order -fileset sources_1
generate_target all [get_ips $bram_name]; #[get_files  ${ip_path}/${bram_name}/${bram_name}.xci]
}
