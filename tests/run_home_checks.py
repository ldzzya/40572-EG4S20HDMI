from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_menu_checks import run
jobs={'background_catalog':['SD/fat32_catalog.v'],'resume_media':['SD/sd_card_bmp.v','SD/bmp_read.v','SD/bmp_bilinear.v','SD/scan_address_hint.v','SD/sd_sector_bridge.v','frame_presenter.v','SD/fat32_catalog.v','SD/fat_file_sector.v','SD/media_sector_arbiter.v','SD/wav_file_player.v','wav_pcm_48k.v'], 'pcm_pause':['wav_pcm_48k.v']}
# Recreate the exact OVL9 fixture for a fresh checkout/build directory.
if len(sys.argv)==1 or 'resume_media' in sys.argv[1:]:
 root=Path(__file__).resolve().parents[1]
 out=root/'build/warning_sim';out.mkdir(parents=True,exist_ok=True)
 (out/'packed.hex').write_text('\n'.join(f'{b:02x}' for b in (root/'tests/fixtures/home_warning.bmp').read_bytes()))
for n,files in jobs.items():
 if len(sys.argv)==1 or n in sys.argv[1:]:print(run(n,files),flush=True)
