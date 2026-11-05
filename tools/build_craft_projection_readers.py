"""Generate checkpointed private crafting projection readers from addon sources."""
from pathlib import Path
import argparse,hashlib,importlib.util,re

def build(directory,instrument):
    spec=importlib.util.spec_from_file_location('projection_instrument',instrument)
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    out='-- Generated checkpointed projection readers; see tools/build_craft_projection_readers.py.\nlocal _,E=...\nE.CraftProjectionReaderFactories={}\nE.CraftProjectionReaderSources={}\n'
    sources={name:(directory/(name+'.lua')).read_text(encoding='utf-8') for name in ('Production','Items')}
    recap=(directory/'RecapView.lua').read_text(encoding='utf-8')
    a=recap.index('function V.Allowed');b=recap.index('function V.CraftingDetails')
    declarations=re.findall(r'^local eligible=.*$',recap,re.M)
    assert len(declarations)==1,'Expected one literal RecapView eligible declaration'
    eligible=declarations[0].strip()
    assert re.fullmatch(r'local eligible=\{[A-Za-z_]\w*=(?:true|false)(?:,[A-Za-z_]\w*=(?:true|false))*\}',eligible),'Unsupported eligible declaration; review generator dependencies'
    sources['ProjectionRecaps']='local _,E=...\nlocal V,S={},E.Store;E.ProjectionRecaps=V\n'+eligible+'\n'+recap[a:b]
    for name,source in sources.items():
        header,body=source.split('\n',1);assert header.replace(' ','')=='local_,E=...'
        words=list(helper.tokens(body));converted=[];i=0
        while i<len(words):
            token=words[i];triple=''.join(words[i:i+3])
            replacement={'table.sort':'_auctionSort','E.Copy':'_auctionCopy','E.Same':'_auctionSame'}.get(triple)
            if replacement:converted.append(replacement);i+=3;continue
            converted.append(token)
            if token in ('do','repeat'):converted.append(' _auctionTick();')
            i+=1
        out+='\ndo\nlocal function create(E)\n'+helper.HELPERS.replace('MODULE',name)+''.join(converted)+'\nend\nE.CraftProjectionReaderFactories[#E.CraftProjectionReaderFactories+1]={name="'+name+'",create=create}\nend\n'
        out+='E.CraftProjectionReaderSources["'+name+'"]="'+hashlib.sha256(source.encode()).hexdigest()+'"\n'
    return out

def main():
    root=Path(__file__).resolve().parents[1]
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=root/'MyEpoch')
    p.add_argument('--output',type=Path,default=root/'MyEpoch/CraftProjectionReaders.lua')
    p.add_argument('--instrument',type=Path,default=root/'tools/build_auction_readers.py');p.add_argument('--check',action='store_true');a=p.parse_args()
    text=build(a.source,a.instrument)
    if a.check:assert a.output.read_text(encoding='utf-8')==text,'CraftProjectionReaders.lua is stale; regenerate before packaging'
    else:a.output.write_text(text,encoding='utf-8',newline='\n')
    print('Verified'if a.check else'Generated','three checkpointed crafting projection readers')
if __name__=='__main__':main()
