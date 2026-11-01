from pathlib import Path
import subprocess,sys,os
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';out=r/'build/720_sim';out.mkdir(parents=True,exist_ok=True)
bin=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(bin)+os.pathsep+str(bin.parent/'lib')+os.pathsep+env['PATH']
jobs={
 'decode_720':['SD/bmp_read.v','SD/bmp_bilinear.v','SD/rgb_row_ram.v','SD/scan_address_hint.v'],
 'timing_720':['SD/color_bar.v','SD/video_timing_data.v','video_rgb_to_axis_640x480.v','video_effects.v','audio_bars.v','font8x16.v','menu_overlay.v','menu_font16.v','menu_strings.v','menu_phrase_rom.v'],
 'warning_render':['video_effects.v','audio_bars.v','font8x16.v','menu_overlay.v','menu_font16.v','menu_strings.v','menu_phrase_rom.v'],
 'audio_720':['wav_pcm_48k.v'],
 'packing_720':['SD/rgb24_pack.v','SD/rgb24_unpack.v'],
 'layer_720':['warning_layer_cache.v'],
 'memory_720':['SD/frame_read_write.v','SD/frame_fifo_write.v','SD/frame_fifo_read.v','SD/rgb24_pack.v','SD/rgb24_unpack.v','frame_presenter.v','IP/afifo_16_32_256.v','IP/afifo_32_16_256.v'],
}
for name,files in jobs.items():
 if len(sys.argv)>1 and name not in sys.argv[1:]:continue
 exe=out/(name+'.vvp')
 cmd=[str(bin/'iverilog.exe'),'-g2012','-DUI_SIMULATION','-I',str(h/'SD'),'-s','tb_'+name,'-o',str(exe),str(r/'tests'/('tb_'+name+'.sv'))]+[str(h/f) for f in files]
 c=subprocess.run(cmd,env=env,cwd=r,capture_output=True,text=True,timeout=90)
 (out/(name+'_compile.log')).write_text(c.stdout+c.stderr)
 assert c.returncode==0,c.stderr
 with (out/(name+'.log')).open('w') as log:
  p=subprocess.run([str(bin/'vvp.exe'),str(exe)],cwd=r,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900)
 text=(out/(name+'.log')).read_text();print(text,flush=True)
 assert p.returncode==0 and 'PASS' in text,name
