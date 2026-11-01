from pathlib import Path
import sys, subprocess
from run_menu_checks import bin,env
r=Path(__file__).resolve().parents[1]
h=r/'src/user_source/hdl_source';out=r/'build/menu_sim';out.mkdir(parents=True,exist_ok=True)
src=['top_tf_hdmi_audio.v','priority_guard.v','menu_controller.v','key_gesture.v','frame_presenter.v','SD/video_timing_data.v','SD/video_delay.v','SD/color_bar.v','SD/frame_read_write.v','SD/frame_fifo_read.v','SD/frame_fifo_write.v','SD/rgb24_pack.v','SD/rgb24_unpack.v','warning_layer_cache.v']
if len(sys.argv)>1:h=Path(sys.argv[1])/'src/user_source/hdl_source'
cmd=[str(bin/'iverilog.exe'),'-g2012','-DUI_SIMULATION','-i','-I',str(h/'SD'),'-s','tb_boot_top','-o',str(out/'boot_top.vvp'),str(r/'tests/tb_boot_top.sv')]+[str(h/f) for f in src]
p=subprocess.run(cmd,env=env,capture_output=True,text=True)
(out/('boot_top_baseline_compile.log' if len(sys.argv)>1 else 'boot_top_compile.log')).write_text(p.stdout+p.stderr)
assert p.returncode==0,p.stderr
logpath=out/('boot_top_baseline.log' if len(sys.argv)>1 else 'boot_top.log')
with logpath.open('w') as log:
 p=subprocess.run([str(bin/'vvp.exe'),str(out/'boot_top.vvp')],env=env,stdout=log,stderr=subprocess.STDOUT,text=True,timeout=600)
print(logpath.read_text());sys.exit(p.returncode)
