"""Cross-check scoped quest coordinates and starter sources in two immutable MIT ATT representations."""
import hashlib
import json
import re

PIN = '3ee4ae1c4415867468de71bc61b8b0896c9b5c166670b6881c119baece3f039d'
MAPS = {'STORMWIND_CITY':(1453,'Stormwind City'), 'ORGRIMMAR':(1454,'Orgrimmar'), 'IRONFORGE':(1455,'Ironforge'),
        'THUNDER_BLUFF':(1456,'Thunder Bluff'), 'DARNASSUS':(1457,'Darnassus'), 'UNDERCITY':(1458,'Undercity')}
FIELDS = ('coord','coords','qg','qgs','providers','r','races','allianceQuestData','hordeQuestData','aqd','hqd')


def direct(declarations, expression, keys):
    rows=declarations('q(1,'+expression+')',keys)
    if len(rows)!=1 or rows[0].get('unsupported'):
        raise ValueError('Expected one literal direct table')
    return {k:v['expression'] for k,v in rows[0]['fields'].items()}


def literal(parser, expr):
    # The same restricted literal parser is used throughout the bundled catalog.
    return parser(expr).parse()


def branch(expr, compiled, declarations, parser):
    fields=direct(declarations,expr,FIELDS)
    if set(fields) - {'coord','coords','qg','qgs','providers'}:
        raise ValueError('Unsupported nested scopes in faction coordinates')
    source_keys=set(fields)&{'qg','qgs','providers'}
    if len(source_keys)!=1 or ('coord' in fields)==('coords' in fields):
        raise ValueError('Expected one direct starter data field and one coordinate field')
    source=source_keys.pop()
    values=literal(parser,fields[source])
    if source=='providers':
        if not isinstance(values,dict) or any(not isinstance(v,dict) or set(v)!={1,2} for v in values.values()):
            raise ValueError('Unexpected provider tuple')
        providers=sorted((v[1],v[2]) for v in values.values())
    else:
        providers=sorted(('n',n) for n in ([values] if source=='qg' else values.values()))
    if not providers or not any(k=='n' for k,_ in providers) or any(k not in ('n','i') or type(n)!=int or n<1 for k,n in providers):
        raise ValueError('Unsupported source provider')
    coords=fields.get('coord',fields.get('coords'))
    if compiled:
        points=[]
        for map_id,group in literal(parser,coords).items():
            if not isinstance(group,dict) or not group:raise ValueError('Empty compiled map group')
            for p in group.values():
                if not isinstance(p,dict) or set(p)!={1,2}:raise ValueError('Unexpected compiled coordinate')
                points.append((map_id,p[1],p[2]))
    else:
        coords=re.sub(r'\bMAP\.([A-Z_]+)\b',lambda m:str(MAPS[m[1]][0]),coords)
        data=literal(parser,coords)
        points=[]
        for p in ([data] if 'coord' in fields else data.values()):
            if not isinstance(p,dict) or set(p)!={1,2,3}:raise ValueError('Unsupported authored coordinate')
            points.append((p[3],p[1],p[2]))
    if not points or any(type(m)!=int or type(x) not in (int,float) or type(y) not in (int,float) or not (0<=x<=100 and 0<=y<=100) for m,x,y in points):
        raise ValueError('Invalid source coordinates')
    return providers,sorted(points)


def load(root, quests, declarations, parser):
    folder=root/'vendor/quest-start-areas'
    raw=(folder/'source-pins.json').read_bytes()
    if hashlib.sha256(raw).hexdigest()!=PIN:raise ValueError('Unreviewed start-area pins')
    pins=json.loads(raw);names=dict(MAPS.values())
    compiled=(root/'vendor/att-6174f27-quest-ranks/Zones.lua').read_bytes()
    if hashlib.sha256(compiled).hexdigest()!=pins['compiledSHA256']:raise ValueError('Unreviewed compiled Zones')
    text=compiled.decode('utf8');by_id={r['questID']:r for r in quests};result={}
    for key,ref in pins['quests'].items():
        n=int(key);q=by_id[n]
        if q.get('starts') or q.get('mapIDs') or not q.get('sourceDisputes',{}).get('mapIDs'):
            raise ValueError('Recheck the original disputed maps')
        data=(folder/ref['file']).read_bytes()
        if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=ref['gitBlob']:
            raise ValueError('Unreviewed author source')
        block='\n'.join(data.decode('utf-8-sig').splitlines()[ref['first']-1:ref['last']])
        rows=declarations(block,('allianceQuestData','hordeQuestData'))
        if len(rows)!=1 or rows[0]['questID']!=n:raise ValueError('Quest identity mismatch')
        prefix=f'q({n},_.ResolveQuestData('
        if text.count(prefix)!=1:raise ValueError('Expected one compiled ResolveQuestData')
        begin=text.index(prefix)+len(prefix);end=text.index('})),',begin)+1
        scopes=direct(declarations,text[begin:end],('aqd','hqd'))
        result[n]={}
        for side,scope in [('Alliance','aqd'),('Horde','hqd')]:
            expr=rows[0]['fields'][side.lower()+'QuestData']['expression']
            author=branch(expr,False,declarations,parser)
            if author!=branch(scopes[scope],True,declarations,parser):
                raise ValueError(f'Author and compiled coordinates/sources disagree for {n} {side}')
            result[n][side]=[{'mapID':m,'area':names[m]} for m in sorted({p[0] for p in author[1]})]
    return result
