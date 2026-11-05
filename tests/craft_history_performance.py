"""Exercise actual Lua queries and crafting claims against a loaded scrapbook."""
from pathlib import Path
import json
import sys
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('E={};time=os.time;date=os.date')
files = [ROOT / 'MyEpoch' / line for line in (ROOT / 'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8').splitlines() if line and not line.startswith('#')]
for path in files:
    if path.name == 'Book.lua':
        lua.execute((ROOT / 'tests/wow_mock.lua').read_text(encoding='utf-8'))
    lua.execute('assert(loadstring(...))("MyEpoch",E)', path.read_text(encoding='utf-8'))
lua.execute('E.Store.Open(nil);E.current=E.Store.Character("performance-player",{name="TEST"})')
lua.execute('assert(loadstring(...))("MyEpoch",E)', (ROOT / 'tests/fixtures/uiforever-craft-costs.lua').read_text(encoding='utf-8'))
lua.execute('MyEpochCraftCostsReview()')
result = lua.execute('''
local S,Q,K=E.Store,E.Query,E.CraftCosts
local c=E.Book.Character();local request=c.records[c.state.craftCost]
local inv=c.records[c.records[c.state.craftCostOutput].evidence];local now=request.ts
-- Model loading SavedVariables, not 55,000 newly delivered gameplay events.
local function saved(kind,ts)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,character=c.id,kind=kind,ts=ts,sequence=c.seq,category=S.categories[kind]}
 c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
for i=1,5000 do local r=saved('craft_request',now-(i+10)*86400);r.recipeID=900 end
for i=1,50000 do saved('chat',now+i%240)end
collectgarbage('collect');local memory=collectgarbage('count');local start=os.clock()
c.revision=c.revision+1;E.Emit('RECORDS_REMOVED',c,{})
Q.Kind(c,'inventory') -- Include rebuilds triggered by other evidence listeners.
local refreshMs=(os.clock()-start)*1000;collectgarbage('collect');local refreshKB=collectgarbage('count')-memory
local realPairs,realPlan=pairs,K.Plan;local visits,plans=0,0
pairs=function(t)local step,state,key=realPairs(t);return function(s,k)local n,v=step(s,k);if n~=nil then visits=visits+1 end;return n,v end,state,key end
K.Plan=function(...)plans=plans+1;return realPlan(...)end
local function measured(fn)
 visits,plans=0,0;local start=os.clock();fn();return {visits=visits,plans=plans,ms=(os.clock()-start)*1000}
end
local range=measured(function()local rows=Q.Range(c,now-10,now+30,'craft_request');assert(#rows==1 and rows[1]==request)end)
local cold=measured(function()assert(K.Claim(c,inv))end)
local warm=measured(function()assert(K.Claim(c,inv))end)
S.Add(c,'chat',now+1,{title='A new group message'})
local afterChat=measured(function()assert(K.Claim(c,inv))end)
pairs,K.Plan=realPairs,realPlan
assert(K.Info(c,request).cost==817,'the complete material-cost evidence is unchanged')
return {records=#c.order,refreshMs=refreshMs,refreshKB=refreshKB,range=range,cold=cold,warm=warm,afterChat=afterChat}
''')
report = {'records': result['records']}
report.update(refreshMs=round(result['refreshMs'],3),refreshKB=round(result['refreshKB'],3))
for key in ('range', 'cold', 'warm', 'afterChat'):
    report[key] = {name: round(result[key][name], 3) for name in ('visits', 'plans', 'ms')}
print(json.dumps(report, indent=2))
if '--baseline' not in sys.argv:
    assert report['range']['visits'] < 100, 'A typed date lookup must not scan unrelated days or chat'
    for key in ('cold', 'warm', 'afterChat'):
        assert report[key]['plans'] <= 2, 'Only requests capable of owning this observation may be considered'
        assert report[key]['visits'] < 1000, 'Claim matching must not scan the complete scrapbook'
