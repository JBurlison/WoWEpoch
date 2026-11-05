"""Extract literal quest requirements from reviewed ATT data, never execute Lua.

This is deliberately a bounded data reader, not a Lua interpreter. Only bare
q(integer[, {fields}]) constructors and literal direct keys are supported.
Other expression values are retained as unresolved evidence. Nested tables and
calls are skipped when reading a quest's fields, so a recipe's learnedAt cannot
become its parent quest's rank. Unsupported/malformed syntax fails the build.
"""
import hashlib
import json
import re
from dataclasses import dataclass

PIN = '6174f27d042f8e4ff2624b5d9a099a707e4852a9'
MAX_INT = 2147483647
LONG = re.compile(r'\[(=*)\[')
WORD = re.compile(r'[A-Za-z_][A-Za-z_0-9]*|\d+(?:\.\d+)?')
FIELDS = ('requireSkill', 'learnedAt')


@dataclass(frozen=True)
class Token:
    kind: str
    text: str
    line: int
    start: int
    end: int


def tokenize(text):
    if len(text) > 2_000_000:
        raise ValueError('Oversized ATT source')
    out = []; i = 0; line = 1
    while i < len(text):
        ch = text[i]
        if ch.isspace():
            line += ch == '\n'; i += 1; continue
        comment = text.startswith('--', i)
        bracket = LONG.match(text, i + 2 if comment else i)
        if bracket:
            close = ']' + bracket[1] + ']'
            end = text.find(close, bracket.end())
            if end < 0:
                raise ValueError('Unterminated long string/comment')
            end += len(close)
            if not comment:
                out.append(Token('string', text[i:end], line, i, end))
            line += text[i:end].count('\n'); i = end; continue
        if comment:
            end = text.find('\n', i); i = len(text) if end < 0 else end; continue
        if ch in '\"\'':
            start = i; begin = line; i += 1
            while i < len(text):
                if text[i] == '\\':
                    if i + 1 >= len(text):
                        raise ValueError('Unterminated string escape')
                    line += text[i + 1] == '\n'; i += 2
                elif text[i] == ch:
                    i += 1; break
                elif text[i] in '\r\n':
                    raise ValueError('Unescaped string newline')
                else:
                    i += 1
            else:
                raise ValueError('Unterminated string')
            out.append(Token('string', text[start:i], begin, start, i)); continue
        word = WORD.match(text, i)
        if word:
            value = word.group(); end = word.end()
            out.append(Token('number' if ch.isdigit() else 'name', value, line, i, end)); i = end
        else:
            out.append(Token('punct', ch, line, i, i + 1)); i += 1
    return out


def string_value(token):
    text = token.text
    long = LONG.match(text)
    if long:
        value = text[long.end():-(len(long[1]) + 2)]
        return value[1:] if value.startswith('\n') else value
    escapes = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r',
               't': '\t', 'v': '\v', '\\': '\\', '"': '"', "'": "'", '\n': '\n'}
    def replace(match):
        value = match[0][1:]
        if value.isdecimal() and int(value) <= 255:
            return chr(int(value))
        if value in escapes:
            return escapes[value]
        raise ValueError('Unsupported literal-key escape')
    return re.sub(r'\\(?:\d{1,3}|[\s\S])', replace, text[1:-1])


def guarded_positions(ts, pairs):
    """Identify quest calls below restricted tables or executable predicates."""
    restricted = set()
    branch_ranges = {}
    branches = {'aqd', 'hqd'}
    selectors = {'r', 'races', 'c', 'classes'}
    for start, end in pairs.items():
        if ts[start].text != '{':
            continue
        j = start + 1
        while j < end:
            key = ts[j].text
            key_end = j
            if key == '[':
                key_end = pairs[j]
                key = (string_value(ts[j+1]) if key_end == j+2 and ts[j+1].kind == 'string' else None)
            if ts[key_end+1].text == '=':
                if key in selectors:
                    restricted.add(start)
                if key in branches:
                    begin = key_end + 2
                    stop = begin
                    while stop < end and ts[stop].text not in (',', ';'):
                        stop = pairs.get(stop, stop) + 1
                    branch_ranges[begin] = branch_ranges.get(begin, 0) + 1
                    branch_ranges[stop] = branch_ranges.get(stop, 0) - 1
            j = pairs.get(j, j) + 1
    positions = set()
    scopes = []
    blocks = []
    branch_depth = 0
    for i, t in enumerate(ts):
        branch_depth += branch_ranges.get(i, 0)
        if t.kind == 'name':
            if t.text in ('function','if','do','repeat'):
                # The generated category root registers an unconditional data loader.
                loader = (t.text == 'function' and i >= 4 and ts[i-4].text == 'AddEventHandler'
                          and ts[i-3].text == '(' and ts[i-2].kind == 'string'
                          and string_value(ts[i-2]) == 'OnBuildDataCache' and ts[i-1].text == ',')
                blocks.append(not loader)
            elif t.text in ('end','until') and blocks:
                blocks.pop()
            elif t.text == 'q' and (branch_depth or any(scopes) or any(blocks) or (i and ts[i-1].text in ('and','or','not'))):
                positions.add(i)
        elif i in pairs:
            class_call = t.text == '(' and i and ts[i-1].text in ('cl', 'race')
            scopes.append(i in restricted or class_call)
        elif t.text in (')',']','}'):
            scopes.pop()
    return positions


def declarations(text, fields=FIELDS, guard_ancestry=False):
    ts = tokenize(text); pairs = {}; stack = []; closing = {'}': '{', ')': '(', ']': '['}
    for i, token in enumerate(ts):
        if token.kind != 'punct':
            continue
        if token.text in '{([':
            stack.append(i)
            if len(stack) > 128:
                raise ValueError('Excessive source nesting')
        elif token.text in closing:
            if not stack or ts[stack[-1]].text != closing[token.text]:
                raise ValueError('Unbalanced source delimiters')
            pairs[stack.pop()] = i
    if stack:
        raise ValueError('Unclosed source delimiters')
    guarded = guarded_positions(ts, pairs) if guard_ancestry else set()
    out = []
    for i, token in enumerate(ts):
        if (token.kind, token.text) != ('name', 'q') or i + 1 >= len(ts) or ts[i + 1].text != '(':
            continue
        if i and ts[i - 1].text in ('.', ':'):
            continue  # unrelated object methods, not ATT's quest constructor
        if i and ts[i - 1].text == 'function':
            raise ValueError('Quest constructor redefinition is unsupported')
        end = pairs[i + 1]
        if i + 2 >= end or ts[i + 2].kind != 'number' or not re.fullmatch(r'[1-9]\d*', ts[i + 2].text):
            raise ValueError('Quest ID must be a positive literal integer')
        quest = int(ts[i + 2].text)
        if quest > MAX_INT:
            raise ValueError('Quest ID out of range')
        row = {'questID': quest, 'line': token.line, 'fields': {}}
        if i in guarded:
            row['unsupported'] = 'Conditional, executable or restricted ancestor'
            out.append(row); continue
        if i + 3 == end:
            out.append(row); continue
        if ts[i + 3].text != ',' or i + 4 >= end:
            raise ValueError('Unsupported quest constructor arguments at line ' + str(token.line))
        if ts[i + 4].text != '{':
            # ATT also wraps faction-dependent tables in ResolveQuestData.
            # Do not interpret wrapper/conditional semantics or take inner ranks.
            row['unsupported'] = 'Nonliteral quest argument'; out.append(row); continue
        if pairs[i + 4] != end - 1:
            raise ValueError('Unexpected expression after quest table')
        first = i + 4; last = end - 1; j = first + 1
        scan = j
        while scan < last:
            if ts[scan].kind == 'name' and ts[scan].text == 'function':
                row['unsupported'] = 'Quest table contains executable fields'; break
            scan = pairs[scan] + 1 if scan in pairs else scan + 1
        if row.get('unsupported'):
            out.append(row); continue
        while j < last:
            stop = j; top = []
            while stop < last and ts[stop].text not in (',', ';'):
                top.append(stop); stop = pairs[stop] + 1 if stop in pairs else stop + 1
            if stop == j:
                raise ValueError('Empty quest field')
            key = None; value_start = j
            if ts[j].kind == 'name' and j + 1 < stop and ts[j + 1].text == '=':
                key = ts[j].text; value_start = j + 2
            elif ts[j].text == '[':
                key_end = pairs[j]
                if key_end != j + 2 or ts[j + 1].kind not in ('string', 'number') or key_end + 1 >= stop or ts[key_end + 1].text != '=':
                    raise ValueError('Computed/malformed quest field key')
                key = string_value(ts[j + 1]) if ts[j + 1].kind == 'string' else None
                value_start = key_end + 2
            elif ts[j].text in fields:
                raise ValueError('Missing requirement field assignment')
            if value_start == stop:
                raise ValueError('Missing quest field value')
            # An extra top-level assignment means a missing field separator.
            # Comparisons are allowed as unresolved values, never evaluated.
            for at in top:
                if at < value_start or ts[at].text != '=':
                    continue
                before = ts[at - 1].text if at > value_start else ''
                after = ts[at + 1].text if at + 1 < stop else ''
                if before not in ('=', '~', '<', '>') and after != '=':
                    raise ValueError('Missing quest field separator at line ' + str(ts[at].line))
            if key in fields:
                if key in row['fields']:
                    raise ValueError('Duplicate direct requirement field: ' + key)
                values = ts[value_start:stop]
                literal = len(values) == 1 and values[0].kind == 'number' and re.fullmatch(r'\d+', values[0].text)
                value = int(values[0].text) if literal else None
                row['fields'][key] = {'value': value, 'literal': bool(literal), 'line': ts[j].line,
                                      'expression': text[values[0].start:values[-1].end]}
            j = stop + 1
        out.append(row)
    return out


def select(wanted, occurrences):
    known = {}; unknown = {}
    for quest, skill in sorted(wanted.items()):
        ranked = []; reason = None
        for row in occurrences.get(quest, []):
            if row.get('unsupported'):
                reason = row['unsupported']; break
            identity = row['fields'].get('requireSkill'); rank = row['fields'].get('learnedAt')
            if identity and (not identity['literal'] or identity['value'] != skill):
                reason = 'Conflicting or nonliteral direct profession requirement'; break
            if rank:
                if not identity or not rank['literal'] or not 0 <= rank['value'] <= MAX_INT:
                    reason = 'Minimum rank lacks a matching literal profession/rank pair'; break
                ranked.append(row)
        values = {row['fields']['learnedAt']['value'] for row in ranked}
        if len(values) > 1:
            reason = 'Conflicting direct minimum ranks'
        if reason or not ranked:
            unknown[str(quest)] = reason or 'No explicit direct minimum rank'
        else:
            known[str(quest)] = {'skillID': skill, 'minRank': next(iter(values)), 'evidence': ranked}
    return known, unknown


def load(directory, wanted, expected_manifest_sha256):
    manifest_bytes = (directory / 'source-pins.json').read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != expected_manifest_sha256:
        raise ValueError('ATT rank source manifest hash mismatch')
    manifest = json.loads(manifest_bytes)
    if manifest['commit'] != PIN or manifest['repository'] != 'ATTWoWAddon/AllTheThings':
        raise ValueError('Unexpected ATT rank source pin')
    occurrences = {}; paths = set()
    for pin in manifest['files'] + [manifest['license']]:
        name = pin['path']
        if not re.fullmatch(r'[A-Za-z_]+\.(?:lua|txt)|LICENSE', name) or name in paths:
            raise ValueError('Invalid/duplicate pinned source path')
        paths.add(name)
        data = (directory / name).read_bytes()
        if len(data) != pin['bytes'] or hashlib.sha256(data).hexdigest() != pin['sha256']:
            raise ValueError('ATT rank input hash/length mismatch: ' + name)
        if pin is manifest['license']:
            continue
        for row in declarations(data.decode('utf-8')):
            row.update(path=pin['upstreamPath'], sourceSHA256=pin['sha256'])
            occurrences.setdefault(row['questID'], []).append(row)
    known, unknown = select(wanted, occurrences)
    report = {'repository': manifest['repository'], 'commit': PIN,
              'sourceManifest': 'vendor/' + directory.name + '/source-pins.json', 'sourceManifestSHA256': expected_manifest_sha256,
              'method': 'Literal direct q quest requireSkill/learnedAt pairs; no upstream Lua execution. Nested recipe fields excluded.',
              'compatibility': 'Candidate source facts only; released-client availability and complete eligibility unverified.',
              'known': known, 'unknown': unknown}
    return known, report
