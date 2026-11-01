from pathlib import Path
import sys,hashlib,struct
from PIL import Image,ImageDraw,ImageFont
r=Path(__file__).resolve().parents[1];sys.path.insert(0,str(r/'tools'))
from prepare_warning import prepare
from check_media import bmp_info
p=r/'build/warning_sim';p.mkdir(parents=True,exist_ok=True)
bg=Image.new('RGB',(640,480),(66,96,128));bg.save(p/'background.bmp')
layer=Image.new('RGBA',(640,80));layer.putdata([(255,0,0,(0,64,192,255)[(x//16)%4]) for y in range(80) for x in range(640)])
layer.save(p/'layer.png');before=hashlib.sha256((p/'background.bmp').read_bytes()).hexdigest()
report=prepare(p/'background.bmp',p/'layer.png',p/'warning.bmp')
assert report['copy_to_tf']==['warning.bmp','your existing warning.wav']
assert hashlib.sha256((p/'background.bmp').read_bytes()).hexdigest()==before
b=(p/'warning.bmp').read_bytes();assert len(b)==1228854 and b[6:10]==b'OVL9'
for y in range(480):
 for x in range(640):
  i=54+((479-y)*640+x)*4;assert b[i:i+3]==bytes((128,96,66))
  q=(x//16)%4 if y<80 else 0;assert b[i+3]==(192|q if q else 0)
assert 'OVL9' in bmp_info(p/'warning.bmp')
try:prepare(p/'background.bmp',p/'layer.png',p/'background.bmp')
except ValueError:pass
else:raise AssertionError('source overwrite was allowed')
(p/'packed.hex').write_text('\n'.join(f'{x:02x}' for x in b))
Image.new('RGB',(4,2),(18,52,86)).save(p/'ordinary.bmp')
ordinary=(p/'ordinary.bmp').read_bytes();(p/'ordinary.hex').write_text('\n'.join(f'{x:02x}' for x in ordinary)+('\n00'*(512-len(ordinary))))
# A reusable transparent PNG template, without an example background/card image.
examples=r/'素材示例';examples.mkdir(exist_ok=True)
im=Image.new('RGBA',(640,80));draw=ImageDraw.Draw(im)
font=ImageFont.truetype('C:/Windows/Fonts/simsun.ttc',48)
draw.text((82,12),'警告：发生火灾',font=font,fill=(255,0,0,255),stroke_width=0)
draw.polygon([(39,9),(7,69),(71,69)],outline=(255,0,0,255),width=4)
draw.line([(39,28),(39,46)],fill=(255,0,0,255),width=5);draw.ellipse((36,54,42,60),fill=(255,0,0,255))
im.save(examples/'warning.png')
# Render a supersampled template for smooth Songti edges.
hi=Image.new('RGBA',(1280,160));d=ImageDraw.Draw(hi);f=ImageFont.truetype('C:/Windows/Fonts/simsun.ttc',96)
d.text((164,24),'警告：发生火灾',font=f,fill=(255,0,0,255));d.polygon([(78,18),(14,138),(142,138)],outline=(255,0,0,255),width=8)
d.line([(78,56),(78,92)],fill=(255,0,0,255),width=10);d.ellipse((72,108,84,120),fill=(255,0,0,255))
hi.resize((640,80),Image.Resampling.LANCZOS).save(examples/'warning.png')
print('PASS PNG preparation: RGB background unchanged, transparent RGBA2222 top layer, bottom-up placement, header/size, source protection, media checker')
