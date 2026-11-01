from pathlib import Path
import importlib.util,struct,wave
r=Path(__file__).resolve().parents[1];out=r/'build/checker_fixture';out.mkdir(exist_ok=True)
spec=importlib.util.spec_from_file_location('check_media',r/'tools/check_media.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
n=0
for hz in (44100,48000):
 for bits in (16,24):
  for ch in (1,2):
   p=out/f'{n}.wav'
   with wave.open(str(p),'wb') as f:
    f.setnchannels(ch);f.setsampwidth(bits//8);f.setframerate(hz);f.writeframes(b'\x00'*(bits//8*ch*100))
   assert '48000 Hz' in m.wav_info(p);n+=1
p=out/'extensible.wav'
fmt=struct.pack('<HHIIHHHHI',65534,2,48000,288000,6,24,22,24,3)+bytes.fromhex('0100000000001000800000aa00389b71')
body=b'WAVEfmt '+struct.pack('<I',40)+fmt+b'JUNK'+struct.pack('<I',3)+b'abc\0'+b'data'+struct.pack('<I',12)+bytes(12)
p.write_bytes(b'RIFF'+struct.pack('<I',len(body))+body)
assert '24 位' in m.wav_info(p)
raw=bytearray(p.read_bytes());struct.pack_into('<H',raw,20,3);p.write_bytes(raw)
try:m.wav_info(p)
except ValueError:pass
else:raise AssertionError('float WAV accepted')
assert '640 × 480' in m.bmp_info(r/'tests/fixtures/example_2.bmp')
print('PASS read-only checker: eight PCM formats, extensible/odd chunks, float rejection, supplied BMP')
