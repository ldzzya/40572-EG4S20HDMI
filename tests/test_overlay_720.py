from pathlib import Path
import sys,struct,json
from PIL import Image,ImageDraw,ImageOps
r=Path(__file__).resolve().parents[1];sys.path.insert(0,str(r/'tools'))
from prepare_warning import prepare
out=r/'build/overlay_720';out.mkdir(parents=True,exist_ok=True)
# Deliberately wide BMP: an absolute screen-top banner would fall in the black
# letterbox, the exact failure this regression must prevent.
bg=Image.new('RGB',(1600,400));bg.putdata([((x*3)%256,(y*5)%256,(x+y)%256) for y in range(400) for x in range(1600)])
bg.save(out/'source.bmp')
fg=Image.new('RGBA',(900,96));d=ImageDraw.Draw(fg)
d.rectangle((10,10,889,85),fill=(255,0,0,255));d.rectangle((32,25,860,70),fill=(255,255,255,128))
fg.save(out/'source.png')
report=prepare(out/'source.bmp',out/'source.png',out/'result/warning.bmp',fit='contain',trim_border=False)
data=(out/'result/warning.bmp').read_bytes()
assert struct.unpack_from('<ii',data,18)==(1280,720)
assert len(data)==64+1280*720*4 and data[6:10]==b'OVL9'
assert struct.unpack_from('<I',data,10)[0]==64
bx,by,br,bb=report['background_rect'];px,py,pr,pb=report['overlay_rect']
assert bx<=px<pr<=br and by<py<pb<bb and by>0,(report)
original=Image.new('RGB',(1280,720));original.paste(ImageOps.contain(bg,(1280,720),method=Image.Resampling.LANCZOS),(bx,by))
off=Image.open(out/'result/preview_off.png').convert('RGB');on=Image.open(out/'result/preview_on.png').convert('RGB')
assert off.tobytes()==original.tobytes(),'Overlay changed or shifted the base image'
base=off.load();visible=on.load();mask_count=0
for y in range(720):
 for x in range(1280):
  i=64+((719-y)*1280+x)*4;b,g,red,a=data[i:i+4]
  assert (red,g,b)==base[x,y]
  if a&3:assert px<=x<pr and py<=y<pb;mask_count+=1
  else:assert visible[x,y]==base[x,y]
assert mask_count>0 and on.tobytes()!=off.tobytes()
# Repair a previously letterboxed file: remove its outer canvas, stretch the
# complete content, and keep the blink mask independent of the RGB background.
canvas=Image.new('RGB',(1280,720));content=Image.new('RGB',(960,470),(73,144,211))
ImageDraw.Draw(content).rectangle((100,100,130,130),fill=(0,0,0))
canvas.paste(content,(160,126));canvas.save(out/'letterboxed.bmp')
fixed=prepare(out/'letterboxed.bmp',out/'source.png',out/'fixed/warning.bmp')
assert tuple(fixed['source_crop'])==(160,126,1120,596)
assert tuple(fixed['background_rect'])==(0,0,1280,720)
assert fixed['fit']=='stretch'
fixed_off=Image.open(out/'fixed/preview_off.png').convert('RGB')
fixed_on=Image.open(out/'fixed/preview_on.png').convert('RGB')
assert fixed_off.tobytes()==content.resize((1280,720),Image.Resampling.LANCZOS).tobytes()
payload=(out/'fixed/warning.bmp').read_bytes()
for y in range(720):
 for x in range(1280):
  i=64+((719-y)*1280+x)*4;b,g,red,a=payload[i:i+4]
  assert (red,g,b)==fixed_off.getpixel((x,y))
  if not(a&3):assert fixed_on.getpixel((x,y))==fixed_off.getpixel((x,y))
assert fixed['overlay_rect'][1]>=0 and fixed['overlay_rect'][3]<=96
try:prepare(out/'source.bmp',out/'source.png',out/'source.bmp')
except ValueError:pass
else:raise AssertionError('Input overwrite allowed')
# A solid reference image with spatially varying masks for real RTL decoding.
pixels=bytearray()
for y in range(720):
 for x in range(1280):
  m=0 if y<560 else (0xC0|((x//160)&3))
  pixels.extend((0x80,0x60,0x42,m))
header=data[:64]
(out/'packed.hex').write_text('\n'.join(f'{v:02x}' for v in header+pixels))
(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS 720p overlay: contain compatibility; outer-canvas trim and full-screen stretch; independent RGB/mask at every pixel; input protected')
