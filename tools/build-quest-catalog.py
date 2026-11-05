"""Convert a pinned MIT-licensed Forever candidate table without executing upstream Lua."""
import hashlib
import json
import re
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'vendor/dondata-37a53f6/ATT_Quests.lua'
PIN = '37a53f62cab34e6daa2421a0cd4749bf977fffd2'
ATT_PIN = '6174f27d042f8e4ff2624b5d9a099a707e4852a9'
SOURCE_SHA256 = '823018309cbc5714a29edd71177ce022eb6f7ff480666578a5ab5471de348988'
START_ENGINE = SOURCE.with_name('Engine-QuestData.lua')
START_ENGINE_SHA256 = '6e4ddd722243068017f8fec3090028bf613077ad8e69146aec09763c0503d1be'
RANK_SOURCE = ROOT / 'vendor/att-6174f27-quest-ranks'
RANK_MANIFEST_SHA256 = 'fa2b382e6eed7c9f3b706ac17763a21f27c9a5edabd2085009d2099f86fe4323'
RANKS = runpy.run_path(str(ROOT / 'tools/quest_profession_ranks.py'))
TOKEN = re.compile(r'''\s+|--[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|-?\d+(?:\.\d+)?|\b(?:nil|true|false)\b|[{}\[\]=,;]''')

class LiteralParser:
    def __init__(self, text):
        if len(text) > 2000000:
            raise ValueError('Oversized table')
        self.tokens = []
        pos = 0
        while pos < len(text):
            match = TOKEN.match(text, pos)
            if not match:
                raise ValueError('Unsupported Lua syntax at ' + str(pos))
            token = match.group(); pos = match.end()
            if not token.isspace() and not token.startswith('--'):
                self.tokens.append(token)
        self.at = 0

    def pop(self, expected=None):
        if self.at >= len(self.tokens):
            raise ValueError('Truncated literal')
        token = self.tokens[self.at]; self.at += 1
        if expected is not None and token != expected:
            raise ValueError('Expected ' + expected)
        return token

    def value(self, depth=0):
        if depth > 32:
            raise ValueError('Deep table')
        token = self.pop()
        if token == '{':
            out = {}; index = 1
            while self.tokens[self.at] != '}':
                if self.tokens[self.at] == '[':
                    self.pop('['); key = self.value(depth+1); self.pop(']'); self.pop('=')
                    if type(key) is not int or key < 1:
                        raise ValueError('Only positive integer keys are accepted')
                else:
                    key = index; index += 1
                if key in out:
                    raise ValueError('Duplicate key')
                out[key] = self.value(depth+1)
                if self.tokens[self.at] in (',', ';'):
                    self.pop()
                elif self.tokens[self.at] != '}':
                    raise ValueError('Missing separator')
            self.pop('}'); return out
        if token in ('nil', 'true', 'false'):
            return {'nil': None, 'true': True, 'false': False}[token]
        if token[0] in ('"', "'"):
            escapes = {'a':'\a', 'b':'\b', 'f':'\f', 'n':'\n', 'r':'\r', 't':'\t', 'v':'\v', '\\':'\\', '"':'"', "'":"'"}
            def escape(match):
                value = match.group()[1:]
                if value.isdecimal() and int(value) < 128:
                    return chr(int(value))
                if value in escapes:
                    return escapes[value]
                raise ValueError('Unsupported string escape')
            return re.sub(r'\\(?:\d{1,3}|.)', escape, token[1:-1])
        if re.fullmatch(r'-?\d+(?:\.\d+)?', token):
            return float(token) if '.' in token else int(token)
        raise ValueError('Expected literal')

    def parse(self):
        try:
            value = self.value()
            if self.at != len(self.tokens):
                raise ValueError('Trailing code')
            return value
        except IndexError as exc:
            raise ValueError('Truncated table') from exc

def id_list(raw):
    if raw is None:
        return None
    if not isinstance(raw, dict) or set(raw) != set(range(1, len(raw)+1)):
        raise ValueError('Non-dense ID array')
    values = list(raw.values())
    if any(type(v) is not int or v <= 0 for v in values) or len(values) != len(set(values)):
        raise ValueError('Invalid/duplicate ID')
    return sorted(values)

def convert(rows):
    quests = []; omitted_old = 0; ambiguous = 0
    for quest_id, row in sorted(rows.items()):
        if not isinstance(row, dict) or max(row) > 15:
            raise ValueError('Unexpected quest tuple')
        if row.get(14) in ('o', 'of'):
            omitted_old += 1; continue
        if row.get(14) is not None:
            raise ValueError('Unknown origin')
        title = row.get(13)
        if title is not None and (not isinstance(title, str) or not title):
            raise ValueError('Invalid title')
        q = dict(questID=quest_id, eligibility=dict(complete=False))
        if title is not None:
            q['title'] = title
        map_id = row.get(1)
        if map_id is not None:
            if type(map_id) is not int or map_id <= 0:
                raise ValueError('Invalid UI map')
            q['mapIDs'] = [map_id]
        faction = row.get(4)
        if faction not in (None, 'A', 'H'):
            raise ValueError('Unknown faction')
        if faction:
            q['eligibility']['faction'] = {'A':'Alliance', 'H':'Horde'}[faction]
        minimum = row.get(5)
        if minimum is not None:
            if type(minimum) is not int or minimum < 1:
                raise ValueError('Invalid minimum level')
            q['eligibility']['minLevel'] = minimum
        for slot, field in [(9, 'classIDs'), (10, 'raceIDs')]:
            values = id_list(row.get(slot))
            if values is not None:
                q['eligibility'][field] = values
        skill = row.get(12)
        if skill is not None:
            if type(skill) is not int or skill <= 0 or skill > 2147483647:
                raise ValueError('Invalid profession skill-line ID')
            # The pinned tuple supplies only identity, never a minimum rank.
            q['eligibility']['profession'] = dict(skillID=skill)
        pre = id_list(row.get(6)); needed = row.get(11)
        if pre:
            if needed == 1:
                q['requiresAny'] = pre
            elif needed == len(pre) or len(pre) == 1 and needed is None:
                q['requiresAll'] = pre
            else:
                # Unknown AND/OR, faction alternatives and N-of-M are not invented.
                q['prerequisiteCandidates'] = pre; ambiguous += 1
        if row.get(8) and 'r' in row[8]:
            q['repeatable'] = True
        # Missing restrictions/flags are not assertions of unrestricted or one-time quests.
        quests.append(q)
    return quests, dict(inputRows=len(rows), quests=len(quests), omittedOld=omitted_old, ambiguousPrerequisites=ambiguous,
                       unnamed=sum('title' not in q for q in quests), mapped=sum('mapIDs' in q for q in quests), maps=len({m for q in quests for m in q.get('mapIDs', [])}), professionIDs=sum('profession' in q['eligibility'] for q in quests), professionRanks=0)

def numbered_series(quests):
    """Require both a complete numbered title set and the mandatory step-to-step edges."""
    groups = {}
    for quest in quests:
        match = re.fullmatch(r'(.+) \(([1-9][0-9]*)/([1-9][0-9]*)\)', quest.get('title', ''))
        if match:
            name, step, total = match.groups()
            groups.setdefault(name, []).append((int(step), int(total), quest))
    result = {}
    for name, group in groups.items():
        group.sort(key=lambda part: part[0])
        total = group[0][1]
        if total < 2 or len(group) != total:
            continue
        ids = [quest['questID'] for _, _, quest in group]
        if any(step != index or count != total or quest.get('repeatable')
               or quest.get('prerequisiteCandidates') or quest.get('prerequisiteThreshold')
               or any(quest.get('sourceDisputes', {}).get(key) for key in ('prerequisites','repeatable','offer'))
               or (index > 1 and ids[index - 2] not in quest.get('requiresAll', [])
                   and quest.get('requiresAny') != [ids[index - 2]])
               for index, (step, count, quest) in enumerate(group, 1)):
            continue
        for _, _, quest in group:
            quest['chain'] = ids
        result[ids[-1]] = name
    return result

def lua(value):
    if value is True: return 'true'
    if value is False: return 'false'
    if isinstance(value, str):
        # JSON's control escapes outside Lua's shared subset are disallowed in data text.
        if any(ord(c) < 32 for c in value): raise ValueError('Control character in catalog text')
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, list): return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value, dict): return '{'+','.join(k+'='+lua(v) for k,v in value.items())+'}'
    raise ValueError('Unsupported output value')

def start_pin(map_id, x, y):
    if type(map_id) is not int or not 0 < map_id <= 2147483647:
        raise ValueError('Invalid start UI map ID')
    if not all(type(n) in (int, float) and 0 <= n <= 100 for n in (x, y)):
        raise ValueError('Start coordinates must be finite literal percentages')
    return dict(mapID=map_id, x=x, y=y)

def start_overrides():
    engine = START_ENGINE.read_bytes()
    if hashlib.sha256(engine).hexdigest() != START_ENGINE_SHA256:
        raise ValueError('Pinned DonData quest start contract hash mismatch')
    # This pin declares one literal override. Fail closed on a changed layout.
    pattern = r'^local START_BY_FACTION = \{ \[(\d+)\] = \{ ([AH]) = (\{[^{}\n]+\}) \} \}\s*$'
    match = re.search(pattern, engine.decode('utf8'), re.MULTILINE)
    if not match:
        raise ValueError('Unrecognized faction start declaration')
    triple = LiteralParser(match[3]).parse()
    if set(triple) != {1, 2, 3}:
        raise ValueError('Invalid override coordinate triple')
    return {int(match[1]): {match[2]: start_pin(triple[1], triple[2], triple[3])}}

def attach_starts(quests, rows, overrides):
    factions = {'A':'Alliance', 'H':'Horde'}
    applied = set()
    counts = {'mapOnlyOrAbsent':0, 'itemStartsOmitted':0, 'multipleGivers':0, 'withoutGiverIDs':0,
              'singleGiver':0, 'scopeCounts':{'all':0, 'Alliance':0, 'Horde':0}}
    for q in quests:
        qid = q['questID']
        row = rows[qid]
        m,x,y = (row.get(k) for k in (1, 2, 3))
        if x is None and y is None:
            counts['mapOnlyOrAbsent'] += 1
            continue
        pin = start_pin(m, x, y)
        givers = id_list(row.get(7))
        if not givers and 'i' in (row.get(8) or ''):
            # DonData IsItemStartQuest and TurnInPoint identify these as item drop points.
            counts['itemStartsOmitted'] += 1
            continue
        starts = {factions.get(row.get(4), 'all'):pin}
        if qid in overrides:
            if row.get(4) is not None or q.get('mapIDs') != [m]:
                raise ValueError('Faction override conflicts with base tuple')
            starts = {label:overrides[qid].get(code, pin) for code,label in factions.items()}
            del q['mapIDs']  # Restore only independently declared general map evidence below.
            applied.add(qid)
        q['starts'] = starts
        counts['multipleGivers' if len(givers or []) > 1 else 'singleGiver' if givers else 'withoutGiverIDs'] += 1
        for scope in starts:
            counts['scopeCounts'][scope] += 1
    if applied != set(overrides):
        raise ValueError('Faction override lacks a supported base start')
    return counts

def enrich_fields(quests, rows, raw, fields=None, occurrences=None):
    if fields is None:
        fields = runpy.run_path(str(ROOT / 'tools/quest_catalog_evidence.py'))
    dungeon_body = raw.split('ns.ATT_DUNGEONS = {\n', 1)[1].split('\n}\n', 1)[0]
    dungeons = LiteralParser('{\n'+dungeon_body+'\n}').parse()
    wanted_ids = {q['questID'] for q in quests if 'mapIDs' not in q or 'prerequisiteCandidates' in q}
    if occurrences is None:
        occurrences = fields['load_occurrences'](RANK_SOURCE, RANKS['declarations'], wanted_ids)
    changes, unresolved = {}, {}
    for q in quests:
        qid = q['questID']
        if qid in wanted_ids:
            proof, issues = fields['select'](q, rows[qid], dungeons, occurrences[qid], LiteralParser)
            if proof:
                changes[str(qid)] = proof
            if issues:
                unresolved[str(qid)] = issues
    return changes, unresolved

ZONE_REVIEW_SHA256 = 'e48c756d52a8c321310e4b20516df933502962d0baa02e1414a599275055a06c'

def apply_reviewed_zones(quests):
    path = ROOT / 'vendor/quest-zone-review.json'
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != ZONE_REVIEW_SHA256:
        raise ValueError('Quest zone evidence changed')
    review = json.loads(raw)
    for name, expected in review['sources'].items():
        if hashlib.sha256((ROOT / 'vendor' / name).read_bytes()).hexdigest() != expected:
            raise ValueError('Changed source for quest zone evidence: ' + name)
    by_id = {q['questID']: q for q in quests}
    for key, evidence in review['quests'].items():
        q = by_id[int(key)]
        maps = evidence['maps']
        if q.get('mapIDs') or q.get('starts') or not maps or maps != sorted(set(maps)):
            raise ValueError('Reviewed zone must fill an unmapped quest with unique maps: ' + key)
        if any(type(m) is not int or not 0 < m <= 2147483647 for m in maps):
            raise ValueError('Invalid reviewed map ID')
        q['mapIDs'] = maps

def faction_giver_areas(quests):
    path = ROOT/'vendor/quest-faction-giver-areas.json'
    if hashlib.sha256(path.read_bytes()).hexdigest() != "b7585a73d8a6b9a20a059bd1212e894051ed110dd87007e80742bb2578dd4bfd":
        raise ValueError("Faction giver area evidence changed")
    review = json.loads(path.read_text(encoding="utf8"))["quests"]
    by_id = {q["questID"]: q for q in quests}
    areas = {}
    for key, evidence in review.items():
        quest_id = int(key)
        q = by_id[quest_id]
        if q.get("starts") or q.get("mapIDs") or not q.get("sourceDisputes", {}).get("mapIDs"):
            raise ValueError("Recheck disputed source fields before applying reviewed giver areas")
        if "generalMapIDs" in evidence:
            q["mapIDs"] = evidence["generalMapIDs"]
        areas[quest_id] = evidence["givers"]
    return areas


def apply_reviewed_destinations(quests):
    destination_file = ROOT/'vendor/quest-destination-review.json'
    destination_hash = hashlib.sha256(destination_file.read_bytes()).hexdigest()
    if destination_hash != 'f63ff8244e22faaacc881a4d3477e3587cc0dfc75d4eec8a320764c99c82dfa6':
        raise ValueError('Reviewed beta destination source changed')
    reviewed = json.loads(destination_file.read_text(encoding='utf8'))['quests']
    by_id = {str(q['questID']): q for q in quests}
    for quest_id, evidence in reviewed.items():
        q = by_id[quest_id]
        record = evidence['report']
        if q['eligibility'].get('faction') != record['faction'] or q.get('starts') or q.get('mapIDs'):
            raise ValueError('Review changed destination scope: ' + quest_id)
        q['destinationReports'] = [record]
    return reviewed, destination_hash


def attach_givers(quests, rows):
    source = (ROOT/'vendor/quest-giver-names.json').read_bytes()
    if hashlib.sha256(source).hexdigest() != 'f3c421a1e0145d39de8acff6de975ccbf189a2bcf766563776b58ea50e97e3c5':
        raise ValueError('Pinned quest giver evidence changed')
    evidence = json.loads(source)
    assert evidence['upstream'] == ATT_PIN and evidence['baseSHA256'] == SOURCE_SHA256
    for quest in quests:
        qid = quest['questID']
        references = evidence['quests'].get(str(qid))
        if references:
            npcs = [npc for npc, _, _ in references]
            assert sorted(id_list(rows[qid].get(7))) == npcs
            quest['questGiver'] = ', '.join(f"{evidence['names'][str(npc)]} [{npc}]" for npc in npcs)
    return len(evidence['quests'])


def writ_items(quests):
    source=RANK_SOURCE/'ExpansionFeatures.lua'
    expected='c820d713f645b82bb2521db6de87c6bf3799d9b7fb559b15a4a0de5073e8fc34'
    if hashlib.sha256(source.read_bytes()).hexdigest()!=expected:
        raise ValueError('Unreviewed Forever crafting-writ declarations')
    wanted={q['questID'] for q in quests if (q.get('title') or '').startswith("Craftsman's Writ:")}
    result={}
    for row in RANKS['declarations'](source.read_text(encoding='utf8'),('qss','cost','isDaily')):
        qid=row['questID']
        if qid not in wanted:continue
        fields=row['fields']
        if qid in result or row.get('unsupported') or set(fields)!={'qss','cost','isDaily'} or fields['isDaily']['value']!=1:
            raise ValueError(f'Unreviewed crafting-writ fields for quest {qid}')
        starts=LiteralParser(fields['qss']['expression']).parse()
        costs=LiteralParser(fields['cost']['expression']).parse()
        if not isinstance(starts,dict) or set(starts)!={1} or not isinstance(costs,dict) or set(costs)!={1}:
            raise ValueError(f'Unreviewed crafting-writ items for quest {qid}')
        item=costs[1]
        if not isinstance(item,dict) or set(item)!={1,2,3} or item[1]!='i':
            raise ValueError(f'Unsupported crafting-writ cost for quest {qid}')
        values=starts[1],item[2],item[3]
        if any(type(n)!=int or not 0<n<=2147483647 for n in values):
            raise ValueError(f'Invalid crafting-writ item or quantity for quest {qid}')
        result[qid]=dict(zip(('starterItemID','requestedItemID','requestedQuantity'),values))
    if result.keys()!=wanted or len(wanted)!=150:
        raise ValueError('Re-review crafting-writ coverage')
    return result

def build(check=False):
    source_bytes = SOURCE.read_bytes()
    if hashlib.sha256(source_bytes).hexdigest() != SOURCE_SHA256:
        raise ValueError('Pinned DonData source hash mismatch')
    raw = source_bytes.decode('utf-8')
    if 'ATT commit: '+ATT_PIN not in raw or 'Copyright (c) 2026 AllTheThings WoW Addon' not in raw:
        raise ValueError('Provenance header changed')
    body = raw.split('ns.ATT_QUESTS = {\n', 1)[1].split('\n}\n', 1)[0]
    rows = LiteralParser('{\n'+body+'\n}').parse()
    quests, counts = convert(rows)
    counts['namedGiverQuests'] = attach_givers(quests, rows)
    assert counts['inputRows'] == 4349
    wanted = {q['questID']: q['eligibility']['profession']['skillID'] for q in quests if 'profession' in q['eligibility']}
    ranks, rank_manifest = RANKS['load'](RANK_SOURCE, wanted, RANK_MANIFEST_SHA256)
    for q in quests:
        fact = ranks.get(str(q['questID']))
        if fact:
            q['eligibility']['profession']['minRank'] = fact['minRank']
    counts['professionRanks'] = len(ranks)
    counts['professionRanksUnknown'] = len(wanted) - len(ranks)
    overrides = start_overrides()
    start_counts = attach_starts(quests, rows, overrides)
    fields = runpy.run_path(str(ROOT / 'tools/quest_catalog_evidence.py'))
    available = {q['questID'] for q in quests}
    occurrences = fields['load_occurrences'](RANK_SOURCE, RANKS['declarations'], available)
    changes, unresolved = enrich_fields(quests, rows, raw, fields, occurrences)
    breadcrumbs, breadcrumb_evidence = fields['breadcrumb_links'](occurrences, available, LiteralParser)
    counts['breadcrumbSources'] = len(breadcrumbs)
    counts['breadcrumbLinks'] = sum(map(len, breadcrumbs.values()))
    prerequisite_review = runpy.run_path(str(ROOT/'tools/quest_prerequisite_review.py'))
    counts['prerequisiteDisputes'] = prerequisite_review['apply'](quests, ROOT/'vendor/quest-prerequisite-review.json')
    field_review = runpy.run_path(str(ROOT/'tools/quest_field_review.py'))
    counts['fieldDisputes'] = field_review['apply'](quests, ROOT/'vendor/quest-field-review.json')
    apply_reviewed_zones(quests)
    giver_areas = faction_giver_areas(quests)
    area_source = runpy.run_path(str(ROOT/'tools/quest_faction_start_areas.py'))
    start_areas = area_source['load'](ROOT, quests, RANKS['declarations'], LiteralParser)
    professions = [q['eligibility']['profession'] for q in quests if 'profession' in q['eligibility']]
    counts['professionIDs'] = len(professions)
    counts['professionRanks'] = sum('minRank' in rule for rule in professions)
    counts['professionRanksUnknown'] = len(professions) - counts['professionRanks']
    counts['startPinsByScope'] = {scope:sum(scope in q.get('starts', {}) for q in quests) for scope in ('all','Alliance','Horde')}
    counts['disputedWithSharedMembers'] = sum(bool(q.get('prerequisiteCandidates') and q.get('sourceDisputes', {}).get('prerequisites')) for q in quests)
    counts['questsWithStartPins'] = sum('starts' in q for q in quests)
    counts['mapped'] = sum(bool(q.get('mapIDs') or q.get('starts')) for q in quests)
    counts['maps'] = len({m for q in quests for m in q.get('mapIDs', [])}
                         | {pin['mapID'] for q in quests for pin in q.get('starts', {}).values()})
    counts['ambiguousPrerequisites'] = sum('prerequisiteCandidates' in q and not q.get('sourceDisputes', {}).get('prerequisites') for q in quests)
    counts['prerequisiteThresholds'] = sum('prerequisiteThreshold' in q for q in quests)
    reviewed, destination_hash = apply_reviewed_destinations(quests)
    counts['questsWithDestinationReports'] = len(reviewed)
    counts['locatedIncludingDestinations'] = sum(bool(q.get('mapIDs') or q.get('starts') or q.get('destinationReports')) for q in quests)
    counts['questsWithFactionGiverAreas'] = len(giver_areas)
    counts['locatedIncludingFactionGiverAreas'] = sum(bool(q.get('mapIDs') or q.get('starts') or q.get('destinationReports') or q['questID'] in giver_areas) for q in quests)
    writs = writ_items(quests)
    counts['questsWithWritItems'] = len(writs)
    counts['questsWithFactionStartAreas'] = len(start_areas)
    counts['factionStartAreaAssociations'] = sum(len(areas) for sides in start_areas.values() for areas in sides.values())
    counts['locatedIncludingFactionStartAreas'] = sum(bool(q.get('mapIDs') or q.get('starts') or q.get('destinationReports') or q['questID'] in giver_areas or q['questID'] in start_areas) for q in quests)
    series = numbered_series(quests)
    counts['numberedSeries'] = len(series)
    data = dict(schema=1, client='forever', interface=16001, compatibility='candidate', id='myepoch-bundled-forever',
                name='My Epoch bundled Forever candidates', version='DonData 1.1.0 / '+PIN[:7],
                source='https://github.com/WoW-Forever-Addons/dondata/blob/'+PIN+'/Data/ATT_Quests.lua',
                license='All The Things and DonData MIT notices: Licenses/QuestCatalog.txt', coverage='partial',
                coverageNote='Bundled Forever candidate data; exact build availability and complete zone coverage are unverified. Map associations can include quest locations and associated dungeon interiors. A start pin gives one source location and can represent a quest with multiple givers. Source disagreements are marked on the affected quests. Sourced profession IDs and explicit quest-level minimum ranks are retained; unsourced ranks remain unknown. Eligibility remains incomplete; event, reputation, exclusions and ambiguous prerequisite rules may be missing. Titles retain upstream annotations.')
    header='-- Generated by tools/build-quest-catalog.py; do not hand-edit.\n-- Derived from All The Things / DonData, MIT; see Licenses/QuestCatalog.txt.\nlocal _,E=...\nlocal data='+lua(data)+'\ndata.quests={\n'
    output=header+'\n'.join(lua(q)+',' for q in quests)+'\n}\nassert(E.QuestCatalog.Register(data))\n'
    annotations = ','.join(f'[{quest_id}]={lua(sides)}' for quest_id, sides in sorted(giver_areas.items()))
    output += 'E.BundledQuestGiverAreas={provider=E.QuestCatalog.providers[data.id],quests={'+annotations+'}}\n'
    starts_by_quest = ','.join(f'[{quest_id}]={lua(sides)}' for quest_id,sides in sorted(start_areas.items()))
    output += 'E.BundledQuestGiverAreas.startAreas={'+starts_by_quest+'}\n'
    writ_rows = ','.join(f'[{qid}]={lua(info)}' for qid,info in sorted(writs.items()))
    output += 'E.BundledQuestWrits={provider=E.QuestCatalog.providers[data.id],items={'+writ_rows+'}}\n'
    terminals = ','.join(f'[{quest_id}]={lua(name)}' for quest_id,name in sorted(series.items()))
    members = ','.join(f"[{q['questID']}]={q['chain'][-1]}" for q in quests if 'chain' in q)
    output += 'E.BundledQuestSeries={provider=E.QuestCatalog.providers[data.id],terminals={'+terminals+'},members={'+members+'}}\n'
    incoming = {}
    for origin, targets in breadcrumbs.items():
        for target in targets:
            incoming.setdefault(target, []).append(origin)
    def link_index(index):
        return '{'+','.join(f'[{qid}]={lua(sorted(ids))}' for qid, ids in sorted(index.items()))+'}'
    output += ('E.BundledQuestBreadcrumbs={provider=E.QuestCatalog.providers[data.id],outgoing='+
               link_index(breadcrumbs)+',incoming='+link_index(incoming)+'}\n')
    # The second tuple field identifies the interior. The third identifies its entrance.
    dungeon_table = raw.split('ns.ATT_DUNGEONS = {\n', 1)[1].split('\n}\n', 1)[0]
    dungeon_maps = {}
    for row in LiteralParser('{\n'+dungeon_table+'\n}').parse().values():
        name, map_id = row[1], row.get(2)
        if map_id is None:
            continue
        if type(map_id) is not int or map_id < 1 or not isinstance(name, str) or not name.strip():
            raise ValueError('Invalid dungeon map name in pinned source')
        if dungeon_maps.setdefault(map_id, name) != name:
            raise ValueError('Conflicting names for dungeon map ' + str(map_id))
    labels = ','.join('['+str(key)+']='+lua(name) for key,name in sorted(dungeon_maps.items()))
    output += 'E.BundledQuestDungeonNames={'+labels+'}\n'
    notices=(ROOT/'vendor/dondata-37a53f6/THIRD_PARTY_LICENSES.txt').read_text(encoding='utf-8').split('----------------------------------------------------------------------')[0]
    notices+='\nDonData source and conversion provenance: '+data['source']+'\n\n'+(ROOT/'vendor/dondata-37a53f6/LICENSE.txt').read_text(encoding='utf-8')
    notices+='\nAdditional direct quest field evidence: https://github.com/ATTWoWAddon/AllTheThings/tree/'+ATT_PIN+'/db/Camelot/Categories\nPinned source hashes and per-quest field evidence: vendor/bundled-quest-source.json in the source distribution.\n\n'+(RANK_SOURCE/'LICENSE').read_text(encoding='utf-8')
    notices+='\nBreadcrumb navigation uses direct isBreadcrumb and nextQuests declarations from those pinned Camelot categories. Individual paths and lines are recorded in the source manifest.\n'
    engine_url = 'https://github.com/WoW-Forever-Addons/dondata/blob/'+PIN+'/Engine/QuestData.lua'
    notices+='\nDated beta destination facts: Milenkas, WoW Forever Talents beta observer. Preserved roles distinguish reported hand-ins, outdoor objectives and physical dungeon objectives. A cache series does not identify an individual observation date. Dungeon Map identities: https://wago.tools/db2/Map/csv?build=1.60.1.70755\n'
    for row in reviewed.values():
        notices+=row['url']+'\n'
    notices+='\nQuest start semantics and faction overrides: '+engine_url+' (DonData MIT license above).\n'
    notices+='\nCrafting-writ starter items and requested quantities are drawn from the Forever ExpansionFeatures.lua file at the same ATT revision.\n'
    notices+='\nFaction-specific quest giver areas for quests 687 and 737 come from the corresponding Forever authoring blocks and compiled Zones.lua at the ATT revision above. No exact start coordinates are asserted. Source locations: vendor/quest-faction-giver-areas.json.\n'
    notices+='\nPossible faction-specific quest start areas come from matched Forever authoring blocks and compiled Camelot Zones.lua in the same MIT-licensed ATT revision. Sources: vendor/quest-start-areas/source-pins.json.\n'
    manifest=dict(repository='WoW-Forever-Addons/dondata',commit=PIN,upstreamATTCommit=ATT_PIN,source='vendor/dondata-37a53f6/ATT_Quests.lua',
                  sourceSHA256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),compatibility='candidate; interface 16001; no claimed build range',counts=counts,professionRankEvidence=rank_manifest,
                  startEvidence={'source':'vendor/dondata-37a53f6/Engine-QuestData.lua', 'url':engine_url, 'sha256':START_ENGINE_SHA256,
                                 'method':'ATT_QUESTS slots 1/2/3 give one UI map and x/y in percent. Slot 4 bounds faction. Slot 7 lists potential givers independently. A tuple pin identifies no specific giver. Rows flagged i without giver IDs represent item acquisition, and have no start pin.',
                                 'contractLines':{'factionStarts':[20,43], 'itemStarts':[542,545], 'tupleUnits':[818,824]}, 'counts':start_counts,
                                 'overrides':{str(q['questID']):q['starts'] for q in quests if q['questID'] in overrides}},
                  giverEvidence={'source':'vendor/quest-giver-names.json','sha256':'f3c421a1e0145d39de8acff6de975ccbf189a2bcf766563776b58ea50e97e3c5','scope':'Named quest giver candidates, without inferred positions or turn-ins.'},
                  factionStartAreas={'source':'vendor/quest-start-areas/source-pins.json','sha256':area_source['PIN'],
                      'scope':'Faction-scoped quest coordinates compiled alongside starter sources. Possible areas only, with no NPC-to-map assignment, exact pin, general zone or availability claim.'},
                  factionGiverAreaEvidence={'source':'vendor/quest-faction-giver-areas.json','sha256':'b7585a73d8a6b9a20a059bd1212e894051ed110dd87007e80742bb2578dd4bfd',
                      'scope':'Two scoped quest givers per quest, area only. Independent general Badlands association for 687.'},
                  fieldReview={'decisions':'vendor/quest-field-review.json','sha256':field_review['REVIEW_SHA256'],
                               'method':'Withhold disputed base fields. Independently supported base map associations survive.'},
                  destinationReview={'source':'vendor/quest-destination-review.json','sha256':destination_hash},
                  zoneReview={'source':'vendor/quest-zone-review.json','sha256':ZONE_REVIEW_SHA256,
                              'method':'Ten audited quest IDs receive general zone or dungeon associations independently of their starts.'},
                  prerequisiteReview={'decisions':'vendor/quest-prerequisite-review.json', 'sha256':prerequisite_review['REVIEW_SHA256'],
                                      'method':'Suppress disputed MIT base assertions. Shared base members remain possible links. No supplemental prerequisite lists or counts are imported.'},
                  breadcrumbEvidence={'sourceManifest':rank_manifest['sourceManifest'],'commit':ATT_PIN,'quests':breadcrumb_evidence},
                  questFieldEvidence={'sourceManifest':rank_manifest['sourceManifest'],
                                      'changes':changes, 'withheldEvidence':unresolved})
    for name, content in [('MyEpoch/BundledQuests.lua', output), ('MyEpoch/Licenses/QuestCatalog.txt', notices), ('vendor/bundled-quest-source.json', json.dumps(manifest, indent=2)+'\n')]:
        path=ROOT/name
        if check:
            assert path.read_text(encoding='utf-8')==content, 'Stale generated file: '+name
        else:
            path.parent.mkdir(parents=True,exist_ok=True);path.write_text(content,encoding='utf-8')
    print('Bundled Forever candidate catalog: '+json.dumps(counts))

if __name__ == '__main__':
    build('--check' in sys.argv)
