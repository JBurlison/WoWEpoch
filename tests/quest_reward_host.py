"""Exercise registered quest loot events and the ordinary scrapbook views in clean Lua VMs."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
p=argparse.ArgumentParser();p.add_argument('--addon',type=Path);p.add_argument('--fixtures',type=Path);args=p.parse_args()
tests=Path(__file__).resolve().parent;addon=args.addon or tests.parent/'MyEpoch';fixtures=args.fixtures or addon.parent/'tests'
def vm(saved=None):
 v=LuaRuntime(encoding=None,unpack_returned_tuples=True);v.execute(b'E={};time=os.time;date=os.date')
 for n in (addon/'MyEpoch.toc').read_text(encoding='utf-8-sig').splitlines():
  if not n.endswith('.lua'):continue
  if n=='Book.lua':v.execute((fixtures/'wow_mock.lua').read_bytes())
  v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(addon/n).read_bytes(),n.encode())
 if saved:v.execute(b'assert(loadstring(...))()',saved)
 v.execute(b"""function fire(name,...)local f=E.frame;assert(f.events[name],name);return f.scripts.OnEvent(f,name,...)end
 fire('ADDON_LOADED','MyEpoch');fire('PLAYER_LOGIN');assert(E.current and not E.failure)
 function qready(c)for i=1,1000 do if E.Query.EnsureWarm(c)=='ready'then return end;E.Query.ProcessPreparation(500)end;error('query readiness')end
 """)
 return v
v=vm();v.execute((fixtures/'craft_projection_test_support.lua').read_bytes())
v.execute((tests/'quest_reward_spec.lua').read_bytes())
saved=v.execute(b"""fire('PLAYER_LOGOUT');local function enc(x)
 if type(x)=='table'then local t={'{'};for k,y in pairs(x)do t[#t+1]='['..enc(k)..']='..enc(y)..','end;t[#t+1]='}';return table.concat(t)
 elseif type(x)=='string'then return string.format('%q',x)else return tostring(x)end end;return 'MyEpochDB='..enc(MyEpochDB)""")
w=vm(saved);w.execute(b"""local c=E.current;qready(c);local _,_,_,before=E.QuestRewards.Page(c,109)
assert(before>=4);local seq=c.seq
fire('QUEST_LOOT_RECEIVED',109,'item:2589:0',2);local rows,_,_,after=E.QuestRewards.Page(c,109)
assert(after==before+1 and rows[1].sequence>seq and rows[1].quantity==2)
assert(rows[1].recipient==nil and rows[1].group==nil);print('PASS quest rewards fresh logout/login: repeated event appended and original evidence retained')""")
