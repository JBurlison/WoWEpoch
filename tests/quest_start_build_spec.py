"""Check authored DonData tuple starts separately from its giver IDs and general map evidence."""
import json
import runpy
from pathlib import Path

root = Path(__file__).resolve().parents[1]
build = runpy.run_path(str(root/'tools/build-quest-catalog.py'))
raw = build['SOURCE'].read_text(encoding='utf8')
body = raw.split('ns.ATT_QUESTS = {\n',1)[1].split('\n}\n',1)[0]
rows = build['LiteralParser']('{'+body+'}').parse()
quests, _ = build['convert'](rows)
overrides = build['start_overrides']()
counts = build['attach_starts'](quests, rows, overrides)
index = {q['questID']:q for q in quests}
assert index[10]['starts'] == {'all':{'mapID':1446,'x':50.2,'y':27.5}}
assert len(rows[109][7])==6 and index[109]['starts'] == {'Alliance':{'mapID':1436,'x':60,'y':19.4}}
assert 'starts' not in index[2] and index[2]['mapIDs']==[1440], 'Item-drop point must not become an offer'
assert 'starts' not in index[123] and index[123]['mapIDs']==[1429], 'Incomplete tuple retains its general association'
assert not rows[169].get(7) and index[169]['starts']['Alliance']=={'mapID':1433,'x':24.6,'y':46.2}
assert rows[231].get(7) and 'i' in rows[231][8] and index[231]['starts']['Alliance']['mapID']==1431
assert index[79192]['starts']=={'Alliance':{'mapID':1413,'x':46.4,'y':73.8},
                                'Horde':{'mapID':1436,'x':37.5,'y':50.7}}
assert 'mapIDs' not in index[79192]
changes,_ = build['enrich_fields'](quests,rows,raw)
assert index[79192]['mapIDs']==[1442]
assert changes['79192']==[{'path':'db/Camelot/Categories/Zones.lua','line':8250,'fields':{'maps':'{1442}'}}]
assert sum(bool(q.get('starts') or q.get('mapIDs')) for q in quests)==4222
assert sum('starts' in q for q in quests)==3722 and sum(counts['scopeCounts'].values())==3723
assert counts['itemStartsOmitted']==117 and counts['mapOnlyOrAbsent']==510 and counts['multipleGivers']==36
manifest=json.loads((root/'vendor/bundled-quest-source.json').read_text(encoding='utf8'))
assert manifest['startEvidence']['counts']==counts and manifest['startEvidence']['overrides']['79192']==index[79192]['starts']
for triple in [(0,1,1),(True,0,100),(1,False,5),(1,-0.1,5),(1,5,100.1),(1,None,1),(1,1,None),
               (1,float('inf'),2),(1,1,float('nan')),(1,'50',5)]:
    try:build['start_pin'](*triple)
    except ValueError:pass
    else:raise AssertionError('Accepted malformed start '+str(triple))
assert build['start_pin'](1,0,100)=={'mapID':1,'x':0,'y':100}
assert build['start_pin'](1,0.5,1)=={'mapID':1,'x':0.5,'y':1}, 'Percentage literals must not be rescaled'
print('PASS 3,722 quest starts, multiple givers, item-drop exclusions, percentages, scope, independent maps and provenance')
