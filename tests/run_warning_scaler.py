from pathlib import Path
import sys,subprocess,os
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';o=r/'build/warning_sim';o.mkdir(exist_ok=True)
b=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(b)+';'+str(b.parent/'lib')+';'+env.get('PATH','')
exe=o/'scaler.vvp';subprocess.run([str(b/'iverilog.exe'),'-g2012','-s','tb_scaler','-o',str(exe),str(r/'tests/tb_scaler.sv'),str(h/'SD/bmp_read.v'),str(h/'SD/bmp_bilinear.v'),str(h/'SD/scan_address_hint.v')],env=env,check=True)
for name,args in [('max_size',['+W=1920','+H=1080','+OFFSET=4096','+BYTE_GAP=1']),('portrait_fit',['+W=241','+H=321','+FIT=1','+BYTE_GAP=1'])]:
 p=subprocess.run([str(b/'vvp.exe'),str(exe)]+args,env=env,cwd=r,capture_output=True,text=True,timeout=600)
 log=p.stdout+p.stderr;(o/(name+'.log')).write_text(log);print(log,flush=True)
 assert p.returncode==0 and 'PASS' in log
