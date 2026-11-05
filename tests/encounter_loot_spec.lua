local c,A,S,C,L,B,Q=E.current,E.API,E.Store,E.Collectors,E.EncounterLoot,E.Book,E.Query
local e,item=7001,2589
local payload="item:2589:7:0:0:0:0:-20:22"
local link="|cff1eff00|H"..payload.."|h[Linen Cloth]|h|r"
local function notice(a,b,d,n,x,y)fire("ENCOUNTER_LOOT_RECEIVED",a,b,d,n,x,y)end
local function count(kind)return #Q.Kind(c,kind)end
local function total()local _,_,_,n=L.Page(c,1);return n end
qready(c)
fire("ENCOUNTER_START",e,"An independently reported boss",1,5)
local active=assert(c.state.activeEncounter)
local original=count("encounter");local loot=count("loot");local rolls=count("drop");local now=A.Now()
local oldLocation=A.Location
local roster=A.Roster
A.Roster=function()return {{id=c.id,name="Recorder",fullName="Recorder"},{id="partner",name="Partner",fullName="Partner"}}end
fire("GROUP_ROSTER_UPDATE")
local group=assert(C.CurrentGroup())
A.Location=function()return {mapID=1436,zone="Westfall",subzone="Sentinel Hill"}end
notice(e,item,link,3,"Should never be indexed","MAGE")
notice(e,item,link,3,"Other observer","WARRIOR")
local secret={};local nativeSecret=issecretvalue
issecretvalue=function(v)return rawequal(v,secret) or nativeSecret and nativeSecret(v)end
notice(e,item,secret,2,secret,secret);notice(e,item,nil,1,secret,secret);notice(e,item,"item:777:89",5)
notice(e,item,link..link,2);notice(e,item,"|cff1eff00|Hitem:2589:7:0",2,secret,secret)
for _,bad in ipairs({0,-1,1.5,2147483648,0/0,math.huge,"14",secret})do
 notice(bad,item,link,3);notice(e,bad,link,3);notice(e,item,link,bad)
end
issecretvalue=nativeSecret
assert(total()==7 and count("loot")==loot and count("encounter")==original and count("drop")==rolls)
local older,_,_,n=L.Page(c,2);assert(n==7 and #older==3)
local first=older[3];assert(first.itemLink==link and first.session==C.session and first.observerLocation.zone=="Westfall")
assert(first.encounterID==e and first.itemID==item and first.quantity==3 and first.recipient==nil and first.group==nil and first.encounter==nil)
assert(first.refs[2]==nil and first.refs[1]~=active and first.startObservation==nil)
assert(first.npcID==nil and first.encounterName==nil and first.encounterID~=item)
assert(first.observerGroupState=="group" and first.observerGroup==group and first.refs[1]==group)
A.Roster=roster
assert(older[2].id~=first.id and older[2].ts==first.ts and older[2].itemLink==first.itemLink)
for _,r in ipairs(L.Page(c,1))do assert(r.itemID==item and r.itemLink==nil and r.title=="Item 2589")end
local allowed=canaccessvalue;canaccessvalue=function(v)return v~="denied" and (not allowed or allowed(v))end
notice(e,item,"denied",2);canaccessvalue=allowed;assert(total()==8 and L.Page(c,1)[1].itemLink==nil)
local extra=L.Page(c,1)[1];extra.kind="observation";S.Changed(c,extra);assert(total()==7)
local session=C.session
A.Location=function()C.session="superseded";return {}end
notice(e,item,link,1);C.session=session;A.Location=oldLocation;assert(total()==7)
LOOT_ITEM_SELF_MULTIPLE="You receive loot: %sx%d."
fire("CHAT_MSG_LOOT","You receive loot: "..link.."x3.",nil,nil,nil,nil,nil,nil,nil,nil,nil,831)
assert(count("loot")==loot+1 and total()==7)
local report=E.Items.Report(c,{from=now-1,through=now+1});assert(report.events==1 and report.quantity==3)
assert(#Q.Kind(c,"cost_lot")==0)
assert(E.Search.Find(c,"encounter_loot_received","items").total==7)
assert(E.Search.Find(c,tostring(e),"encounter").total==8)
assert(E.Search.Find(c,"sentinel hill","encounter").total==7)
assert(E.Search.Find(c,"Should never be indexed","all").total==0)
local function button(page,label)
 for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==label then return f.scripts.OnClick end end
end
local function action(r)return "Open notice · "..A.RecordDate(r).." · #"..r.sequence end
B.Open();B.SetChapter("Loot");B.lootMode="encounter_loot";B.Render(true)
for i=1,100 do if B.left.used.ledgerItem==4 then break end;E.frame.scripts.OnUpdate(E.frame,.1);B.Render()end
assert(B.left.used.ledgerItem==4 and not E.CraftProjectionPreparation.job,"Only the four visible notices should be rendered")
local scan=Q.Kind;Q.Kind=function()error("notice repaint attempted a sorted history scan")end
assert(button(B.left,"Older notices"))();assert(B.left.used.ledgerItem==3)
local open=assert(button(B.left,action(first)));open();assert(B.selected==first.id and B.right.used.ledgerItem==1)
Q.Kind=scan
local icon=B.right.pool.ledgerItem[1].icon
local tip=GameTooltip;GameTooltip={SetOwner=function()end,SetHyperlink=function(self,s)self.link=s end,Show=function()end,Hide=function()end}
icon.scripts.OnEnter(icon);assert(GameTooltip.link==payload);icon.scripts.OnLeave(icon);GameTooltip=tip
assert(button(B.right,"Star and protect this notice"))();assert(first.starred)
local goGroup=assert(button(B.right,"Open observer’s group in Company"))
local groupRecord=c.records[group];c.records[group]=E.Copy(groupRecord);goGroup()
assert(B.chapter=="Loot" and B.selected==first.id);c.records[group]=groupRecord
goGroup();assert(B.chapter=="Company" and B.selected==group and B.Character()==c)
local hit=E.Search.Find(c,"sentinel hill","encounter").hits[1]
local old=c.records[hit.record];local copy=E.Copy(old);c.records[copy.id]=copy;S.Changed(c,copy)
assert(not E.SearchView.Open(hit));assert(E.SearchView.Open(E.Search.Find(c,"sentinel hill","encounter").hits[1]))
local other=S.Character("second-notice-owner",{name="Other"});B.ChangeCharacter(other.id);open()
assert(B.Character()==other and B.selected~=first.id and not E.SearchView.Open(hit))
qready(other);assert(select(4,L.Page(other,1))==0)
A.Roster=function()return nil end;fire("GROUP_ROSTER_UPDATE")
notice(e,item,nil,4);local during=L.Page(c,1)[1]
assert(during.character==c.id and during.observerGroupState=="unknown" and not during.observerGroup and select(4,L.Page(other,1))==0)
during.kind="observation";S.Changed(c,during);A.Roster=roster;B.ChangeCharacter(c.id)
-- A kind correction evicts the original notice, restoration reenrolls it exactly once.
first.kind="observation";S.Changed(c,first);assert(total()==6)
first.kind="encounter_loot";S.Changed(c,first);assert(total()==7)
assert(first.starred);c.retention.loot=1
local preview=S.PreviewExpiry(c,now+10*86400);assert(S.ApplyExpiry(c,preview));qready(c)
assert(total()==1 and L.Page(c,1)[1]==first)
print("PASS registered encounter-loot reception, validation, observer/session, search/owner guards, bounded paging, exact hover, separate receipts and retained notice")


