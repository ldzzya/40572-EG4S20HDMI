from pathlib import Path
import os,subprocess,concurrent.futures,sys
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';out=r/'build/storage_sim';out.mkdir(exist_ok=True)
b=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(b)+';'+str(b.parent/'lib')+';'+env['PATH']
core=['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v','SD/sd_sector_bridge.v','SD/sd_card_top.v','SD/sd_card_sec_read_write.v','SD/sd_card_cmd.v','SD/spi_master.v']
core += ['SD/fat32_catalog.v','SD/fat_file_sector.v','SD/media_sector_arbiter.v','SD/wav_file_player.v','wav_pcm_48k.v']
jobs={'autoplay':core,'pipeline':[f for f in core if f!='SD/spi_master.v']+['SD/frame_fifo_write.v','frame_presenter.v'],'sd_boot':['SD/scan_address_hint.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/sd_card_sec_read_write.v']}
def run(n,files):
 exe=out/(n+'.vvp');p=subprocess.run([str(b/'iverilog.exe'),'-g2012','-I',str(h/'SD'),'-s','tb_'+n,'-o',str(exe),str(r/'tests'/('tb_'+n+'.sv'))]+[str(h/f) for f in files],env=env,capture_output=True,text=True,timeout=90)
 assert p.returncode==0,p.stderr
 args=['+FILE='+str(r/'tests/fixtures/example_2.bmp')] if n=='pipeline' else []
 with (out/(n+'.log')).open('w') as logfile:
  p=subprocess.run([str(b/'vvp.exe'),str(exe)]+args,cwd=r,env=env,stdout=logfile,stderr=subprocess.STDOUT,text=True,timeout=900)
 s=(out/(n+'.log')).read_text();(out/(n+'.log')).write_text(s);assert p.returncode==0 and 'PASS' in s,n+' '+s
 return s
logs=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for f in concurrent.futures.as_completed([pool.submit(run,n,files) for n,files in jobs.items() if len(sys.argv)==1 or n in sys.argv[1:]]):
  s=f.result();logs.append(s);print(s,flush=True)
(r/'docs/storage_checks.txt').write_text('\n'.join(logs))


