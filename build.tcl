# All files are registered in multimedia_v12_720p.al.
# Open the project once: repeated multi-run / single-run opens in the same
# TD process crashed during encrypted-IP elaboration in a fresh directory.
set root [file normalize [file dirname [info script]]]
file mkdir "$root/build"
source "$root/compile.tcl"
