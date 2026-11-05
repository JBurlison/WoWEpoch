"""Run receipt-to-operation and returned-stock checks on the packaged Lua modules."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

TESTS = Path(__file__).resolve().parent
ADDON = TESTS.parent / 'MyEpoch'

def run_case(fixture, spec):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={};time=os.time;date=os.date')
    for name in (ADDON/'MyEpoch.toc').read_text(encoding='utf-8').splitlines():
        if not name or name.startswith('#'):
            continue
        if name == 'Book.lua':
            lua.execute((TESTS/'wow_mock.lua').read_text(encoding='utf-8'))
        lua.execute('assert(loadstring(...))("MyEpoch",E)',(ADDON/name).read_text(encoding='utf-8'))
    lua.execute('E.Store.Open();MyEpochDB=E.db;E.runtime={interface=16001,build=70532};E.current=E.Store.Character("accounting-test",{})')
    for name in ('craft_projection_test_support.lua','sidebar_test_support.lua'):
        lua.execute((TESTS/name).read_text(encoding='utf-8'))
    source=(TESTS/'fixtures'/fixture).read_text(encoding='utf-8')+'\n'+(TESTS/spec).read_text(encoding='utf-8')
    lua.execute('local s=...;E.TestProjection.WithFrames(function() assert(loadstring(s))() end)',source)

if __name__ == '__main__':
    for fixture, spec in (
        ('partial_commodity_return.lua','partial_commodity_return_spec.lua'),
        ('partial_commodity_return.lua','partial_commodity_parcel_spec.lua'),
        ('one_cast_output.lua','one_cast_output_spec.lua'),
        ('one_cast_output.lua','one_cast_retention_spec.lua'),
    ):
        run_case(fixture,spec)
