"""Container, provenance, staged-apply and installed-file preservation regressions."""
from pathlib import Path
import copy
import hashlib
import json
import struct
import sys
import tempfile
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from export_art_blp import dds_to_blp, apply, PROFILE
from art_texture_manifest import active_paths, retirement_plan, validate_texture

def sha(data):return hashlib.sha256(data).hexdigest()
def write(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
def js(path,value):write(path,(json.dumps(value)+'\n').encode())
def fails(fn):
    try:fn()
    except (ValueError,KeyError):return
    raise AssertionError('Unsafe migration accepted')
def dds(w,h):
    levels=[];a,b=w,h
    while True:
        levels.append(bytes.fromhex('00f81f0000000000')*((a+3)//4)*((b+3)//4))
        if a==b==1:break
        a,b=max(1,a//2),max(1,b//2)
    header=bytearray(128);header[:4]=b'DDS '
    for offset,value in [(4,124),(12,h),(16,w),(28,len(levels)),(76,32)]:struct.pack_into('<I',header,offset,value)
    header[84:88]=b'DXT1'
    return bytes(header)+b''.join(levels)

# Tiny independently specified red BC1 chain preserves every input block.
gold=dds(4,2);blp=dds_to_blp(gold)
assert blp[:4]==b'BLP2' and blp[1172:]==gold[128:]
for data in (gold[:127],gold[:-1],gold+b'x',gold[:84]+b'DXT5'+gold[88:]):fails(lambda:dds_to_blp(data))
damaged=bytearray(gold);struct.pack_into('<I',damaged,112,0x200);fails(lambda:dds_to_blp(bytes(damaged)))

with tempfile.TemporaryDirectory() as tmp:
    root=Path(tmp);addon=root/'MyEpoch';candidate=root/'dist/art-candidates/test'
    art='test-art';source='design/illustrations/generated/test-art.png';write(root/source,b'unchanged source fixture')
    old={'source':source,'sourceSHA256':sha((root/source).read_bytes()),'stage':'Development'}
    new={**old,'profile':PROFILE}
    for role,suffix,size in [('image','',(1024,512)),('thumbnail','-thumb',(256,128))]:
        header=bytearray(18);header[2]=2;struct.pack_into('<HH',header,12,4,2);header[16]=24
        data=bytes(header)+b'\x00\x00\xff'*8;relative=f'Media/Illustrations/{art}{suffix}.tga'
        write(addon/relative,data);old[role]={'path':relative,'sha256':sha(data),'bytes':len(data),'width':4,'height':2}
        data=dds_to_blp(dds(*size));relative=f'Media/Illustrations/{art}{suffix}.blp'
        write(candidate/'MyEpoch'/relative,data);new[role]={'path':relative,'sha256':sha(data),'bytes':len(data),'width':size[0],'height':size[1]}
        preview=candidate/'review'/(art+suffix)/'decoded-blp.png';preview.parent.mkdir(parents=True,exist_ok=True)
        Image.open(candidate/'MyEpoch'/relative).convert('RGB').save(preview)
    js(root/'design/generated-art.json',[{'id':art,'src':'illustrations/generated/test-art.png'}])
    js(root/'design/art-exports.json',{art:old});original=(root/'design/art-exports.json').read_bytes()
    proposal={'schema':1,'profile':PROFILE,'manifestBeforeSHA256':sha(original),'entries':{art:new}}
    js(candidate/'candidate.json',proposal)
    # A changed source, existing user file, corrupt candidate or stale manifest
    # must fail before modifying either of the old native textures.
    native={x['path']:(addon/x['path']).read_bytes() for x in (old['image'],old['thumbnail'])}
    def preserved():
        assert all((addon/p).read_bytes()==data for p,data in native.items())
        assert (root/'design/art-exports.json').read_bytes()==original
    target=addon/new['image']['path'];write(target,b'user file')
    fails(lambda:apply(root,candidate));preserved();target.unlink()
    candidate_file=candidate/'MyEpoch'/new['thumbnail']['path'];saved=candidate_file.read_bytes();candidate_file.write_bytes(saved[:-1])
    fails(lambda:apply(root,candidate));preserved();candidate_file.write_bytes(saved)
    preview=candidate/'review'/art/'decoded-blp.png';saved_preview=preview.read_bytes()
    Image.new('RGB',(1024,512),'blue').save(preview)
    fails(lambda:apply(root,candidate));preserved();preview.write_bytes(saved_preview)
    (root/source).write_bytes(b'changed');fails(lambda:apply(root,candidate));preserved();(root/source).write_bytes(b'unchanged source fixture')
    (root/'design/art-exports.json').write_bytes(original+b' ');fails(lambda:apply(root,candidate));(root/'design/art-exports.json').write_bytes(original);preserved()
    bad=copy.deepcopy(proposal);bad['entries'][art]['image']['path']='../escape.blp';js(candidate/'candidate.json',bad)
    fails(lambda:apply(root,candidate));preserved();js(candidate/'candidate.json',proposal)
    backup=apply(root,candidate)
    assert (backup/'art-exports-before.json').read_bytes()==original
    for p,data in native.items():assert not (addon/p).exists() and (backup/'MyEpoch'/p).read_bytes()==data
    for role in ('image','thumbnail'):validate_texture(addon,new[role])
    assert Image.open(root/'design/illustrations/generated/test-art-export.png').size==(1024,512)
    assert (root/source).read_bytes()==b'unchanged source fixture'
    # Installer retirement is derived only from the previous managed manifest.
    installed=root/'Installed';previous={}
    for p,data in native.items():write(installed/p,data);previous[p]=sha(data)
    write(installed/'Media/Illustrations/foreign.tga',b'keep')
    previous['RetiredModule.lua']=sha(b'keep');write(installed/'RetiredModule.lua',b'keep')
    current=active_paths({art:new})
    retired=retirement_plan(installed,previous,current,{art:new})
    assert {p.relative_to(installed).as_posix() for p in retired}==set(native)
    changed=installed/old['thumbnail']['path'];changed.write_bytes(b'user edit')
    fails(lambda:retirement_plan(installed,previous,current,{art:new}))
    assert changed.read_bytes()==b'user edit' and (installed/'Media/Illustrations/foreign.tga').read_bytes()==b'keep'
    fails(lambda:retirement_plan(installed,previous,set(),{art:new}))
print('PASS artwork migration: DDS/BLP payloads, preflight failures, source/backup integrity and managed-only format retirement')
