local wid,gid,reopened=...
local B,S,Q,L,A=E.Book,E.Store,E.Query,E.CompanyLayout,E.API
local c=E.current;local r=assert(c.records[wid]);local g=assert(c.records[gid])
assert(r.amount==37 and r.after-r.before==37 and r.source=="unknown" and r.refs[1]==r.window and r.refs[2]==gid)
assert(Q.GroupWalletObservation(c,gid,r) and (r.session~=E.Collectors.session)==reopened)
local function find(page,pool,key,val)
 for i=1,page.used[pool] or 0 do local f=page.pool[pool][i];local x=f[key];if (type(x)=="table"and x.GetText and x:GetText()or x)==val then return f end end
end
local function act(f)assert(f);local callback=f.GetScript and f:GetScript("OnClick")or f.scripts.OnClick;callback(f)end
local function wait(f)
 for i=1,3000 do if f()then return end;E.frame.scripts.OnUpdate(E.frame,.02);if i%5==0 then B.Render()end end
 error("Did not show expected wallet control in "..B.chapter)
end
local function openGroup()
 B.Open();B.ChangeCharacter(c.id);B.SetChapter("Company");B.selected=g.id;B.groupTab="events";B.Render(true)
 wait(function()return find(B.right,"companyControl","text","My wallet")end);act(find(B.right,"companyControl","text","My wallet"))
end
openGroup()
local fromGroup="+"..E.Money(37);local source=find(B.right,"companyRow","text",fromGroup);act(source)
assert(B.selected==wid and B.Character().records[B.selected]==r and B.right.used.ledgerAmount>=1)
act(find(B.right,"button","text","Open group at wallet observation"));assert(B.chapter=="Company" and B.selected==gid and B.groupTab=="wallet")
local gap
for _,entry in pairs(c.records)do if entry.kind=="balance"and entry.unobservedChange==55 then gap=entry end end
assert(gap and not Q.GroupWalletObservation(c,gid,gap),"Across-gap balance was associated with the prior party")
for _,entry in ipairs(L.Report(c,g).wallet)do assert(entry.kind=="gold" and entry.session==r.session and entry.observerGroup==gid and entry~=gap)end
-- Click the same canonical event on the ordinary Gold / Transactions ledger.
B.goldSection="wallet";B.goldList="transactions";B.goldPreset="custom";B.goldFrom=A.Day(r.ts);B.goldThrough=A.Day(r.ts)
B.goldSource=nil;B.goldQuality=nil;B.goldPage=1;B.SetChapter("Gold");B.selected=nil;B.Render(true)
wait(function()return (B.right.used.financeRow or 0)>0 end)
for i=1,20 do
 local row=find(B.right,"financeRow","recordID",wid)
 if row then act(row);break end
 act(find(B.right,"button","text","More entries"))
end
assert(B.chapter=="Gold" and B.selected==wid and B.right.used.ledgerAmount>=1)
act(find(B.right,"button","text","Open group at wallet observation"))
assert(B.chapter=="Company" and B.selected==gid and B.groupTab=="wallet" and find(B.right,"companyRow","text",fromGroup))
print("PASS registered PLAYER_MONEY to exact personal wallet source, both Company and Gold original, correct group return and excluded gap; reopened "..tostring(reopened))
