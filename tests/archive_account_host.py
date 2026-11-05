"""Exercise account and per-character storage measurement in a fresh addon VM."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
tests=Path(__file__).resolve().parent
addon=tests.parent/'MyEpoch'
v=LuaRuntime(unpack_returned_tuples=True);v.execute('E={};time=os.time;date=os.date')
for n in (addon/'MyEpoch.toc').read_text(encoding='utf8').splitlines():
    if not n.endswith('.lua'):continue
    if n=='Book.lua':v.execute((tests/'wow_mock.lua').read_bytes())
    v.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(addon/n).read_bytes(),n)
v.execute("local f=E.frame;f.scripts.OnEvent(f,'ADDON_LOADED','MyEpoch');f.scripts.OnEvent(f,'PLAYER_LOGIN')")
for name in ('archive_account_spec.lua','archive_measurement_spec.lua'):v.execute((tests/name).read_bytes())
