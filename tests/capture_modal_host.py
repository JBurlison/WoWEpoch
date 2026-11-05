"""Use a fresh real TOC and ordinary capture keybinding for each modal suspension case."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
t=Path(__file__).resolve().parent;p=argparse.ArgumentParser()
p.add_argument('--addon',type=Path);p.add_argument('--overlay',type=Path);args=p.parse_args()
addon=args.addon or t.parent/'MyEpoch'
for scenario in ('apply','cancel','manual-open','manual-close','record-replaced','owner-changed','recorder-handoff','unavailable','combat','combat-manual-close','location','filter'):
 v=LuaRuntime(unpack_returned_tuples=True);v.execute('E={};time=os.time;date=os.date')
 for n in (addon/'MyEpoch.toc').read_text(encoding='utf8').splitlines():
  if not n.endswith('.lua'):continue
  if n=='Book.lua':v.execute((addon.parent/'tests/wow_mock.lua').read_bytes())
  f=args.overlay/n if args.overlay and(args.overlay/n).is_file()else addon/n
  v.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',f.read_bytes(),n)
 v.execute("local f=E.frame;f.scripts.OnEvent(f,'ADDON_LOADED','MyEpoch');f.scripts.OnEvent(f,'PLAYER_LOGIN')")
 v.globals().SCENARIO=scenario;v.execute((t/'capture_modal_spec.lua').read_bytes())
 print('PASS bound screenshot preserves staged picker -',scenario)
