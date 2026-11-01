from pathlib import Path
import os,subprocess
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source'
out=r/'build/alignment_checks';out.mkdir(parents=True,exist_ok=True)
b=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy()
env['PATH']=str(b)+os.pathsep+str(b.parent/'lib')+os.pathsep+env['PATH']
exe=out/'wide.vvp'
subprocess.run([str(b/'iverilog.exe'),'-g2012','-s','tb_sdram_align_wide','-o',str(exe),
 str(h/'SD/sdram_stream_align.v'),str(h/'IP/afifo_16_32_256.v'),str(r/'tests/tb_sdram_align_wide.sv')],env=env,check=True)
p=subprocess.run([str(b/'vvp.exe'),str(exe)],env=env,capture_output=True,text=True,timeout=120)
(out/'wide.log').write_text(p.stdout+p.stderr)
assert p.returncode==0 and 'PASS wide calibration:' in p.stdout,p.stdout+p.stderr
print(p.stdout)
