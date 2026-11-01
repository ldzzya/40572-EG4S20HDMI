onerror {quit -f -code 1}
vmap work {C:/Users/87842/Documents/Codex/2026-10-01/new-chat/work/sdram_probe/work}
vlog {C:/Users/87842/Documents/Codex/2026-10-01/new-chat/outputs/hx4s20_multimedia_v12_720p_mem_fix/build/mapped_memory/full_memory_gate.v}
vlog -sv {C:/Users/87842/Documents/Codex/2026-10-01/new-chat/outputs/hx4s20_multimedia_v12_720p_mem_fix/build/mapped_memory/tb_vendor_full.sv}
vsim -suppress 3016,3017,3722 work.tb_vendor_full work.glbl
run -all
quit -f -code 0
