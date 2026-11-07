"""Pure Lua 5.1 controller text algorithms, independent of game UI mocks."""
from pathlib import Path
import hashlib
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={}')
    for name in ('ControllerUnicodeData.lua', 'ControllerUnicode.lua',
                 'ControllerChinese.lua', 'ControllerComposition.lua'):
        lua.execute('local s,n=...; assert(loadstring(s,"@"..n))("MyEpoch",E)',
                    (ROOT / 'MyEpoch' / name).read_text(encoding='utf-8'), name)
    return lua


def main():
    lua = runtime()
    lua.execute((ROOT / 'tests/controller_unicode_spec.lua').read_text(encoding='utf-8'))
    fixture = ROOT / 'tests/fixtures/Unicode17-GraphemeBreakTest.txt'
    assert hashlib.sha256(fixture.read_bytes()).hexdigest() == (
        'e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec')
    boundaries = lua.eval('E.ControllerUnicode.Boundaries')
    count = 0
    for line_number, line in enumerate(fixture.read_text(encoding='utf-8').splitlines(), 1):
        value = line.partition('#')[0].strip()
        if not value:
            continue
        text, expected = '', []
        for token in value.split():
            if token == '÷':
                expected.append(len(text.encode('utf-8')))
            elif token != '×':
                text += chr(int(token, 16))
        actual = list(boundaries(text).values())
        assert actual == expected, (line_number, value, actual, expected)
        count += 1
    print(f'PASS Unicode 17 extended-grapheme conformance: {count} cases')


if __name__ == '__main__':
    main()
