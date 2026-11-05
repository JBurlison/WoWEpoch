local G,S,Q,A,D=E.Gathering,E.Store,E.Query,E.API,E.Diary
local c=S.Character('gathering-owner',{name='Angler'});local now=time();local n=0
local function fixture(options)
 options=options or{};n=n+1;local ts=now+n*20;local session=options.session or'fish-session'
 local w=S.Add(c,'loot_window',ts,{title='Observed fishing window',session=session,fishing=true,fromItem=false,originEvidence=1,refs={},slots={}})
 local data={itemID=629,visibleQuantity=3,slotType=1};local cleared=E.Copy(data);cleared.cleared=true
 local slot=S.Add(c,'drop',ts,{title='Visible fish',source='loot_window',window=w.id,session=session,itemID=629,slot=1,maxVisibleQuantity=3,
  snapshots={{ts=ts,data=data},{ts=ts+1,data=cleared}},latest=cleared,clearedAt=ts+1,refs={w.id}})
 w.refs={slot.id};w.slots[1]=slot.id
 local receipt=E.History.Acquisition(c,ts+1,'loot',{title='Raw fish',rawMessage='Original receipt text',itemID=629,quantity=3,recipient=c.id,
  observedLootWindow=w.id,session=session,zone='Elwynn Forest',refs={}},'fish-line-'..n)
 assert(receipt.kind=='loot','open window is not sufficient')
 w.closedAt=ts+2;S.Changed(c,w)
 assert(G.Inferred(receipt));return w,slot,receipt
end
local w,slot,r=fixture();local id=r.id;local count=#c.order
assert(r.kind=='gathered'and r.gatheringOriginal.kind=='loot'and r.profession=='Fishing'and r.category=='production')
assert(#Q.Kind(c,'loot')==0 and #Q.Kind(c,'gathered')==1 and #c.order==count)
assert(E.Items.Report(c,{from=now,through=now+100}).quantity==3,'one canonical acquisition')
assert(E.Items.Dimension(c,r,'source')=='gathered-inferred')
local facts=D.Facts(c,now,now+100);assert(facts.counts.gathered==3 and facts.gathered[629].inferred==3)
assert(D.Write(facts):find('3 inferred gathered',1,true))
assert(D.Daily(c,now,now+100):find('3 inferred gathered',1,true))
local boundary=S.Add(c,'milestone',now+100,{title='Fishing chapter',subject=c.id,major=true,milestoneType='level',from=1,to=2})
local recap=D.Generate(c,'milestone:'..boundary.id,now,now+100,'Fishing recap',{milestone=true,periodKind='milestone',partialBoundary=true,now=now+100})
S.Note(c,recap.noteKey,'My personal fishing note',now)
assert(G.Reject(c,id,true));assert(r.kind=='loot'and r.category=='loot'and r.profession==nil and r.gathering.state=='rejected')
local queued=E.JournalJobs.pending[c];local hasMilestone=false;for _,job in pairs(queued or{})do if job.kind=='milestone'and job.event==boundary.id then hasMilestone=true end end;assert(hasMilestone,'revocation updates saved recap jobs')
D.Generate(c,'milestone:'..boundary.id,now,now+100,'Fishing recap',{milestone=true,periodKind='milestone',partialBoundary=true,now=now+100})
assert(recap.facts.counts.gathered==0 and c.notes[recap.noteKey].text=='My personal fishing note')
assert(r.id==id and r.rawMessage=='Original receipt text'and r.quantity==3 and r.title=='Raw fish')
assert(G.Reject(c,id,false)and G.Inferred(r))
local duplicate=S.Add(c,'loot',r.ts,{title='Another receipt',itemID=629,quantity=3,recipient='someone-else',session=r.session,observedLootWindow=w.id})
assert(r.kind=='loot'and r.gathering.state=='unmatched','competing group receipt revokes inference')
c.records[duplicate.id]=nil;E.Emit('RECORDS_REMOVED',c);assert(G.Inferred(r),'evidence removal re-evaluates rather than duplicates')
local function fails(change,restore)
 change();S.Changed(c,slot);assert(not G.Inferred(r));restore();S.Changed(c,slot);assert(G.Inferred(r))
end
fails(function()slot.clearedAt=r.ts+3 end,function()slot.clearedAt=r.ts end)
fails(function()slot.maxVisibleQuantity=4 end,function()slot.maxVisibleQuantity=3 end)
fails(function()slot.snapshots[1].data.visibleQuantity=4 end,function()slot.snapshots[1].data.visibleQuantity=3 end)
fails(function()slot.slotReplacedAt=r.ts end,function()slot.slotReplacedAt=nil end)
fails(function()slot.session='other-session'end,function()slot.session=r.session end)
w.originConflict=true;S.Changed(c,w);assert(r.kind=='loot');w.originConflict=nil;S.Changed(c,w);assert(G.Inferred(r))
w.fromItem=true;S.Changed(c,w);assert(r.kind=='loot');w.fromItem=false;S.Changed(c,w);assert(G.Inferred(r))
w.interruptionObservedAt=r.ts;S.Changed(c,w);assert(r.kind=='loot');w.interruptionObservedAt=nil;S.Changed(c,w);assert(G.Inferred(r))
r.starred=true;S.Changed(c,r);local protected=S.Protected(c);assert(protected[w.id]and protected[slot.id],'star keeps inference evidence')
local other=S.Character('gathering-other',{name='Other'});assert(not G.Reject(other,r.id,true))
assert(#Q.Kind(c,'gold')==0 and #Q.Kind(c,'cost_lot')==0 and not r.harvestID and not r.operationID,'no invented gold, costs or node/operation counts')
local receiptAgain,new=E.History.Acquisition(c,r.ts,'loot',{itemID=629,quantity=3,recipient=c.id},'fish-line-1');assert(receiptAgain==r and not new)
local old=E.Copy(c);G.Start(c);assert(E.Same(c,old),'reload re-evaluation is idempotent')
local originalWindow=r.observedLootWindow;r.observedLootWindow=nil;S.Changed(c,r);assert(r.kind=='loot');r.observedLootWindow=originalWindow;S.Changed(c,r);assert(G.Inferred(r))
c.records[slot.id]=nil;E.Emit('RECORDS_REMOVED',c);assert(r.kind=='loot'and r.quantity==3,'missing proof revokes rather than removes receipt')
-- The collector records context before correlation, and contradictory origin observations remain explicit.
local saved={current=E.current,session=E.Collectors.session,now=A.Now,receipt=A.Receipt,item=A.Item,roster=E.Collectors.Roster,location=A.Location,live=E.Drops.live}
E.current=c;E.Collectors.session='collector-fishing';A.Now=function()return now+1000 end
A.Receipt=function()return'loot',{itemID=629,quantity=3,recipient=c.id}end;A.Item=function()return{}end;E.Collectors.Roster=function()end;A.Location=function()return{}end
c.state.activeLootWindow=w.id;E.Collectors.Loot('test',nil,nil,nil,nil,nil,nil,nil,nil,nil,999)
local captured=c.records[c.state.acquisitions['collector-fishing:999']];assert(captured.session=='collector-fishing'and captured.observedLootWindow==w.id)
local globals={'Enum','GetNumLootItems','GetLootSlotType','GetLootSlotInfo','GetLootSlotLink','IsFishingLoot'};local oldGlobals={};for _,key in ipairs(globals)do oldGlobals[key]=_G[key]end
Enum={LootSlotType={Item=1,None=0,Money=2,Currency=3}};GetNumLootItems=function()return 1 end;GetLootSlotType=function()return 1 end
GetLootSlotInfo=function()return 1,'Raw fish',3,nil,1,false,false,nil,false,false end;GetLootSlotLink=function()return'|Hitem:629|h[Raw fish]|h'end
IsFishingLoot=function()return true end;c.state.activeLootWindow=nil
E.Collectors.handlers.LOOT_READY(false);E.Collectors.handlers.LOOT_OPENED(false,false)
E.Collectors.Loot('test',nil,nil,nil,nil,nil,nil,nil,nil,nil,1001)
local real=c.records[c.state.acquisitions['collector-fishing:1001']];assert(real.kind=='loot')
E.Collectors.handlers.LOOT_SLOT_CLEARED(1);E.Collectors.handlers.LOOT_CLOSED();assert(G.Inferred(real),'actual collector path derives fishing from its captured evidence')
E.Collectors.Loot('test',nil,nil,nil,nil,nil,nil,nil,nil,nil,1002)
assert(c.records[c.state.acquisitions['collector-fishing:1002']].kind=='loot','receipt after close has no invented window association')
E.Collectors.handlers.LOOT_OPENED(false,false);local conflict=c.records[c.state.activeLootWindow]
IsFishingLoot=function()return false end;E.Collectors.handlers.LOOT_READY(false);IsFishingLoot=function()return true end;E.Collectors.handlers.LOOT_READY(false)
assert(conflict.originConflict and conflict.fishing,'contradictory readings are not erased by a later true value')
assert(E.Drops.Dimension(c,conflict,'origin')=='conflict','source report displays the conflict')
E.Collectors.Loot('test',nil,nil,nil,nil,nil,nil,nil,nil,nil,1003);E.Collectors.handlers.LOOT_SLOT_CLEARED(1);E.Collectors.handlers.LOOT_CLOSED()
assert(c.records[c.state.acquisitions['collector-fishing:1003']].kind=='loot','origin conflict blocks inference')
for _,key in ipairs(globals)do _G[key]=oldGlobals[key]end
c.state.activeLootWindow=nil;E.current=saved.current;E.Collectors.session=saved.session;A.Now=saved.now;A.Receipt=saved.receipt;A.Item=saved.item;E.Collectors.Roster=saved.roster;A.Location=saved.location;E.Drops.live=saved.live
print('PASS gathering: unique fishing attribution, one receipt, conflicts/revocation, user undo, recap labels/notes/refresh, session isolation, evidence retention and collector context')
