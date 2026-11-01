from run_menu_checks import bin,env,root,h,out
import subprocess
exe=out/'resume_race.vvp'
p=subprocess.run([str(bin/'iverilog.exe'),'-g2012','-i','-s','tb_resume_race','-o',str(exe),str(root/'tests/tb_resume_race.sv'),str(h/'SD/sd_card_bmp.v'),str(h/'SD/wav_file_player.v'),str(h/'wav_pcm_48k.v')],env=env,capture_output=True,text=True);assert p.returncode==0,p.stderr
p=subprocess.run([str(bin/'vvp.exe'),str(exe)],env=env,capture_output=True,text=True,timeout=30)
(out/'resume_race.log').write_text(p.stdout+p.stderr);print(p.stdout+p.stderr);assert p.returncode==0
