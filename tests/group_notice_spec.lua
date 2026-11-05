local A,B,C,L,Q,S=E.API,E.Book,E.Collectors,E.CompanyLayout,E.Query,E.Store
local c=E.current;local now=A.Now()
local function fire(name,...) local f=E.frame;assert(f.events[name]);return f.scripts.OnEvent(f,name,...)end
local function warm()for i=1,2000 do if Q.EnsureWarm(c)=="ready" then return end;Q.ProcessPreparation(500)end error("cold")end
local function enter(member)
    A.Roster=function()return {{id=c.id,name=c.identity.name},{id=member,name=member}}end
    fire("GROUP_ROSTER_UPDATE");return assert(c.records[C.CurrentGroup()])
end
local function leave()
    A.Roster=function()return {}end;fire("GROUP_ROSTER_UPDATE");assert(not C.CurrentGroup())
end
local link="|cffffffff|Hitem:2589:44|h[Group Linen]|h|r"
local function notice(n)fire("ENCOUNTER_LOOT_RECEIVED",7230,2589,link,n)end
local g=enter("Camp companion");notice(3);fire("QUEST_LOOT_RECEIVED",109,link,2)
LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
fire("CHAT_MSG_LOOT","You receive loot: "..link.."x3.",nil,nil,nil,nil,nil,nil,nil,nil,nil,4367)
leave();notice(99);local other=enter("Other party");notice(5);warm()
local function data()
 local report=L.Report(c,g);assert(#report.loot==1 and #report.notices==2)
 local first=report.notices[1];local second=report.notices[2]
 assert(first.kind=="encounter_loot" and first.quantity==3 and not first.group and not first.recipient)
 assert(second.kind=="quest_reward" and second.quantity==2 and not second.group)
 assert(#L.Report(c,other).notices==1)
 for _,r in ipairs(Q.Group(c,g.id))do assert(r.kind~="encounter_loot" and r.kind~="quest_reward")end
 return first,second
end
local first,second=data()
B.Open();B.SetChapter("Company");B.selected=g.id;B.groupTab="loot"
local function draw()
 for i=1,500 do B.Render();if (B.right.used.companyRow or 0)>=3 then return end;E.frame.scripts.OnUpdate(E.frame,.1)end;error("missing group rows")
end
draw()
local function row(label)
 for i=1,B.right.used.companyRow or 0 do local w=B.right.pool.companyRow[i];if w.status:GetText()==label then return w.scripts.OnClick end end
end
local open=assert(row("Encounter loot notice"))
local quest=assert(row("Quest reward notice"));quest();assert(B.selected==second.id and B.right.used.ledgerItem==1)
B.selected=g.id;draw();open();assert(B.selected==first.id and B.right.used.ledgerItem==1)
B.selected=g.id;draw()
first.observerGroup=other.id;S.Changed(c,first);open();assert(B.selected==g.id and #L.Report(c,g).notices==1 and #L.Report(c,other).notices==2)
first.observerGroup=g.id;S.Changed(c,first);draw()
c.records[first.id]=E.Copy(first);open();assert(B.selected==g.id);c.records[first.id]=first
B.selected=other.id;open();assert(B.selected==other.id)
first.observerGroupState="unknown";S.Changed(c,first);assert(#L.Report(c,g).notices==1)
first.observerGroupState="group";S.Changed(c,first);data()
local a=S.Character("different-company-owner",{name="Other scrapbook"});B.ChangeCharacter(a.id);open();assert(B.Character()==a and not B.selected)
print("PASS Company independently observed encounter and quest loot, separate receipt totals, two groups and solo, source clicks, correction and owner isolation")
