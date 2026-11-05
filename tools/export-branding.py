"""Deterministic size/format exports of the approved generated My Epoch logos."""
from pathlib import Path
import hashlib,json
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BRAND=ROOT/'design/branding'
NATIVE=ROOT/'MyEpoch/Media/Book'
RESAMPLE=Image.Resampling.LANCZOS

def inspect(path):
    with Image.open(path) as image:
        row={'path':path.relative_to(ROOT).as_posix(),'size':list(image.size),'mode':image.mode,
             'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        if 'A' in image.getbands():
            alpha=image.getchannel('A');counts=alpha.histogram()
            row.update(alphaExtrema=list(alpha.getextrema()),fullyTransparentPixels=counts[0],
                       partiallyTransparentPixels=sum(counts[1:255]),fullyOpaquePixels=counts[255])
        return row

sources={kind:BRAND/f'my-epoch-{kind}-v1.png'for kind in ['transparent','parchment']}
manifest={'operation':'Aspect-preserving square resize and format conversion only; no cropping, drawing or creative edits.',
          'resampling':'Pillow LANCZOS','sources':[inspect(p)for p in sources.values()],'outputs':[]}
transparent=Image.open(sources['transparent']).convert('RGBA')
assert transparent.width==transparent.height
assert transparent.getchannel('A').getextrema()==(0,255),'Transparent master must contain actual alpha'
for size,name in [(256,'emblem-v1.tga'),(128,'emblem-small-v1.tga')]:
    resized=transparent.resize((size,size),RESAMPLE)
    path=NATIVE/name;resized.save(path,format='TGA',compression=None,orientation=1)
    with Image.open(path)as check:assert check.mode=='RGBA'and check.size==(size,size)and check.tobytes()==resized.tobytes()
    header=path.read_bytes()[:18]
    assert header[2]==2 and header[16]==32 and header[17]&15==8,'Expected uncompressed32-bit TGA with8 alpha bits'
    manifest['outputs'].append(inspect(path))
for kind,path in sources.items():
    with Image.open(path)as source:
        assert source.width==source.height
        for size in [512,1024]:
            output=BRAND/f'my-epoch-{kind}-curseforge-{size}-v1.png'
            resized=source.resize((size,size),RESAMPLE);resized.save(output,format='PNG',optimize=True)
            with Image.open(output)as check:assert check.size==(size,size)and check.mode==source.mode and check.tobytes()==resized.tobytes()
            manifest['outputs'].append(inspect(output))
assert [inspect(p)for p in sources.values()]==manifest['sources'],'Master sources changed'
(BRAND/'exports-v1.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
