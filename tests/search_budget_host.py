"""Exercise actual Search and Book entry points in a fresh full-addon Lua 5.1 VM."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
parser=argparse.ArgumentParser()
parser.add_argument('--addon',type=Path)
parser.add_argument('--overlay',type=Path)
args=parser.parse_args()
tests=Path(__file__).resolve().parent
addon=args.addon or tests.parent/'MyEpoch'
v=LuaRuntime(unpack_returned_tuples=True)
v.execute('E={};time=os.time;date=os.date')
for n in (addon/'MyEpoch.toc').read_text(encoding='utf-8-sig').splitlines():
    if not n.endswith('.lua'):continue
    if n=='Book.lua':v.execute((addon.parent/'tests/wow_mock.lua').read_bytes())
    path=args.overlay/n if args.overlay and (args.overlay/n).is_file() else addon/n
    v.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',path.read_bytes(),n)
v.execute("local f=E.frame;f.scripts.OnEvent(f,'ADDON_LOADED','MyEpoch');f.scripts.OnEvent(f,'PLAYER_LOGIN');E.Book.Open()")
v.execute((tests/'search_budget_spec.lua').read_bytes())
