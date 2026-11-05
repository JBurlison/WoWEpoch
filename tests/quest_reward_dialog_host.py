"""Registered Forever dialog events and real Book drill-down in isolated 5.1 VMs."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
tests=Path(__file__).resolve().parent;addon=tests.parent/'MyEpoch'
def vm(saved=None):
    v=LuaRuntime(encoding=None,unpack_returned_tuples=True);v.execute(b'E={};time=os.time;date=os.date')
    for name in (addon/'MyEpoch.toc').read_text(encoding='utf-8-sig').splitlines():
        if not name.endswith('.lua'):continue
        if name=='Book.lua':v.execute((tests/'wow_mock.lua').read_bytes())
        v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(addon/name).read_bytes(),name.encode())
    if saved:v.execute(b'assert(loadstring(...))()',saved)
    v.execute(b"""function fire(name,...)local f=E.frame;assert(f.events[name],name);return f.scripts.OnEvent(f,name,...)end
    fire('ADDON_LOADED','MyEpoch');fire('PLAYER_LOGIN');assert(E.current and not E.failure)""")
    v.execute((tests/'sidebar_test_support.lua').read_bytes())
    return v
v=vm();v.execute((tests/'quest_reward_dialog_spec.lua').read_bytes(),name='quest_reward_dialog_spec.lua')
first,second=v.execute(b'return TEST_SAVED.first,TEST_SAVED.second')
saved=v.execute(b"""fire('PLAYER_LOGOUT');local function encode(x)
if type(x)=='table'then local t={'{'};for k,y in pairs(x)do t[#t+1]='['..encode(k)..']='..encode(y)..','end;t[#t+1]='}';return table.concat(t)end
if type(x)=='string'then return string.format('%q',x)end;return tostring(x)end;return 'MyEpochDB='..encode(MyEpochDB)""")
w=vm(saved);w.execute(b"""local old,current=...;local c=E.current;local a,b=c.records[old],c.records[current]
assert(#a.rewardDialogs==10 and #b.rewardDialogs==1 and a.completion and c.state.activeQuests[100]==b.id)
local previous=b.rewardDialogs[1]
UnitExists=function()return true end
local guid=UnitGUID;UnitGUID=function(u)if u=='questnpc'then return 'Creature-0-0-0-0-234-009' end;return guid(u)end
UnitName=function()return 'Fresh session' end;GetQuestID=function()return 100 end
fire('QUEST_COMPLETE');assert(#b.rewardDialogs==2 and b.rewardDialogs[1]==previous and b.rewardDialogs[2].session==E.Collectors.session)
fire('GOSSIP_CLOSED',true);fire('QUEST_COMPLETE');assert(#b.rewardDialogs==2)
fire('GOSSIP_CLOSED',false);fire('QUEST_COMPLETE');assert(#b.rewardDialogs==3)
fire('PLAYER_LOGOUT');fire('QUEST_COMPLETE');assert(#b.rewardDialogs==3)
print('PASS saved reward-dialog observations on old and repeat quest, fresh registered login, continuing recording and logout guard')""",first,second)
