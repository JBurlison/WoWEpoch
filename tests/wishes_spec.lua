local W,K,S,H=E.Wishes,E.Keepsakes,E.Store,E.History
local c=S.Character('wish-owner',{name='Thrum'});local other=S.Character('wish-other',{})
E.current=c;TEST_NOW(1800000000)
local function drain()
    for i=1,20000 do K.Process(200);if not W.Pending(c)and not W.Pending(other)then return end end
    error('Wish work did not settle')
end
local notices={};E.On('GOAL_COMPLETED',function(owner,g,m,options)
    if owner==c then assert(c.records[g.id]==g and c.records[m.id]==m and g.status=='completed');notices[#notices+1]={goal=g.id,quiet=options.quiet}end
end)
local function create(kind,target,history)
    return assert(W.Create(c,{title='A small adventure',goalType=kind,target=target,includeHistory=history}))
end
local before=H.Acquisition(c,1800000000,'loot',{itemID=10,quantity=6,recipient=c.id})
local fromNow=create('acquire',{itemID=10,quantity=4});local history=create('acquire',{itemID=10,quantity=4},true)
drain();assert(fromNow.progress.current==0 and fromNow.status=='active'and history.status=='completed')
assert(notices[#notices].quiet,'Creation from recorded history is quiet')
local wrong=H.Acquisition(c,1800000000,'loot',{itemID=10,quantity=100,recipient=other.id})
local receipt=H.Acquisition(c,1800000000,'loot',{itemID=10,quantity=4,recipient=c.id},'wish-one')
H.Acquisition(c,1800000000,'loot',{itemID=10,quantity=4,recipient=c.id},'wish-one')
drain();assert(fromNow.progress.current==4 and fromNow.status=='completed'and not notices[#notices].quiet)
local memory=assert(c.records[fromNow.completionMemory]);assert(memory.artID,'Goal completion uses existing illustration artwork')
K.Note(c,memory,'My words stay');E.Memories.Edit(c,memory.id,'title','My own title')
local noticeCount=#notices;W.Request(c,false);drain();assert(#notices==noticeCount)
receipt.quantity=2;S.Changed(c,receipt);drain()
assert(fromNow.status=='active'and fromNow.evidenceRevised and memory.completionEvidence=='revised')
assert(memory.title=='My own title'and K.Notes(c,memory)=='My words stay')
receipt.quantity=4;S.Changed(c,receipt);drain();assert(fromNow.status=='completed'and fromNow.completionMemory==memory.id and #notices==noticeCount)
assert(W.SetStatus(c,fromNow,'reopen'));drain();assert(fromNow.status=='active'and memory.completionEvidence=='reopened')
H.Acquisition(c,1800000001,'loot',{itemID=10,quantity=1,recipient=c.id});drain()
assert(fromNow.status=='completed'and fromNow.completionMemory==memory.id and #notices==noticeCount)
local count=0;for _,r in pairs(c.records)do if r.goal==fromNow.id then count=count+1 end end;assert(count==1)
local free=create('freeform',{});drain();assert(free.status=='active')
assert(W.SetStatus(c,free,'complete'));assert(free.status=='completed'and free.completionMethod=='manual')
local freeMemory=c.records[free.completionMemory];assert(freeMemory and not notices[#notices].quiet)
assert(W.SetStatus(c,free,'archive'));assert(not W.SetStatus(c,free,'complete'))
assert(#W.List(c,'archived')==1 and W.SetStatus(c,free,'restore'));drain();assert(free.status=='completed')
assert(not W.SetStatus(other,free,'reopen')and not W.Definition(other,free))
local level=create('level',{level=15});local skill=create('skill',{skillID=43,rank=75})
local quests=create('quests',{ids={101,102}});local locations=create('locations',{ids={1429,1453}})
local craft=create('craft',{itemID=20,quantity=3});local gather=create('gather',{itemID=30,quantity=3})
drain();assert(level.progress.known==false and skill.progress.known==false)
S.Add(c,'milestone',1800000002,{subject=other.id,milestoneType='level',after=60})
S.Add(c,'milestone',1800000002,{subject=c.id,milestoneType='level',after=15})
S.Add(c,'milestone',1800000002,{subject=c.id,milestoneType='skill',skillID=43,after=75})
S.Add(c,'quest_attempt',1800000002,{questID=102,status='completed'})
S.Add(c,'quest',1800000002,{questID=101,status='completed'})
S.Add(c,'quest',1800000002,{questID=101,status='completed'})
S.Add(c,'quest',1800000002,{questID=102,status='active'})
S.Add(c,'milestone',1800000002,{subject=c.id,milestoneType='discovery',mapID=1429})
S.Add(c,'memory',1800000002,{mapID=1453,locationObservedAt=1800000002})
S.Add(c,'quest',1800000002,{questID=500,status='completed',mapID=1453})
H.Acquisition(c,1800000002,'crafted',{itemID=20,quantity=3,recipient=c.id})
local inferred=H.Acquisition(c,1800000002,'gathered',{itemID=30,quantity=3,recipient=c.id,gathering={state='inferred'}})
drain();assert(level.status=='completed'and skill.status=='completed'and craft.status=='completed'and gather.status=='completed')
assert(quests.progress.current==1 and locations.progress.current==1 and #gather.progress.inferredRefs==1)
S.Add(c,'quest',1800000003,{questID=102,status='completed'})
S.Add(c,'travel',1800000003,{mapID=1453,locationObservedAt=1800000003})
drain();assert(quests.status=='completed'and locations.status=='completed')
inferred.kind='loot';inferred.gathering={state='rejected'};S.Changed(c,inferred);drain()
assert(gather.status=='active'and c.records[gather.completionMemory].completionEvidence=='revised')
assert(W.SetStatus(c,gather,'complete'));W.Request(c,true);drain();assert(gather.status=='completed'and gather.completionMethod=='manual')
-- Removing a supporting source invalidates an automatic wish but preserves writing.
c.records[receipt.id]=nil;S.Touch(c);E.Emit('RECORDS_REMOVED',c,{[receipt.id]=true});drain()
assert(fromNow.status=='active'and K.Notes(c,memory)=='My words stay')
-- Reload recovery reconstructs progress and finds the existing completion memory.
local reloaded=E.Copy(c);E.db.characters[c.id]=reloaded;E.current=reloaded
W.Recover(reloaded)
for i=1,20000 do K.Process(200);if not W.Pending(reloaded)then break end end
assert(not W.Pending(reloaded));local loadedGoal=reloaded.records[fromNow.id]
assert(loadedGoal.completionMemory==memory.id and K.Notes(reloaded,reloaded.records[memory.id])=='My words stay')
assert(#W.List(reloaded,'all')==9)
assert(not W.Create(other,{title='',goalType='freeform'}))
assert(not W.Validate({title='Bad IDs',goalType='quests',target={ids={1,1}}}))
assert(not W.Validate({title='Bad quantity',goalType='craft',target={itemID=1,quantity=math.huge}}))
-- The history scan yields instead of walking the entire archive on the UI path.
local big=S.Character('wish-large',{});local g=assert(W.Create(big,{title='More linen',goalType='acquire',target={itemID=1,quantity=9000}}))
for i=1,3000 do S.Add(big,'loot',1800000010+i,{itemID=1,quantity=1,recipient=big.id})end
local observed=0;local job=E.RetentionWork.Start(function(work)return W.Evaluate(big,g,function()observed=observed+1;work()end)end)
E.RetentionWork.Step(job,20);assert(observed<=21 and observed>0)
local state,result;for i=1,300 do state,result=E.RetentionWork.Step(job,20);if state then break end end
assert(state=='done'and result.current==3000 and not result.complete)
-- Continuous heartbeats must not starve a scan. An appended receipt is picked
-- up by the next coalesced pass without losing its first-completion notice.
local liveNotices=0;E.On('GOAL_COMPLETED',function(owner,_,_,options)if owner==big and not options.quiet then liveNotices=liveNotices+1 end end)
local heartbeat=S.Add(big,'play',1800004000,{status='active',ended=1800004000})
for i=1,30 do K.Process(20)end
S.Add(big,'loot',1800004001,{itemID=1,quantity=6000,recipient=big.id})
for i=1,20000 do
    if i%30==0 then heartbeat.ended=heartbeat.ended+1;S.Changed(big,heartbeat)end
    K.Process(100)
    if not W.Pending(big)then break end
end
assert(not W.Pending(big)and g.status=='completed'and g.progress.current==9000 and liveNotices==1)
local revisedGoal=assert(W.Create(big,{title='Corrected count',goalType='acquire',target={itemID=2,quantity=2}}))
local corrected=S.Add(big,'loot',1800004010,{itemID=2,quantity=1,recipient=big.id})
corrected.quantity=2;S.Changed(big,corrected)
for i=1,20000 do K.Process(200);if not W.Pending(big)then break end end
assert(revisedGoal.status=='completed'and liveNotices==1,'A correction before first publication remains quiet')
local enrichedGoal=assert(W.Create(big,{title='Price arrives later',goalType='acquire',target={itemID=3,quantity=1}}))
local enriched=S.Add(big,'loot',1800004011,{itemID=3,quantity=1,recipient=big.id})
enriched.vendorUnitValue=50;S.Changed(big,enriched)
for i=1,20000 do K.Process(200);if not W.Pending(big)then break end end
assert(enrichedGoal.status=='completed'and liveNotices==2,'Price enrichment does not suppress a real new acquisition')
local gatheringGoal=assert(W.Create(big,{title='One fresh herb',goalType='gather',target={itemID=4,quantity=1}}))
local newlyGathered=S.Add(big,'loot',1800004012,{itemID=4,quantity=1,recipient=big.id})
for i=1,20000 do K.Process(200);if not W.Pending(big)then break end end
assert(gatheringGoal.status=='active')
newlyGathered.kind='gathered';newlyGathered.gathering={state='inferred'};S.Changed(big,newlyGathered)
for i=1,20000 do K.Process(200);if not W.Pending(big)then break end end
assert(gatheringGoal.status=='completed'and liveNotices==3,'A new receipt classified as gathered can celebrate once')
print('PASS wish types, baselines, reversal, manual completion, one memory, sharing ownership and bounded evaluation')
