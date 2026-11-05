"""Select explicit map associations and prerequisite counts from matching pinned quest IDs."""
import hashlib
import json
from collections import defaultdict

FIELDS = ('mapID', 'maps', 'coords', 'coord', 'r', 'aqd', 'hqd', 'sourceQuests', 'sqreq', 'isBreadcrumb', 'nextQuests')
MAX_ID = 2147483647


def positive(value):
    return type(value) is int and 0 < value <= MAX_ID


def dense(value):
    if not isinstance(value, dict) or set(value) != set(range(1, len(value) + 1)):
        raise ValueError('Expected a dense array')
    return [value[i] for i in range(1, len(value) + 1)]


def ids(value):
    result = dense(value)
    if not result or not all(positive(x) for x in result) or len(result) != len(set(result)):
        raise ValueError('Malformed ID list')
    return sorted(result)


def breadcrumb_links(occurrences, available, literal):
    links, evidence = {}, {}
    for qid in sorted(occurrences):
        targets, references = None, []
        for row in occurrences[qid]:
            fields = row['fields']
            if row.get('unsupported'):
                break
            if 'isBreadcrumb' not in fields and 'nextQuests' not in fields:
                continue
            if fields.get('isBreadcrumb', {}).get('value') != 1 or 'nextQuests' not in fields:
                break
            try:
                current = ids(literal(fields['nextQuests']['expression']).parse())
            except (ValueError, IndexError):
                break
            if qid in current or (targets is not None and targets != current):
                break
            targets = current
            references.append({'path': row['path'], 'line': row['line']})
        else:
            supported = [target for target in targets or [] if target in available]
            if supported:
                links[qid] = supported
                evidence[str(qid)] = {'targets': supported, 'declarations': references}
    return links, evidence


def coordinate(point):
    xy = dense(point)
    if len(xy) != 2 or any(type(n) not in (int, float) or not 0 <= n <= 100 for n in xy):
        raise ValueError('Malformed coordinate')


def associations(fields, literal):
    maps = set()
    for key in ('mapID', 'maps', 'coord', 'coords'):
        if key not in fields:
            continue
        value = literal(fields[key]['expression']).parse()
        if key == 'mapID':
            if not positive(value):
                raise ValueError('Malformed direct map')
            maps.add(value)
        elif key == 'maps':
            maps.update(ids(value))
        elif key == 'coords':
            if not isinstance(value, dict) or not value or not all(positive(m) for m in value):
                raise ValueError('Malformed map coordinate table')
            for m, points in value.items():
                points = dense(points)
                if not points:
                    raise ValueError('No coordinates')
                for point in points:
                    coordinate(point)
                maps.add(m)
        else:
            raise ValueError('Unverified coordinate format')
    return sorted(maps)


def load_occurrences(directory, declarations, wanted):
    pins = json.loads((directory / 'source-pins.json').read_bytes())
    result = defaultdict(list)
    for pin in pins['files']:
        raw = (directory / pin['path']).read_bytes()
        if hashlib.sha256(raw).hexdigest() != pin['sha256']:
            raise ValueError('Unverified ATT source bytes')
        for row in declarations(raw.decode('utf8'), FIELDS, guard_ancestry=True):
            if row['questID'] in wanted:
                row['path'] = pin['upstreamPath']
                result[row['questID']].append(row)
    return result


def select(quest, source, dungeons, occurrences, literal):
    qid = quest['questID']
    wanted_maps = 'mapIDs' not in quest
    wanted_count = 'prerequisiteCandidates' in quest
    maps = set()
    evidence = []
    issues = []
    if wanted_maps and source.get(15) is not None:
        instance = source[15]
        m = dungeons.get(instance, {}).get(2)
        if not positive(instance) or not positive(m):
            issues.append('Instance has no verified UI map')
        else:
            maps.add(m)
            evidence.append({'table': 'ATT_QUESTS', 'questID': qid, 'slot': 15,
                             'instanceID': instance, 'lookup': 'ATT_DUNGEONS[instanceID][2]', 'mapID': m})
    declared_maps = set()
    map_evidence = []
    counts = []
    uncertain_map = False
    uncertain_count = False
    for row in occurrences:
        fields = row['fields']
        where = {'path': row['path'], 'line': row['line']}
        unsupported = row.get('unsupported') or any(k in fields for k in ('aqd', 'hqd'))
        if 'r' in fields:
            faction = fields['r']['value']
            supported_faction = {'Alliance': 2, 'Horde': 1}.get(quest['eligibility'].get('faction'))
            unsupported = unsupported or faction not in (1, 2) or faction != supported_faction
        if unsupported:
            uncertain_map = uncertain_count = True
            issues.append(dict(where, reason='Conditional, unsupported, or inconsistent faction declaration'))
            continue
        if wanted_maps:
            # On faction-dependent starts the quest coordinate maps can name
            # both sides' start points. Keep separately declared general maps.
            map_fields = fields
            if len(quest.get('starts', {})) > 1:
                map_fields = {key:value for key,value in fields.items() if key in ('maps','mapID')}
            try:
                direct = associations(map_fields, literal)
            except ValueError:
                uncertain_map = True
                issues.append(dict(where, reason='Unsupported direct map encoding'))
            else:
                if direct:
                    declared_maps.add(tuple(direct))
                    map_evidence.append(dict(where, fields={k:map_fields[k]['expression'] for k in ('mapID','maps','coords','coord') if k in map_fields}))
        if wanted_count and ('sqreq' in fields or 'sourceQuests' in fields):
            try:
                pre = ids(literal(fields['sourceQuests']['expression']).parse())
                n = fields['sqreq']['value']
                if pre != quest['prerequisiteCandidates'] or n != source.get(11) or not positive(n) or not 1 < n < len(pre):
                    raise ValueError('Missing or inconsistent explicit threshold')
            except (ValueError, KeyError):
                uncertain_count = True
            else:
                counts.append(dict(where, count=n, sourceQuests=pre))
    if len(declared_maps) > 1:
        uncertain_map = True
        issues.append('Conflicting direct map sets across declarations')
    if declared_maps and not uncertain_map:
        maps.update(next(iter(declared_maps)))
        evidence.extend(map_evidence)
    if maps:
        quest['mapIDs'] = sorted(maps)
    if counts and not uncertain_count:
        quest['prerequisiteThreshold'] = {'required': counts[0]['count'], 'questIDs': quest.pop('prerequisiteCandidates')}
        evidence.extend(counts)
    return evidence, issues
