local _,E=...
local T,A,C,S,F={},E.API,E.Collectors,E.Store,E.Economy;E.TrainingMoney=T
local function integer(v)return type(v)=='number'and v==v and v>=0 and v<=9007199254740991 and v%1==0 and v end
local function current(v)return v and E.current==v.owner and E.db.characters[v.owner.id]==v.owner and C.session==v.session end
local function trainer()
 local kind=A.Call('trainingType',C_Trainer and C_Trainer.GetTrainerType)
 local enum=Enum and Enum.TrainerType;local label
 if enum and enum.General~=nil and kind==enum.General then label='General'
 elseif enum and enum.Tradeskills~=nil and kind==enum.Tradeskills then label='Tradeskills'end
 if not label then return end
 local guid=A.Call('trainingNPC',UnitGUID,'npc')
 if type(guid)=='string'and guid~=''then return guid,label end
end
local function snapshot(v)
 local guid,kind=trainer();if guid~=v.guid or kind~=v.kind then return end
 local count=integer(A.Call('trainingCount',GetNumTrainerServices));if not count or count>2000 then return end
 local rows={filters={}}
 for _,key in ipairs({'available','unavailable','used'})do
  local value=A.Call('trainingFilter',GetTrainerServiceTypeFilter,key);if type(value)~='boolean'then return end
  rows.filters[key]=value
 end
 for i=1,count do
  local name,state,_,level,subText,category=A.Call('trainingInfo',GetTrainerServiceInfo,i)
  if A.status.trainingInfo=='restricted values omitted'or type(name)~='string'or name==''or #name>1024
   or not integer(level)or(subText~=nil and(type(subText)~='string'or #subText>1024))
   or(category~=nil and type(category)~='string'and not integer(category))
   or(state~='available'and state~='used'and state~='unavailable')then return end
  local cost=integer(A.Call('trainingCost',GetTrainerServiceCost,i))
  rows[i]={identity={name=name,subText=subText,level=level,category=category},state=state,cost=cost,index=i}
 end
 return rows
end
local function unique(rows,identity)
 local found
 for _,row in ipairs(rows)do if E.Same(row.identity,identity)then if found then return end;found=row end end
 return found
end
local function withdraw(v,r,why)
 r.invalid=why
 if r.proof and v.owner.records[r.proof.id]==r.proof and not r.proof.withdrawnReason then
  r.proof.amount=0;r.proof.withdrawnReason=why;S.Changed(v.owner,r.proof);F.ReconcileEvidence(v.owner,v.session,r.proof.ts,r.proof)
 end
end
local function block(v,why)
 for _,r in ipairs(v.requests)do withdraw(v,r,why)end
 v.invalid=why
end
local function observe(v,r,rows,now)
 if r.invalid or now<r.requestedAt or now-r.requestedAt>2 then return end
 if not E.Same(rows.filters,r.filters)then withdraw(v,r,'Trainer filters changed during the request.');return end
 local row=unique(rows,r.identity)
 if not row or row.index~=r.index then withdraw(v,r,'Requested service became hidden, ambiguous or reordered.');return end
 if row.state~='used'then if r.proof then withdraw(v,r,'The observed service was no longer marked used.')end;return end
 if r.proof then return end
 local usedSequence=S.ReserveObservation(v.owner)
 r.proof=F.Evidence(v.owner,r.requestedAt,{title='Training / inferred: '..r.identity.name,source='training',amount=-r.cost,session=v.session,
  trainingMoneyVersion=1,observationType='trainer_service',trainerType=v.kind,trainerGUID=v.guid,requestTrainerGUID=v.guid,usedTrainerGUID=v.guid,
  service=E.Copy(r.identity),requestService=E.Copy(r.identity),usedService=E.Copy(row.identity),uniqueService=true,
  filters=E.Copy(r.filters),requestFilters=E.Copy(r.filters),usedFilters=E.Copy(rows.filters),
  initialServiceType='available',requestServiceType=r.requestState,usedServiceType='used',serviceIndex=r.index,requestIndex=r.index,usedIndex=row.index,
  quotedCost=r.cost,requestQuotedCost=r.cost,quoteAt=r.quoteAt,quoteSequence=r.quoteSequence,
  requestedAt=r.requestedAt,requestSequence=r.requestSequence,usedAt=now,usedSequence=usedSequence,
  walletWindow=v.window,refs={v.window},evidenceNote='Inferred from matching trainer quotes, an observed used-service transition and wallet debit; no spell-ID association.'})
end
local function prune(v,now)
 for i=#v.requests,1,-1 do if now-v.requests[i].requestedAt>2 then table.remove(v.requests,i)end end
end
local function refresh(v,rows,now)
 for _,r in ipairs(v.requests)do observe(v,r,rows,now)end
 v.rows=rows;v.quoteAt=now;v.quoteSequence=S.ReserveObservation(v.owner)
end
function T.Reset()T.visit=nil;T.lastAttempt=nil end
function T.Attempt(index)
 local v=T.visit;local now=A.Now();local c=E.current
 if c and E.db.characters[c.id]==c and C.session then
  local prior=current(T.lastAttempt)and T.lastAttempt.ts or now
  T.lastAttempt={owner=c,session=C.session,ts=math.max(prior,now)}
 end
 if not current(v)then return end
 v.lastAttempt=now
 if v.invalid then return end
 if v.closed or now<v.quoteAt or v.owner.state.walletWindow~=v.window then
  block(v,'A request was observed after trainer observation continuity changed.');return
 end
 prune(v,now)
 if #v.requests>=64 then block(v,'Too many overlapping trainer requests.');return end
 if #v.requests>0 then
  for _,r in ipairs(v.requests)do withdraw(v,r,'Overlapping trainer requests cannot be separated from aggregate wallet changes.')end
  v.requests[#v.requests+1]={requestedAt=now,invalid='Overlapping trainer request'};return
 end
 index=integer(A.Plain(index));local initial=index and v.rows[index]
 if not initial or initial.state~='available'or not initial.cost or initial.cost<=0 or not unique(v.rows,initial.identity)then
  v.requests[#v.requests+1]={requestedAt=now,invalid='Request did not identify a unique available quoted service'};return
 end
 local rows=snapshot(v);local row=rows and rows[index]
 if not row or not unique(rows,initial.identity)or not E.Same(row.identity,initial.identity)or row.cost~=initial.cost or not E.Same(rows.filters,v.rows.filters)
  or row.state~='available'then block(v,'Request-time service identity, availability or quote was unavailable or changed.');return end
 local r={identity=E.Copy(initial.identity),filters=E.Copy(rows.filters),index=index,cost=row.cost,quoteAt=v.quoteAt,quoteSequence=v.quoteSequence,
  requestState=row.state,requestedAt=now,requestSequence=S.ReserveObservation(v.owner)}
 v.requests[#v.requests+1]=r;refresh(v,rows,now)
end
function T.InstallHooks()
 if T.hooked then return end
 if type(hooksecurefunc)~='function'or type(BuyTrainerService)~='function'then A.status.trainingMoney='Trainer request hook unavailable';return end
 local ok=pcall(hooksecurefunc,'BuyTrainerService',function(index)
  if E.RecorderReady() then T.Attempt(index) end
 end);T.hooked=ok or nil
end
function T.Open()
 local prior=T.visit;local now=A.Now()
 if current(T.lastAttempt)and now<=T.lastAttempt.ts+2 then
  if current(prior)then block(prior,'Trainer reopened during an unresolved request.')else T.visit=nil end
  return
 end
 T.Reset();T.InstallHooks();if not E.current or not C.session or not T.hooked then return end
 local guid,kind=trainer();local cash=integer(A.Call('trainingWallet',GetMoney));if not guid or not cash then return end
 E.History.Wallet(E.current,now,cash,C.session)
 local v={owner=E.current,session=C.session,guid=guid,kind=kind,window=E.current.state.walletWindow,requests={}}
 local rows=snapshot(v);if not rows then return end
 T.visit=v;refresh(v,rows,now)
end
function T.Close()local v=T.visit;if v then v.closed=true end end
function T.Update()
 local v=T.visit;local now=A.Now();if not current(v)or v.invalid or v.closed then return end
 if now<v.quoteAt or v.owner.state.walletWindow~=v.window then block(v,'Trainer observation continuity changed.');return end
 prune(v,now);local rows=snapshot(v)
 if not rows then block(v,'Trainer identity or service data became unavailable.');return end
 refresh(v,rows,now)
end
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)if old then old(...)end;fn(...)end end
wrap('TRAINER_SHOW',T.Open);wrap('TRAINER_CLOSED',T.Close);wrap('TRAINER_UPDATE',T.Update)
wrap('TRAINER_SERVICE_INFO_NAME_UPDATE',T.Update);wrap('PLAYER_LOGOUT',T.Reset)
wrap('TRAINER_DESCRIPTION_UPDATE',T.Update)
