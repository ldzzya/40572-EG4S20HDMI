"""Reproducible self-checking RTL simulations. Python 3 + Icarus Verilog."""
from pathlib import Path
import argparse,os,shutil,subprocess,concurrent.futures
root=Path(__file__).resolve().parents[1]
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--iverilog-dir',type=Path,default=Path('D:/fpga/text/tools/oss-cad-suite/bin'))
    args=ap.parse_args();bindir=args.iverilog_dir
    iv=bindir/'iverilog.exe';vv=bindir/'vvp.exe'
    if not iv.exists():iv=Path(shutil.which('iverilog') or 'iverilog');vv=Path(shutil.which('vvp') or 'vvp')
    env=os.environ.copy();env['PATH']=str(bindir)+os.pathsep+str(bindir.parent/'lib')+os.pathsep+env.get('PATH','')
    out=root/'build/sim';out.mkdir(parents=True,exist_ok=True);hdl=root/'src/user_source/hdl_source'
    designs={'sector_bridge':['SD/sd_sector_bridge.v'],'scaler':['SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v'],'presenter':['frame_presenter.v'],
             'axis':['video_rgb_to_axis_640x480.v'],
             'display_chain':['SD/color_bar.v','SD/video_timing_data.v','SD/video_delay.v','video_effects.v','font8x16.v','SD/sd_card_bmp.v','tone_pcm_48k.v','audio_volume.v','audio_arc_calculate.v','video_rgb_to_axis_640x480.v'],
             'audio':['tone_pcm_48k.v','audio_arc_calculate.v'],
             'effects':['video_effects.v','font8x16.v','SD/sd_card_bmp.v'],
             'overlay':['video_effects.v','font8x16.v','SD/sd_card_bmp.v'],
             'wave_capture':['video_effects.v','font8x16.v','SD/sd_card_bmp.v'],
             'autoplay':['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v','SD/sd_sector_bridge.v','SD/sd_card_top.v','SD/sd_card_sec_read_write.v','SD/sd_card_cmd.v','SD/spi_master.v'],
             'sd_boot':['SD/scan_address_hint.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/sd_card_sec_read_write.v'],
             'scan_hint':['SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v'],
             'pipeline':['SD/sd_sector_bridge.v','SD/scan_address_hint.v','SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/sd_card_top.v','SD/sd_card_sec_read_write.v','SD/sd_card_cmd.v','SD/frame_fifo_write.v','frame_presenter.v']}
    for name,files in designs.items():
        cmd=[str(iv),'-g2012','-I',str(hdl/'SD'),'-s','tb_'+name,'-o',str(out/(name+'.vvp')),str(root/'tests'/('tb_'+name+'.sv'))]+[str(hdl/f) for f in files]
        r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=60)
        if r.returncode:raise RuntimeError(r.stdout+r.stderr)
    jobs=[('axis',[]),('display_chain',[]),('sector_bridge',[]),('presenter',[]),('audio',[]),('effects',[])]+[('scaler',a) for a in [
        ['+W=3','+H=2','+OFFSET=122'],['+W=320','+H=240'],['+W=640','+H=480'],
        ['+W=641','+H=479'],['+W=1920','+H=1080'],['+BAD=1'],['+TIMEOUT=1']]]
    jobs += [('overlay',[]),('sd_boot',[])]+[('scaler',['+FILE='+str(f)]) for f in sorted((root/'tests/fixtures').glob('*.bmp'))]
    jobs += [('scan_hint',['+KIND='+str(k)]) for k in range(5)]
    jobs += [('scaler',['+W='+str(w),'+H='+str(h)]) for w,h in [(1,1),(160,120),(321,241),(800,600),(1280,720),(1920,240)]]
    jobs += [('pipeline',['+FILE='+str(root/'tests/fixtures/example_2.bmp')])]
    jobs += [('autoplay',[]),('wave_capture',[])]
    jobs += [('scaler',['+W='+str(w),'+H='+str(h),'+PATTERN=1']) for w,h in [(1,480),(640,1),(639,479),(320,240)]]
    jobs += [('scaler',['+BAD='+str(k)]) for k in [2,3,4,5]]
    jobs += [('scaler',['+W=320','+H=240','+SEQUENCE=1'])]
    jobs += [('scaler',['+FILE='+str(f)]) for f in sorted((root/'demo_images').glob('*.bmp'))]
    def run(job):
        name,a=job;r=subprocess.run([str(vv),str(out/(name+'.vvp'))]+a,cwd=out,env=env,capture_output=True,text=True,timeout=900)
        text=r.stdout+r.stderr
        if r.returncode or 'PASS' not in text:raise RuntimeError(text)
        return text
    logs=[None]*len(jobs);failures=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        pending={pool.submit(run,job):i for i,job in enumerate(jobs)}
        for completed in concurrent.futures.as_completed(pending):
            i=pending[completed]
            try:result=completed.result()
            except Exception as e:
                result='FAIL '+repr(jobs[i])+'\n'+str(e);failures.append(i)
            logs[i]=result;print(result,flush=True)
            (out/f'case_{i:02d}_{jobs[i][0]}.log').write_text(result,encoding='utf-8')
    (root/'docs/simulation_results.txt').write_text('\n'.join(logs),encoding='utf-8')
    if failures:raise RuntimeError(f'{len(failures)} cases failed: {failures}')
    print(f'PASS all {len(jobs)} simulations')
if __name__=='__main__':main()
