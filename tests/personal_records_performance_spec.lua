local S,A,K,P,W,H=E.Store,E.API,E.Keepsakes,E.PersonalRecords,E.RetentionWork,E.AuctionHistory
S.Open(nil)
local now=1800000000;TEST_NOW(now)
local cutoff=A.DayStart(now);local before=A.ShiftDay(cutoff,-1)
local c=S.Character('performance-owner',{});local other=S.Character('performance-other',{})
E.current=c;c.state.recapLoginThrough=cutoff
local loot=S.Add(c,'loot',before+1,{itemID=1,quantity=2,recipient=c.id,vendorUnitValue=20})
local window=S.Add(c,'wallet_window',before,{ended=cutoff,opening=0,closing=5,transactionCount=1,session='wallet'})
S.Add(c,'gold',before+2,{window=window.id,before=0,after=5,amount=5,session='wallet'})
local foreign=S.Add(other,'memory',before,{payload={nested={proof='retained complete'}}})
local proof=S.Add(c,'milestone',before,{characterSnapshot={equipment={{itemID=1,link='item:1'}}},sourceRecord=foreign.id})
local merchant=S.Add(c,'merchant',cutoff+200,{refs={proof.id},quantity=1})
local orphan=S.Add(other,'craft_request',cutoff+300,{session='orphan',subject=other.id})
for i,id in ipairs(other.order)do if id==orphan.id then table.remove(other.order,i);break end end
local unrelated=S.Add(c,'milestone',before,{characterSnapshot={equipment={}}})
for i=1,1000 do unrelated.characterSnapshot.equipment[i]={itemID=i,stats={strength=i}}end
local payload=S.Add(c,'chat',before,{text=string.rep('journal words ',1000)})
S.Note(c,'record:'..loot.id,'Untouched writing',now)
local original=E.Copy(E.db)
local engine=P.ReadEngine(nil,c)
assert(engine.PreparationValid())
assert(not engine.db.characters[c.id].records[unrelated.id]and not engine.db.characters[c.id].records[payload.id],
 'Unreferenced journal payloads must not be duplicated into financial readers')
assert(E.Same(engine.db.characters[c.id].records[proof.id],proof))
assert(E.Same(engine.db.characters[other.id].records[foreign.id],foreign),'Cross-account ancillary closure must retain full evidence')
assert(E.Same(engine.db.characters[other.id].records[orphan.id],orphan),'Unordered financial negatives must be retained')
assert(E.Same(engine.db.characters[c.id].records[merchant.id],merchant),'Later evidence must not be cutoff filtered')
assert(E.Same(original,E.db),'Snapshot construction must not change saved history')
assert(not pcall(engine.Store.Add,engine.db.characters[c.id],'memory',now,{}))
local snapshot=H.Snapshot
local compact=P.Build(c,cutoff)
H.Snapshot=function(a,work)return W.Copy(E.db,work)end
local full=P.Build(c,cutoff)
H.Snapshot=snapshot
assert(E.Same(compact.desired,full.desired)and E.Same(compact.operations,full.operations),'Compacted and full readers must produce the same record decisions')
foreign.payload.nested.proof='corrected';S.Changed(other,foreign)
assert(not engine.PreparationValid(),'Ancillary changes must invalidate an already prepared reader')
engine=P.ReadEngine(nil,c)
S.Add(other,'merchant',cutoff+400,{})
assert(not engine.PreparationValid(),'Later cross-account financial evidence must invalidate the reader')
-- An insertion while copying an unordered row must stop before next() on the
-- mutated dictionary and invalidate that incomplete snapshot.
local audit=H.Start(c);local inserted=false
H.Snapshot(audit,function()
 if audit.dictionaryOwner==other.id and not inserted then
  inserted=true;S.Add(other,'memory',now,{title='Concurrent journal entry'})
 end
end,true)
assert(inserted and not H.Valid(audit))

local failures={};E.On('KEEPSAKE_JOB_FAILED',function(owner,key,why)failures[#failures+1]=why end)
local function drain()
 for i=1,20000 do K.Process(1000);if not K.Pending(c,'personal-records')then return end end
 error('Personal records failed to settle')
end
P.Login(c,now);drain()
local best=c.records[c.state.keepsakes.personalRecords.ids[1]]
local build=P.Build;local starts=0
P.Build=function(...)starts=starts+1;return build(...)end
-- Repeated current-day receipts invalidate historical financial decisions,
-- but allocate no new snapshot during the quiet period.
S.Add(c,'loot',cutoff+1,{itemID=1,quantity=1,recipient=c.id})
assert(K.Pending(c,'personal-records'))
for second=0,29 do
 TEST_NOW(now+second)
 if second>0 then S.Add(c,'loot',cutoff+second+1,{itemID=1,quantity=1,recipient=c.id})end
 for i=1,10 do K.Process(20)end
 assert(starts==0,'Continuous receipts must coalesce before the maximum retry deadline')
end
TEST_NOW(now+30);S.Add(c,'loot',cutoff+31,{itemID=1,quantity=1,recipient=c.id})
K.Process(20);assert(starts==0,'Continuous receipts wait for quiet instead of starting a rebuild the next receipt cancels')
-- Ready work for another key must not wait behind the deferred request.
local independent=false
K.Queue(c,'ready-work',function()return true end,function()independent=true end)
K.Process(20);assert(independent and starts==0)
TEST_NOW(now+34);K.Process(20);assert(starts==0)
TEST_NOW(now+35);K.Process(20);assert(starts==1,'Five quiet seconds must resume the latest request')
-- Invalidating that partial build cancels it immediately and preserves the
-- queued request for the next quiet period.
S.Add(c,'loot',cutoff+36,{itemID=1,quantity=1,recipient=c.id})
K.Process(20);assert(starts==1 and K.Pending(c,'personal-records'))
TEST_NOW(now+40);K.Process(20);assert(starts==2,'The cancelled request resumes after the next quiet period')
drain();assert(not K.Pending(c,'personal-records'))
-- Explicit page demand and login bypass the delay, even when a deferred job
-- already exists. A changed historical value is published only when current.
loot.quantity=3;S.Changed(c,loot)
local count=starts;P.Ensure(c);K.Process(20);assert(starts==count+1)
loot.quantity=4;S.Changed(c,loot)
TEST_NOW(now+45);drain()
local found
for _,r in ipairs(P.Rows(c))do if r.recordType=='loot_value'and r.valid~=false then found=r end end
assert(found and found.value==80 and c.notes['record:'..loot.id].text=='Untouched writing')
S.Add(c,'loot',cutoff+50,{itemID=1,quantity=1,recipient=c.id})
count=starts;P.Login(c,now+40);K.Process(20);assert(starts==count+1);drain()
P.Build=build
assert(#failures==0,failures[1])
print('PASS personal-record coalescing, prompt cancellation, bounded retries, compact snapshot closure and reader parity')
