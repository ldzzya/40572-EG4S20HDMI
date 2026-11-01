from pathlib import Path
import os,subprocess,concurrent.futures,sys
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';out=r/'build/bars_sim';out.mkdir(parents=True,exist_ok=True)
b=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(b)+';'+str(b.parent/'lib')+';'+env['PATH']
jobs={'audio_bars':['audio_bars.v','audio_volume.v'],'bars_schedule':['audio_bars.v'],
 'bars_render':['audio_bars.v','video_effects.v','font8x16.v','SD/sd_card_bmp.v','menu_overlay.v','menu_font16.v','menu_strings.v']}
def run(n,files):
 exe=out/(n+'.vvp');p=subprocess.run([str(b/'iverilog.exe'),'-g2012','-DUI_SIMULATION','-s','tb_'+n,'-o',str(exe),str(r/'tests'/('tb_'+n+'.sv'))]+[str(h/f) for f in files],env=env,capture_output=True,text=True)
 if p.returncode:raise RuntimeError(p.stderr)
 with (out/(n+'.log')).open('w') as log:
  p=subprocess.run([str(b/'vvp.exe'),str(exe)],cwd=r,env=env,stdout=log,stderr=subprocess.STDOUT,text=True,timeout=600)
 s=(out/(n+'.log')).read_text()
 if p.returncode or 'PASS' not in s:raise RuntimeError(s)
 return s
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 for f in concurrent.futures.as_completed([pool.submit(run,n,fs) for n,fs in jobs.items() if len(sys.argv)==1 or n in sys.argv[1:]]):print(f.result(),flush=True)
