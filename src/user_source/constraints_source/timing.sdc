# 50 MHz board reference. All generated clocks are kept related.

# In particular HDMI pixel and serializer clocks are NOT mutually exclusive.

create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]

derive_clocks

rename_clock -name {ext_mem_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[1]}]

rename_clock -name {mem_shift_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[2]}]

rename_clock -name {video_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[0]}]

rename_clock -name {hdmi_5x_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[1]}]

# rst_all is exclusively the asynchronous input of three reset release chains.

# Functional logic uses each chain's synchronous release output.

set_false_path -through [get_nets {rst_all}]

# HDMI IP lock is a status indication sampled by hdmi_lock_sync[0:1] at 50 MHz.
# Exclude only the input to that two-register synchronizer, not its second stage
# and not the related pixel/serializer/data clocks or any audio/video path.
set_false_path -through [get_nets {hdmi_video_locked}]


rename_clock -name {spi_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[0]}]

# Video and its serializer remain one related clock group. The other service
# domains use asynchronous FIFOs or request/acknowledge synchronizers.
# This is NOT an exception for pixel, font, HDMI or SDRAM interface paths.
set_clock_groups -asynchronous -group {video_clk hdmi_5x_clk} -group {ext_mem_clk mem_shift_clk} -group {spi_clk} -group {clk}
