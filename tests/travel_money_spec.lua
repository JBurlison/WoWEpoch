local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local T,A,C,F,S,H,Q=E.TravelMoney,E.API,E.Collectors,E.Economy,E.Store,E.History,E.Query
local saved={current=E.current,session=C.session,now=A.Now,hooked=T.hooked,map=T.map,pending=T.pending,lastAttempt=T.lastAttempt}
local globals={'hooksecurefunc','TakeTaxiNode','GetMoney','NumTaxiNodes','TaxiNodeGetType','TaxiNodeCost','TaxiNodeName','UnitOnTaxi','issecretvalue'}
for _,k in ipairs(globals)do saved[k]=_G[k]end
local now=1793720000;A.Now=function()return now end
local hooks={};hooksecurefunc=function(name,fn)hooks[name]=fn end;T.hooked=nil
TakeTaxiNode=function()end;local cash=10000;GetMoney=function()return cash end
local price=250;local readable=true;local nodeType='REACHABLE';local destination='Crossroads';local flying=false
NumTaxiNodes=function()if readable then return 2 end end
TaxiNodeGetType=function(i)return i==1 and nodeType or'CURRENT'end
TaxiNodeCost=function()return price end;TaxiNodeName=function()return destination end
UnitOnTaxi=function()return flying end
local function event(name,...)return E.frame.scripts.OnEvent(E.frame,name,...)end
local function frame()return E.frame.scripts.OnUpdate(E.frame,0)end
event('ADDON_LOADED','MyEpoch')
assert(E.frame.events.TAXIMAP_OPENED and E.frame.events.TAXIMAP_CLOSED and E.frame.events.TAXI_NODE_STATUS_CHANGED,'actual Bootstrap registered the collector handlers')
local seq=0
local function setup()
 seq=seq+1;now=1793720000+seq*100;cash=10000;flying=false;price=250;readable=true;nodeType='REACHABLE';destination='Crossroads';T.Reset()
 local c=S.Character('travel-173-'..seq,{name='Synthetic travel'});bindWallet(c,'flight-'..seq)
 H.Wallet(c,now,cash,C.session);event('TAXIMAP_OPENED',0);assert(hooks.TakeTaxiNode)
 return c
end
local function spend(c,amount)cash=cash+amount;event('PLAYER_MONEY');return Q.Kind(c,'gold')[#Q.Kind(c,'gold')]end
local function request(index)hooks.TakeTaxiNode(index or 1)end
local function eq(a,b,label)assert(a==b,(label or'Travel')..': '..tostring(a)..' ~= '..tostring(b))end
local c=setup();request();now=now+1;local w=spend(c,-250);flying=true;frame()
eq(w.source,'travel');eq(w.quality,'inferred');eq(w.amount,-250);eq(w.before,10000);eq(w.after,9750)
local proof=c.records[w.evidenceRefs[1]];eq(proof.walletWindow,w.window);eq(proof.quotedCost,250);eq(proof.destination,'Crossroads');assert(F.ValidTravelMoneyProof(c,proof))
frame();eq(#Q.Kind(c,'money_evidence'),1,'one source proof per request')
w.starred=true;local keep=S.Protected(c);assert(keep[proof.id]and keep[w.window]);w.starred=nil
F.Evidence(c,now,{source='repair',amount=-250,session=C.session},'competing');eq(w.source,'unknown');eq(w.amount,-250)
c=setup();request();flying=true;frame();now=now+1;w=spend(c,-250);eq(w.source,'travel','flight before wallet')
c=setup();w=spend(c,-250);request();flying=true;frame();eq(w.source,'travel','wallet callback inside request may precede post-hook')
c=setup();request();w=spend(c,-250);flying=true;frame();local duplicate=spend(c,-250)
eq(w.source,'unknown');eq(duplicate.source,'unknown','one flight cannot claim two equal wallet debits')

-- Fresh post-hook data must agree with the prior observed UI quote.
c=setup();for i=1,6 do now=now+5;H.Wallet(c,now,cash,C.session)end
price=500;request();now=now+1;w=spend(c,-250);flying=true;frame();eq(w.source,'unknown','31-second stale fare cannot identify another debit');eq(#Q.Kind(c,'money_evidence'),0)
c=setup();price=500;event('TAXI_NODE_STATUS_CHANGED');request();w=spend(c,-500);flying=true;frame();eq(w.source,'travel','idle status update resamples the quote')
c=setup();price=500;event('TAXI_NODE_STATUS_CHANGED');request();w=spend(c,-250);flying=true;frame();eq(w.source,'unknown')
c=setup();nodeType='UNREACHABLE';event('TAXI_NODE_STATUS_CHANGED');request();w=spend(c,-250);flying=true;frame();eq(w.source,'unknown')
c=setup();destination='Changed destination';request();w=spend(c,-250);flying=true;frame();eq(w.source,'unknown','slot identity change rejected')
c=setup();event('TAXIMAP_CLOSED');readable=false;request();w=spend(c,-250);flying=true;frame();eq(w.source,'unknown','closed-map unavailable data never uses cached quote')
c=setup();request();w=spend(c,-250);event('TAXI_NODE_STATUS_CHANGED');flying=true;frame();eq(w.source,'unknown','status change after request withdraws pending source')
c=setup();request();w=spend(c,-250);flying=true;frame();event('TAXI_NODE_STATUS_CHANGED');eq(w.source,'unknown','status change withdraws emitted source too')

-- Any repeated request from the observed map is ambiguous, even an unquoted index.
c=setup();request();flying=true;frame();w=spend(c,-250);eq(w.source,'travel');request(2);eq(w.source,'unknown');eq(T.map.proof.quotedCost,250)
c=setup();request();request();now=now+1;w=spend(c,-250);flying=true;frame();eq(w.source,'unknown');eq(#Q.Kind(c,'money_evidence'),0)
c=setup();request();event('TAXIMAP_OPENED',0);w=spend(c,-250);flying=true;frame();eq(w.source,'unknown','repeated open does not reset request ambiguity')
c=setup();request();event('TAXIMAP_CLOSED');destination='Ratchet';event('TAXIMAP_OPENED',0);request();w=spend(c,-250);flying=true;frame()
eq(w.source,'unknown','close/open cannot assign an unresolved prior debit to a new destination')
c=setup();request();w=spend(c,-250);flying=true;frame();eq(w.source,'travel');flying=false;event('TAXIMAP_CLOSED');event('TAXIMAP_OPENED',0)
TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','overlap withdraws a previously emitted source')
c=setup();request();event('TAXIMAP_CLOSED');now=now-1;event('TAXIMAP_OPENED',0);request();now=now+1;w=spend(c,-250);flying=true;frame();eq(w.source,'unknown','clock rollback cannot reset request epoch')
c=setup();request();event('TAXIMAP_CLOSED');now=now+2;event('TAXIMAP_OPENED',0);now=now+1;frame();request();w=spend(c,-250);flying=true;frame()
eq(w.source,'unknown','blocked map does not become eligible when pending expires')
c=setup();request();event('TAXIMAP_CLOSED');now=now+3;frame();destination='Ratchet';event('TAXIMAP_OPENED',0);request();w=spend(c,-250);flying=true;frame()
eq(w.source,'travel','a fresh later open after the old matching horizon can qualify');eq(T.map.proof.destination,'Ratchet')
c=setup();request(2);event('TAXIMAP_CLOSED');event('TAXIMAP_OPENED',0);request();w=spend(c,-250);flying=true;frame()
eq(w.source,'unknown','an unquoted request also reserves its ambiguity horizon')
c=setup();request();event('TAXIMAP_CLOSED');local firstAttemptAt=now;now=now-10;request(999);now=firstAttemptAt;event('TAXIMAP_OPENED',0);request();w=spend(c,-250);flying=true;frame()
eq(w.source,'unknown','rollback cannot shorten flight attempt horizon')
c=setup();readable=false;event('TAXIMAP_OPENED',0);assert(not T.map);request(999);readable=true;event('TAXIMAP_OPENED',0);request();w=spend(c,-250);flying=true;frame()
eq(w.source,'unknown','unidentifiable flight attempt cannot be forgotten')
now=now+3;flying=false;event('TAXIMAP_OPENED',0);request();w=spend(c,-250);flying=true;frame();eq(w.source,'travel','later fresh flight map recovers')

-- Preserve all original negatives and same-window behavior.
c=setup();request();now=now+1;w=spend(c,-250);frame();eq(w.source,'unknown');eq(#Q.Kind(c,'money_evidence'),0)
now=now+3;flying=true;frame();eq(#Q.Kind(c,'money_evidence'),0)
c=setup();request();now=now+1;w=spend(c,-249);flying=true;frame();eq(w.source,'unknown')
c=setup();request();C.session='other';flying=true;frame();eq(#Q.Kind(c,'money_evidence'),0)
c=setup();request();E.current=S.Character('other-travel-owner',{});flying=true;frame();eq(#Q.Kind(c,'money_evidence'),0)
c=setup();request();now=now-1;flying=true;frame();eq(#Q.Kind(c,'money_evidence'),0)
c=setup();request();event('TAXIMAP_CLOSED');now=now+1;w=spend(c,-250);flying=true;frame();eq(w.source,'travel')
c=setup();event('TAXIMAP_CLOSED');now=now+2;request();w=spend(c,-250);flying=true;frame();eq(w.source,'unknown')
c=setup();request();now=now+1;c.state.wallet=nil;H.Wallet(c,now,cash,C.session);w=spend(c,-250);flying=true;frame();eq(w.source,'unknown')
c=setup();price=0;event('TAXIMAP_OPENED',0);request();flying=true;frame();eq(#Q.Kind(c,'money_evidence'),0)
c=setup();TaxiNodeCost=function()error('unavailable')end;request();w=spend(c,-250);flying=true;frame();eq(w.source,'unknown');TaxiNodeCost=function()return price end
c=setup();flying=true;event('TAXIMAP_OPENED',0);request();w=spend(c,-250);frame();eq(w.source,'unknown')
c=setup();issecretvalue=function(value)return value==price end;request();issecretvalue=saved.issecretvalue;w=spend(c,-250);flying=true;frame();eq(w.source,'unknown')

-- Historical source-field corrections/reversion run through retained GoldChecks.
c=setup();request();now=now+1;w=spend(c,-250);flying=true;frame();proof=T.map.proof
local original=E.Copy(proof);local before,after,amount=w.before,w.after,w.amount
local function corrupt(key,value)
 proof[key]=value;S.Changed(c,proof);TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','corrected '..key..' invalidates')
 proof[key]=E.Copy(original[key]);S.Changed(c,proof);TEST_PREPARE_HISTORY(c);eq(w.source,'travel','restored '..key..' is revalidated')
 eq(w.before,before);eq(w.after,after);eq(w.amount,amount)
end
corrupt('quotedCost',500);corrupt('uiQuotedCost',500);corrupt('requestQuotedCost',500)
corrupt('flightObservedAt',proof.ts+60);corrupt('flightObservedAt',proof.ts-1)
corrupt('fareQuotedAt',proof.ts+1);corrupt('requestQuotedAt',proof.ts+1)
corrupt('walletWindow','other');corrupt('requestWalletWindow','other');corrupt('flightWalletWindow','other')
corrupt('requestObservedSequence',proof.flightObservedSequence);corrupt('flightObservedSequence',proof.requestObservedSequence)
corrupt('uiQuoteSequence',proof.requestObservedSequence);corrupt('uiNodeType','UNREACHABLE');corrupt('requestNodeType','UNREACHABLE')
corrupt('destination','Changed');corrupt('initialOffTaxi',false);corrupt('flightObserved',false);corrupt('withdrawnReason','Corrected source')
corrupt('character','another-owner');corrupt('session','another-session')

assert(E.AuctionWalletReads.Certified())
local shadow=setmetatable({db=E.Copy(E.db),On=function()end,Emit=function()error('private writer')end,Collectors=setmetatable({handlers={}},{__index=C})},{__index=E})
for _,factory in ipairs(E.AuctionReaderFactories)do factory.create(shadow)end
local sc=shadow.db.characters[c.id];assert(shadow.Economy.ValidTravelMoneyProof(sc,sc.records[proof.id]));sc.records[proof.id].quotedCost=500
assert(not shadow.Economy.ValidTravelMoneyProof(sc,sc.records[proof.id]));assert(F.ValidTravelMoneyProof(c,proof))
for _,quality in ipairs({'confirmed','inferred'})do
 c=setup();request();w=spend(c,-250);flying=true;frame();proof=T.map.proof
 F.Attribute(c,w.id,'travel',quality,{proof.id},false);proof.quotedCost=500;S.Changed(c,proof);TEST_PREPARE_HISTORY(c)
 eq(w.source,'travel');eq(w.quality,quality);eq(w.automaticAttribution,false,'explicit classification is preserved')
end

-- Legacy generic proof semantics and optional window restrictions remain intact.
c=setup();now=now+1;w=spend(c,-250)
local p=F.Evidence(c,now,{source='travel',amount=-250,session=C.session,walletWindow='different'})
eq(w.source,'unknown');F.CheckWallet(c,w);eq(w.source,'unknown')
w.source='travel';w.quality='inferred';w.automaticAttribution=true;w.evidenceRefs={p.id};c.state.goldSourceReviewVersion=4
E.GoldChecks.Ensure(c);TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','older completed review rechecks optional window restrictions');eq(c.state.goldSourceReviewVersion,5)
p.walletWindow=w.window;S.Changed(c,p);F.ReconcileEvidence(c,C.session,now,p);eq(w.source,'travel')
p.walletWindow=nil;S.Changed(c,p);F.ReconcileEvidence(c,C.session,now,p);eq(w.source,'travel','legacy evidence without version or window retains its former semantics')
for _,k in ipairs(globals)do _G[k]=saved[k]end
E.current,C.session,A.Now=saved.current,saved.session,saved.now;T.hooked,T.map,T.pending,T.lastAttempt=saved.hooked,saved.map,saved.pending,saved.lastAttempt
print('PASS travel173: actual Bootstrap event/OnUpdate wiring, fresh request-time quote equality, status refresh/invalidation, source corrections, retained negatives, private readers, legacy proofs and raw-wallet immutability')

restoreWallet()
