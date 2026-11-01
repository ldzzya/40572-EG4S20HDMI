from pathlib import Path
import sys,subprocess
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_menu_checks import run,root
if len(sys.argv)==1 or any(n in sys.argv[1:] for n in ("warning_media","warning_decode")):
 subprocess.run([sys.executable,"-X","utf8",str(root/"tests/test_warning_tool.py")],cwd=root,check=True)
jobs={'warning_media':['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v','SD/sd_sector_bridge.v','frame_presenter.v','SD/fat32_catalog.v','SD/fat_file_sector.v','SD/media_sector_arbiter.v','SD/wav_file_player.v','wav_pcm_48k.v'],
 'warning_decode':['SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v'],
 'warning_render':['video_effects.v','audio_bars.v','font8x16.v','SD/sd_card_bmp.v','menu_overlay.v','menu_font16.v','menu_strings.v']}
for n,files in jobs.items():
 if len(sys.argv)==1 or n in sys.argv[1:]:print(run(n,files),flush=True)
