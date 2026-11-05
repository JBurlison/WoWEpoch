"""Exercise registered encounter loot events and the ordinary scrapbook views in clean Lua VMs."""
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
v.execute((tests/'encounter_loot_spec.lua').read_bytes())
saved=v.execute(b"""fire('PLAYER_LOGOUT');local function enc(x)
 if type(x)=='table'then local t={'{'};for k,y in pairs(x)do t[#t+1]='['..enc(k)..']='..enc(y)..','end;t[#t+1]='}';return table.concat(t)
 elseif type(x)=='string'then return string.format('%q',x)else return tostring(x)end end;return 'MyEpochDB='..enc(MyEpochDB)""")
w=vm(saved);w.execute(b"""local c=E.current; qready(c)
local rows,_,_,n=E.EncounterLoot.Page(c,1)
assert(n==1 and rows[1].starred and rows[1].quantity==3 and rows[1].itemID==2589)
local old=rows[1];fire('ENCOUNTER_LOOT_RECEIVED',7001,2589,'item:2589:88',3)
rows,_,_,n=E.EncounterLoot.Page(c,1);assert(n==2 and rows[1].sequence>old.sequence and rows[2]==old)
assert(rows[1].session==E.Collectors.session and rows[1].session~=old.session)
local B=E.Book;B.Open();assert(E.SearchView.Open(E.Search.Find(c,'encounter_loot_received','items').hits[1]))
for i=1,100 do if B.right.used.ledgerItem==1 then break end;E.frame.scripts.OnUpdate(E.frame,.1);B.Render()end
assert(B.chapter=='Loot' and B.lootMode=='encounter_loot' and B.right.used.ledgerItem==1)
print('PASS saved encounter notices compiled in fresh VM, new recording session, actual source detail')""")

