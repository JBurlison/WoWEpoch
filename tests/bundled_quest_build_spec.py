"""Verify the converter's actual pinned source, semantics, and nonexecuting parser."""
import runpy
from pathlib import Path
root=Path(__file__).resolve().parents[1]
m=runpy.run_path(str(root/'tools/build-quest-catalog.py'))
parse=lambda s:m['LiteralParser'](s).parse()
for bad in ['{os.execute("bad")}', '{[1]=1,[1]=2}', '{1+2}', '{function()end}', '{};print("bad")', '{', '{1 2}', '{[0]=1}']:
    try:parse(bad)
    except ValueError:pass
    else:raise AssertionError('Accepted executable or invalid input: '+bad)
assert parse('{[1]="a\\\"b",[2]="c\\039d",[3]=nil}')[1]=='a"b'
assert parse('{[1]="a\\\"b",[2]="c\\039d",[3]=nil}')[2]=="c'd"
assert parse('{1, -- harmless comment\n {2,3}, nil}')[2]=={1:2,2:3}
q=lambda pre,need=None:{1:1436,4:'A',5:9,6:pre,11:need,13:'Fixture only'}
rows={1:q({1:10}),2:q({1:10,2:20},1),3:q({1:10,2:20},2),4:q({1:10,2:20}),5:q({1:10,2:20,3:30},2)}
out,counts=m['convert'](rows)
assert out[0]['requiresAll']==[10] and out[1]['requiresAny']==[10,20] and out[2]['requiresAll']==[10,20]
assert out[3]['prerequisiteCandidates']==[10,20] and out[4]['prerequisiteCandidates']==[10,20,30]
assert all(not r['eligibility']['complete'] and 'excludes' not in r and 'repeatable' not in r for r in out)
assert m['convert']({1:{1:1436,13:'Old',14:'o'}})[1]['omittedOld']==1
for bad in [{1:1,3:2},{1:-1},{1:1,2:1}]:
    try:m['id_list'](bad)
    except ValueError:pass
    else:raise AssertionError('Accepted invalid prerequisite list')
m['build'](True)
raw=m['SOURCE'].read_text(encoding='utf-8')
actual=parse('{'+raw.split('ns.ATT_QUESTS = {',1)[1].split('\n}\n',1)[0]+'}')
out,counts=m['convert'](actual)
real={q['questID']:q for q in out}
assert real[3639]['title']=='Show Your Work' and real[3639]['eligibility']['profession']=={'skillID':202}
assert counts['professionIDs']==202 and counts['professionRanks']==0
assert all(q['eligibility']['complete'] is False for q in out)
series=m['numbered_series'](out)
assert series[166]=='The Defias Brotherhood' and real[166]['chain']==[65,132,135,141,142,155,166]
parts=[{'questID':1,'title':'Thread (1/2)'},{'questID':2,'title':'Thread (2/2)','requiresAll':[1]}]
assert m['numbered_series']([dict(q) for q in parts])=={2:'Thread'}
for extra in ({'title':'Thread (3/3)'},{'requiresAll':[],'requiresAny':[1,3]},
              {'prerequisiteCandidates':[1]},{'repeatable':True}):
    assert not m['numbered_series']([dict(parts[0]),dict(parts[1],**extra)])
assert not m['numbered_series'](parts+[dict(parts[1],questID=3)]), 'Duplicate ordinal is ambiguous'
assert all('minRank' not in q['eligibility'].get('profession',{}) for q in out)
for bad in [0,-1,True,1.5,{1:202,2:200}]:
    try:m['convert']({1:{12:bad,13:'Synthetic validation only'}})
    except ValueError:pass
    else:raise AssertionError('Invalid profession identity accepted')
print('PASS bundled quest build: pinned source, reproducible data/notices, literal parser, unknown rules and no fabricated restrictions')

runpy.run_path(str(root/'tests/quest_profession_ranks_build_spec.py'))
runpy.run_path(str(root/'tests/quest_start_build_spec.py'))
