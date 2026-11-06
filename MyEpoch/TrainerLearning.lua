local _,E=...
local T,A,S,C,F,Q={},E.API,E.Store,E.Collectors,E.Economy,E.Query;E.TrainerLearning=T
local function valid(v)return v and v.owner==E.current and E.db.characters[v.owner.id]==v.owner and v.session==C.session end
local function identity()
 local kind=A.Call('trainingType',C_Trainer and C_Trainer.GetTrainerType)
 local enum=Enum and Enum.TrainerType
 local label=enum and(kind==enum.General and 'General'or kind==enum.Tradeskills and 'Tradeskills')
 local guid=A.Call('trainingNPC',UnitGUID,'npc')
 if label and type(guid)=='string'and guid~=''then return guid,label end
end
local function snapshot(v)
 local guid,kind=identity();if guid~=v.guid or kind~=v.kind then return end
 local count=A.Call('trainingCount',GetNumTrainerServices)
 if type(count)~='number'or count<0 or count>2000 or count%1~=0 then return end
 local rows={}
 for i=1,count do
  local name,state,_,level,rank=A.Call('trainingInfo',GetTrainerServiceInfo,i)
  local cost=A.Call('trainingCost',GetTrainerServiceCost,i)
  if state=='available'and type(name)=='string'and name~=''and type(cost)=='number'and cost>0 and cost%1==0 then
   rows[i]={name=name,rank=rank,level=level,cost=cost,index=i}
  end
 end
 return rows
end
function T.Refresh()
 local v=T.visit;if not valid(v)or v.closed then return end
 local rows=snapshot(v);if not rows then v.closed=true;return end
 -- Keep the previous available quote for synchronous purchase callbacks that
 -- rebuild or hide the row before the secure post-hook runs.
 v.previous=v.rows;v.previousAt=v.quoteAt;v.rows=rows;v.quoteAt=A.Now();v.quoteSequence=S.ReserveObservation(v.owner)
end
function T.Open()
 local guid,kind=identity();T.visit=nil
 if not E.current or not C.session or not guid then return end
 T.visit={owner=E.current,session=C.session,guid=guid,kind=kind,requests={}}
 T.Refresh()
 if not T.hooked and type(hooksecurefunc)=='function'and type(BuyTrainerService)=='function'then
  T.hooked=pcall(hooksecurefunc,'BuyTrainerService',function(index)if E.RecorderReady()then T.Attempt(index)end end)
 end
end
function T.Attempt(index)
 local v=T.visit;local now=A.Now();if not valid(v)or v.closed then return end
 local guid,kind=identity();if guid~=v.guid or kind~=v.kind then v.closed=true;return end
 if #v.requests>=64 then v.closed=true;return end
 index=A.Plain(index);if type(index)~='number'or index<1 or index>2000 or index%1~=0 then index=nil end
 local currentRows=snapshot(v)
 local request={ts=now,sequence=S.ReserveObservation(v.owner),window=v.owner.state.walletWindow,quotes={}}
 local function candidate(rows,at)
  local q=rows and rows[index]
  if q and at and now>=at and now-at<=300 then
   for _,old in ipairs(request.quotes)do if old.service.name==q.name and old.service.cost==q.cost then return end end
   request.quotes[#request.quotes+1]={service=E.Copy(q),at=at}
  end
 end
 candidate(v.rows,v.quoteAt);candidate(v.previous,v.previousAt);candidate(currentRows,now)
 v.requests[#v.requests+1]=request
end
function T.Tick()
 local v=T.visit;local now=A.Now();if not valid(v)or #v.requests==0 then return end
 if Q.EnsureWarm(v.owner)~='ready'then return end
 for _,request in ipairs(v.requests)do if not request.done and now-request.ts>=4 then
  request.done=true
  local overlap=false
  for _,other in ipairs(v.requests)do if other~=request and math.abs(other.ts-request.ts)<=2 then overlap=true end end
  if #request.quotes>0 and not overlap then
   local rows=Q.RangeKinds(v.owner,request.ts-2,request.ts+3,{gold=true,spell=true,money_evidence=true})
   local selected,matches= nil,0
   for _,quote in ipairs(request.quotes)do
    local q=quote.service;local wallet,learned;local wallets,learnings=0,0;local existing=false
    for _,r in ipairs(rows)do
     if r.kind=='gold'and r.session==v.session and r.window==request.window and r.amount==-q.cost and r.ts>=quote.at then wallet=r;wallets=wallets+1 end
     if r.kind=='spell'and r.subject==v.owner.id and r.observedEvent=='LEARNED_SPELL_IN_SKILL_LINE'and r.spellName==q.name and r.isGuildPerk~=true and r.ts>=quote.at then learned=r;learnings=learnings+1 end
     if r.kind=='money_evidence'and r.source=='training'and r.session==v.session and F.ValidTrainingMoneyProof(v.owner,r)then existing=true end
    end
    if wallets==1 and learnings==1 and not existing then matches=matches+1;selected={quote=quote,wallet=wallet,learned=learned}end
   end
   if matches==1 then
    local q,wallet,learned=selected.quote.service,selected.wallet,selected.learned
    F.Evidence(v.owner,request.ts,{title='Training / inferred: '..q.name,source='training',amount=-q.cost,session=v.session,
     trainingLearningVersion=1,trainerGUID=v.guid,trainerType=v.kind,service=E.Copy(q),quoteAt=selected.quote.at,
     requestedAt=request.ts,requestSequence=request.sequence,walletID=wallet.id,walletWindow=request.window,learnedID=learned.id,
     refs={wallet.id,request.window,learned.id}})
   end
  end
 end end
 -- Retain requests through the matching horizon so an overlapping request cannot
 -- become unique simply because its earlier neighbour was processed first.
 for i=#v.requests,1,-1 do if now-v.requests[i].ts>10 then table.remove(v.requests,i)end end
end
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)if old then old(...)end;fn(...)end end
wrap('TRAINER_SHOW',T.Open);wrap('TRAINER_UPDATE',T.Refresh);wrap('TRAINER_SERVICE_INFO_NAME_UPDATE',T.Refresh)
wrap('TRAINER_CLOSED',function()if T.visit then T.visit.closed=true end end)
wrap('PLAYER_LOGOUT',function()T.visit=nil end)

E.On('RECORD_ADDED',function(c,r)
 if r.kind=='spell'and r.notifications and r.notifications[1]and r.notifications[1].session then
  F.ReconcileEvidence(c,r.notifications[1].session,r.ts)
 end
end)
