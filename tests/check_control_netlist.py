from pathlib import Path
import re,json,sys
r=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
s=(r/'build/gate.v').read_text(errors='replace');log=(r/'build/compile.log').read_text(errors='replace')
bad=[x for x in log.splitlines() if re.search(r'HDL-5314|SYN-5013|HDL-7225|HDL-5373',x) and not re.search(r'src/user_source/hdl_source/(include/sdr_wrrd.enc.v|menu_font16.v)|HDL-5314 Similar messages',x)]
assert not bad,'Signal construction failed:\n'+'\n'.join(bad)
seq={}
for m in re.finditer(r'AL_MAP_SEQ\s*#\((.*?)\)\s+(\S+)\s*\((.*?)\);',s,re.S):seq[m[2]]=(m[1],m[3])
# Live-menu v12 never pauses playback: TD may fold this register to constant 1.
boot_reg=seq.get(r'\controls/playback_requested_reg')
if boot_reg:
 assert '.REGSET("SET")' in boot_reg[0], 'boot playback not initialized high'
else:
 controller=(r/'src/user_source/hdl_source/menu_controller.v').read_text()
 values=re.findall(r'playback_requested\s*<=\s*([^;]+);',controller)
 assert values and all(v.strip()=='1' for v in values), 'playback constant changed'
 boot_log=(r/'build/menu_sim/boot_top.log').read_text()
 assert 'PASS actual top: automatic boot play' in boot_log, 'run actual top simulation first'
assert 'home_frame' not in s,'obsolete home buffer selector remains'
for name in ['session_active_reg','saved_index_reg','saved_buf_reg','saved_position_reg','saved_samples_reg','restore_inflight_reg']:
 assert any(name in n for n in seq),name+' optimized away'
t=(r/'build/timing.rpt').read_text(errors='replace')
assert re.search(r'STNS:\s+0\.000ns',t) and re.search(r'HTNS:\s+0\.000ns',t)
report={'boot_playback_verified_by':'register initialization' if boot_reg else 'constant source plus actual top simulation','home_buffer_selector_removed':True,'checkpoint_registers_present':True,'no_unexpected_signal_warnings':True,'setup_and_hold_TNS_zero':True,'exceptions':'existing encrypted SDRAM IP and separately checked readmemh font ROM warnings'}
(r/'docs/control_netlist_check.json').write_text(json.dumps(report,indent=2))
print('PASS final synthesis controls and timing:',report)
