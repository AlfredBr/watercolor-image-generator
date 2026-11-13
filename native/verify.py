"""Render reference studies and verify determinism against the actual native DLL."""
import ctypes as c
from pathlib import Path
import time
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
class Settings(c.Structure):
    _fields_ = [(n, c.c_int) for n in ('width','height','seed','palette','style')] + [(n,c.c_float) for n in ('water','pigment','texture','splatter')]
dll = c.CDLL(str(ROOT / 'native/WatercolorCuda.dll'))
dll.wc_render.argtypes = [Settings, c.c_void_p, c.c_char_p, c.c_int]
name = c.create_string_buffer(256)
dll.wc_device(name, 256)
print(name.value.decode())
out = ROOT / 'samples'
out.mkdir(exist_ok=True)
fingerprints = set()
for title, palette, style in [('chromatic-garden',0,0),('wild-botanical',1,0),('lilac-sea-glass',2,1),('color-field',0,2),('geometrics',7,3),('mondrian',7,4),('puddles',3,5),('lines',2,6),('splatter',0,7)]:
    p = Settings(1200,900,48271,palette,style,.72,.85,.85,.85)
    buf = (c.c_ubyte * (p.width*p.height*4))()
    error = c.create_string_buffer(512)
    start = time.perf_counter()
    result = dll.wc_render(p,buf,error,512)
    assert result >= 0, error.value
    print(title, 'CUDA' if result else 'CPU', round(time.perf_counter()-start,3), error.value)
    image = Image.frombytes('RGBA',(p.width,p.height),bytes(buf),'raw','BGRA')
    image.save(out / (title+'.png'))
    again = (c.c_ubyte * len(buf))()
    assert dll.wc_render(p,again,error,512) >= 0
    assert bytes(buf)==bytes(again), 'Seed must reproduce pixels'
    assert min(low for low, high in image.convert('RGB').getextrema()) < 180, 'Pigment missing'
    import hashlib
    fingerprint = hashlib.sha256(bytes(buf)).hexdigest()
    assert fingerprint not in fingerprints, 'Composition must be distinct'
    fingerprints.add(fingerprint)
print('Render and determinism checks passed.')
