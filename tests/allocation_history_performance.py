"""Compare shared allocations with independent historical replay runtimes."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

def runtime():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={};time=os.time;date=os.date')
    for line in (ROOT/'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):continue
        path=ROOT/'MyEpoch'/line.replace('\\','/')
        if path.name=='Book.lua':lua.execute((ROOT/'tests/wow_mock.lua').read_text(encoding='utf-8'))
        lua.execute('assert(loadstring(...))("MyEpoch",E)',path.read_text(encoding='utf-8'))
    lua.execute('E.Store.Open(nil);E.current=E.Store.Character("allocation-test-controller",{name="TEST"})')
    return lua

results=[]
for shared in [False,True]:
    lua=runtime();lua.globals().USE_SHARED=shared
    rows,capture=lua.execute((ROOT/'tests/fixtures/allocation-cases.lua').read_text(encoding='utf-8'))
    lua.globals().capture=capture
    bank=(ROOT/'tests/bank_costs_spec.lua').read_text(encoding='utf-8').split("local a=char('custody-A'")[0]
    lua.execute(bank+'\n'+(ROOT/'tests/fixtures/allocation-bank-cases.lua').read_text(encoding='utf-8'))
    lua.execute('assert(loadstring(...))("MyEpoch",E)',(ROOT/'tests/fixtures/uiforever-craft-costs.lua').read_text(encoding='utf-8'))
    lua.execute('local S,F=E.Store,E.Economy\n'+(ROOT/'tests/fixtures/allocation-craft-cases.lua').read_text(encoding='utf-8'))
    results.append('\n'.join(rows.values()))
assert results[0]==results[1],'Shared allocations differ from original historical-boundary replay.'
print(f'PASS {len(results[0].splitlines())} complete allocation snapshots in independent current-production runtimes.')
lua=runtime()
lua.execute((ROOT/'tests/fixtures/auction_history_performance.lua').read_text(encoding='utf-8'))
lua.execute((ROOT/'tests/fixtures/allocation-budgets.lua').read_text(encoding='utf-8'))
