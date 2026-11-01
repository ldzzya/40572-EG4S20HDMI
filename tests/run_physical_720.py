from pathlib import Path
import subprocess,os,sys,re
r=Path(__file__).resolve().parents[1];h=r/'src/user_source/hdl_source';out=r/'build/720_sim';out.mkdir(exist_ok=True)
bin=Path('D:/fpga/text/tools/oss-cad-suite/bin');env=os.environ.copy();env['PATH']=str(bin)+os.pathsep+str(bin.parent/'lib')+os.pathsep+env['PATH']
vendor=Path('C:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/sim_release/eg4')
# The PLL file supplies a public functional implementation. Its trailing
# protected section cannot be parsed by Icarus. No vendor file is modified.
# BRAM behavior is encrypted and is deliberately NOT claimed as verified here.
compat=out/'public_models';compat.mkdir(exist_ok=True)
for name in ['eg_phy_pll.v']:
 s=(vendor/name).read_text(errors='replace')
 s=re.sub(r'`pragma protect begin_protected.*?`pragma protect end_protected','',s,flags=re.S)
 # Vendor model declares load_reg scalar at the port but [4:0] internally.
 # Normalize that declaration for Icarus. All five bits are tied to zero in
 # this static-clock test; dynamic reconfiguration is not exercised.
 s=re.sub(r'input\s+load_reg;', 'input [4:0] load_reg;',s)
 (compat/name).write_text(s)
jobs={'clocks_720':('2005',[h/'IP/sys_pll.v',h/'IP/video_pll.v',compat/'eg_phy_pll.v'])}
for name,(version,files) in jobs.items():
 if len(sys.argv)>1 and name not in sys.argv[1:]:continue
 exe=out/(name+'.vvp');cmd=[str(bin/'iverilog.exe'),'-g'+version,'-s','tb_'+name,'-o',str(exe),str(r/'tests'/('tb_'+name+'.sv'))]+list(map(str,files))
 p=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=90);assert p.returncode==0,p.stderr
 p=subprocess.run([str(bin/'vvp.exe'),str(exe)],env=env,cwd=r,capture_output=True,text=True,timeout=180)
 text=p.stdout+p.stderr;(out/(name+'.log')).write_text(text);print(text,flush=True)
 assert p.returncode==0 and 'PASS' in text,name
