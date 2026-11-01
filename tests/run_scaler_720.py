from pathlib import Path
import subprocess,sys
from run_menu_checks import bin,env
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';o=r/'build/720_sim'
files=['bmp_read.v','bmp_bilinear.v','rgb_row_ram.v','scan_address_hint.v']
exe=o/'scaler_720.vvp'
p=subprocess.run([str(bin/'iverilog.exe'),'-g2012','-DUI_SIMULATION','-s','tb_scaler_720','-o',str(exe),str(r/'tests/tb_scaler_720.sv')]+[str(h/'SD'/f) for f in files],env=env,capture_output=True,text=True)
assert p.returncode==0,p.stderr
jobs={'upscale':['+W=321','+H=241'],
      'downscale':['+W=1920','+H=1080','+OFFSET=4096'],
      'portrait_fit':['+W=241','+H=321','+FIT=1'],
      'single_pixel':['+W=1','+H=1']}
for name,args in jobs.items():
 if len(sys.argv)>1 and name not in sys.argv[1:]:continue
 with (o/(name+'.log')).open('w') as log:
  p=subprocess.run([str(bin/'vvp.exe'),str(exe),'+BYTE_GAP=1']+args,env=env,cwd=r,stdout=log,stderr=subprocess.STDOUT,timeout=600)
 text=(o/(name+'.log')).read_text();print(text,flush=True)
 assert p.returncode==0 and 'PASS' in text,name
