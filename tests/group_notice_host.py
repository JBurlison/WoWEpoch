from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
here=Path(__file__).resolve().parent
opts=argparse.ArgumentParser();opts.add_argument('--addon',type=Path,default=here.parent/'MyEpoch');opts.add_argument('--fixtures',type=Path,default=here);opts.add_argument('--overlay',type=Path);args=opts.parse_args()
def openvm(saved=None):
    v=LuaRuntime(encoding=None,unpack_returned_tuples=True);v.execute(b'E={};time=os.time;date=os.date')
    for name in (args.addon/'MyEpoch.toc').read_text(encoding='utf-8-sig').splitlines():
        if not name.endswith('.lua'):continue
        if name=='Book.lua':v.execute((args.fixtures/'wow_mock.lua').read_bytes())
        source=args.addon/name
        if args.overlay and (args.overlay/name).exists():source=args.overlay/name
        v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',source.read_bytes(),name.encode())
    if saved:v.execute(b'assert(loadstring(...))()',saved)
    v.execute(b"local f=E.frame;f.scripts.OnEvent(f,'ADDON_LOADED','MyEpoch');f.scripts.OnEvent(f,'PLAYER_LOGIN');assert(E.current and not E.failure)")
    return v
v=openvm()
v.execute((here/'group_notice_spec.lua').read_text(encoding='utf-8-sig').encode(),name='group_notice_spec')

saved=v.execute(b'''local f=E.frame;f.scripts.OnEvent(f,'PLAYER_LOGOUT')
local function enc(x)
 if type(x)=='table'then local a={'{'};for k,val in pairs(x)do a[#a+1]='['..enc(k)..']='..enc(val)..',' end;a[#a+1]='}';return table.concat(a)
 elseif type(x)=='string'then return string.format('%q',x)else return tostring(x)end end
return 'MyEpochDB='..enc(MyEpochDB)''')
other=openvm(saved);other.execute(b'''local c,B=E.current,E.Book
for i=1,2000 do if E.Query.EnsureWarm(c)=='ready' then break end;E.Query.ProcessPreparation(500)end
local groups=E.Query.Kind(c,'group');local done=false
for _,g in ipairs(groups)do
 local t=E.CompanyLayout.Report(c,g)
 if #t.notices==2 then assert(#t.loot==1 and t.notices[1].quantity==3 and t.notices[2].quantity==2)
  B.Open();B.ChangeCharacter(c.id);B.SetChapter('Company');B.selected=g.id;B.groupTab='loot';for i=1,200 do B.Render();if (B.right.used.companyRow or 0)>=3 then break end;E.frame.scripts.OnUpdate(E.frame,.1)end
  for i=1,B.right.used.companyRow or 0 do local w=B.right.pool.companyRow[i]
   if w.status:GetText()=='Encounter loot notice' then w.scripts.OnClick()
    assert(B.selected==t.notices[1].id and B.right.used.ledgerItem==1);done=true;break end
  end
 end
end
assert(done);print('PASS fresh session reopened the original group notice and its separate receipt')''')

openvm().execute((here/"group_notice_calendar_spec.lua").read_bytes(),name="group_notice_calendar_spec")
