"""Actual pinned rank facts and adversarial nonexecuting-reader regressions."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import tempfile

root = Path(__file__).resolve().parents[1]
build = runpy.run_path(str(root / 'tools/build-quest-catalog.py'))
reader = build['RANKS']

# The common children of a resolved faction table are shared. Its two
# exclusive branches cannot establish a location for both factions.
wrapped = ('h(1,_.ResolveQuestData({aqd={g={q(1,{mapID=55})}},'
           'hqd={g={q(2,{mapID=56})}},g={q(3,{mapID=57})}}))')
scoped = reader['declarations'](wrapped, ('mapID',), guard_ancestry=True)
assert {row['questID'] for row in scoped if not row.get('unsupported')} == {3}


def rejected(text):
    try:
        reader['declarations'](text)
    except ValueError:
        return
    raise AssertionError('Malformed/unsupported requirement syntax accepted: ' + text)


def select(text, skill=164):
    occurrences = {}
    for row in reader['declarations'](text):
        occurrences.setdefault(row['questID'], []).append(row)
    return reader['select']({1618: skill}, occurrences)


for bad in [
    'q(1618,{requireSkill=164,learnedAt=60,learnedAt=115})',
    'q(1618,{requireSkill=164,["requireSkill"]=164,learnedAt=60})',
    'q(1618,{requireSkill=164,learnedAt=60 ["learnedAt"]=115})',
    'q(1618,{requireSkill=164 learnedAt=60})',
    'q(1618,{requireSkill=164,learnedAt 60})',
    'q(1618,{requireSkill=164,learnedAt=})',
    'q(1618,{requireSkill=164,,learnedAt=60})',
    'q(1618,{requireSkill=164, [key]=60})',
    'q(1618,{requireSkill=164, ["learned".."At"]=60})',
    'q(1618,{requireSkill=164,learnedAt=60}',
    'q(1618,{requireSkill=164,learnedAt="unterminated})',
    '--[=[ unfinished comment',
    'q(1618,{requireSkill=164,learnedAt=60}) --[==[ bad comment ]=]',
    'q(1618,{requireSkill=164,learnedAt=60}, {})',
    'q(1618+1,{requireSkill=164,learnedAt=60})',
    'q(SOME_ID,{requireSkill=164,learnedAt=60})',
    'q(1618.0,{requireSkill=164,learnedAt=60})',
    'q(2147483648,{requireSkill=164,learnedAt=60})',
    'function q(id) return id end',
    '{' * 129 + '}' * 129,
]:
    rejected(bad)

simple = 'q(1618,{requireSkill=164,learnedAt=60})'
known, unknown = select(simple)
assert known['1618']['minRank'] == 60 and not unknown
known, unknown = select(simple + ';' + simple)
assert len(known['1618']['evidence']) == 2 and not unknown
for other in [
    'q(1618,{requireSkill=164,learnedAt=115})',
    'q(1618,{requireSkill=202,learnedAt=60})',
    'q(1618,{requireSkill=SKILL,learnedAt=60})',
    'q(1618,{requireSkill=164,learnedAt=RANK})',
    'q(1618,{learnedAt=60})',
    'q(1618,_.ResolveQuestData({requireSkill=164,learnedAt=60}))',
    'q(1618,{requireSkill=164,learnedAt=60,OnUpdate=function(t)t.learnedAt=115 end})',
]:
    known, unknown = select(simple + ';' + other)
    assert not known and '1618' in unknown, other
for value in ['-1', '2147483648', '60.5', '"60"', 'true', 'nil', '{}', 'getRank()', '60+55', '0x3c', '6e1']:
    known, unknown = select('q(1618,{requireSkill=164,learnedAt=' + value + '})')
    assert not known and '1618' in unknown, value
for value in [0, 60, 2147483647]:
    known, unknown = select('q(1618,{requireSkill=164,learnedAt=' + str(value) + '})')
    assert known['1618']['minRank'] == value and not unknown
known, unknown = select('q(1618,{requireSkill=164,g={r(123,{learnedAt=115,requireSkill=164})}})')
assert not known and unknown['1618'] == 'No explicit direct minimum rank'
known, unknown = select('q(1618,{requireSkill=164,learnedAt=60,g={r(123,{learnedAt=115,requireSkill=164})}})')
assert known['1618']['minRank'] == 60
known, unknown = select('q(1618,{["require\\083kill"]=164,[ [=[learnedAt]=] ]=60})')
assert known['1618']['minRank'] == 60
noise = '''-- q(1618,{requireSkill=202,learnedAt=115})
--[==[ q(1618,{requireSkill=202,learnedAt=115}) ]==]
local str = "q(1618,{requireSkill=202,learnedAt=115})"
local str2 = [=[q(1618,{requireSkill=202,learnedAt=115})]=]
obj.q(1618,{requireSkill=202,learnedAt=115})
obj:q(1618,{requireSkill=202,learnedAt=115})
'''
known, unknown = select(noise + simple)
assert known['1618']['minRank'] == 60 and len(known['1618']['evidence']) == 1
assert known['1618']['evidence'][0]['line'] == 7

raw = build['SOURCE'].read_text(encoding='utf-8')
rows = build['LiteralParser']('{' + raw.split('ns.ATT_QUESTS = {\n', 1)[1].split('\n}\n', 1)[0] + '}').parse()
quests, counts = build['convert'](rows)
wanted = {q['questID']: q['eligibility']['profession']['skillID'] for q in quests if 'profession' in q['eligibility']}
known, evidence = reader['load'](build['RANK_SOURCE'], wanted, build['RANK_MANIFEST_SHA256'])
assert len(quests) == 4349 and len(wanted) == 202 and len(known) == 85 and len(evidence['unknown']) == 117
assert known['1618']['skillID'] == 164 and known['1618']['minRank'] == 60
assert known['3639']['skillID'] == 202 and known['3639']['minRank'] == 200
assert '2178' not in known and wanted[2178] == 185
assert set(evidence['unknown'].values()) == {'No explicit direct minimum rank'}
build['attach_givers'](quests, rows)
build['attach_starts'](quests, rows, build['start_overrides']())
build['enrich_fields'](quests, rows, raw)
runpy.run_path(str(root/'tools/quest_prerequisite_review.py'))['apply'](quests, root/'vendor/quest-prerequisite-review.json')
runpy.run_path(str(root/'tools/quest_field_review.py'))['apply'](quests, root/'vendor/quest-field-review.json')
build['apply_reviewed_zones'](quests)
build['faction_giver_areas'](quests)
build['apply_reviewed_destinations'](quests)
build['numbered_series'](quests)
before = copy.deepcopy(quests)
for quest in quests:
    fact = known.get(str(quest['questID']))
    if fact and 'profession' in quest['eligibility']:
        quest['eligibility']['profession']['minRank'] = fact['minRank']
assert all(q['eligibility']['complete'] is False for q in quests)
generated = (root / 'MyEpoch/BundledQuests.lua').read_text(encoding='utf-8')
actual_rows = generated.split('data.quests={\n', 1)[1].split('\n}\n', 1)[0]
assert actual_rows == '\n'.join(build['lua'](q) + ',' for q in quests)
for q in quests:
    q['eligibility'].get('profession', {}).pop('minRank', None)
assert before == quests, 'Rank enrichment changed unrelated quest fields'
manifest = json.loads((root / 'vendor/bundled-quest-source.json').read_text(encoding='utf-8'))
assert manifest['professionRankEvidence'] == evidence and manifest['counts']['professionRanks'] == 84
pins = json.loads((build['RANK_SOURCE'] / 'source-pins.json').read_text(encoding='utf-8'))
assert len(pins['files']) == 12
for fact in known.values():
    for occurrence in fact['evidence']:
        source = next(p for p in pins['files'] if p['upstreamPath'] == occurrence['path'])
        lines = (build['RANK_SOURCE'] / source['path']).read_text(encoding='utf-8').splitlines()
        assert occurrence['sourceSHA256'] == source['sha256']
        for field, value in [('requireSkill', fact['skillID']), ('learnedAt', fact['minRank'])]:
            actual = occurrence['fields'][field]
            assert actual['literal'] and actual['value'] == value and actual['expression'] == str(value)
            assert field + '=' + str(value) in lines[actual['line'] - 1]

# Every vendored input, the license and the manifest are checked before use.
with tempfile.TemporaryDirectory() as temp:
    directory = Path(temp) / build['RANK_SOURCE'].name
    shutil.copytree(build['RANK_SOURCE'], directory)
    for pin in pins['files'] + [pins['license']] + [{'path': 'source-pins.json'}]:
        path = directory / pin['path']; original = path.read_bytes(); path.write_bytes(original + b'\n')
        try:
            reader['load'](directory, wanted, build['RANK_MANIFEST_SHA256'])
        except ValueError as exc:
            assert 'hash' in str(exc)
        else:
            raise AssertionError('Changed pinned input accepted: ' + pin['path'])
        finally:
            path.write_bytes(original)
    bad_source = Path(temp) / 'ATT_Quests.lua'; bad_source.write_bytes(build['SOURCE'].read_bytes() + b'\n')
    globals_ = build['build'].__globals__; original_source = globals_['SOURCE']; globals_['SOURCE'] = bad_source
    try:
        build['build'](True)
    except ValueError as exc:
        assert 'hash' in str(exc)
    else:
        raise AssertionError('Changed DonData input accepted')
    finally:
        globals_['SOURCE'] = original_source
print('PASS quest ranks: 85 sourced direct facts / 117 unknown; nested ranks, conflicts, malformed/nonliteral fields, comments/strings, all 12 source hashes, license/manifest hashes, provenance and unchanged 4,349 incomplete quest rows')
