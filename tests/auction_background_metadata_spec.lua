local P,T,S,C=E.AuctionPreparation,E.QuestAtlas,E.Store,E.Collectors
local c=AuctionPerfHistory(40,'varied')
local live=S.Character('quest-metadata-observer',{name='Quest observer',level=12});E.current=live;C.session='metadata-session'
local savedGUID=UnitGUID
UnitGUID=function(unit)if unit=='player' then return live.id end;return savedGUID(unit)end
T.worker={c=live,session=C.session,queue={},head=1,queued={},requested={},elapsed=0}
for id=201,240 do T.worker.queue[#T.worker.queue+1]=id;T.worker.queued[id]=true end
local spec={kind='book',chapter='Gold',goldSection='auctions',goldPreset='all',auctionMode='history',auctionPage=1,now=E.API.Now()}
local job=P.Start(c,spec);P.Step(job,1)
T.Profile(live);assert(P.HistoryValid(job),'Quest profile metadata cancelled financial work')
for i=1,20 do
 T.Process(1);assert(P.HistoryValid(job),'Background quest metadata cancelled financial work')
 P.Step(job,1000)
end
T.worker.requested[201]=true;C.handlers.QUEST_DATA_LOAD_RESULT(201,false)
assert(P.HistoryValid(job),'Failed quest metadata request cancelled financial work')
for i=1,10000 do if job.status~='preparing'then break end;P.Step(job,1000)end
assert(job.status=='ready',job.error or job.status)
S.Touch(live);assert(not P.HistoryValid(job),'Unspecified changes must remain invalidating')
-- Metadata-only receipts must not conceal changes to a referenced quest record.
local quest=E.History.BeginQuest(live,201,'Referenced quest',E.API.Now(),true)
S.Add(c,'auction',E.API.Now(),{source='owned',metadataReference=quest.id,auctionData={}})
job=P.Start(c,spec)
for i=1,10000 do if job.status~='preparing'then break end;P.Step(job,1000)end
assert(job.status=='ready'and job.audit.watched[quest.id])
assert(live.state.activeQuests[201]==quest.id)
local on=E.API.OnQuest;E.API.OnQuest=function(id)return id==201 end
T.worker.queue={201};T.worker.head=1;T.worker.queued={[201]=true};T.worker.elapsed=0
T.Process(1);E.API.OnQuest=on
UnitGUID=savedGUID
assert(not P.HistoryValid(job),'Referenced quest flags escaped their independent record invalidation')
print('PASS quest metadata loading/profile/failure receipts preserve preparation; unknown writes and referenced record changes still invalidate')
