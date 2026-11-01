from pathlib import Path
import os,subprocess,concurrent.futures
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';out=r/'build/fit_sim';out.mkdir(exist_ok=True)
b=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(b)+';'+str(b.parent/'lib')+';'+env['PATH']
files=['SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v']
c=subprocess.run([str(b/'iverilog.exe'),'-g2012','-s','tb_scaler','-o',str(out/'scaler.vvp'),str(r/'tests/tb_scaler.sv')]+[str(h/f) for f in files],env=env,capture_output=True,text=True)
assert c.returncode==0,c.stderr
cases=[(1,1280,720),(1,600,800),(1,1,1080),(1,1920,1),(1,321,241),(1,640,480),(0,320,240),(0,640,480),(0,1920,1080)]
def run(case):
 fit,w,hh=case;n=f'fit{fit}_{w}x{hh}';c=subprocess.run([str(b/'vvp.exe'),str(out/'scaler.vvp'),f'+FIT={fit}',f'+W={w}',f'+H={hh}'],cwd=r,env=env,capture_output=True,text=True,timeout=900)
 s=c.stdout+c.stderr;(out/(n+'.log')).write_text(s);assert c.returncode==0 and 'PASS' in s,n+' '+s
 return n+' '+s
logs=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for f in concurrent.futures.as_completed([pool.submit(run,c) for c in cases]):
  s=f.result();logs.append(s);print(s,flush=True)
(r/'docs/ratio_checks.txt').write_text('\n'.join(logs))

