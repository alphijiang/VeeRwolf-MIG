# SPDX-License-Identifier: Apache-2.0
# Create the two board-specific AMD IP blocks used by the Genesys 2 target.
# Each IP has its own output root so Vivado never sees shared XCI output paths.

if {[info exists ::veerwolf_genesys2_mig_loaded]} { return }
set ::veerwolf_genesys2_mig_loaded 1

set here [file dirname [file normalize [info script]]]
set mig_prj [file join $here mig.prj]
if {![file isfile $mig_prj]} {
    error "Digilent Genesys 2 H MIG project is missing: $mig_prj"
}

set mig_name design_1_mig_7series_0_0
set cdc_name genesys2_axi_clock_converter
set mig_root [file join $here generated_mig]
set cdc_root [file join $here generated_axi_cdc]
file mkdir $mig_root
file mkdir $cdc_root

if {![llength [get_ips -quiet $mig_name]]} {
    create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.2 \
        -module_name $mig_name -dir $mig_root
}
set_property CONFIG.XML_INPUT_FILE [file normalize $mig_prj] [get_ips $mig_name]

if {![llength [get_ips -quiet $cdc_name]]} {
    create_ip -name axi_clock_converter -vendor xilinx.com -library ip -version 2.1 \
        -module_name $cdc_name -dir $cdc_root
}
set_property -dict [list \
    CONFIG.PROTOCOL AXI4 \
    CONFIG.READ_WRITE_MODE READ_WRITE \
    CONFIG.ADDR_WIDTH 32 \
    CONFIG.DATA_WIDTH 64 \
    CONFIG.ID_WIDTH 6 \
    CONFIG.ACLK_ASYNC 1 \
    CONFIG.SYNCHRONIZATION_STAGES 3] [get_ips $cdc_name]

generate_target all [get_ips [list $mig_name $cdc_name]]

# Remove only stale project-file entries; keep the valid H project above.
foreach prj_file [get_files -all -quiet *.prj] {
    set prj_path [get_property NAME $prj_file]
    if {![file exists $prj_path]} {
        remove_files $prj_file
    }
}

update_compile_order -fileset sources_1
