"""Run event_throttle_spec.lua through the real Bootstrap frame in a fresh Lua 5.1 VM."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('E={};time=os.time;date=os.date')
for line in (ROOT / 'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8').splitlines():
    if not line or line.startswith('#'):
        continue
    if line == 'Book.lua':
        lua.execute((ROOT / 'tests/wow_mock.lua').read_text(encoding='utf-8'))
    lua.execute('assert(loadstring(...))("MyEpoch",E)', (ROOT / 'MyEpoch' / line).read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/event_throttle_spec.lua').read_text(encoding='utf-8'))
