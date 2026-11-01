"""Verify nonzero physical ROM INIT contents against the delivered two-bit font hex files."""
from pathlib import Path
from collections import Counter
import re,json
r=Path(__file__).resolve().parents[1]
s=(r/'build/gate.v').read_text(errors='replace')
actual=[]
for body,name in re.findall(r'EG_PHY_BRAM\s*#\((.*?)\)\s+(\S+)\s+\(',s,re.S):
 # Parse each BRAM first, then filter names: constraining the name in the
 # regex can cross intervening instances and accidentally select a flip-flop.
 if not name.startswith('\\effects/menu_layer$overlay/font/'):continue
 words=re.findall(r'\.INIT_([0-9A-Fa-f]{2})\(256\x27h([0-9A-Fa-f]+)\)',body)
 assert len(words)==32,(name,len(words))
 value=sum(int(v,16)<<(int(i,16)*256) for i,v in words)
 if value:actual.append(value)
expected=[]
for n in ['ui_body','ui_title']:
 data=[int(x,16) for x in (r/f'src/user_source/hdl_source/{n}.hex').read_text().split()]
 for start in range(0,len(data),8192):
  for bit in range(2):
   v=sum(((x>>bit)&1)<<i for i,x in enumerate(data[start:start+8192]))
   if v:expected.append(v)
missing=Counter(expected)-Counter(actual)
assert not missing,f'{sum(missing.values())} font bit-plane blocks absent from synthesized BRAM INITs'
report={'expected_nonzero_blocks':len(expected),'actual_nonzero_font_blocks':len(actual),'all_expected_contents_present':True}
(r/'docs/font_rom_check.json').write_text(json.dumps(report,indent=2))
print('PASS font ROM netlist:',report)
