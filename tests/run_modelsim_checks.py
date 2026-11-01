"""Focused vendor-controller and full-size emergency-media regressions.

No hardware I/O. Requires the installed TD and ModelSim tools. Run from any
directory: python tests/run_modelsim_checks.py controller | native_warning
"""
from pathlib import Path
import argparse, os, subprocess

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('test',choices=['controller','alignment','native_warning'])
parser.add_argument('--td',default='C:/Anlogic/TD_6.2.1_Engineer_6.2.168.116')
parser.add_argument('--modelsim',default='D:/fpga/quar/modelsim_ase/win32aloem/vsim.exe')
args=parser.parse_args()
td=Path(args.td); src=root/'src/user_source/hdl_source'
out=root/'build'/({'controller':'controller_sim','alignment':'alignment_vendor','native_warning':'native_modelsim'}[args.test])
out.mkdir(parents=True,exist_ok=True)
q=lambda p:'{'+Path(p).as_posix()+'}'
env=os.environ.copy()

if args.test in ('controller','alignment'):
    # Export a mapped controller from the actual registered TD source list.
    # This avoids replacing the encrypted controller with an idealized mock.
    export=out/'export_controller.tcl'
    export.write_text('\n'.join([
        'cd '+q(root),'import_device eagle_s20.db -package EG4S20BG256',
        'open_project -single_run ./multimedia_v12_720p.al',
        'elaborate -top sdr_as_ram','optimize_rtl','optimize_gate',
        'write_verilog '+q(out/'controller_gate.v'),'close_project','exit'])+'\n')
    with (out/'export_controller.log').open('w') as log:
        subprocess.run([str(td/'bin/td_commands_prompt.exe'),str(export)],cwd=root,
                       env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
    lib=td/'sim_release'
    commands=['vlib work','vmap work '+q(out/'work')]
    commands+=['vlog -sv -timescale 1ns/1ps -permissive '+' '.join(q(lib/'common'/n) for n in ['al_map_lut.v','al_map_seq.v','al_phy_glbl.v'])]
    commands+=['vlog -permissive '+' '.join(q(lib/'eg4'/n) for n in ['eg_logic_io.v','eg_phy_dff.v','eg_phy_pad.v','eg_phy_lslice.v','eg_phy_mslice.v','eg_phy_config.v'])]
    commands+=['vlog '+q(out/'controller_gate.v')]
    rtl=['SD/frame_read_write.v','SD/frame_fifo_write.v','SD/frame_fifo_read.v',
         'SD/rgb24_pack.v','SD/rgb24_unpack.v','frame_presenter.v',
         'IP/afifo_16_32_256.v','IP/afifo_32_16_256.v']
    name='align_controller' if args.test=='alignment' else 'frame_controller'
    if args.test=='alignment':rtl.append('SD/sdram_stream_align.v')
    commands+=['vlog -sv '+' '.join(q(src/n) for n in rtl)+' '+q(root/('tests/sdram/tb_'+name+'.sv'))+' '+q(root/'tests/sdram/sdram_model.sv')]
    commands+=['vsim -voptargs=+acc -suppress 3016,3017,3722 work.tb_'+name+' work.glbl']
    expected='PASS calibration + actual controller + FIFO:' if args.test=='alignment' else 'PASS actual controller + FIFO:'
else:
    fixture=root/'build/overlay_720/packed.hex'
    if not fixture.is_file():
        raise SystemExit('Generate fixture first: python tests/test_overlay_720.py')
    rtl=['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/rgb_row_ram.v',
         'SD/scan_address_hint.v','SD/sd_sector_bridge.v','frame_presenter.v',
         'SD/fat32_catalog.v','SD/fat_file_sector.v','SD/media_sector_arbiter.v',
         'SD/wav_file_player.v','wav_pcm_48k.v','SD/frame_read_write.v',
         'SD/frame_fifo_read.v','SD/frame_fifo_write.v','SD/rgb24_pack.v',
         'SD/rgb24_unpack.v','IP/afifo_16_32_256.v','IP/afifo_32_16_256.v']
    commands=['vlib work','vmap work '+q(out/'work')]
    commands+=['vlog -sv +define+UI_SIMULATION '+q('+incdir='+str(src/'SD'))+' '+
               ' '.join(q(src/n) for n in rtl)+' '+q(root/'tests/tb_native_warning.sv')]
    commands+=['vsim -suppress 3016,3017,3722 work.tb_native_warning '+q('+PACKED_HEX='+str(fixture))]
    name='native_warning'; expected='PASS native warning integration:'

script=out/'run.do'
script.write_text('\n'.join(['onerror {quit -f -code 1}']+commands+['run -all','quit -f -code 0'])+'\n')
logpath=out/(name+'.log')
with (out/(name+'_console.log')).open('w') as console:
    result=subprocess.run([args.modelsim,'-c','-l',str(logpath),'-do',str(script)],
                           cwd=out,stdout=console,stderr=subprocess.STDOUT,timeout=7200)
text=logpath.read_text(errors='replace')
assert result.returncode==0 and expected in text and '** Fatal:' not in text,logpath
print('\n'.join(line for line in text.splitlines() if 'PASS' in line))
