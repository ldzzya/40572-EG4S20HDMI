"""Verify this V12 memory-repair candidate, without accessing the board/card."""
from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
r=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((r/'docs/build_evidence.json').read_text())
for f,d in b['files'].items():assert sha(r/f)==d,f
for f,d in b['source_hashes'].items():assert sha(r/f)==d,f
log=(r/b['final_route_log']).read_text(errors='replace')
assert 'Generate bits file' in log and not re.search(r'\bERROR:',log)
t=(r/'build/timing.rpt').read_text(errors='replace')
timing={k:float(re.search(k+r':\s+(-?[\d.]+)ns',t)[1]) for k in ['SWNS','STNS','HWNS','HTNS']}
assert timing['SWNS']>=0 and timing['HWNS']>=0 and timing['STNS']==timing['HTNS']==0,timing
assert re.search(r'74\.250\s+\d+\s+video_clk',t)
area=(r/'build/route.area').read_text();util={}
for k in ['lut','reg','bram','bram32k','dsp']:
 m=re.search(r'^#'+k+r'\s+(\d+)\s+out of\s+(\d+)',area,re.M);assert m,k
 util[k]={'used':int(m[1]),'available':int(m[2])};assert int(m[1])<=int(m[2]),k
prj=(r/'multimedia_v12_720p.al').read_text(encoding='utf-8')
files=ET.fromstring(prj.replace('UsedInP&R','UsedInP&amp;R')).findall('.//Source_Files//File')
assert all((r/f.attrib['Path']).is_file() for f in files)
checks={}
for rel in ['alignment_checks/wide.log','mapped_memory/custom.log','mapped_memory/micron.log',
            'menu_sim/boot_top.log','menu_sim/warning_catalog.log','menu_sim/named_warning.log']:
 p=r/'build'/rel;s=p.read_text(errors='replace')
 assert 'PASS ' in s and not re.search(r'(?:^|\n)(?:#\s*)?(?:FATAL|FAIL|ERROR|\*\*\s+(?:Fatal|Error))',s),p
 assert 'ERROR:' not in s,p
 checks[rel]={'sha256':sha(p),'passed':[x.strip() for x in s.splitlines() if 'PASS ' in x]}
mapped=json.loads((r/'docs/mapped_memory_evidence.json').read_text())
assert mapped['tested_gate_sha256']==sha(r/'build/gate.v')
for m in mapped['checks'].values():assert sha(r/m['log'])==m['sha256']
for n in ['font_rom_check.json','control_netlist_check.json','phrase_netlist_check.json']:assert (r/'docs'/n).is_file(),n
audit=json.loads((r/'docs/change_audit.json').read_text(encoding='utf-8'))
for rel,digest in audit['unchanged_source_files'].items():assert sha(r/rel)==digest,rel
for item in audit['inherited_checks'].values():
 for rel,digest in item['unchanged_dependencies'].items():assert sha(r/rel)==digest,rel
 assert sha(r/item['log'])==item.get('log_sha256',item.get('sha256'))
h=r/'src/user_source/hdl_source'
assert 'BURST_SIZE             = 192' in (h/'SD/frame_read_write.v').read_text()
assert 'wrusedw<(512-BURST_SIZE)' in (h/'SD/frame_read_write.v').read_text()
assert '49500000/1000*64/4096' in (h/'include/global_def.v').read_text()
bit=r/'build/multimedia_v12_720p.bit';assert bit.stat().st_size>700000
report={'baseline':'V12 only','resolution':[1280,720],'refresh_hz':60,'audio_hz':48000,'picture_rgb_bits':24,
 'timing_ns':timing,'resources':util,'fresh_checks':checks,'inherited_checks':audit['inherited_checks'],
 'bit':{'path':'build/multimedia_v12_720p.bit','sha256':sha(bit),'bytes':bit.stat().st_size},
 'gate_sha256':sha(r/'build/gate.v'),'hardware_download_performed':False,
 'limitations':['Physical colour/seams and F recovery await board test; original F has not been reproduced exactly.',
 'Mapped simulations are functional, not SDF/electrical verification.',
 'Whole-word calibration handles shifts from -2 through +2 clocks; it cannot repair unstable analog sampling.',
 'The complete full-size emergency system was not rerun end-to-end; current control/media regressions and unchanged decoder/scaler hashes are recorded separately.']}
(r/'docs/release_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS release',timing,util,'BIT',sha(bit))
