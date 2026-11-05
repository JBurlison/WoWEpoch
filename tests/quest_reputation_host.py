from pathlib import Path
import argparse,sys,json,time
from lupa.lua51 import LuaRuntime
tests=Path(__file__).resolve().parent
def vm(addon,overlay=None,provider=None,faction=b'Alliance'):
 v=LuaRuntime(encoding=None,unpack_returned_tuples=True)
 v.execute(b'E={};time=os.time;date=os.date')
 for n in (addon/'MyEpoch.toc').read_text(encoding='utf8').splitlines():
  if not n.endswith('.lua'):continue
  if n=='Book.lua':v.execute((addon.parent/'tests/wow_mock.lua').read_bytes())
  p=overlay/n if overlay and (overlay/n).is_file() else addon/n
  v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',p.read_bytes(),n.encode())
 v.globals().FACTION=faction
 v.execute(b"UnitFactionGroup=function()return FACTION end;UnitClassBase=function()return 'WARRIOR'end")
 if provider:provider(v)
 v.execute(b"function fire(n,...)E.frame.scripts.OnEvent(E.frame,n,...)end;fire('ADDON_LOADED','MyEpoch');fire('PLAYER_LOGIN');J=E.QuestieBridge;B=E.Book;c=E.current;T=E.QuestAtlas")
 v.execute((tests/'sidebar_test_support.lua').read_bytes())
 return v
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--addon',type=Path,default=tests.parent/'MyEpoch');p.add_argument('--overlay',type=Path);a=p.parse_args()
 v=vm(a.addon,a.overlay);v.execute((tests/'quest_reputation_spec.lua').read_bytes());print('PASS optional quest reputation / live book, boundaries, source isolation.')
