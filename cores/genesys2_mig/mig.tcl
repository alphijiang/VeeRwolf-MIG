# SPDX-License-Identifier: Apache-2.0
# Fixed Genesys 2 MIG/AXI Clock Converter import.
# The XCI files and their generated output products are checked in under
# cores/mig. Normal FuseSoC/Vivado builds do not create or regenerate IP.

if {[info exists ::veerwolf_mig_fixed_ip_loaded]} { return }
set ::veerwolf_mig_fixed_ip_loaded 1

set here [file dirname [file normalize [info script]]]
set mig_xci [file join $here design_1_mig_7series_0_0 design_1_mig_7series_0_0.xci]
set cdc_xci [file join $here genesys2_axi_clock_converter genesys2_axi_clock_converter.xci]

foreach xci [list $mig_xci $cdc_xci] {
    if {![file isfile $xci]} { error "VeeRwolf fixed MIG IP missing: $xci" }
    read_ip $xci
}

# Do not retain stale MIG project-file references in the generated XPR.  A
# valid mig.prj remains packaged beside the MIG XCI and is not removed here.
foreach mig_prj [get_files -all -quiet *.prj] {
    set mig_prj_path [get_property NAME $mig_prj]
    if {![file exists $mig_prj_path]} {
        remove_files $mig_prj
    }
}

update_compile_order -fileset sources_1
