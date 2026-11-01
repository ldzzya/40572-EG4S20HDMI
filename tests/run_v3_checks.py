"""Focused, reproducible simulations for audio, UART, controls and video regression."""
from pathlib import Path
import os,subprocess,concurrent.futures
root=Path(__file__).resolve().parents[1];hdl=root/'src/user_source/hdl_source'
out=root/'build/v3_sim';out.mkdir(parents=True,exist_ok=True)
bindir=Path('D:/fpga/text/tools/oss-cad-suite/bin')
env=os.environ.copy();env['PATH']=str(bindir)+os.pathsep+str(bindir.parent/'lib')+os.pathsep+env.get('PATH','')
fx=['video_effects.v','font8x16.v','SD/sd_card_bmp.v']
jobs={'controls':['key_gesture.v','audio_volume.v'],'subtitle':['subtitle_uart.v'],
      'effects':fx,'overlay':fx,'wave_capture':fx,
      'audio_visual':fx+['subtitle_uart.v','audio_volume.v'],
      'audio':['tone_pcm_48k.v','audio_arc_calculate.v'],
      'axis':['video_rgb_to_axis_640x480.v'],
      'display_chain':fx+['SD/color_bar.v','SD/video_timing_data.v','SD/video_delay.v','tone_pcm_48k.v','audio_volume.v','audio_arc_calculate.v','video_rgb_to_axis_640x480.v']}
def run(name,files):
 exe=out/(name+'.vvp')
 cmd=[str(bindir/'iverilog.exe'),'-g2012','-I',str(hdl/'SD'),'-s','tb_'+name,'-o',str(exe),str(root/'tests'/('tb_'+name+'.sv'))]+[str(hdl/f) for f in files]
 c=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=90)
 if c.returncode:raise RuntimeError(f'{name}: compiler exit {c.returncode}\n'+c.stdout+c.stderr)
 c=subprocess.run([str(bindir/'vvp.exe'),str(exe)],cwd=out,env=env,capture_output=True,text=True,timeout=240)
 log=c.stdout+c.stderr;(out/(name+'.log')).write_text(log,encoding='utf-8')
 if c.returncode or 'PASS' not in log:raise RuntimeError(log)
 return log
if __name__=='__main__':
 from PIL import Image
 im=Image.open(root/'tests/fixtures/example_2.bmp').convert('RGB').resize((640,480))
 (out/'preview_photo.hex').write_text('\n'.join('%02x%02x%02x'%p for p in im.getdata()),encoding='ascii')
 logs=[];failures=[]
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  work={pool.submit(run,n,f):n for n,f in jobs.items()}
  for task in concurrent.futures.as_completed(work):
   try:s=task.result()
   except Exception as e:s='FAIL '+work[task]+': '+str(e);failures.append(s)
   print(s,flush=True);logs.append(s)
 (root/'docs/v3_checks.txt').write_text('\n'.join(logs),encoding='utf-8')
 if failures:raise SystemExit(1)
 print(f'PASS all {len(jobs)} v3 checks')
