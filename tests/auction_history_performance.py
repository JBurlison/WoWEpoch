"""Check lookup work and financial results in an isolated real Lua 5.1 runtime."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('E={};time=os.time;date=os.date')
for line in (ROOT/'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8').splitlines():
    if not line or line.startswith('#'):
        continue
    path=ROOT/'MyEpoch'/line.replace('\\','/')
    if path.name=='Book.lua':
        lua.execute((ROOT/'tests/wow_mock.lua').read_text(encoding='utf-8'))
    lua.execute('assert(loadstring(...))("MyEpoch",E)',path.read_text(encoding='utf-8'))
lua.execute('E.Store.Open(nil);E.current=E.Store.Character("auction-performance-controller",{name="TEST"})')
lua.execute((ROOT/'tests/fixtures/auction_history_performance.lua').read_text(encoding='utf-8'))
lua.execute((ROOT/'tests/auction_history_scaling_spec.lua').read_text(encoding='utf-8'))
