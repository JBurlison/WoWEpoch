local D,S,A,C,Q,B=E.Drops,E.Store,E.API,E.Collectors,E.Query,E.Book
local function eq(a,b,label)assert(a==b,(label or "Drop mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local saved={current=E.current,session=C.session,live=D.live,enum=Enum,roster=A.Roster,location=A.Location,item=A.Item}
local globals={"GetLootSlotType","GetLootSlotInfo","GetLootSlotLink","GetNumLootItems","IsFishingLoot","C_LootHistory","issecretvalue"}
for _,key in ipairs(globals)do saved[key]=_G[key]end
local now=A.ParseDay("2026-10-31")+73000; TEST_NOW(now)
local c=S.Character("drop-owner",{name="Observer"}); local other=S.Character("drop-other",{name="Other"})
E.current=c; C.session="drop-session"; D.live=nil
Enum={LootSlotType={None=0,Item=1,Money=2,Currency=3},EncounterLootDropRollState={NeedMainSpec=0,Pass=5}}
A.Roster=function()return {{id=E.current.id,name=E.current.identity.name},{id="companion",name="Friend"}}end
A.Location=function()return {zone="Observed zone",subzone="A clearing",mapID=2}end
A.Item=function(id)return {rarity=2,vendorUnitValue=id*10,vendorValuation={source="observed quote",observedAt=now}}end
local slots={{type=1,id=100,name="Green sword",quantity=4,quality=2,locked=false},{type=2,name="Coins",quantity=200},{type=3,name="Currency",quantity=2}}
GetNumLootItems=function()return #slots end
GetLootSlotType=function(i)return slots[i] and slots[i].type end
GetLootSlotInfo=function(i)local r=slots[i]; if r then return 1,r.name,r.quantity,r.currency,r.quality,r.locked,false,nil,false,r.type==2 end end
GetLootSlotLink=function(i)return slots[i] and slots[i].id and "|Hitem:"..slots[i].id.."|h["..slots[i].name.."]|h" end
IsFishingLoot=function()return true end
local histories={[7]={{lootListKey=0,itemHyperlink="|Hitem:100|h[Green sword]|h",startTime=10,duration=30,
    allPassed=false,currentLeader={playerName="Friend",playerGUID="companion",state=0,roll=80},rollInfos={{playerName="Friend",playerGUID="companion",state=0,roll=80}}}}}
local info={encounterID=7,encounterName="An earlier encounter",startTime=8,duration=40}
local reads=0
C_LootHistory={GetAllEncounterInfos=function()return {info}end,GetInfoForEncounter=function(id)return id==7 and info end,
    GetSortedDropsForEncounter=function(id)reads=reads+1; return histories[id]end,
    GetSortedInfoForDrop=function(id,key)for _,v in ipairs(histories[id] or {})do if v.lootListKey==key then return v end end end}
C.handlers.LOOT_READY(false); local window=c.records[c.state.activeLootWindow]; local first=c.records[window.slots[1]]
eq(first.itemID,100); eq(first.maxVisibleQuantity,4); eq(first.recipient,nil); eq(#Q.Kind(c,"drop"),1,"money/currency slots are not item receipts")
eq(first.npcID,nil,"current target is never used as loot-source proof"); assert(first.group); eq(first.zone,"Observed zone")
C.handlers.LOOT_OPENED(false,false); C.handlers.LOOT_READY(false); eq(#Q.Kind(c,"drop"),1); eq(#first.snapshots,1,"unchanged updates do not duplicate observations")
eq(window.fishing,true); eq(window.fromItem,false); eq(D.Dimension(c,first,"origin"),"fishing")
slots[1].quantity=2; C.handlers.LOOT_SLOT_CHANGED(1); eq(first.maxVisibleQuantity,4); eq(first.latest.visibleQuantity,2); eq(#first.snapshots,2)
C.handlers.LOOT_SLOT_CLEARED(1); C.handlers.LOOT_SLOT_CLEARED(1); eq(#first.snapshots,3); eq(first.recipient,nil)
C.handlers.LOOT_OPENED(false,false); eq(#Q.Kind(c,"drop"),1,"a stale/repeated open cannot turn a cleared slot into another drop")
slots[1]={type=1,id=101,name="Another sword",quantity=1,quality=3}; C.handlers.LOOT_SLOT_CHANGED(1)
local second=c.records[window.slots[1]]; assert(second.id~=first.id); eq(#Q.Kind(c,"drop"),2); assert(first.slotReplacedAt)
assert(S.Protected(c)[first.id],"live window protects its observations")
C.handlers.LOOT_CLOSED(); eq(c.state.activeLootWindow,nil); eq(window.closedAt,now)
local windowCount=#Q.Kind(c,"loot_window"); C.handlers.LOOT_SLOT_CHANGED(2)
eq(c.state.activeLootWindow,nil); eq(#Q.Kind(c,"loot_window"),windowCount,"late non-item slot updates cannot invent another open window")
first.starred=true; local keep=S.Protected(c); assert(keep[window.id] and keep[second.id]); first.starred=nil
-- Reopening is a new observation, not a proven new unique drop.
C.handlers.LOOT_OPENED(false,true); local reopened=c.records[c.state.activeLootWindow]; assert(reopened.id~=window.id); eq(#Q.Kind(c,"drop"),3)
-- Roll history can be historical: no current party, coordinates, quantity or receipt is substituted.
D.Refresh(); D.Tick(0.25); eq(reads,1)
local historical=Q.Kind(c,"drop")[4]; eq(historical.source,"roll_history"); eq(historical.group,nil); eq(historical.zone,nil); eq(historical.quantity,nil); eq(historical.recipient,nil)
eq(historical.latest.winner,nil); eq(historical.encounterName,"An earlier encounter"); eq(historical.ts,now)
C.handlers.LOOT_HISTORY_UPDATE_DROP(7,0); eq(#Q.Kind(c,"drop"),4); eq(#historical.snapshots,1)
histories[7][1].winner={playerName="Friend",playerGUID="companion",isWinner=true,roll=80,state=0}
C.handlers.LOOT_HISTORY_UPDATE_DROP(7,0); eq(#historical.snapshots,2); eq(D.Report(c,{source="roll_history"}).winners,1)
eq(historical.recipient,nil,"a reported roll winner is not an inventory receipt")
histories[7][1].rollInfos[2]={playerName="Second roller",playerGUID="second",state=5}
local rawWinner=histories[7][1].winner; rawWinner.playerName="Changed name"; eq(historical.latest.winner.playerName,"Friend","snapshot copied")
histories[7][1].allPassed=true; C.handlers.LOOT_HISTORY_UPDATE_DROP(7,0); eq(D.Report(c,{source="roll_history"}).winners,0,"conflicting outcome is unresolved")
histories[7][1].allPassed=false
-- No duplicate acquired quantities, gold or recaps; observed groups/locations remain navigable.
eq(E.Items.Report(c,{from=now-1,through=now+1}).quantity,0)
local receipt=E.History.Acquisition(c,now,"loot",{itemID=100,title="Green sword",quantity=4,recipient=c.id},"line")
eq(E.Items.Report(c,{from=now-1,through=now+1}).quantity,4)
local recap=E.Diary.Facts(c,now-1,now+1)
eq(recap.counts.looted,4); eq(#recap.refs,1); eq(recap.refs[1],receipt.id,"only the personal item receipt contributes to this recap")
assert(#E.Company.History(c,"companion").drops>=3); eq(E.Journey.LocationKey(first),"map:2"); eq(E.Journey.LocationKey(historical),"unplaced")
-- Source identity reuse and native history clearing preserve earlier journal entries.
histories[7][1].startTime=50; C.handlers.LOOT_HISTORY_UPDATE_DROP(7,0); eq(#Q.Kind(c,"drop"),5)
C.handlers.LOOT_HISTORY_CLEAR_HISTORY(); C.handlers.LOOT_HISTORY_UPDATE_DROP(7,0); eq(#Q.Kind(c,"drop"),6)
assert(c.records[historical.id])
-- Missing/restricted fields remain unknown; missing quantity does not become zero.
local secret={}; issecretvalue=function(value)return value==secret end
slots[1]={type=1,id=102,name="Unknown quantity",quantity=secret,quality=secret,locked=secret}; C.handlers.LOOT_SLOT_CHANGED(1)
local partial=c.records[reopened.slots[1]]; eq(partial.latest.visibleQuantity,nil); eq(partial.maxVisibleQuantity,nil)
local before=#Q.Kind(c,"drop"); C.handlers.LOOT_SLOT_CHANGED(secret); C.handlers.LOOT_HISTORY_UPDATE_DROP(secret,0); eq(#Q.Kind(c,"drop"),before)
histories[7][1].winner={playerName=secret,playerGUID=secret,roll=secret}; C.handlers.LOOT_HISTORY_UPDATE_DROP(7,0)
local recent=Q.Kind(c,"drop"); eq(recent[#recent-1].latest.winner.playerName,nil)
histories[7][1].rollInfos[1]=secret; C.handlers.LOOT_HISTORY_UPDATE_DROP(7,0)
eq(recent[#recent-1].latest.rolls[1].playerName,"Second roller","restricted array holes cannot hide later public entries")
issecretvalue=saved.issecretvalue
-- Temporary absence of history data creates no invented drop; a later refresh can capture it.
local originalLookup=C_LootHistory.GetSortedInfoForDrop
C_LootHistory.GetSortedInfoForDrop=function()return nil end
before=#Q.Kind(c,"drop"); C.handlers.LOOT_HISTORY_UPDATE_DROP(7,99); eq(#Q.Kind(c,"drop"),before)
C_LootHistory.GetSortedInfoForDrop=originalLookup
histories[7][3]={lootListKey=99,itemHyperlink="|Hitem:700|h[Late loot]|h",startTime=70,rollInfos={}}
D.Refresh(); D.Tick(0.25); eq(#Q.Kind(c,"drop"),before+1,"public drops after a sparse array gap are retained")
local late=Q.Kind(c,"drop")[#Q.Kind(c,"drop")]; eq(late.itemID,700)
-- Repeated refresh requests coalesce, and an offline selected scrapbook never causes live API reads.
D.Queue(7); D.Queue(7); local prior=reads; D.Tick(0.25); eq(reads,prior+1)
E.current=other; D.Tick(1); eq(reads,prior+1); E.current=c
C.session="drop-session-two"; D.Start(); eq(reopened.status,"recording interrupted; actual close time unknown"); eq(c.state.activeLootWindow,nil)
-- Native filters and direct search navigation, including source dates and bounded detail controls.
B.ChangeCharacter(c.id); B.SetChapter("Loot"); B.lootMode="drops"; B.dropPreset="all"; B.selected=nil; B.Render(true)
assert(E.DropView.lastReport.visible>0); assert(E.DropView.lastReport.history>0)
local hit=E.Search.Find(c,"earlier encounter","items").hits[1]; assert(hit and E.SearchView.Open(hit)); eq(B.lootMode,"drops"); assert(B.selected)
E.SearchView.Open({character=c.id,record=receipt.id}); eq(B.lootMode,"receipts")
E.SearchView.Open({character=c.id,record=historical.id}); eq(B.lootMode,"drops")
local width,height=B.frame:GetWidth(),B.frame:GetHeight()
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]); B.Fit(); B.Render(); eq(B.frame:GetWidth(),width); eq(B.frame:GetHeight(),height)end
UIParent:SetSize(1920,1080); B.Fit()
B.dropQuery="sword"; B.ChangeCharacter(other.id); eq(B.dropQuery,nil); eq(D.Report(other).visible,0); B.ChangeCharacter(c.id); eq(B.dropQuery,"sword")
-- Many observations are grouped and paginated without claiming unique physical drops.
local archive=S.Character("drop-archive",{name="Archivist"})
for i=1,6000 do S.Add(archive,"drop",now,{title="Loot "..i,itemID=i,source="loot_window",latest={visibleQuantity=1},maxVisibleQuantity=1})end
local begin=os.clock(); local report=D.Report(archive); eq(report.visible,6000); eq(#report.buckets,6000)
B.ChangeCharacter(archive.id); B.SetChapter("Loot"); B.lootMode="drops"; B.Render(true); assert((B.right.used.button or 0)<=12)
print(string.format("PASS drop archive: 6,000 observations, grouped and paginated; %.1f ms host processing",(os.clock()-begin)*1000))
E.current=saved.current; C.session=saved.session; D.live=saved.live; Enum=saved.enum; A.Roster=saved.roster; A.Location=saved.location; A.Item=saved.item
for _,key in ipairs(globals)do _G[key]=saved[key]end
print("PASS drops: available slots, repeated updates/clears, slot reuse, history outcomes, historical context, source resets, secret omission, no receipt inflation, source-graph protection, character isolation and native navigation")
