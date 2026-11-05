"""Stage reviewed BC1 BLP2 exports, then explicitly apply an unchanged candidate.

Original PNGs are read-only. Applying backs up replaced textures and the export
manifest, and removes only the verified superseded native formats. This tool
does not grant visual approval, released-client certification or GPU guarantees.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import uuid
from art_texture_manifest import active_paths, texture_path, validate_texture
from blp_validation import validate_blp

ROOT = Path(__file__).resolve().parents[1]
TEXCONV_SHA256 = 'dcfdec10244e02cf5037fba089c55fb7e1326b1c8181742d77d15fa5cb5eef06'
PROFILE = 'blp2-bc1-1024'
def digest(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def write(path, value): path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def job_id(): return datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')+'-'+uuid.uuid4().hex[:8]

def dds_to_blp(data):
    if len(data) < 128 or data[:4] != b'DDS ' or struct.unpack_from('<I', data, 4)[0] != 124:
        raise ValueError('Expected legacy DDS header')
    if struct.unpack_from('<I', data, 76)[0] != 32 or data[84:88] != b'DXT1' or any(data[112:128]):
        raise ValueError('Expected a single 2D BC1 surface')
    height, width = struct.unpack_from('<II', data, 12)
    count = struct.unpack_from('<I', data, 28)[0]
    if any(n < 1 or n > 4096 or n & (n-1) for n in (width,height)) or not 1 <= count <= 13:
        raise ValueError('Invalid DDS dimensions or mip count')
    blocks=[];offsets=[];lengths=[];at=128;end=1172
    for level in range(count):
        w,h=max(1,width>>level),max(1,height>>level)
        length=((w+3)//4)*((h+3)//4)*8
        block=data[at:at+length]
        if len(block)!=length: raise ValueError('Truncated DDS mip')
        blocks.append(block);offsets.append(end);lengths.append(length)
        at+=length;end+=length
    if at!=len(data): raise ValueError('DDS contains excess surfaces or trailing bytes')
    result=(struct.pack('<4sIBBBBII',b'BLP2',1,2,0,0,int(count>1),width,height)
        +struct.pack('<16I',*(offsets+[0]*(16-count)))
        +struct.pack('<16I',*(lengths+[0]*(16-count)))+bytes(1024)+b''.join(blocks))
    validate_blp(result)  # Requires a complete chain, including tiny mips.
    return result

def stage(root, ids, texconv):
    from PIL import Image, __version__
    if __version__!='12.0.0': raise ValueError('This export profile requires Pillow 12.0.0')
    if digest(texconv.read_bytes())!=TEXCONV_SHA256: raise ValueError('Unrecognized texconv binary')
    registry=read(root/'design/generated-art.json')
    rows={r['id']:r for r in registry}
    if len(rows)!=len(registry) or len(set(ids))!=len(ids) or not ids: raise ValueError('Expected distinct explicit artwork IDs')
    manifest_path=root/'design/art-exports.json';before=manifest_path.read_bytes();exports=json.loads(before)
    active_paths(exports)
    inputs=[]
    for asset_id in ids:
        if asset_id not in rows or asset_id not in exports: raise ValueError('Only existing verified exports may be migrated')
        entry=exports[asset_id]
        source=(root/entry['source']).resolve()
        if not source.is_relative_to((root/'design/illustrations/generated').resolve()): raise ValueError('Source path escapes generated artwork')
        if source!=(root/'design'/rows[asset_id]['src']).resolve() or digest(source.read_bytes())!=entry['sourceSHA256']: raise ValueError('Source evidence changed')
        for role in ('image','thumbnail'): validate_texture(root/'MyEpoch',entry[role])
        inputs.append((asset_id,entry,source))
    folder=root/'dist/art-candidates'/job_id();folder.mkdir(parents=True)
    proposal={'schema':1,'profile':PROFILE,'manifestBeforeSHA256':digest(before),'entries':{},'visualReview':'Pending','releasedClient':'Not tested'}
    for asset_id,prior,source in inputs:
        entry={'source':prior['source'],'sourceSHA256':prior['sourceSHA256'],'profile':PROFILE,'stage':'Development texture; client review pending',
               'encoder':{'texconvSHA256':TEXCONV_SHA256,'pillow':'12.0.0','mipFilter':'BOX','gpu':False}}
        for role,suffix,width,height in [('image','',1024,512),('thumbnail','-thumb',256,128)]:
            name=asset_id+suffix;work=folder/'review'/name;work.mkdir(parents=True)
            reference=work/'reference.png'
            pixel_run=subprocess.run(['node',str(root/'tools/prepare-art-pixels.cjs'),str(source),str(reference),str(width),str(height)],capture_output=True,text=True,check=True,cwd=root)
            entry['encoder']['sharp']=json.loads(pixel_run.stdout)['sharp']
            im=Image.open(reference);assert im.mode=='RGB' and im.size==(width,height)
            tga=work/'input.tga';im.save(tga)
            args=[str(texconv),'-nologo','-y','-f','BC1_UNORM','-m','0','-if','BOX','-nogpu','-o',str(work),str(tga)]
            run=subprocess.run(args,capture_output=True,text=True,check=True,creationflags=0x08000000 if os.name=='nt' else 0)
            dds=work/'input.dds';data=dds_to_blp(dds.read_bytes())
            metadata=validate_blp(data,expected_size=(width,height))
            relative=f'Media/Illustrations/{name}.blp';target=folder/'MyEpoch'/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            decoded=Image.open(io.BytesIO(data)).convert('RGB');assert decoded.size==(width,height)
            decoded.save(work/'decoded-blp.png');Image.open(dds).convert('RGB').save(work/'decoded-dds.png')
            write(work/'command.json',{'args':args,'stdout':run.stdout,'stderr':run.stderr})
            entry[role]={'path':relative,**{k:metadata[k] for k in ('width','height','bytes','sha256','format','encoding','mipCount')}}
        proposal['entries'][asset_id]=entry
    write(folder/'candidate.json',proposal)
    return folder

def apply(root, folder):
    from PIL import Image
    folder=folder.resolve()
    if not folder.is_relative_to((root/'dist/art-candidates').resolve()): raise ValueError('Candidate must be inside this project')
    proposal=read(folder/'candidate.json')
    if proposal['schema']!=1 or proposal['profile']!=PROFILE or not proposal['entries']: raise ValueError('Unsupported candidate')
    manifest_path=root/'design/art-exports.json';before=manifest_path.read_bytes()
    if digest(before)!=proposal['manifestBeforeSHA256']: raise ValueError('Export manifest changed since staging')
    exports=json.loads(before);candidate_entries=proposal['entries'];active_paths(candidate_entries)
    registry={r['id']:r for r in read(root/'design/generated-art.json')}
    for asset_id,new in candidate_entries.items():
        old=exports[asset_id]
        if new['source']!=old['source'] or new['sourceSHA256']!=old['sourceSHA256']: raise ValueError('Candidate source changed')
        source=(root/new['source']).resolve()
        if not source.is_relative_to((root/'design/illustrations/generated').resolve()) or source!=(root/'design'/registry[asset_id]['src']).resolve(): raise ValueError('Candidate source path mismatch')
        if digest(source.read_bytes())!=new['sourceSHA256']: raise ValueError('Artwork source changed')
        for role,size in [('image',(1024,512)),('thumbnail',(256,128))]:
            item=new[role]
            if new['profile']!=PROFILE or (item['width'],item['height'])!=size or not item['path'].endswith('.blp'): raise ValueError('Candidate profile mismatch')
            validate_texture(folder/'MyEpoch',item);validate_texture(root/'MyEpoch',old[role])
            name=asset_id+('-thumb' if role=='thumbnail' else '')
            preview=folder/'review'/name/'decoded-blp.png'
            decoded=Image.open(folder/'MyEpoch'/item['path']).convert('RGB')
            shown=Image.open(preview).convert('RGB')
            if shown.size!=decoded.size or shown.tobytes()!=decoded.tobytes(): raise ValueError('Review preview differs from the actual BLP')
            destination=texture_path(root/'MyEpoch',item['path'])
            if destination.exists() and item['path']!=old[role]['path']: raise ValueError('Unmanaged destination already exists')
    backup=root/'dist/art-export-backups'/job_id();backup.mkdir(parents=True)
    (backup/'art-exports-before.json').write_bytes(before)
    write(backup/'candidate.json',proposal)
    # All selected sources and targets are validated before the first mutation.
    for asset_id,new in candidate_entries.items():
        for role in ('image','thumbnail'):
            old=exports[asset_id][role];previous=texture_path(root/'MyEpoch',old['path'])
            saved=backup/'MyEpoch'/old['path'];saved.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(previous,saved)
            target=texture_path(root/'MyEpoch',new[role]['path']);target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(folder/'MyEpoch'/new[role]['path'],target)
            if target!=previous: previous.unlink()
            name=asset_id+('-thumb' if role=='thumbnail' else '')
            review_path=Path(f'design/illustrations/generated/{name}-export.png')
            if (root/review_path).exists():
                saved_review=backup/review_path;saved_review.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(root/review_path,saved_review)
            shutil.copy2(folder/'review'/name/'decoded-blp.png',root/review_path)
        exports[asset_id]=new
    temporary=manifest_path.with_suffix('.json.'+uuid.uuid4().hex+'.tmp');write(temporary,exports);temporary.replace(manifest_path)
    return backup

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ids',nargs='*')
    parser.add_argument('--texconv',type=Path,default=ROOT/'.tools/texture-budget-draft/texconv.exe')
    parser.add_argument('--apply',type=Path)
    args=parser.parse_args()
    if args.apply and args.ids: parser.error('Apply a candidate or stage IDs, not both')
    result=apply(ROOT,args.apply) if args.apply else stage(ROOT,args.ids,args.texconv.resolve())
    print(('Applied; backup: ' if args.apply else 'Staged for visual review: ')+str(result))
