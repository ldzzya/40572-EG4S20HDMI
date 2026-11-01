from pathlib import Path
import os,subprocess,sys
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';out=r/'build/wav_sim';out.mkdir(parents=True,exist_ok=True)
b=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(b)+os.pathsep+str(b.parent/'lib')+os.pathsep+env.get('PATH','')
jobs={'wav_resume':['SD/wav_file_player.v','wav_pcm_48k.v'],'wav_player':['SD/wav_file_player.v','wav_pcm_48k.v'],
      'media_pipeline':['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v','SD/sd_sector_bridge.v','frame_presenter.v','SD/fat32_catalog.v','SD/fat_file_sector.v','SD/media_sector_arbiter.v','SD/wav_file_player.v','wav_pcm_48k.v'],
      'fat_media':['SD/fat32_catalog.v','SD/fat_file_sector.v','SD/media_sector_arbiter.v'],
      'audio_bars':['audio_bars.v','audio_volume.v']}
for n,files in jobs.items():
 if len(sys.argv)>1 and n not in sys.argv[1:]:continue
 exe=out/(n+'.vvp')
 c=subprocess.run([str(b/'iverilog.exe'),'-g2012','-DUI_SIMULATION','-s','tb_'+n,'-o',str(exe),str(r/'tests'/('tb_'+n+'.sv'))]+[str(h/f) for f in files],env=env,capture_output=True,text=True)
 if c.returncode:print(c.stdout+c.stderr);raise SystemExit(c.returncode)
 p=subprocess.run([str(b/'vvp.exe'),str(exe)],cwd=r,env=env,capture_output=True,text=True,timeout=900)
 log=p.stdout+p.stderr;(out/(n+'.log')).write_text(log);print(log,flush=True)
 if p.returncode or 'PASS' not in log:raise SystemExit(p.returncode or 1)
