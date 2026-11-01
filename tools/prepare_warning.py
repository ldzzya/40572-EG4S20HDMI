"""PNG + BMP -> independent RGBA2222 warning byte in a marked 32-bit BMP.

The original RGB image remains separate from the warning, not pre-composited.
The v12 720p decoder understands the OVL9 reserved-header marker.
"""
from pathlib import Path
import argparse,struct,json
from PIL import Image,ImageOps,ImageChops
W,H,TOP=1280,720,80
LEVELS=(0,64,192,255)

def prepare(background,png,output,fit='stretch',trim_border=True):
 background,png,output=map(Path,(background,png,output))
 if output.resolve() in (background.resolve(),png.resolve()):raise ValueError('输出文件不能覆盖原始素材，请选择其他目录。')
 if output.name.lower()!='warning.bmp':raise ValueError('紧急播放文件必须命名为 warning.bmp。')
 with Image.open(background) as src:
  if src.format!='BMP':raise ValueError('背景请选择真正的 BMP 文件。')
  if src.width<1 or src.height<1 or src.width>1920 or src.height>1080:raise ValueError('背景支持 1–1920 × 1–1080。')
  src=src.convert('RGB')
  original_size=src.size
  crop_box=(0,0,src.width,src.height)
  if trim_border:
   # Remove only an outer near-black canvas, never internal black regions.
   # Already-packed BMPs often contain a letterbox from an earlier conversion.
   channels=src.split()
   nonblack=ImageChops.lighter(ImageChops.lighter(channels[0],channels[1]),channels[2]).point(lambda v:255 if v>4 else 0)
   bounds=nonblack.getbbox()
   if bounds is None:raise ValueError('背景完全为黑色，无法确定可显示内容。')
   crop_box=bounds;src=src.crop(crop_box)
  if fit=='stretch':
   bg=src.resize((W,H),Image.Resampling.LANCZOS);image_box=(0,0,W,H)
  else:
   resized=ImageOps.contain(src,(W,H),method=Image.Resampling.LANCZOS)
   bx,by=(W-resized.width)//2,(H-resized.height)//2
   bg=Image.new('RGB',(W,H));bg.paste(resized,(bx,by))
   image_box=(bx,by,bx+resized.width,by+resized.height)
 with Image.open(png) as src:
  if src.format!='PNG':raise ValueError('图层请选择真正的 PNG 文件。')
  fg=src.convert('RGBA');bounds=fg.getchannel('A').getbbox()
  if bounds is None:raise ValueError('PNG 完全透明，没有可叠加内容。')
  fg=fg.crop(bounds)
  bx,by,br,bb=image_box;bw,bh=br-bx,bb-by
  margin=min(16,max(0,min(bw,bh)//20))
  max_width=(bw-2*margin)//2;max_height=min(TOP,bh-2*margin)//2
  if min(max_width,max_height)<1:raise ValueError('底图显示区域太窄，无法容纳警告文字条。')
  # Filter once to the independent mask cache, then replicate exactly 2x2.
  # The background is never reduced to this resolution.
  fg.thumbnail((max_width,max_height),Image.Resampling.LANCZOS)
  fg=fg.resize((fg.width*2,fg.height*2),Image.Resampling.NEAREST)
  px=(bx+(bw-fg.width)//2)//2*2;py=(by+margin+1)//2*2
  layer=Image.new('RGBA',(W,H));layer.paste(fg,(px,py))
  overlay_box=(px,py,px+fg.width,py+fg.height)
 encoded=bytearray(W*H);preview=bg.copy();bp=list(bg.getdata());fp=list(layer.getdata());out=[]
 for i,(base,color) in enumerate(zip(bp,fp)):
  r,g,b,a=color;q=0 if a<32 else 1 if a<128 else 2 if a<224 else 3
  rr,gg,bb=((c+42)//85 for c in (r,g,b))
  encoded[i]=(rr<<6)|(gg<<4)|(bb<<2)|q if q else 0
  weight=(0,1,3,4)[q]
  out.append(tuple((v*(4-weight)+c*85*weight)//4 for v,c in zip(base,(rr,gg,bb))))
 preview.putdata(out)
 payload=bytearray(W*H*4)
 for y in range(H):
  for x in range(W):
   i=y*W+x;j=((H-1-y)*W+x)*4;r,g,b=bp[i]
   payload[j:j+4]=bytes((b,g,r,encoded[i]))
 header=b'BM'+struct.pack('<I',64+len(payload))+b'OVL9'+struct.pack('<I',64)
 header+=struct.pack('<IiiHHIIiiII',40,W,H,1,32,0,len(payload),2835,2835,0,0)
 header+=struct.pack('<H',py)+b'W720'+bytes(4)
 output.parent.mkdir(parents=True,exist_ok=True)
 output.write_bytes(header+payload)
 bg.save(output.parent/'preview_off.png');preview.save(output.parent/'preview_on.png')
 report={'background':str(background.resolve()),'png':str(png.resolve()),'output':str(output.resolve()),
 'format':'OVL9 marked BI_RGB32; offset64; B,G,R,RGBA2222','size':[W,H],'max_banner_height':TOP,
 'original_background_size':original_size,'source_crop':crop_box,'trim_outer_black_border':trim_border,
 'mask_cache':[640,40],'mask_scale':2,'strip_top':py,'output_mode':'1280x720 60Hz',
 'background_rect':image_box,'overlay_rect':overlay_box,
 'placement':'inside BMP content at top centre; background is never moved to make room',
 'alpha_weights':[0,.25,.75,1],'palette_levels':[0,85,170,255],'fit':fit,
 'visible_overlay_pixels':sum(bool(v&3) for v in encoded),
 'copy_to_tf':['warning.bmp','your existing warning.wav'],'previews_are_not_board_inputs':True}
 (output.parent/'warning_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 return report

def gui():
 import tkinter as tk
 from tkinter import filedialog,messagebox
 root=tk.Tk();root.withdraw()
 try:
  bg=filedialog.askopenfilename(title='选择背景 BMP（原文件不会修改）',filetypes=[('BMP 图片','*.bmp')])
  if not bg:return
  png=filedialog.askopenfilename(title='选择裁好的警告文字 PNG（透明背景，叠在底图内部顶部）',filetypes=[('PNG 图层','*.png')])
  if not png:return
  folder=filedialog.askdirectory(title='选择输出目录：将生成 warning.bmp 和两张预览图')
  if not folder:return
  output=Path(folder)/'warning.bmp'
  if output.exists() and not messagebox.askyesno('覆盖已生成文件','输出目录已有 warning.bmp，是否覆盖？原始素材仍禁止覆盖。'):return
  report=prepare(bg,png,output,fit='stretch',trim_border=True)
  messagebox.showinfo('已生成',f"已生成 1280×720：{output}\n已去掉底图外侧黑边并拉伸铺满，文字覆盖在底图上方。\n请查看 preview_on.png / preview_off.png，闪动时底图保持不动。\n向 TF 卡复制新 warning.bmp，保留配对的 warning.wav。\n配合 v12 720p BIT 使用；无需把 PNG、预览图或 JSON 复制进卡。")
 except Exception as e:messagebox.showerror('未完成',str(e))
 finally:root.destroy()

if __name__=='__main__':
 p=argparse.ArgumentParser(description='为 v12 720p 制作覆盖在底图内部的闪动警告条；无参数打开选择窗口。')
 p.add_argument('--background',type=Path);p.add_argument('--png',type=Path);p.add_argument('--output',type=Path)
 p.add_argument('--fit',choices=['contain','stretch'],default='stretch')
 p.add_argument('--keep-border',action='store_true',help='保留原素材中的外侧黑边');a=p.parse_args()
 if not any((a.background,a.png,a.output)):gui()
 elif not all((a.background,a.png,a.output)):p.error('--background、--png、--output 必须同时指定')
 else:print(json.dumps(prepare(a.background,a.png,a.output,a.fit,not a.keep_border),ensure_ascii=False,indent=2))
