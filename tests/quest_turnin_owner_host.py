from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
here=Path(__file__).resolve().parent
opts=argparse.ArgumentParser();opts.add_argument('--addon',type=Path,default=here.parent/'MyEpoch');opts.add_argument('--fixtures',type=Path,default=here);opts.add_argument('--overlay',type=Path);args=opts.parse_args()
v=LuaRuntime(encoding=None,unpack_returned_tuples=True);v.execute(b'E={};time=os.time;date=os.date')
for name in (args.addon/'MyEpoch.toc').read_text(encoding='utf-8-sig').splitlines():
    if not name.endswith('.lua'):continue
    if name=='Book.lua':v.execute((args.fixtures/'wow_mock.lua').read_bytes())
    source=args.addon/name
    if args.overlay and (args.overlay/name).exists():source=args.overlay/name
    v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',source.read_bytes(),name.encode())
v.execute(b"local f=E.frame;f.scripts.OnEvent(f,'ADDON_LOADED','MyEpoch');f.scripts.OnEvent(f,'PLAYER_LOGIN');assert(E.current and not E.failure)")
v.execute((here/'quest_turnin_owner_spec.lua').read_text(encoding='utf-8-sig').encode(),name='quest_turnin_owner_spec')
