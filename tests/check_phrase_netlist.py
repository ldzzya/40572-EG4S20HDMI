from pathlib import Path
import re
from collections import Counter
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source'
s=(r/'build/gate.v').read_text(errors='replace');actual=[]
for body,name in re.findall(r'EG_PHY_BRAM32K\s*#\((.*?)\)\s+(\S+)\s+\(',s,re.S):
 if '/words/phrase_' not in name:continue
 pairs=re.findall(r"\.INIT_([0-9A-Fa-f]{2})\(256'([hb])([0-9A-Fa-f]+)\)",body)
 assert len(pairs)==128,(name,len(pairs))
 actual.append(sum(int(v,16 if radix=='h' else 2)<<(int(i,16)*256) for i,radix,v in pairs))
chars=[int(x,16) for x in (h/'menu_phrases.hex').read_text().split()]
expected=[]
for bank in range(4):
 expected.append(sum(max(0,c-32)<<(i*8) for i,c in enumerate(chars[bank*4096:(bank+1)*4096])))
assert not (Counter(expected)-Counter(actual)), 'Packed phrase contents missing from physical BRAM32K INITs'
print('PASS phrase ROM: all 16384 Chinese/English character positions match the synthesized packed RAM contents')
