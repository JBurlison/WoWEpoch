local G,B,S,Q,A=E.CraftProjectionPreparation,E.Book,E.Store,E.Query,E.API
local c=assert(E.db.characters['craft-projection-long-archive'])
local requests=Q.Kind(c,'craft_request');local receipts=Q.Kind(c,'crafted')
local request,receipt=requests[#requests],receipts[#receipts]
local options={from=request.ts,through=receipt.ts+1,dimension='recipient'}
local first=E.Items.Report(c,options)
S.Character(c.id,{name='Corrected character name'})
assert(E.Items.Report(c,options).groups['id:'..c.id].label=='Corrected character name')
c.identity.name='Direct identity update'
assert(E.Items.Report(c,options).groups['id:'..c.id].label=='Direct identity update','identity mutation without Touch must invalidate label')
assert(E.Production.Association(c,receipt))
local profession=request.profession;request.profession='Unannounced correction';S.Touch(c)
assert(not E.Production.Association(c,receipt),'untyped Touch cannot retain accepted metadata')
request.profession=profession;S.Changed(c,request)
-- Isolate a cold projection after the book's general history checks have finished.
for frame=1,10000 do
 if B.HistoryReadiness(c)=='ready' then break end
 Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
end
assert(B.HistoryReadiness(c)=='ready')
local resolve,plan,replay=E.CraftCosts.Resolve,E.CraftCosts.Plan,E.Economy.Replay
local calls,plans,replays=0,0,0
E.CraftCosts.Resolve=function(...)calls=calls+1;return resolve(...)end
E.CraftCosts.Plan=function(...)plans=plans+1;return plan(...)end
E.Economy.Replay=function(...)replays=replays+1;return replay(...)end
local function pump(limit,churn)
 local steps,maxSeconds=0,0;local totalStart=os.clock()
 while G.job and G.job.status=='preparing'do
  steps=steps+1;assert(steps<(limit or 100000),'preparation must complete')
  local job=G.job;local before=job.checkpoints;local start=os.clock();G.Process(1000)
  maxSeconds=math.max(maxSeconds,os.clock()-start)
  assert(job.checkpoints-before<=1000,'each timer slice has a hard checkpoint budget')
  if churn and steps%100==0 and G.job.status=='preparing'then
   local old=G.job
   S.Add(c,'kill',A.Now(),{npcID=1,title='Unrelated kill'})
   S.Add(c,'play',A.Now(),{ended=A.Now()+1,status='active'})
   S.Add(c,'chat',A.Now(),{text='party chatter',channel='PARTY'})
   assert(G.job==old and E.Production.AssociationRevision(c)==old.generation,'journal-only active play cannot starve preparation')
  end
 end
 assert(G.job and G.job.status=='ready',G.job and(G.job.error or G.job.status)or'job disappeared')
 return steps,maxSeconds,os.clock()-totalStart
end
B.character=c.id;B.chapter='Loot';B.selected=nil;B.lootMode='receipts';B.lootPreset='all';B.lootQuery='';B.lootOwn=nil;B.lootDimension='item';B.lootFilters={};B.lootBucket=nil;B.lootFacet=nil
G.Cancel();S.Add(c,'note',A.Now(),{text='Cold aggregate'})
local leftUsed=B.left.used.label;local start=os.clock();B.Render(true);local foreground=os.clock()-start
assert(G.job and G.job.status=='preparing'and G.job.checkpoints==0,'actual render schedules without executing aggregate matching')
assert(B.left.used.label==leftUsed,'previous page remains intact while preparation runs')
assert(calls==0 and plans==0 and replays==0,'foreground does not invoke public financial engines')
local steps,maxSlice,totalCPU=pump(nil,true);assert(E.LootView.lastReport.quantity==20000 and E.LootView.lastReport.events==10000)
assert(#E.LootView.lastReport.records==10000,'no historical receipts omitted')
assert(E.LootView.lastReport.records[1]==receipts[1],'publication restores canonical record objects')
local ready=G.job;S.Add(c,'chat',A.Now(),{text='unrelated',channel='PARTY'});B.Render()
assert(G.job==ready and G.job.status=='ready','chat retains prepared aggregate')
-- Pending typed search text survives a same-context rebuild.
local input
for i=1,B.nav.used.edit or 0 do local f=B.nav.pool.edit[i];if f.inputValue==''then input=f;break end end
assert(input);input:SetText('Unsubmitted recipe query')
S.Character(c.id,{name='Prepared identity update'});B.Render();assert(G.job.status=='preparing')
local draftSteps=pump();local found=false
for i=1,B.nav.used.edit or 0 do if B.nav.pool.edit[i]:GetText()=='Unsubmitted recipe query'then found=true end end
assert(found and B.lootQuery=='','pending query draft is preserved without applying it')
-- A relevant correction cancels the old worker. A range switch never publishes
-- the old all-history totals into the new selection.
S.Touch(c);B.Render();local abandoned=G.job;G.Process(1000)
B.lootPreset='custom';B.lootFrom=A.Day(request.ts);B.lootThrough=A.Day(request.ts);B.Render()
assert(abandoned.status=='cancelled'and G.job~=abandoned)
pump();assert(E.LootView.lastRange.first==A.Day(request.ts)and E.LootView.lastReport.quantity<20000)
-- A complete saved recap prepares its sources and crafting projection too.
local refs={};for _,r in ipairs(receipts)do refs[#refs+1]=r.id end
local recap=S.Add(c,'recap',A.Now(),{periodKind='milestone',key='review',refs=refs,facts={},text='Review'})
B.chapter='Recaps';B.selected=recap.id;B.recapFocus=recap.id;B.recapSourcesOpen=false;G.Cancel();B.Clear(B.right)
start=os.clock();E.RecapView.Record(B.right,c,recap);local recapForeground=os.clock()-start
assert(G.job.status=='preparing'and G.job.checkpoints==0,'direct recap renderer schedules complete work')
local recapSteps,recapSlice,recapCPU=pump();local model=assert(G.job.model.recap)
assert(#model.sources==10000 and model.missing==0)
local total,events=0,0;for _,row in ipairs(model.crafting)do total=total+row.quantity;events=events+row.receipts end
assert(total==20000 and events==10000)
assert(recap.text=='Review'and next(recap.facts)==nil,'projection preserves saved recap words/facts')
assert(calls==0 and plans==0 and replays==0,'private work leaves public financial caches untouched')
-- Direct identity drift during work is rejected even without a Store signal.
S.Touch(c);B.Render();local drift=G.job;G.Process(1000);c.identity.name='Changed mid-build';G.Step(drift,1000)
assert(drift.status=='cancelled','unannounced identity change prevents stale publication')
G.Cancel();B.chapter='Chronicle';B.selected=nil
E.CraftCosts.Resolve=resolve;E.CraftCosts.Plan=plan;E.Economy.Replay=replay
print(string.format('PASS actual 90k-record UI: render %.4fs / %d slices max %.4fs total host clock %.3fs; recap %.4fs / %d slices max %.4fs total host clock %.3fs; safe appends,20k items complete, canonical, guarded, no public FIFO',foreground,steps,maxSlice,totalCPU,recapForeground,recapSteps,recapSlice,recapCPU))
