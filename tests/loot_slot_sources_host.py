"""Open actual loot slots in isolated Lua 5.1 sessions, then reload the saved observations."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
p=argparse.ArgumentParser();p.add_argument('--addon',type=Path);p.add_argument('--fixtures',type=Path);p.add_argument('--overlay',type=Path);args=p.parse_args()
tests=Path(__file__).resolve().parent;addon=args.addon or tests.parent/'MyEpoch';fixtures=args.fixtures or addon.parent/'tests'
def vm(saved=None):
 v=LuaRuntime(encoding=None,unpack_returned_tuples=True);v.execute(b'E={};time=os.time;date=os.date')
 for n in (addon/'MyEpoch.toc').read_text(encoding='utf-8-sig').splitlines():
  if not n.endswith('.lua'):continue
  if n=='Book.lua':v.execute((fixtures/'wow_mock.lua').read_bytes())
  v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',((args.overlay/n) if args.overlay and (args.overlay/n).is_file() else (addon/n)).read_bytes(),n.encode())
 if saved:v.execute(b'assert(loadstring(...))()',saved)
 v.execute(b"""function fire(name,...)local f=E.frame;assert(f.events[name],name);return f.scripts.OnEvent(f,name,...)end
 fire('ADDON_LOADED','MyEpoch');fire('PLAYER_LOGIN');assert(E.current and not E.failure)
 function qready(c)for i=1,1000 do if E.Query.EnsureWarm(c)=='ready'then return end;E.Query.ProcessPreparation(500)end;error('query readiness')end
 """)
 return v
v=vm();v.execute((tests/'loot_slot_sources_spec.lua').read_bytes())
saved=v.execute(b"""fire('PLAYER_LOGOUT');local function enc(x)
 if type(x)=='table'then local t={'{'};for k,y in pairs(x)do t[#t+1]='['..enc(k)..']='..enc(y)..','end;t[#t+1]='}';return table.concat(t)
 elseif type(x)=='string'then return string.format('%q',x)else return tostring(x)end end;return 'MyEpochDB='..enc(MyEpochDB)""")
w=vm(saved)
w.execute(b"""local c=E.current;local d=E.Drops.Report(c,{dimension='mob',source='loot_window',from=0,through=E.API.Now()+1})
 assert(#d.rows==2 and #d.groups['npc:515'].rows==1 and d.groups['npc:3100'].reportedUnits==6)
 E.Book.Open();E.Book.SetChapter('Loot');E.Book.lootMode='drops';E.Book.dropDimension='mob';E.Book.Render(true)
 for i=1,1200 do if E.DropView.lastReport then break end;E.frame.scripts.OnUpdate(E.frame,.06);E.Book.Render()end;local report=assert(E.DropView.lastReport);assert(report.groups['npc:3100'].label=='Elder Boar')""")
print('PASS fresh source grouping and Loot chapter')
