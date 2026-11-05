local B,D,A,S=E.Book,E.Drops,E.API,E.Store
local function fire(name,...)assert(E.frame.events[name],name);E.frame.scripts.OnEvent(E.frame,name,...)end
local c=E.current
local boar="Creature-0-1-0-0-3100-00000001"
local boar2="Creature-0-1-0-0-3100-00000002"
local wolf="Creature-0-1-0-0-515-00000003"
local bag="Item-1-00000005"
local old=UnitGUID;local target=boar
UnitGUID=function(u)if u=="target" then return target else return old(u)end end
local oldName=UnitName;UnitName=function(u)if u=="target" then return "Elder Boar" elseif oldName then return oldName(u)end end
C_CreatureInfo={GetCreatureID=function(g) if g==wolf then return 515 elseif g==boar or g==boar2 then return 3100 end end}
Enum=Enum or {};Enum.LootSlotType={None=0,Item=1,Money=2,Currency=3}
local quantity=6;local link="|Hitem:2589:0|h[Linen Cloth]|h"
local function source(...)local t={n=select("#",...),...};GetLootSourceInfo=function()return unpack(t,1,t.n)end end
GetNumLootItems=function()return 1 end
GetLootSlotType=function()return 1 end
GetLootSlotLink=function()return link end
GetLootSlotInfo=function()return 1,"Linen Cloth",quantity,nil,1,false,false,nil,false end
source(boar2,2,wolf,1,boar,3)
fire("LOOT_READY",false);local win=c.records[c.state.activeLootWindow];local r=c.records[win.slots[1]];assert(r)
local function report()return D.Report(c,{source="loot_window",dimension="mob",from=r.ts-1,through=A.Now()+1})end
local function count(b,units)assert(#b.rows==1 and b.reportedUnits==units)end
local a=report();assert(#a.rows==1 and #a.buckets==2);count(a.groups["npc:3100"],5);count(a.groups["npc:515"],1)
assert(a.groups["npc:3100"].label=="Elder Boar" and #D.Sources(r)==3 and D.Sources(r)[1].guid==boar)
assert(#D.Report(c,{query="elder boar",source="loot_window"}).rows==1)
local n=#r.snapshots;source(boar,3,wolf,1,boar2,2);fire("LOOT_OPENED",false,false);assert(#r.snapshots==n)
-- No fabricated source quantity or recipient after mismatched evidence, inaccessible fields or a slot clear.
source(boar,4);fire("LOOT_SLOT_CHANGED",1);assert(not r.latest.slotSources and #D.Sources(r)==3)
local secret={};issecretvalue=function(v)return v==secret end; source(boar,6,secret,1);fire("LOOT_SLOT_CHANGED",1)
assert(not r.latest.slotSources and not r.recipient)
source(boar,2,boar,4);fire("LOOT_SLOT_CHANGED",1);assert(not r.latest.slotSources)
source(bag,6);fire("LOOT_SLOT_CHANGED",1);a=report();assert(not a.groups["npc:3100"]);count(a.groups["source:Item"],6)
source(wolf);fire("LOOT_SLOT_CHANGED",1);local latest=D.Sources(r);assert(latest[1].npcID==515 and latest[1].quantity==nil and latest[1].name==nil)
fire("LOOT_SLOT_CLEARED",1);assert(D.Sources(r)[1].guid==wolf and report().groups['npc:515'].reportedUnits==nil)
-- Same item ID with different variant creates an independent observed slot record, even with a reused slot number.
link="|Hitem:2589:9|h[Linen Cloth]|h";source(boar,6);fire("LOOT_SLOT_CHANGED",1)
local replacement=c.records[win.slots[1]];assert(replacement~=r and replacement.itemID==r.itemID);count(report().groups["npc:3100"],6)
local prior=#replacement.snapshots
GetLootSourceInfo=function()link="|Hitem:369|h[Different]|h";return wolf,6 end
fire("LOOT_SLOT_CHANGED",1);assert(#replacement.snapshots==prior and D.Sources(replacement)[1].guid==boar)
-- An old call cannot publish against a closed window.
link=replacement.itemLink;GetLootSourceInfo=function()fire("LOOT_CLOSED");return wolf,6 end;fire("LOOT_SLOT_CHANGED",1)
assert(c.state.activeLootWindow==nil and #replacement.snapshots==prior)
assert(E.Items.Report(c,{from=r.ts-1,through=A.Now()+1}).quantity==0)
print("PASS observed slot sources, mixed GUIDs and species, stable rereads, mismatched quantities, unknown/restricted, exact variant, stale window and independent receipt totals")
