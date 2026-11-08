local _,E=...
local T,A,C,F,S={},E.API,E.Collectors,E.Economy,E.Store;E.TravelMoney=T
local function integer(v)
 v=A.Plain(v);return type(v)=='number'and v==v and v%1==0 and v>=0 and v<=9007199254740991 and v or nil
end
local function current(m)
 return m and E.current==m.owner and E.db.characters[m.owner.id]==m.owner and C.session==m.session
end
local function withdraw(m,reason)
 if T.pending and T.pending.map==m then T.pending=nil end
 if m and m.proof and m.owner.records[m.proof.id]==m.proof and not m.proof.withdrawnReason then
  m.proof.amount=0;m.proof.withdrawnReason=reason;S.Changed(m.owner,m.proof)
  F.ReconcileEvidence(m.owner,m.session,m.proof.ts,m.proof)
 end
 if m then m.invalid=reason end
end
local function quote(index)
 if A.Call('travelType',TaxiNodeGetType,index)~='REACHABLE'then return end
 local cost=integer(A.Call('travelFare',TaxiNodeCost,index));local name=A.Call('travelDestination',TaxiNodeName,index)
 if not cost or cost<=0 or type(name)~='string'or name==''or #name>1024 then return end
 return {cost=cost,name=name,type='REACHABLE'}
end
local function sample(m)
 local now=A.Now()
 if not current(m)or m.closed or now<m.opened or A.Call('travelInitialState',UnitOnTaxi,'player')~=false then return false end
 local count=integer(A.Call('travelNodes',NumTaxiNodes));if not count or count>2000 then return false end
 local quotes={};for index=1,count do quotes[index]=quote(index)end
 m.quotes=quotes;m.quotedAt=now;m.quoteSequence=S.ReserveObservation(m.owner)
 return true
end
function T.Reset()T.map=nil;T.pending=nil;T.lastAttempt=nil end
function T.Attempt(index)
 local m=T.map;local now=A.Now()
 local c=E.current
 if c and E.db.characters[c.id]==c and C.session then
  local prior=current(T.lastAttempt)and T.lastAttempt.ts or now
  T.lastAttempt={owner=c,session=C.session,ts=math.max(prior,now)}
 end
 if not current(m)then return end
 local prior=m.attemptedAt;m.attemptedAt=math.max(prior or now,now)
 if m.used or prior then withdraw(m,'More than one request was observed for this flight map.');return end
 index=integer(index)
 if m.invalid or not index or not m.quotes[index]or now<m.quotedAt or(m.closed and(now<m.closed or now-m.closed>1))
  or m.owner.state.walletWindow~=m.window then return end
 -- A post-hook is not a success notification. The map data must still be
 -- readable after the call; never substitute the open-time cached fare.
 local count=integer(A.Call('travelRequestNodes',NumTaxiNodes))
 local fresh=count and count<=2000 and index>=1 and index<=count and quote(index)
 local displayed=m.quotes[index]
 if not fresh or fresh.cost~=displayed.cost or fresh.name~=displayed.name then
  withdraw(m,'Request-time fare or destination was unavailable or differed from the observed map.');return
 end
 m.used=true
 T.pending={map=m,requestedAt=now,requestSequence=S.ReserveObservation(m.owner),index=index,cost=fresh.cost,
  name=fresh.name,window=m.window,quotedAt=m.quotedAt,quoteSequence=m.quoteSequence}
end
function T.InstallHooks()
 if T.hooked then return end
 if type(hooksecurefunc)~='function'or type(TakeTaxiNode)~='function'then A.status.travelMoney='Flight request hook unavailable';return end
 local ok=pcall(hooksecurefunc,'TakeTaxiNode',function(index)
  if E.RecorderReady() then T.Attempt(index) end
 end)
 if ok then T.hooked=true else A.status.travelMoney='Flight request hook unavailable'end
end
function T.Open()
 -- Close/open events cannot resolve a request that is still in its matching
 -- horizon. Keep the blocked map until a later open; never auto-enable it.
 local prior=T.map;local now=A.Now()
 if current(T.lastAttempt)and now<=T.lastAttempt.ts+2 or current(prior)and prior.attemptedAt and not prior.closed then
  if current(prior)then withdraw(prior,'Flight map reopened before the previous request could be distinguished.')end
  return
 end
 T.Reset();T.InstallHooks();local c=E.current
 if not c or not C.session or not T.hooked then return end
 if A.Call('travelInitialState',UnitOnTaxi,'player')~=false then return end
 local wallet=integer(A.Wallet('travelWallet'));if not wallet then return end
 E.History.Wallet(c,now,wallet,C.session)
 local m={owner=c,session=C.session,opened=now,window=c.state.walletWindow,quotes={}}
 if not sample(m)then A.status.travelMoney='Flight map quote unavailable';return end
 T.map=m
end
function T.Close()if T.map then T.map.closed=A.Now()end end
function T.StatusChanged()
 local m=T.map;if not current(m)then return end
 if m.used then withdraw(m,'Flight-map status changed during the request.');return end
 -- This event is not a receipt. It can refresh a still-idle map, or make its
 -- cached quotes unusable when the current state cannot be sampled.
 if not sample(m)then withdraw(m,'Updated flight-map quotes unavailable.')end
end
function T.Tick()
 local p=T.pending;if not p then return end
 local m=p.map;local now=A.Now()
 if not current(m)or m.invalid or now<p.requestedAt or now-p.requestedAt>2 or m.owner.state.walletWindow~=p.window then
  T.pending=nil;return
 end
 if A.Call('travelInFlight',UnitOnTaxi,'player')~=true then return end
 local flightSequence=S.ReserveObservation(m.owner);T.pending=nil
 m.proof=F.Evidence(m.owner,p.requestedAt,{source='travel',amount=-p.cost,session=m.session,
  title='Flight fare / inferred'..': '..p.name,travelMoneyVersion=1,observationType='flight_fare',
  initialOffTaxi=true,initialStateAt=m.opened,uiNodeType='REACHABLE',requestNodeType='REACHABLE',
  fareQuotedAt=p.quotedAt,uiQuoteSequence=p.quoteSequence,uiQuotedCost=p.cost,uiTaxiNode=p.index,uiDestination=p.name,
  requestedAt=p.requestedAt,requestQuotedAt=p.requestedAt,requestObservedSequence=p.requestSequence,requestQuotedCost=p.cost,
  flightObservedAt=now,flightObservedSequence=flightSequence,flightObserved=true,
  taxiNode=p.index,destination=p.name,quotedCost=p.cost,walletWindow=p.window,requestWalletWindow=p.window,flightWalletWindow=p.window,refs={p.window},
  evidenceNote='Inferred from matching map/request-time fares and a subsequent in-flight observation; not a purchase confirmation.'})
end
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)if old then old(...)end;fn(...)end end
wrap('TAXIMAP_OPENED',T.Open);wrap('TAXIMAP_CLOSED',T.Close);wrap('TAXI_NODE_STATUS_CHANGED',T.StatusChanged);wrap('PLAYER_LOGOUT',T.Reset)
