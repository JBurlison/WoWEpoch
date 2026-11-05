local c=E.current;local H,L,S,B,Q,A=E.History,E.CompanyLayout,E.Store,E.Book,E.Query,E.API
local now=A.Now();local sess=E.Collectors.session
H.Group(c,now,{{id=c.id,name=c.identity.name},{id="fern",name="Fern"}},sess,"test-party")
local g=assert(c.records[c.state.group]);local window=assert(c.records[c.state.walletWindow])
local function delta(change,state,gid)
 local r=assert(H.Wallet(c,now,c.state.wallet.amount+change,sess))
 r.observerGroupState=state;r.observerGroup=gid;if gid then r.refs[#r.refs+1]=gid end
 S.Changed(c,r);return r
end
local up=delta(12345,"group",g.id);local down=delta(-23,"group",g.id)
local solo=delta(5,"solo");local uncertain=delta(6,"unknown");local legacy=delta(3,nil)
local function warm()for i=1,1000 do if Q.EnsureWarm(c)=="ready" then return end;Q.ProcessPreparation(500)end;error("not warm")end
warm()
local report=L.Report(c,g);assert(#report.wallet==2 and report.wallet[1]==up and report.wallet[2]==down and #report.loot==0)
for _,r in ipairs(Q.Group(c,g.id))do assert(r~=up and r~=down)end
local function click(page,kind,label)
 for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==label then return f.scripts.OnClick end end
end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Company");B.selected=g.id;B.groupTab="events"
for i=1,200 do B.Render();if click(B.right,'companyControl','My wallet')then break end;E.frame.scripts.OnUpdate(E.frame,.1)end
click(B.right,'companyControl','My wallet')()
local open=assert(click(B.right,'companyRow','+'..E.Money(up.amount)))
assert(click(B.right,'companyRow',E.Money(down.amount)) and not click(B.right,'companyRow','+'..E.Money(solo.amount)))
open();assert(B.selected==up.id and B.right.used.ledgerAmount>=1)
local back=assert(click(B.right,'button','Open group at wallet observation'))
back();assert(B.chapter=='Company' and B.groupTab=='wallet' and B.selected==g.id)
B.groupTab='events';open();assert(B.selected==g.id);B.groupTab='wallet'
up.observerGroupState='unknown';S.Changed(c,up);open();assert(B.selected==g.id and #L.Report(c,g).wallet==1)
up.observerGroupState='group';S.Changed(c,up);B.Render();open();assert(B.selected==up.id)
B.SetChapter("Gold");B.selected=up.id;B.Render();back();assert(B.chapter=="Gold" and B.selected==up.id)
local alt=S.Character("wallet-other-owner",{name="Other owner"});B.ChangeCharacter(alt.id);open();assert(B.Character()==alt and not B.selected)
assert(solo.group==nil and uncertain.group==nil and legacy.group==nil and up.source=='unknown')
print("PASS Company / My wallet signed personal changes, original financial detail, group return and stale-callback guards; solo/legacy/unknown separate")
