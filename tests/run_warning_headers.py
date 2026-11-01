from pathlib import Path
import os,subprocess
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';o=r/'build/warning_sim'
b=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(b)+';'+str(b.parent/'lib')+';'+env.get('PATH','')
exe=o/'headers.vvp'
subprocess.run([str(b/'iverilog.exe'),'-g2012','-s','tb_scaler','-o',str(exe),str(r/'tests/tb_scaler.sv'),str(h/'SD/bmp_read.v'),str(h/'SD/bmp_bilinear.v'),str(h/'SD/scan_address_hint.v')],env=env,check=True)
base=(o/'ordinary.bmp').read_bytes();logs=[]
for offset,value in [(0,0),(1,0),(19,8),(20,1),(21,128),(23,8),(24,1),(25,255),(26,2),(27,1),(30,1),(31,1),(32,1),(33,1)]:
 data=bytearray(base);data[offset]=value;p=o/'invalid.bmp';p.write_bytes(data)
 result=subprocess.run([str(b/'vvp.exe'),str(exe),'+FILE='+str(p),'+BAD=1'],cwd=r,env=env,capture_output=True,text=True,timeout=30)
 assert result.returncode==0 and 'pixels=0' in result.stdout,(offset,value,result.stdout,result.stderr)
 logs.append(f'PASS invalid header byte {offset} value {value}: rejected without pixels')
(o/'invalid_headers.log').write_text('\n'.join(logs),encoding='utf-8');print('\n'.join(logs))
