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
for title, palette, style in [('chromatic-garden',0,0),('wild-botanical',1,0),('lilac-sea-glass',2,1),('color-field',0,2),('geometrics',7,3),('mondrian',7,4),('puddles',3,5),('lines',2,6),('splatter',0,7),('african-inspired',6,8),('yin-yang',3,9),('infinity',0,10),('human-forms',2,11),('mobius',3,12),('planetary-systems',5,13),('nebula',2,14),('quilt',7,15),('eyeball-iris',3,16),('sparkle-metallics',8,2),('leaves',1,17),('flowers',0,18),('grayscale',9,17),('sepia',10,18),('vanishing-point',3,19),('violent-storm',5,20),('city-nights',0,21)]:
    p = Settings(1200,900,48271,palette,style,.72,.85,.85,.85)
    buf = (c.c_ubyte * (p.width*p.height*4))()
    error = c.create_string_buffer(512)
    start = time.perf_counter()
    result = dll.wc_render(p,buf,error,512)
    assert result >= 0, error.value
    print(title, 'CUDA' if result else 'CPU', round(time.perf_counter()-start,3), error.value)
    image = Image.frombytes('RGBA',(p.width,p.height),bytes(buf),'raw','BGRA')
    if palette == 9:
        rgb = image.convert('RGB')
        assert rgb.getchannel('R').tobytes() == rgb.getchannel('G').tobytes() == rgb.getchannel('B').tobytes(), 'Grayscale must remain neutral'
    if palette == 10:
        raw = bytes(buf)
        assert all(r >= g >= b for b,g,r in zip(raw[0::4], raw[1::4], raw[2::4])), 'Sepia must remain warm-toned'
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

# A pose gallery makes repeated stances and malformed outlines easy to spot.
from PIL import ImageDraw
gallery = Image.new('RGB', (1600, 1020), '#f4f1e9')
draw = ImageDraw.Draw(gallery)
for i, pose_seed in enumerate([91, 203, 48271, 731, 1024, 8129, 9503, 421]):
    p = Settings(600, 750, pose_seed, [2, 6, 0, 5][i % 4], 11, .6, .85, .8, .65)
    buf = (c.c_ubyte * (p.width*p.height*4))()
    error = c.create_string_buffer(512)
    assert dll.wc_render(p, buf, error, 512) >= 0, error.value
    study = Image.frombytes('RGBA', (p.width, p.height), bytes(buf), 'raw', 'BGRA')
    x, y = (i % 4)*400, (i // 4)*510
    gallery.paste(study.convert('RGB').resize((392, 490)), (x, y+20))
    draw.text((x+8, y+4), f'Study {pose_seed}', fill='#202c29')
gallery.save(out / 'human-poses-preview.jpg')

def preview(names, filename):
    rows = (len(names)+2)//3
    sheet = Image.new('RGB', (1500, rows*390), '#f4f1e9')
    labels = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        x,y = (i%3)*500,(i//3)*390
        sheet.paste(Image.open(out/(name+'.png')).convert('RGB').resize((490,350)),(x,y+25))
        labels.text((x+10,y+7),name,fill='#202c29')
    sheet.save(out/filename)
preview(['geometrics','mondrian','puddles','lines','splatter'], 'theme-preview.jpg')
preview(['african-inspired','yin-yang','infinity','human-forms','mobius','planetary-systems','nebula','quilt','eyeball-iris'], 'new-theme-preview.jpg')
print('Pose gallery and theme previews refreshed.')
