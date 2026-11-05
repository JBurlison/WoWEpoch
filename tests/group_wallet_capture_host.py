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
    v.execute(b"""function fire(n,...)assert(E.frame.events[n]);return E.frame.scripts.OnEvent(E.frame,n,...)end
    fire('ADDON_LOADED','MyEpoch');fire('PLAYER_LOGIN');assert(E.current and not E.failure)""")
    return v
v=vm();v.execute((tests/'group_wallet_capture_spec.lua').read_bytes(),name='group_wallet_capture_spec.lua')
wid,gid,n=v.execute(b'return TEST_WALLET_ID,TEST_GROUP_ID,TEST_GOLD')
v.execute((tests/"group_wallet_journey_spec.lua").read_bytes(),wid,gid,False,name="group_wallet_journey_spec")
saved=v.execute(b"""fire('PLAYER_LOGOUT');local function enc(v)if type(v)=='table'then local t={'{'};for k,x in pairs(v)do t[#t+1]='['..enc(k)..']='..enc(x)..','end;t[#t+1]='}';return table.concat(t)end;if type(v)=='string'then return string.format('%q',v)end;return tostring(v)end;return 'MyEpochDB='..enc(MyEpochDB)""")
w=vm(saved);w.execute(b"""local wid,gid,oldCount=...;local c=E.current;local w=c.records[wid]
assert(w.refs[1]==w.window and w.refs[2]==gid and w.observerGroupState=='group' and c.records[gid].character==c.id)
local function total()local n=0;for _,r in pairs(c.records)do if r.kind=='gold'then n=n+1 end end;return n end
assert(total()==oldCount and c.state.wallet.session==E.Collectors.session and w.session~=E.Collectors.session)
local old=c.state.wallet.amount;GetMoney=function()return old+11 end
fire('PLAYER_MONEY');fire('PLAYER_MONEY');assert(total()==oldCount+1 and c.state.wallet.amount==old+11)
print('PASS fresh registered login, preserved old session refs, new session baseline and one subsequent delta')""",wid,gid,n)

x=vm();x.execute(b"""local c,C,H=E.current,E.Collectors,E.History
local t=E.API.Now();local b=c.state.wallet.amount;local amt=b+100;local old=c.state.walletWindow
TEST_NOW(t+21);GetMoney=function()return amt end
local nested=false;local notices={}
E.On('RECORD_ADDED',function(owner,row)
 if owner~=c then return end
 if row.kind=='balance'and not nested then
  nested=true;notices[#notices+1]=row.kind
  assert(row.window==c.state.walletWindow and row.window~=old and c.records[row.window].refs[1]==row.id)
  amt=amt+5;fire('PLAYER_MONEY')
 elseif row.kind=='wallet_window'then notices[#notices+1]=row.kind end
end)
fire('PLAYER_MONEY')
local window=c.records[c.state.walletWindow];local gold
for _,row in pairs(c.records)do if row.kind=='gold'then assert(not gold);gold=row end end
assert(table.concat(notices,',')=='balance,wallet_window' and c.state.wallet.amount==amt and window.closing==amt)
assert(gold.window==window.id and gold.refs[1]==window.id and gold.amount==5 and window.transactionCount==1 and window.opening==b+100)
-- Older/synthetic direct polls may only reuse a stable same-owner, same-session, same-second roster.
local t=E.API.Now();local session=C.session
local direct=H.Wallet(c,t,amt+1,session,'trade')
assert(direct.observerGroupState=='solo' and direct.context=='trade' and direct.source=='unknown')
local stale=H.Wallet(c,t+1,amt+2,session,'mail');assert(stale.observerGroupState=='unknown' and not stale.observerGroup)
-- A thrown baseline listener leaves coherent canonical records, not a false extra transaction on retry.
local once=true;E.On('RECORD_ADDED',function(owner,row)if owner==c and row.kind=='balance'and once then once=false;error('injected observation error')end end)
TEST_NOW(t+30);amt=amt+20
local ok=pcall(fire,'PLAYER_MONEY');assert(not ok and not once)
local repaired=c.records[c.state.walletWindow];assert(repaired.closing==amt and c.state.wallet.amount==amt and c.records[repaired.refs[1]].window==repaired.id)
local seq=c.seq;fire('PLAYER_MONEY');assert(c.seq==seq and repaired.transactionCount==0)
print('PASS exact gap window published before nested +5, direct same-second/unknown cache, post-insert listener failure and idempotent retry')""")

y=vm();y.execute(b"""local c=E.current;local wrong=E.Store.Add(c,'memory',E.API.Now(),{title='preserve me'})
c.state.group=wrong.id;local old=c.state.wallet.amount;GetMoney=function()return old+19 end
fire('PLAYER_MONEY');local rows=E.Query.Kind(c,'gold');assert(#rows==1 and rows[1].amount==19 and rows[1].observerGroupState=='unknown' and not rows[1].observerGroup)
assert(wrong.kind=='memory' and not wrong.memberships and not wrong.ended)
print('PASS stale prior group identity preserves original memory and +19 raw wallet')""")

z=vm();z.execute(b"""local c,A=E.current,E.API;local cash=c.state.wallet.amount+1
local n,g=0,0
GetMoney=function()return cash end;GetNumGroupMembers=function()n=n+1;return 40 end
IsInRaid=function()return true end;UnitGUID=function(unit)
 if unit=='player'then return c.id end;local idx=tonumber((unit:match('^raid(%d+)$')))
 if idx then g=g+1;return idx==1 and c.id or 'Player-1-'..idx end
end
fire('PLAYER_MONEY');local rows=E.Query.Kind(c,'gold');assert(#rows==1 and rows[1].observerGroup==c.state.group)
assert(n==2 and g==80,'expected exactly one bounded full roster read')
n=0;g=0;for i=1,50 do fire('PLAYER_MONEY')end
assert(n==0 and g==0 and #E.Query.Kind(c,'gold')==1)
print('PASS 40-member raid witness: two size reads, 80 raid-token GUID reads; 50 unchanged notifications perform zero roster scans')""")

v=vm();v.execute(b"""local c=E.current;local old=c.state.wallet.amount;GetMoney=function()return old+43 end
local nested=false
GetNumGroupMembers=function()if not nested then nested=true;fire('GROUP_ROSTER_UPDATE')end;return 0 end
fire('PLAYER_MONEY');local rows=E.Query.Kind(c,'gold')
assert(nested and #rows==1 and rows[1].amount==43 and rows[1].observerGroupState=='unknown')
print('PASS a superseding same-second roster is not retroactively attached to the outer cash sample')""")

for fault in ('stable','guid','session','candidate','unreadable'):
    v=vm();v.execute(b"""local fault=...;local c=E.current;local b=E.Store.Character('Player-TEST-new-wallet',{name='Second',realm='Realm'})
    E.History.Wallet(b,E.API.Now()-300,800,'saved session')
    local oldA=c.state.wallet.amount;local prior=b.state.wallet;local token=b.id;local reads=0
    UnitGUID=function(u)if u=='player'then return token end end
    UnitFullName=function()return 'Second','Realm' end
    GetMoney=function()
        if E.recordingTransition then
            reads=reads+1;assert(not E.RecorderReady() and E.current==b and E.recordingGUID==b.id)
            fire('PLAYER_MONEY');assert(b.state.wallet==prior,'Nested generic money hook passed the handoff gate')
            if fault=='guid'then token='Player-TEST-different'
            elseif fault=='session'then E.Collectors.session='superseded'
            elseif fault=='candidate'then E.recordingCandidate=nil
            elseif fault=='unreadable'then return nil end
            return 7777
        end
        return 9999
    end
    fire('PLAYER_ENTERING_WORLD',false,false)
    for i=1,20 do E.frame.scripts.OnUpdate(E.frame,.25);if reads>0 then break end end
    assert(reads==1 and c.state.wallet.amount==oldA and #E.Query.Kind(b,'gold')==0)
    if fault=='stable' then
        assert(b.state.wallet.amount==7777 and b.state.wallet.session==E.Collectors.session and b.records[b.state.walletWindow].opening==7777)
    else assert(b.state.wallet==prior and #E.Query.Kind(b,'balance')==1,fault)end
    """,fault.encode())
print('PASS verified transition opens only a baseline; nested generic money hook, wrong live GUID/session/candidate and unavailable wallet stay fenced')

vm(saved).execute((tests/"group_wallet_journey_spec.lua").read_bytes(),wid,gid,True,name="group_wallet_journey_spec")
