"""Build the native candidate registry from the authoritative design register and verified files."""
import hashlib
import json
import re
import struct
import sys
from pathlib import Path
from art_texture_manifest import validate_texture, active_paths, release_manifest

ROOT = Path(__file__).resolve().parents[1]
matrix = json.loads((ROOT / 'design/art-matrix.json').read_text(encoding='utf-8'))
exports = json.loads((ROOT / 'design/art-exports.json').read_text(encoding='utf-8'))
active_paths(exports)
assert matrix['decisions']['dedicatedPerLocation'] == 9 and matrix['decisions']['anywherePool'] == 27
def key(location):
    return location['type'].lower() + ':' + location['id']
locations = [{**{k: r[k] for k in ('name', 'type', 'scope')}, 'key': key(r)} for r in matrix['locations']]
physical_maps = set()
for source, location in zip(matrix['locations'], locations):
    if 'physicalMapID' in source:
        map_id = source['physicalMapID']
        assert location['type'] in ('Dungeon', 'Raid') and type(map_id) is int and map_id > 0 and map_id not in physical_maps
        physical_maps.add(map_id)
        location['physicalMapID'] = map_id
by_name = {(r['type'], r['name']): r for r in locations}
professions = [{**{k: r[k] for k in ('name', 'type', 'scope')}, 'key': r['id']} for r in matrix['professions']]
by_profession = {(r['type'], r['name']): r for r in professions}
weapons = [{**{k: r[k] for k in ('name', 'type', 'scope', 'skillLineID')}, 'key': r['id']} for r in matrix.get('weapons', [])]
by_weapon = {r['key']: r for r in weapons}
assert len(by_weapon) == len(weapons)
assert len({r['skillLineID'] for r in weapons}) == len(weapons)
assert len({r['key'] for r in locations}) == len(locations)
rows = []
for row in matrix['rows']:
    assert re.fullmatch(r'[a-z0-9-]+', row['id'])
    location = by_name.get((row['type'], row['location']))
    profession = by_profession.get((row['type'], row['location']))
    weapon = by_weapon.get(row.get('weapon'))
    character_level = row.get('characterLevel')
    assert location or profession or weapon or row['type'] in ('Anywhere', 'Character level')
    if row['type'] == 'Character level':
        assert isinstance(character_level, int) and not isinstance(character_level, bool) and 2 <= character_level <= 60
        assert row.get('faction') in ('Alliance', 'Horde')
        assert row['id'] == f"character-level-{row['faction'].lower()}-{character_level:03d}"
    else:
        assert character_level is None
    if weapon:
        assert row['type'] == 'Weapon skill' and row['skillLineID'] == weapon['skillLineID']
        assert row['location'] == weapon['name']
        assert isinstance(row['milestone'], int) and row['milestone'] > 0 and row['milestone'] % 25 == 0
        assert row['id'] == f"{weapon['key']}-{row['milestone']:03d}"
    result = {k: row[k] for k in ('id', 'type', 'slot', 'title', 'anchors', 'humor', 'generation', 'approved')}
    result['location'] = location['key'] if location else None
    result['profession'] = profession['key'] if profession else None
    if weapon:
        result.update(weapon=weapon['key'], skillLineID=weapon['skillLineID'], milestone=row['milestone'])
        # Existing opening art retains its ID while awaiting a combat-scene replacement.
        result['combatReview'] = row['combatReview']
        if row['asset'] and row['milestone'] > 25:
            assert row['combatReview'] == 'Passed', row['id']
        if row['combatReview'] == 'Passed':
            for field in ('mob', 'combatAction', 'sceneZone'):
                assert isinstance(row.get(field), str) and row[field].strip(), (row['id'], field)
                result[field] = row[field]
    if character_level is not None:
        result['characterLevel'] = character_level
        result['faction'] = row['faction']
    result['alt'] = row['humor'] + ' ' + row['anchors']
    export = exports.get(row['id'])
    if export:
        source = (ROOT / export['source']).resolve()
        assert source.is_relative_to(ROOT / 'design/illustrations')
        assert hashlib.sha256(source.read_bytes()).hexdigest() == export['sourceSHA256']
        assert row['asset'] and (ROOT / 'design' / row['asset']).resolve() == source
        for name in ('image', 'thumbnail'):
            item = export[name]
            path = (ROOT / 'MyEpoch' / item['path']).resolve()
            validate_texture(ROOT / 'MyEpoch', item)
            result['texture' if name == 'image' else 'thumbnail'] = 'Interface\\AddOns\\MyEpoch\\' + item['path'].replace('/', '\\')
        result.update(width=export['image']['width'], height=export['image']['height'], stage=export['stage'])
    rows.append(result)
assert len({r['id'] for r in rows}) == len(rows)
assert sum(r['type'] == 'Anywhere' for r in rows) == 27
for location in locations:
    assert sum(r['location'] == location['key'] for r in rows) == 9
for profession in professions:
    assert sum(r['profession'] == profession['key'] for r in rows) == 18
weapon_pairs = [(r['skillLineID'], r['milestone']) for r in rows if r.get('weapon')]
assert len(weapon_pairs) == len(set(weapon_pairs))
expected_weapon_art = {(w['skillLineID'], n) for w in weapons for n in range(25, 301, 25)}
assert len(weapons) == 16 and set(weapon_pairs) == expected_weapon_art, 'Expected every planned weapon illustration through 300'
for row in matrix['rows']:
    if row.get('weapon'):
        assert row['slot'] == row['milestone'] // 25
        assert bool(row['asset']) == (row['id'] in exports), 'Every generated weapon illustration requires a verified image and thumbnail'
levels = [(r['faction'], r['characterLevel']) for r in rows if 'characterLevel' in r]
assert len(levels) == len(set(levels))
assert set(levels) == {(faction, level) for faction in ('Alliance', 'Horde') for level in range(2, 61)}, 'Character-level artwork must track both complete requested 2-60 ranges'
assert set(exports) <= {r['id'] for r in rows}
def lua(value):
    if value is None: return 'nil'
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, str):
        escaped = value.replace('\\', '\\\\').replace('"', '\\"')
        escaped = re.sub(r'[\x00-\x1f]', lambda m: '\\%03d' % ord(m[0]), escaped)
        return '"' + escaped + '"'
    if isinstance(value, list): return '{' + ','.join(lua(v) for v in value) + '}'
    return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items() if v is not None) + '}'
dungeon_aliases = {}
dungeon_keys = {r['key'] for r in locations if r['type']=='Dungeon'}
for alias in matrix['dungeonNames']['names']:
    assert alias['collection'] in dungeon_keys and alias['name'] not in dungeon_aliases
    assert alias['use'] in ('recorded-zone', 'search')
    entry = {'key': alias['collection']}
    if alias['use'] == 'recorded-zone':
        entry['recorded'] = True
    dungeon_aliases[alias['name']] = entry
data = {'schema': 1, 'locations': locations, 'dungeonAliases': dungeon_aliases, 'professions': professions, 'weapons': weapons, 'rows': rows}
destination = ROOT / 'MyEpoch/ArtCatalog.lua'
content = '-- Generated by tools/build-art-catalog.py; edit the design register, not this file.\nlocal _,E=...\nE.ArtCatalog=' + lua(data) + '\n'
if '--check' in sys.argv:
    assert destination.read_text(encoding='utf-8') == content, 'Native artwork catalog is stale; rebuild it before packaging.'
else:
    destination.write_text(content, encoding='utf-8')
release_path = ROOT / 'tools/art-release.json'
release = release_manifest(ROOT, exports)
if '--check' in sys.argv:
    assert json.loads(release_path.read_text(encoding='utf-8')) == release, 'Artwork release manifest is stale; rebuild it before packaging.'
else:
    release_path.write_text(json.dumps(release, indent=2) + '\n', encoding='utf-8')
print(f'Native art registry: {len(locations)} candidate locations, {len(professions)} candidate professions, {len(rows)} planned slots, {len(exports)} development textures; no client certification implied.')
