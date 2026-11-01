"""Read-only BMP/WAV pairing and format checker. Never formats or modifies a card."""
from pathlib import Path
import argparse,struct,sys,ctypes,os

def wav_info(path):
    size=path.stat().st_size
    with path.open('rb') as f:
        head=f.read(12)
        if len(head)!=12 or head[:4]!=b'RIFF' or head[8:]!=b'WAVE':raise ValueError('不是 RIFF/WAVE 文件')
        end=struct.unpack_from('<I',head,4)[0]+8
        if end>size:raise ValueError('文件被截断：RIFF 长度超过实际文件')
        fmt=None;pos=12
        while pos+8<=end:
            f.seek(pos);name,n=struct.unpack('<4sI',f.read(8));pos+=8
            if pos+n>end:raise ValueError('数据块长度超出 RIFF 范围')
            if name==b'fmt ':
                raw=f.read(min(n,40))
                if len(raw)<16:raise ValueError('fmt 数据块过短')
                tag,ch,hz,byte_rate,align,bits=struct.unpack_from('<HHIIHH',raw)
                pcm=tag==1 or (tag==65534 and len(raw)>=40 and struct.unpack_from('<H',raw,18)[0]==bits and raw[24:40]==bytes.fromhex('0100000000001000800000aa00389b71'))
                if not pcm:raise ValueError('仅支持整数 PCM；不支持浮点、ADPCM 或压缩 WAV')
                if ch not in (1,2) or bits not in (16,24) or hz not in (44100,48000):raise ValueError(f'不支持 {hz} Hz / {bits} 位 / {ch} 声道')
                if align!=ch*bits//8:raise ValueError('音频帧对齐字段不正确')
                fmt=(hz,bits,ch,align)
            if name==b'data':
                if fmt is None:raise ValueError('data 块之前没有有效 fmt 块')
                hz,bits,ch,align=fmt
                if n==0 or n%align:raise ValueError('PCM 长度为空或不是完整采样帧')
                return f'{hz} Hz / {bits} 位 / {ch} 声道 / {n/align/hz:.2f} 秒 → 输出 48000 Hz'
            pos+=n+(n&1)
    raise ValueError('没有 data 音频块')

def bmp_info(path):
    with path.open('rb') as f:b=f.read(64)
    if len(b)<54 or b[:2]!=b'BM':raise ValueError('不是有效 BMP 文件')
    length,offset=struct.unpack_from('<I',b,2)[0],struct.unpack_from('<I',b,10)[0]
    dib,w,h,planes,bits,compression=struct.unpack_from('<IiiHHI',b,14)
    packed=bits==32 and b[6:10]==b'OVL9' and (w,h)==(1280,720)
    stride=5120 if packed else (w*3+3)&~3
    if not (1<=w<=1920 and 1<=h<=1080 and planes==1 and (bits==24 or packed) and compression==0):raise ValueError('需要正高度 RGB24 BMP，或新版工具生成的 1280×720 OVL9 图层 BMP；普通 32 位 BMP 不支持')
    if packed and (len(b)<64 or offset!=64 or struct.unpack_from('<H',b,54)[0]>640 or b[54]&1):raise ValueError('警告条元数据不符合 720P 缓存格式，请用本工程工具重新生成')
    if not (40<=dib<=4082 and max(54,dib+14)<=offset<=4096 and offset+stride*h<=length<=8388608 and path.stat().st_size>=length):raise ValueError('BMP 头、长度或像素偏移不符合读取范围')
    return f'{w} × {h} / '+('OVL9 背景＋独立警告图层（v12 720P）' if packed else '24 位 BMP')

def numeric_name(path):
    return path.stem.isascii() and path.stem.isdigit() and 1<=len(path.stem)<=8

def main():
    parser=argparse.ArgumentParser(description='检查 TF 卡根目录的 BMP/WAV 配对；不修改任何文件')
    parser.add_argument('folder',type=Path,help='TF 卡根目录，如 E:\\')
    args=parser.parse_args();folder=args.folder.resolve()
    if not folder.is_dir():parser.error('目录不存在')
    if os.name=='nt':
        fs=ctypes.create_unicode_buffer(64)
        if ctypes.windll.kernel32.GetVolumeInformationW(str(folder.anchor),None,0,None,None,None,fs,len(fs)):
            print('文件系统：'+fs.value)
            if fs.value!='FAT32':print('提示：开发板 WAV 配对播放需要 FAT32；本工具不会格式化。')
    files=list(folder.iterdir());waves={};errors=0
    for p in files:
        if p.is_file() and p.suffix.lower()=='.wav' and numeric_name(p):
            key=int(p.stem)
            if key in waves:print(f'警告：数字 {key} 存在重复 WAV 名称');errors+=1
            else:waves[key]=p
    pics=[p for p in files if p.is_file() and p.suffix.lower()=='.bmp' and numeric_name(p)]
    print('数字轮播图片数：',len(pics),'（板上最多收录 4 张；warning 使用独立报警名额）')
    if not pics:print('未找到数字命名 BMP，普通模式没有可播放图片')
    seen=set()
    for p in pics:
        try:print(p.name+': '+bmp_info(p))
        except (ValueError,OSError,struct.error) as e:print(p.name+': 错误：'+str(e));errors+=1;continue
        if int(p.stem) in seen:print('  重复数字编号，只收录第一个');errors+=1
        seen.add(int(p.stem))
        wave=waves.get(int(p.stem))
        if wave is None:print('  没有同编号 WAV，播放图片时静音');continue
        try:print('  '+wave.name+': '+wav_info(wave))
        except (ValueError,OSError,struct.error) as e:print('  '+wave.name+': 错误：'+str(e));errors+=1
    warning={p.suffix.lower():p for p in files if p.is_file() and p.stem.lower()=='warning'}
    print('报警素材（不参加轮播）：')
    for ext,checker in (('.bmp',bmp_info),('.wav',wav_info)):
        p=warning.get(ext)
        if p is None:print('  缺少 warning'+ext);errors+=1;continue
        try:
            info=checker(p);print('  '+p.name+': '+info)
            if ext=='.bmp' and 'OVL9' not in info:
                print('  尚未打包 PNG 图层：请用制作紧急图层工具生成 warning.bmp');errors+=1
        except (ValueError,OSError,struct.error) as e:print('  错误：'+str(e));errors+=1
    if '.png' in warning:print('  warning.png 是制作工具的输入，FPGA 不直接解压；放在卡里也不会轮播。')
    ignored=[p.name for p in files if p.is_file() and p not in pics and p not in waves.values() and p.stem.lower()!='warning']
    if ignored:print('忽略的其他文件：'+', '.join(ignored))
    print('检查完成；未写入或更改 TF 卡。')
    return 1 if errors else 0
if __name__=='__main__':sys.exit(main())
