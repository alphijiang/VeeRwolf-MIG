## Digilent Genesys 2 / VeeRwolf MIG board constraints.
## DDR3 and differential system-clock constraints remain owned by the generated
## MIG IP XDC under cores/mig/.
## No Tcl control flow is used in this XDC.

# External DMI JTAG clock on Pmod JC1.
create_clock -add -name jtag_tck_pin -period 100.000 -waveform {0 50} [get_ports {i_jtag_tck}]

# JC1 (AC26) is not a clock-capable input. Keep the low-speed adapter TCK on
# fabric routing instead of constraining an implementation-dependent IBUF net.
set_property CLOCK_BUFFER_TYPE NONE [get_ports {i_jtag_tck}]

# The official Cores-VeeR DMI wrapper synchronizes requests into clk_core.
# Resolve the core clock at its PLL output; sys_clk_p is a MIG instance port,
# while the actual top-level port is sysclk_p.
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks {jtag_tck_pin}] \
    -group [get_clocks -of_objects [get_pins {clk_gen/PLLE2_BASE_inst/CLKOUT0}]]

# Non-DDR board I/O. R19 intentionally has no internal PULLUP.
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports cpu_resetn]
set_property -dict {PACKAGE_PIN Y20 IOSTANDARD LVCMOS33} [get_ports i_uart_rx]
set_property -dict {PACKAGE_PIN Y23 IOSTANDARD LVCMOS33} [get_ports o_uart_tx]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports o_flash_cs_n]
set_property -dict {PACKAGE_PIN P24 IOSTANDARD LVCMOS33} [get_ports o_flash_mosi]
set_property -dict {PACKAGE_PIN R25 IOSTANDARD LVCMOS33} [get_ports i_flash_miso]
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS12} [get_ports {i_sw[0]}]
set_property -dict {PACKAGE_PIN G25 IOSTANDARD LVCMOS12} [get_ports {i_sw[1]}]
set_property -dict {PACKAGE_PIN H24 IOSTANDARD LVCMOS12} [get_ports {i_sw[2]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS12} [get_ports {i_sw[3]}]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS12} [get_ports {i_sw[4]}]
set_property -dict {PACKAGE_PIN P19 IOSTANDARD LVCMOS12} [get_ports {i_sw[5]}]
set_property -dict {PACKAGE_PIN P26 IOSTANDARD LVCMOS33} [get_ports {i_sw[6]}]
set_property -dict {PACKAGE_PIN P27 IOSTANDARD LVCMOS33} [get_ports {i_sw[7]}]
set_property -dict {PACKAGE_PIN T28 IOSTANDARD LVCMOS33} [get_ports {o_led[0]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {o_led[1]}]
set_property -dict {PACKAGE_PIN U30 IOSTANDARD LVCMOS33} [get_ports {o_led[2]}]
set_property -dict {PACKAGE_PIN U29 IOSTANDARD LVCMOS33} [get_ports {o_led[3]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports {o_led[4]}]
set_property -dict {PACKAGE_PIN V26 IOSTANDARD LVCMOS33} [get_ports {o_led[5]}]
set_property -dict {PACKAGE_PIN W24 IOSTANDARD LVCMOS33} [get_ports {o_led[6]}]
set_property -dict {PACKAGE_PIN W23 IOSTANDARD LVCMOS33} [get_ports {o_led[7]}]

# External DMI JTAG on Pmod JC pins 1-4.
set_property -dict {PACKAGE_PIN AC26 IOSTANDARD LVCMOS33} [get_ports {i_jtag_tck}]
set_property -dict {PACKAGE_PIN AJ27 IOSTANDARD LVCMOS33} [get_ports {i_jtag_tdi}]
set_property -dict {PACKAGE_PIN AH30 IOSTANDARD LVCMOS33} [get_ports {o_jtag_tdo}]
set_property -dict {PACKAGE_PIN AK29 IOSTANDARD LVCMOS33} [get_ports {i_jtag_tms}]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Synchronizers / point-to-point CDC exceptions proven in the MIG V53 line.
set_property ASYNC_REG TRUE [get_cells -quiet -hierarchical -regexp {.*(sw_r|sw_2r)_reg\[[0-7]\]$}]
set_property ASYNC_REG TRUE [get_cells -quiet -hierarchical -regexp {.*clk_gen/reset_sync_reg\[[0-2]\]$}]
set_property ASYNC_REG TRUE [get_cells -quiet -hierarchical -regexp {.*clk_gen/hold_rst_sync_reg\[[0-1]\]$}]
set_property ASYNC_REG TRUE [get_cells -quiet -hierarchical -regexp {.*mig_axi_resetn_sync_reg\[[0-2]\]$}]
set_property ASYNC_REG TRUE [get_cells -quiet -hierarchical -regexp {.*mig_init_done_sync_reg\[[0-1]\]$}]
set_property ASYNC_REG TRUE [get_cells -regexp {.*tap/i_dmi_jtag_to_core_sync/(rden|wren)_reg\[[0-2]\]$}]
set_false_path -to [get_pins -quiet -of_objects [get_cells -quiet -hierarchical -regexp {.*clk_gen/hold_rst_sync_reg\[0\]$}] -filter {REF_PIN_NAME == D}]
set_false_path -to [get_pins -quiet -of_objects [get_cells -quiet -hierarchical -regexp {.*mig_init_done_sync_reg\[0\]$}] -filter {REF_PIN_NAME == D}]
set_false_path -from [get_ports {i_sw[*]}] -to [get_pins -quiet -of_objects [get_cells -quiet -regexp {sw_r_reg\[[0-7]\]}] -filter {REF_PIN_NAME == D}]
set_false_path -from [get_ports cpu_resetn] -to [get_pins -quiet -of_objects [get_cells -quiet -hierarchical -regexp {.*clk_gen/reset_sync_reg\[[0-2]\]$}] -filter {REF_PIN_NAME == CLR || REF_PIN_NAME == PRE}]
