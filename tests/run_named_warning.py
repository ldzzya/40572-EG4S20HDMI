"""Regression for the v12 named-warning variant; never downloads hardware."""
import sys
from run_menu_checks import run,root
media=['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/rgb_row_ram.v','SD/scan_address_hint.v',
       'SD/sd_sector_bridge.v','frame_presenter.v','SD/fat32_catalog.v','SD/fat_file_sector.v',
       'SD/media_sector_arbiter.v','SD/wav_file_player.v','wav_pcm_48k.v']
jobs={'warning_catalog':['SD/fat32_catalog.v'],
      'named_warning':media+[str(root/'tests/tb_priority_media.sv')]}
# The full 1280x720 media integration takes much longer than the fast suite.
# Use run_modelsim_checks.py native_warning for that separate regression.
if __name__=='__main__':
 for name,files in jobs.items():
  if len(sys.argv)==1 or name in sys.argv[1:]:print(run(name,files),flush=True)
