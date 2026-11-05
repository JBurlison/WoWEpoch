local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local G,B,S,Q,A,C,I,H=E.CraftProjectionPreparation,E.Book,E.Store,E.Query,E.API,E.Collectors,E.Inventory,E.History
local c=assert(E.db.characters['craft-projection-long-archive'])
local saved={current=E.current,session=C.session,live=I.live,snapshot=I.Snapshot,identity=A.Identity,roster=A.Roster,quests=A.QuestLog,now=A.Now()}
bindWallet(c,'projection-poll');local now=saved.now
A.Identity=function()local identity=E.Copy(c.identity);identity.id=c.id;return identity end
A.Roster=function()return {}end;A.QuestLog=function()return {}end
local snapshot={counts={},carried={},equipment={},equipmentSlots={},sizes={},scope='bags and equipment',banks={}}
for _,key in ipairs({'character','account'})do snapshot.banks[key]={status='available',counts={},tabs={},bagObjects={},usable=true,usesBags=false}end
I.Snapshot=function()return E.Copy(snapshot)end
I.Start(c);I.Process(0.3);I.Process(0.3);C.Heartbeat();E.QuestAtlas.ProfessionProfile(c)
Q.Kind(c,'crafted');TEST_PREPARE_HISTORY(c)
local reasons={};E.On('HISTORY_TOUCHED',function(owner,r)if owner==c then local reason=r.reason or'unknown';reasons[reason]=(reasons[reason]or 0)+1 end end)
B.character=c.id;B.chapter='Loot';B.selected=nil;B.lootMode='receipts';B.lootPreset='all';B.lootQuery='';B.lootOwn=nil;B.lootDimension='item';B.lootFilters={};B.lootBucket=nil;B.lootFacet=nil
G.Cancel();B.frame:Show();B.Render();assert(G.job and G.job.status=='preparing');local original=G.job;local count=0
while G.job.status=='preparing'do
 count=count+1;assert(count<10000);G.Process(4000)
 if count%20==0 and G.job.status=='preparing'then
  now=now+5;TEST_NOW(now);I.Process(5);C.Heartbeat();E.QuestAtlas.ProfessionProfile(c)
  assert(G.job==original and E.Production.AssociationRevision(c)==original.generation,'actual unchanged inventory/bank, quest metadata and heartbeat must not restart item preparation')
 end
end
assert(G.job==original and E.LootView.lastReport.quantity==20000)
for _,reason in ipairs({'inventoryUnchanged','bankUnchanged','walletExtension','questAtlas'})do assert((reasons[reason]or 0)>2,'actual polling path missing '..reason)end
-- A mutable source already linked by a recap remains a dependency, even when
-- its play update is irrelevant to crafting association itself.
local play=assert(c.records[c.state.play]);local receipt=Q.Kind(c,'crafted')[1]
local recap=S.Add(c,'recap',now,{periodKind='milestone',key='polling',title='Polling review',refs={play.id,receipt.id},facts={},text='Saved summary'})
B.chapter='Recaps';B.selected=recap.id;B.recapFocus=recap.id;G.Cancel();B.Render();local prior=G.job;assert(prior)
G.Process(10);now=now+5;TEST_NOW(now);C.Heartbeat();G.Process(10)
assert(prior.status=='cancelled'and G.job~=prior,'referenced mutable play must invalidate recap projection')
while G.job and G.job.status=='preparing'do G.Process(4000)end
assert(G.job and G.job.status=='ready'and recap.text=='Saved summary')
-- Existing public cost detail work remains separate; the new association UI
-- must not call any public association resolver after its private model is ready.
local association,receipts=E.Production.Association,E.Production.Receipts;local calls=0
E.Production.Association=function(...)calls=calls+1;return association(...)end
E.Production.Receipts=function(...)calls=calls+1;return receipts(...)end
for _,record in ipairs({receipt,Q.Kind(c,'craft_request')[1]})do
 B.chapter='Loot';B.selected=record.id;B.lootMode=record.kind=='crafted'and'receipts'or'crafting';G.Cancel();B.Render()
 assert(G.job and G.job.status=='preparing'and G.job.checkpoints==0)
 while G.job.status=='preparing'do G.Process(4000)end
 assert(calls==0,'selected detail must not re-enter public profession projection')
 assert(G.Detail(c,record),'selected detail is present in complete prepared model')
end
E.Production.Association=association;E.Production.Receipts=receipts
local dense=assert(E.db.characters['craft-projection-dense'])
E.Production.Association=function(...)calls=calls+1;return association(...)end
E.Production.Receipts=function(...)calls=calls+1;return receipts(...)end
B.character=dense.id
for _,record in ipairs({Q.Kind(dense,'crafted')[1],Q.Kind(dense,'craft_request')[1]})do
 B.selected=record.id;B.lootMode=record.kind=='crafted'and'receipts'or'crafting';G.Cancel();B.Render()
 assert(G.job and G.job.checkpoints==0)
 while G.job.status=='preparing'do G.Process(4000)end
 assert(calls==0 and G.Detail(dense,record),'dense selected detail must use prepared association')
end
E.Production.Association=association;E.Production.Receipts=receipts
-- A forged typed wallet extension is not treated as unchanged financial data.
local generation=E.Production.AssociationRevision(c)
S.Touch(c,'walletExtension',{record=c.records[c.state.walletWindow],before={}})
assert(E.Production.AssociationRevision(c)>generation)
local replaced=S.Character('projection-replaced-id',{name='Replacement'})
S.Add(replaced,'craft_request',now,{recipeID=1});local before=E.Production.AssociationRevision(replaced)
replaced.seq=0;S.Add(replaced,'chat',now,{text='Reused record key'})
assert(E.Production.AssociationRevision(replaced)>before,'a journal add replacing a financial kind cannot retain caches')
-- A truly cold query index must move from the normal readiness workers to
-- the projection worker automatically, without a second click.
local cold=S.Character('projection-cold-query',{name='Cold query'})
for n=1,2500 do S.Add(cold,'loot',now,{itemID=1,quantity=1,recipient=cold.id,title='Cold receipt'})end
-- Reopen the saved rows under a fresh owner so collection's warmed cache cannot satisfy this cold-start control.
cold=E.Copy(cold);E.db.characters[cold.id]=cold;assert(not E.Query.IsWarm(cold))
B.character=cold.id;B.selected=nil;B.lootMode='receipts';G.Cancel();B.Render()
assert(G.waiting and not G.job,'cold render owns a bounded readiness handoff')
local steps=0
while G.waiting or G.job and G.job.status=='preparing'do
 steps=steps+1;assert(steps<10000)
 Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();G.Process(4000)
end
assert(G.job and G.job.status=='ready'and E.LootView.lastReport.quantity==2500,'cold query handoff completes automatically')
local mismatch=S.Character('projection-conflicting-owner',{name='Local dictionary'})
local foreign=S.Character('projection-foreign-dictionary',{name='Foreign dictionary'})
local localReceipt=S.Add(mismatch,'crafted',now,{itemID=7,quantity=3,recipient=mismatch.id,title='Local raw receipt'})
localReceipt.character=foreign.id;S.Changed(mismatch,localReceipt)
local foreignReceipt=E.Copy(localReceipt);foreignReceipt.quantity=99;foreignReceipt.title='Foreign collision';foreign.records[localReceipt.id]=foreignReceipt
local expected=E.Items.Report(mismatch,{from=0,through=now+1,dimension='item'})
assert(expected.quantity==0 and #expected.records==0,'public receipt report rejects conflicting character payloads')
B.character=mismatch.id;B.selected=nil;G.Cancel();B.Render()
while G.waiting or G.job and G.job.status=='preparing'do Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();G.Process(4000)end
assert(E.LootView.lastReport.quantity==0 and #E.LootView.lastReport.records==0,'private receipt report retains the public ownership filter')
local localRequest=S.Add(mismatch,'craft_request',now,{recipeID=7,title='Local request'})
localRequest.character=foreign.id;S.Changed(mismatch,localRequest)
local foreignRequest=E.Copy(localRequest);foreignRequest.title='Foreign request collision';foreign.records[localRequest.id]=foreignRequest
local expectedProduction=E.Production.Report(mismatch,{from=0,through=now+1})
assert(expectedProduction.rows[1]==localRequest)
B.lootMode='crafting';B.productionPreset='all';B.productionQuery='';B.productionFilter='all';G.Cancel();B.Render()
while G.waiting or G.job and G.job.status=='preparing'do Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();G.Process(4000)end
assert(E.ProductionView.lastReport.rows[1]==localRequest,'publication preserves the actual dictionary source, not a conflicting character payload or same-ID foreign object')
local draftOwner=S.Character('projection-draft-identity',{name='Draft identity'})
local draftRecord=S.Add(draftOwner,'crafted',now,{itemID=8,quantity=1,recipient=draftOwner.id,title='Original record'})
B.character=draftOwner.id;B.lootMode='receipts';B.lootQuery='';B.selected=draftRecord.id;G.Cancel();B.Render()
local function finish()
 while G.waiting or G.job and G.job.status=='preparing'do Q.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process();G.Process(4000)end
 assert(G.job and G.job.status=='ready')
end
local function queryInput()
 for i=1,B.nav.used.edit or 0 do local edit=B.nav.pool.edit[i];if edit.inputLabel=='Search receipts'then return edit end end
 for i=1,B.nav.used.edit or 0 do local edit=B.nav.pool.edit[i];if edit.inputValue==B.lootQuery then return edit end end
 error('No editable receipt query')
end
finish();queryInput():SetText('Old page draft');S.Touch(draftOwner);B.Render();assert(G.job.status=='preparing')
local replacement=E.Copy(draftRecord);replacement.title='Replacement record';draftOwner.records[draftRecord.id]=replacement;S.Changed(draftOwner,replacement);B.Render();finish()
assert(queryInput():GetText()~='Old page draft'and G.shown.record==replacement,'same-ID replacement cannot adopt the old page draft')
queryInput():SetText('Unapplied stale query');S.Touch(draftOwner);B.Render();B.lootQuery='Backing value changed';B.Render();finish()
assert(queryInput():GetText()=='Backing value changed','an unapplied draft cannot overwrite a changed backing value')
S.Touch(draftOwner);B.Render();local oldClock=G.job;local dayLabel=A.Day(A.Now());local dayStart=A.DayStart
A.DayStart=function(ts)return dayStart(ts)+3600 end
assert(A.Day(A.Now())==dayLabel,'the simulated local boundary change keeps its date label')
assert(G.Step(oldClock,100)=='cancelled','same-day local boundary changes must invalidate before publication')
A.DayStart=dayStart;G.Cancel();B.Render();finish()
G.Cancel();B.chapter='Chronicle';B.selected=nil
E.current=saved.current;C.session=saved.session;I.live=saved.live;I.Snapshot=saved.snapshot;A.Identity=saved.identity;A.Roster=saved.roster;A.QuestLog=saved.quests;TEST_NOW(saved.now)
print('PASS actual inventory/bank/QuestAtlas/Heartbeat polling without starvation; referenced recap changes invalidate; selected detail projection stays private; replaced IDs and malformed receipts invalidate; cold query handoff completes')

restoreWallet()
