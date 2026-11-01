"""V4 menu checks plus the preserved V3 video/audio regression boundaries."""
from pathlib import Path
import os,subprocess,concurrent.futures,sys
root=Path(__file__).resolve().parents[1];h=root/'src/user_source/hdl_source'
out=root/'build/menu_sim';out.mkdir(parents=True,exist_ok=True)
bin=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy()
env['PATH']=str(bin)+os.pathsep+str(bin.parent/'lib')+os.pathsep+env.get('PATH','')
fx=['audio_bars.v','video_effects.v','font8x16.v','SD/sd_card_bmp.v']
menu=['menu_controller.v','key_gesture.v','menu_overlay.v','menu_font16.v','menu_strings.v','menu_phrase_rom.v']
jobs={'menu_control':['menu_controller.v','key_gesture.v','audio_volume.v'],
 'menu_render':['menu_overlay.v','menu_font16.v','menu_strings.v','menu_phrase_rom.v','font8x16.v'],
 'menu_pixels':fx+menu,
 'presenter':['frame_presenter.v'],'transition':['frame_presenter.v'],
 'menu_chain':fx+menu+['SD/color_bar.v','SD/video_timing_data.v','SD/video_delay.v','tone_pcm_48k.v','audio_volume.v','audio_arc_calculate.v','video_rgb_to_axis_640x480.v'],
 'controls':['key_gesture.v','audio_volume.v'],'subtitle':['subtitle_uart.v'],
 'overlay':fx,
 'display_chain':fx+['SD/color_bar.v','SD/video_timing_data.v','SD/video_delay.v','tone_pcm_48k.v','audio_volume.v','audio_arc_calculate.v','video_rgb_to_axis_640x480.v']}
def run(name,files):
 exe=out/(name+'.vvp');cmd=[str(bin/'iverilog.exe'),'-g2012','-DUI_SIMULATION','-I',str(h/'SD'),'-s','tb_'+name,'-o',str(exe),str(root/'tests'/('tb_'+name+'.sv'))]+[str(h/f) for f in files]
 c=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=90)
 if c.returncode:raise RuntimeError(f'{name}: {c.returncode}\n'+c.stdout+c.stderr)
 with (out/(name+'.log')).open('w',encoding='utf-8') as f:
  p=subprocess.Popen([str(bin/'vvp.exe'),str(exe)],cwd=root,env=env,stdout=f,stderr=subprocess.STDOUT,text=True)
  try:code=p.wait(timeout=600)
  except subprocess.TimeoutExpired:p.kill();p.wait();raise
 log=(out/(name+'.log')).read_text(encoding='utf-8')
 if code or 'PASS' not in log:raise RuntimeError(log)
 return log
if __name__=='__main__':
 selected={n:f for n,f in jobs.items() if len(sys.argv)==1 or n in sys.argv[1:]}
 logs=[];errors=[]
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  todo={pool.submit(run,n,f):n for n,f in selected.items()}
  for f in concurrent.futures.as_completed(todo):
   try:s=f.result()
   except Exception as e:s='FAIL '+todo[f]+': '+str(e);errors.append(s)
   logs.append(s);print(s,flush=True)
 (root/'docs/menu_checks.txt').write_text('\n'.join(logs),encoding='utf-8')
 if errors:raise SystemExit(1)
 print(f'PASS {len(logs)} checks')

