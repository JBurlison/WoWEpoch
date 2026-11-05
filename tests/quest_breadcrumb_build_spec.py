"""Authored breadcrumb declarations must be explicit, compatible and non-executable."""
from pathlib import Path
import json,runpy
root=Path(__file__).resolve().parents[1]
build=runpy.run_path(str(root/'tools/build-quest-catalog.py'))
fields=runpy.run_path(str(root/'tools/quest_catalog_evidence.py'))
def extract(text):
    occurrences={}
    for row in build['RANKS']['declarations'](text,fields['FIELDS'],guard_ancestry=True):
        row['path']='fixture';occurrences.setdefault(row['questID'],[]).append(row)
    return fields['breadcrumb_links'](occurrences,{1,2,3},build['LiteralParser'])[0]
good='q(1,{isBreadcrumb=1,nextQuests={2,3}})'
assert extract(good)=={1:[2,3]}
assert extract(good+',q(1,{isBreadcrumb=1,nextQuests={3,2}})')=={1:[2,3]}
assert extract('q(1,{isBreadcrumb=1,nextQuests={2,9}})')=={1:[2]}
for bad in ('q(1,{isBreadcrumb=0,nextQuests={2}})','q(1,{isBreadcrumb=1,nextQuests={1,2}})',
            'q(1,{isBreadcrumb=1,nextQuests={2,2}})','q(1,{nextQuests={2}})','q(1,{isBreadcrumb=1})',
            good+',q(1,{isBreadcrumb=1,nextQuests={2}})',good+',q(1,{isBreadcrumb=1,nextQuests=resolve(2)})',
            'if experimental then '+good+' end','q(1,{extra={isBreadcrumb=1,nextQuests={2}}})','q(1,{isBreadcrumb=1,nextQuests={[2]=2}})'):
    assert not extract(bad),bad
manifest=json.loads((root/'vendor/bundled-quest-source.json').read_bytes())
proof=manifest['breadcrumbEvidence']
assert proof['commit']=='6174f27d042f8e4ff2624b5d9a099a707e4852a9'
assert proof['quests']['239']['targets']==[11,176]
assert proof['quests']['239']['declarations']==[{'path':'db/Camelot/Categories/Zones.lua','line':15529}]
assert proof['quests']['163']['targets']==[5] and proof['quests']['473']['targets']==[464]
assert manifest['counts']['breadcrumbSources']==210 and manifest['counts']['breadcrumbLinks']==236
print('PASS direct, agreeing, bounded breadcrumb declarations and authored source lines')
