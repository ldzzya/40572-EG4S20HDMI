"""Collect legacy/current load metrics; enlargement quality differs.

The frozen nearest-only reference verifies legacy RTL; current RTL uses the
bilinear-aware reference. Results do not overwrite the historical speed report.
"""
from pathlib import Path
import os,subprocess,concurrent.futures,re,json
r=Path(__file__).resolve().parents[1];out=r/'build/benchmark';out.mkdir(parents=True,exist_ok=True)
bind=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy()
env['PATH']=str(bind)+os.pathsep+str(bind.parent/'lib')+os.pathsep+env.get('PATH','')
for version,files in [('before',[r/'tests/baseline/bmp_read_before_speedup.v']),('after',[r/'src/user_source/hdl_source/SD/bmp_read.v',r/'src/user_source/hdl_source/SD/bmp_bilinear.v',r/'src/user_source/hdl_source/SD/scan_address_hint.v'])]:
 reference=r/('tests/baseline/tb_scaler_nearest.sv' if version=='before' else 'tests/tb_scaler.sv')
 subprocess.run([str(bind/'iverilog.exe'),'-g2012','-s','tb_scaler','-o',str(out/f'bench_{version}.vvp'),str(reference)]+list(map(str,files)),env=env,check=True)
jobs=[(v,w,h) for w,h in [(160,120),(320,240),(640,480),(800,600),(1280,720)] for v in ['before','after']]
def run(job):
 v,w,h=job
 p=subprocess.run([str(bind/'vvp.exe'),str(out/f'bench_{v}.vvp'),f'+W={w}',f'+H={h}'],env=env,capture_output=True,text=True,timeout=600)
 if p.returncode or 'PASS scaler' not in p.stdout:raise RuntimeError(p.stdout+p.stderr)
 m=re.search(r'sectors=(\d+) cycles=(\d+)',p.stdout)
 mode='bilinear' if v=='after' and w<=640 and h<=480 and (w<640 or h<480) else 'nearest/native'
 result=dict(version=v,width=w,height=h,scaling=mode,sectors=int(m[1]),cycles=int(m[2]))
 print(json.dumps(result),flush=True);return result
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,jobs))
(r/'docs/speed_quality_benchmark.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print('PASS metric collection; small-image interpolation quality differs between versions',flush=True)
