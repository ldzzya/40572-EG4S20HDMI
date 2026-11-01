set root [file dirname [info script]]
cd "$root"
import_device eagle_s20.db -package EG4S20BG256
open_project -single_run ./multimedia_v12_720p.al
set_param gate pack_effort high
elaborate -top top
read_adc ./src/user_source/constraints_source/pin.adc
optimize_rtl
read_sdc ./src/user_source/constraints_source/timing.sdc
optimize_gate
legalize_phy_inst
read_sdc ./src/user_source/constraints_source/timing.sdc
export_db "$root/build/gate.db"
write_verilog "$root/build/gate.v"
report_area -file "$root/build/gate.area"
set_param place seed 1
place
# Match TD's documented drHoldFix flow: finish routing first, then repair
# hold timing as a separate step. This avoids collisions during incremental
# reset-net rerouting; hold checks still have to pass in the final report.
set_param route fix_hold off
set_param flow qor_monitor off
route
fix_hold
set_param route fix_hold on
set_param flow qor_monitor on
export_db "$root/build/route.db"
report_area -file "$root/build/route.area"
update_timing -mode final
report_timing_summary -file "$root/build/timing.rpt"
set timingFile [open "$root/build/timing.rpt" r]
set finalTiming [read $timingFile]
close $timingFile
if {![regexp {STNS:\s+0\.000ns} $finalTiming] || ![regexp {HTNS:\s+0\.000ns} $finalTiming]} {
 error "Final setup or hold timing failed; no new BIT generated."
}
bitgen -bit "$root/build/multimedia_v12_720p.bit"
close_project
exit


