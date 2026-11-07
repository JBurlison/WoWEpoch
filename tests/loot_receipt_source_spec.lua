local S,L,K,B=E.Store,E.KillLoot,E.Keepsakes,E.Book
local serial=0
local function fixture(withKill)
 serial=serial+1;local c=S.Character('receipt-source-'..serial,{name='Observer'})
 local guid='Creature-0-1-2-3-504-ABC'
 local kill=withKill and S.Add(c,'kill',1000,{title='Defias Trapper',npcName='Defias Trapper',npcID=504,victimGUID=guid,source='PARTY_KILL',session='login',mapID=1436,groupState='solo'})
 local w=S.Add(c,'loot_window',1001,{source='loot_window',session='login',mapID=1436,groupState='solo',fromItem=false,fishing=false,closedAt=1002})
 local d=S.Add(c,'drop',1001,{source='loot_window',session='login',window=w.id,itemID=2589,slot=2,snapshots={},itemLink='|Hitem:2589:0|h[Linen Cloth]|h'})
 d.snapshots={{ts=1001,sequence=S.ReserveObservation(c),data={itemID=2589,visibleQuantity=2,slotSources={{guid=guid,npcID=504,name='Defias Trapper',kind='Creature',quantity=2}}}}}
 local r=S.Add(c,'loot',1002,{title='Linen Cloth',itemID=2589,itemLink=d.itemLink,quantity=2,recipient=c.id,session='login',mapID=1436,groupState='solo',source='unknown'})
 return c,r,w,d,kill
end
local function ready(c)
 local report=L.Get(c);local n=0
 while not report do K.Process(1000);n=n+1;assert(n<2000);report=L.Get(c)end
 return report
end
-- Real auto-loot ordering: close, receipt, no active window ID on the receipt.
local c,r,w,d,kill=fixture(true);local before=E.Copy(c);local report=L.Build(c)
assert(report.byRecord[r.id][1].kill==kill and report.byKill[kill.id].byItem[2589].quantity==2)
local source=assert(report.receiptSources[r.id]);assert(source.npcID==504 and source.name=='Defias Trapper'and source.record==kill and source.basis=='inferred')
assert(E.Same(before,c)and not r.observedLootWindow and not r.npcID,'Recovered links do not rewrite receipts or notes')
assert(ready(c).receiptSources[r.id]);assert(L.DismissReceipt(c,r,w))
assert(not ready(c).receiptSources[r.id]and not ready(c).byRecord[r.id],'Rejecting receipt inference leaves the recorded drop/kill intact')
assert(ready(c).byKill[kill.id].byItem[2589].quantity==2)
local copy=E.Copy(c);E.db.characters[c.id]=copy
assert(L.Build(copy).receiptLinks[r.id].rejected and not L.Build(copy).receiptSources[r.id],'Rejection survives reload')
assert(not L.RestoreReceipt(copy,r),'Stale objects cannot alter restored history')
c=copy;r=c.records[r.id];w=c.records[w.id];d=c.records[d.id];kill=c.records[kill.id]
assert(L.RestoreReceipt(c,r)and ready(c).receiptSources[r.id])
r.observedLootWindow=w.id;S.Changed(c,r)
assert(ready(c).receiptSources[r.id].basis=='exact'and not L.DismissReceipt(c,r),'Observed window and corpse source are direct evidence')
-- A corpse can be identified without a saved kill. Never substitute a nearby
-- kill of the same creature type with a different GUID.
local orphan,orr,ow,od=fixture(false)
S.Add(orphan,'kill',1002,{title='Another trapper',npcName='Another trapper',npcID=504,victimGUID='Creature-0-1-2-3-504-DIFFERENT',source='PARTY_KILL',session='login',mapID=1436,groupState='solo'})
local osource=L.Build(orphan).receiptSources[orr.id]
assert(osource and osource.name=='Defias Trapper'and osource.record==od and not osource.kill)
assert(not L.Build(orphan).byRecord[orr.id],'No invented kill link when only the corpse is known')
-- Competing windows, even if one is rejected, remain ambiguous.
local ambiguous,ar,aw,ad=fixture(false)
local bw=S.Add(ambiguous,'loot_window',1001,{session='login',mapID=1436,groupState='solo',fromItem=false,fishing=false,closedAt=1002})
local bd=S.Add(ambiguous,'drop',1001,{source='loot_window',session='login',window=bw.id,itemID=2589,slot=1,snapshots={}})
bd.snapshots={{ts=1001,sequence=S.ReserveObservation(ambiguous),data=E.Copy(ad.snapshots[1].data)}}
ar.sequence=S.ReserveObservation(ambiguous)
assert(not L.Build(ambiguous).receiptSources[ar.id])
ar.starred=true;local protected=S.Protected(ambiguous)
assert(protected[aw.id]and protected[bw.id]and protected[ad.id]and protected[bd.id],'Keep rival sources so expiry cannot manufacture certainty')
-- Reject mismatched sessions, maps, groups, variants, quantities, timing,
-- order and non-combat origins; a bad explicit window is never guessed over.
for _,change in ipairs({{session='other'},{mapID=1429},{group='other'},{quantity=3},{ts=1005},
 {itemLink='|Hitem:2589:99|h[Linen Cloth]|h'},{sequence=1},{observedLootWindow='missing'},
 {kind='crafted'},{source='purchase'},{gathering={state='inferred'}}})do
 local x,xr=fixture(true);for key,value in pairs(change)do xr[key]=value end
 assert(not L.Build(x).receiptSources[xr.id],'Conflicting receipt must not acquire a creature source')
end
for _,change in ipairs({{fromItem=true},{fishing=true},{originConflict=true},{gatherActions={'node'}}})do
 local x,xr,xw=fixture(true);for key,value in pairs(change)do xw[key]=value end
 assert(not L.Build(x).receiptSources[xr.id])
end
local area,air,aiw,aid=fixture(false)
aid.snapshots[1].data.slotSources={{kind='Creature',guid='Creature-0-1-2-3-504-A',npcID=504,quantity=1},
 {kind='Creature',guid='Creature-0-1-2-3-95-B',npcID=95,quantity=1}}
assert(not L.Build(area).receiptSources[air.id],'Shared area-loot stacks do not imply one mob')
local expired,er,ew=fixture(false)
S.Add(expired,'gap',1003,{removedRanges={loot={from=1001,through=1002}}})
assert(not L.Build(expired).receiptSources[er.id],'Missing competing loot history remains unresolved')
local wrongPosition,pr,pw=fixture(false)
pr.position={mapID=1436,x=.9,y=.9};pw.position={mapID=1436,x=.1,y=.1}
assert(not L.Build(wrongPosition).receiptSources[pr.id])
-- The compact source card precedes the map and opens the retained kill or
-- slot evidence from every shared loot detail, without duplicate source cards.
B.ChangeCharacter(orphan.id);B.chapter='Loot';B.selected=orr.id;TEST_PREPARE_BOOK();ready(orphan)
local location=E.LootView.Location;local sourceBeforeMap=false
E.LootView.Location=function(page)sourceBeforeMap=(page.used.killLootRow or 0)==1 end
B.Clear(B.right);B.Record(B.right,orr)
assert(sourceBeforeMap and B.right.used.killLootRow==1,'One creature-source card appears above the map')
local card=B.right.pool.killLootRow[1];assert(card.text:GetText()=='Defias Trapper')
local original=E.SearchView.Open;local hit
E.SearchView.Open=function(value)hit=value.record end
card.open.scripts.OnClick();assert(hit==od.id,'Missing kill navigates to actual corpse evidence')
E.SearchView.Open=original;E.LootView.Location=location
print('PASS loot receipt sources: auto-loot close ordering, corpse without kill, explicit/inferred labels, safe matching, reversals/reload, retention, source card placement and links')
