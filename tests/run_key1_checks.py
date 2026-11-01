"""Focused checks for the isolated KEY1 hold-time experiment; Python + Icarus."""
from pathlib import Path
import os,subprocess,concurrent.futures
root=Path(__file__).resolve().parents[1]
hdl=root/'src/user_source/hdl_source'
out=root/'build/key1_sim';out.mkdir(parents=True,exist_ok=True)
bindir=Path('D:/fpga/text/tools/oss-cad-suite/bin')
env=os.environ.copy();env['PATH']=str(bindir)+os.pathsep+str(bindir.parent/'lib')+os.pathsep+env.get('PATH','')

# Extract the compiled top's actual reset block, including all domain chains.
# Encrypted board IP prevents simulation of the entire top with Icarus.
top=(hdl/'top_tf_hdmi_audio.v').read_text(encoding='utf-8')
block=top[top.index('wire rst_all;'):top.index('wire commit_toggle,commit_ack')]
wrapper='''module reset_under_test(input clk,rst_n,pll_ok,spi_clk,ext_mem_clk,video_clk,
 output a,s,m,v);
wire rst_spi;
wire sd_card_clk=video_clk;
'''+block+'''
assign sys_lock=pll_ok;
assign video_lock=pll_ok;
assign a=rst_all;assign s=rst_spi;assign m=rst_mem;assign v=rst_video;
endmodule
'''
(out/'reset_under_test.v').write_text(wrapper,encoding='utf-8')

# Reuse the existing self-checking display bench, resetting its scoreboards and
# repeating full frame/audio checks after two asynchronous mid-frame resets.
warm=(root/'tests/tb_display_chain.sv').read_text(encoding='utf-8')
warm=warm.replace('module tb_display_chain;','module tb_display_restart;\nreg epoch_done=0;integer boot;')
warm=warm.replace(' if(!rst) begin',''' if(rst) begin
  pixels=0;lines=0;frames=0;samples=0;nonzero=0;col=0;lit=0;cycles=0;previous_sof=0;acrs=0;epoch_done=0;
 end else begin''',1)
warm=warm.replace('if(frames==3) begin','if(frames==3 && !epoch_done) begin')
start=warm.index('   $display("PASS display chain:')
end=warm.index('\n',start)
warm=warm[:start]+'   epoch_done=1; $display("CHECK restart epoch %0d: two complete frames verified",boot); $fflush();'+warm[end:]
warm=warm.replace('initial begin repeat(8) @(negedge clk);rst=0;end','''initial begin
 repeat(8) @(negedge clk);rst=0;
 for(boot=0;boot<3;boot=boot+1) begin
  wait(epoch_done);
  if(boot<2) begin
   repeat(1234+boot*321) @(negedge clk);#7;rst=1;
   repeat(20) @(negedge clk);rst=0;
  end
 end
 $display("PASS video restart: cold boot and 2 mid-frame resets; 6 complete frames, AXIS markers, PCM and ACR recover");$finish;
end''')
warm=warm.replace('#60000000;','#180000000;')
(out/'tb_display_restart.sv').write_text(warm,encoding='utf-8')

jobs={
 'key1_hold':([root/'tests/tb_key1_hold.sv',out/'reset_under_test.v'],['frame_presenter.v']),
 'axis':([root/'tests/tb_axis.sv'],['video_rgb_to_axis_640x480.v']),
 'display_restart':([out/'tb_display_restart.sv'],['SD/color_bar.v','SD/video_timing_data.v','SD/video_delay.v',
  'video_effects.v','font8x16.v','SD/sd_card_bmp.v','tone_pcm_48k.v','audio_volume.v','audio_arc_calculate.v','video_rgb_to_axis_640x480.v'])}
def run(name,files):
    bench,design=files;exe=out/(name+'.vvp')
    c=subprocess.run([str(bindir/'iverilog.exe'),'-g2012','-I',str(hdl/'SD'),'-s','tb_'+name,'-o',str(exe)]+
                     list(map(str,bench))+[str(hdl/f) for f in design],env=env,capture_output=True,text=True,timeout=60)
    if c.returncode:raise RuntimeError(c.stdout+c.stderr)
    with (out/(name+'.log')).open('w',encoding='utf-8') as stream:
        proc=subprocess.Popen([str(bindir/'vvp.exe'),str(exe)],env=env,stdout=stream,stderr=subprocess.STDOUT,text=True)
        try:code=proc.wait(timeout=600)
        except subprocess.TimeoutExpired:proc.kill();proc.wait();raise
    result=(out/(name+'.log')).read_text(encoding='utf-8')
    if code or 'PASS' not in result:raise RuntimeError(result)
    return result
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    futures=[pool.submit(run,n,f) for n,f in jobs.items()]
    logs=[]
    for f in concurrent.futures.as_completed(futures):
        logs.append(f.result());print(logs[-1],flush=True)
(root/'docs/key1_checks.txt').write_text('\n'.join(logs),encoding='utf-8')
print('PASS all 3 focused KEY1 checks')
