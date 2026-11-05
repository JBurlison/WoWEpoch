from pathlib import Path
from lupa.lua51 import LuaRuntime
D=Path(__file__).resolve().parents[1]
ROOT=D if (D/'tests/wow_mock.lua').exists() else D.parents[1]
def run_fixture(filename, mode=None, support=()):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={};time=os.time;date=os.date')
    for line in (D/'MyEpoch/MyEpoch.toc').read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        if line == 'Book.lua':
            lua.execute((ROOT/'tests/wow_mock.lua').read_text(encoding='utf-8'))
        lua.execute('assert(loadstring(...))("MyEpoch",E)', (D/'MyEpoch'/line).read_text(encoding='utf-8'))
    for name in support:
        lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
    lua.globals().MODE = mode
    lua.execute((D/'tests'/filename).read_text(encoding='utf-8'))

run_fixture('quest_kill_collector_spec.lua')
run_fixture('quest_objective_event_spec.lua')
for mode in ('nested', 'error-before-add', 'error-after-add', 'nested-then-error', 'getter-reentry'):
    run_fixture('quest_objective_reentry_spec.lua', mode)
print('PASS: kill collector, quest counters and nested updates through real frame events')

run_fixture('quest_book_scope_spec.lua', support=('sidebar_test_support.lua',))
