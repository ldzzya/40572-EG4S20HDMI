from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_menu_checks import run
jobs={'priority_video':['video_effects.v','audio_bars.v','SD/sd_card_bmp.v','font8x16.v','menu_overlay.v','menu_font16.v','menu_strings.v'],
      'priority_controls':['priority_guard.v','menu_controller.v','key_gesture.v'],
      'priority_catalog':['SD/fat32_catalog.v'],
      'priority_media':['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v','SD/sd_sector_bridge.v','frame_presenter.v','SD/fat32_catalog.v','SD/fat_file_sector.v','SD/media_sector_arbiter.v','SD/wav_file_player.v','wav_pcm_48k.v']}
for name,files in jobs.items():
 if len(sys.argv)==1 or name in sys.argv[1:]:print(run(name,files),flush=True)
