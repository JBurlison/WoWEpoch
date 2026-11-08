local T,A,C,S,H,F,Q=E.TrainingMoney,E.API,E.Collectors,E.Store,E.History,E.Economy,E.Query
local saved={recordingGUID=E.recordingGUID,current=E.current,session=C.session,now=A.Now,visit=T.visit,hooked=T.hooked,lastAttempt=T.lastAttempt,
 walletObservationSuspended=E.walletObservationSuspended,walletObservationGeneration=E.walletObservationGeneration}
local names={'Enum','C_Trainer','UnitGUID','GetMoney','GetNumTrainerServices','GetTrainerServiceInfo','GetTrainerServiceCost','GetTrainerServiceTypeFilter','BuyTrainerService','hooksecurefunc','issecretvalue'}
for _,name in ipairs(names)do saved[name]=_G[name]end
Enum={TrainerType={General=0,Tradeskills=2,Pet=3,TalentsObsolete=1}}
local now=1793720000;A.Now=function()return now end
local hooks={};hooksecurefunc=function(name,fn)local old=hooks[name];hooks[name]=function(...)if old then old(...)end;fn(...)end end;BuyTrainerService=function()end;T.hooked=nil
local trainerKind,guid,cash,rows,readable=0,'Creature-Trainer-A',10000,{},true
local filters={};GetTrainerServiceTypeFilter=function(key)return filters[key]end
C_Trainer={GetTrainerType=function()return trainerKind end};UnitGUID=function(unit)if unit=='player' then return E.recordingGUID end;assert(unit=='npc');return guid end
GetMoney=function()return cash end;GetNumTrainerServices=function()return readable and #rows or nil end
GetTrainerServiceInfo=function(i)local r=rows[i];if readable and r then return r.name,r.state,123,r.level,r.subText,r.category end end
GetTrainerServiceCost=function(i)local r=rows[i];if readable and r then return r.cost,trainerKind==2 end end
local function event(name,...)return E.frame.scripts.OnEvent(E.frame,name,...)end
event('ADDON_LOADED','MyEpoch');assert(E.frame.events.TRAINER_SHOW and E.frame.events.TRAINER_CLOSED and E.frame.events.TRAINER_UPDATE)
local serial=0
local function setup(kind)
 serial=serial+1;now=1793720000+serial*100;trainerKind=kind or 0;guid='Creature-Trainer-A';cash=10000;readable=true;T.Reset()
 filters={available=true,unavailable=true,used=true}
 rows={{name='Test skill',state='available',level=10,subText='Rank 1',category=1,cost=250}}
 local c=S.Character('training-176-'..serial,{name='Synthetic training'});E.current=c;E.recordingGUID=c.id;C.session='trainer-'..serial
 event('PLAYER_ENTERING_WORLD') -- This fresh trainer session follows the integration fixture's logout.
 H.Wallet(c,now,cash,C.session);event('TRAINER_SHOW');return c
end
local function request(i)hooks.BuyTrainerService(i or 1)end
local function debit(c,amount)cash=cash+amount;event('PLAYER_MONEY');local list=Q.Kind(c,'gold');return list[#list]end
local function used(i)rows[i or 1].state='used';event('TRAINER_UPDATE')end
local function eq(a,b,label)assert(a==b,(label or'Training')..': '..tostring(a)..' ~= '..tostring(b))end
local c=setup();request();now=now+1;local w=debit(c,-250);eq(w.source,'unknown');used();eq(w.source,'training');eq(w.quality,'inferred')
local p=c.records[w.evidenceRefs[1]];assert(F.ValidTrainingMoneyProof(c,p));eq(p.service.name,'Test skill');eq(p.trainerType,'General')
eq(w.before,10000);eq(w.after,9750);eq(w.amount,-250)
event('TRAINER_UPDATE');eq(#Q.Kind(c,'money_evidence'),1)
w.starred=true;local protected=S.Protected(c);assert(protected[p.id]and protected[w.window]);w.starred=nil
-- Both wallet callback orders are allowed, with a later used-service observation.
c=setup(2);request();used();w=debit(c,-250);eq(w.source,'training');eq(c.records[w.evidenceRefs[1]].trainerType,'Tradeskills')
c=setup();w=debit(c,-250);request();used();eq(w.source,'training')
c=setup();request();w=debit(c,-250);used();F.Evidence(c,now,{source='repair',amount=-250,session=C.session});eq(w.source,'unknown')
c=setup();request();w=debit(c,-250);used();local duplicate=debit(c,-250);eq(w.source,'unknown');eq(duplicate.source,'unknown')
-- Pet points, unavailable identity/data, free and stale prices are not money evidence.
for _,kind in ipairs({1,3,99})do c=setup(kind);request();w=debit(c,-250);used();eq(w.source,'unknown')end
c=setup();guid=nil;request();w=debit(c,-250);used();eq(w.source,'unknown')
c=setup();rows[1].cost=500;request();w=debit(c,-250);used();eq(w.source,'unknown')
c=setup();rows[1].cost=0;event('TRAINER_UPDATE');request();w=debit(c,-250);used();eq(w.source,'unknown')
c=setup();rows[1].state='used';request();w=debit(c,-250);event('TRAINER_UPDATE');eq(w.source,'unknown','already used post-hook cannot prove this request succeeded')
c=setup();request();w=debit(c,-250);now=now+3;used();eq(w.source,'unknown','late used transition')
c=setup();request();w=debit(c,-250);C.session='other';used();eq(w.source,'unknown')
c=setup();request();w=debit(c,-250);guid='Creature-Trainer-B';used();eq(w.source,'unknown')
c=setup();request();w=debit(c,-250);now=now-1;used();eq(w.source,'unknown')
c=setup();request();w=debit(c,-250);readable=false;event('TRAINER_UPDATE');readable=true;used();eq(w.source,'unknown','unreadable intermediate snapshot cannot later qualify')
c=setup();issecretvalue=function(value)return value==250 end;request();issecretvalue=saved.issecretvalue;w=debit(c,-250);used();eq(w.source,'unknown')
-- Exact fingerprint and raw-index consistency; no invented spell ID association.
c=setup();rows[2]=E.Copy(rows[1]);event('TRAINER_UPDATE');request();w=debit(c,-250);used();eq(w.source,'unknown')
c=setup();rows[2]={name='Other',state='available',level=10,cost=300};event('TRAINER_UPDATE');request();w=debit(c,-250)
rows[1],rows[2]=rows[2],rows[1];used(2);eq(w.source,'unknown','reordered service rejected')
c=setup();request();w=debit(c,-250);rows[1].name='Changed';used();eq(w.source,'unknown')
c=setup();request();w=debit(c,-250);filters.unavailable=false;used();eq(w.source,'unknown','changed filters cannot manufacture uniqueness')
-- Overlapping requests may produce aggregate wallet changes: no arbitrary subset match.
c=setup();rows[1].cost=100;rows[2]={name='Second',state='available',level=10,cost=200};rows[3]={name='Third',state='available',level=10,cost=300};event('TRAINER_UPDATE')
request(1);request(2);request(3);w=debit(c,-300);for _,r in ipairs(rows)do r.state='used'end;event('TRAINER_UPDATE');eq(w.source,'unknown','100+200 aggregate cannot masquerade as 300 service')
c=setup();request();w=debit(c,-250);used();request();TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','overlap withdraws prior inferred proof')
c=setup();request();w=debit(c,-250);used();event('TRAINER_CLOSED');request(999);TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','closed-visit request withdraws earlier proof')
c=setup();request();w=debit(c,-250);now=now-1;request(999);now=now+1;used();eq(w.source,'unknown','rollback request cannot preserve pending match')
c=setup();request();event('TRAINER_CLOSED');event('TRAINER_SHOW');request();w=debit(c,-250);used();eq(w.source,'unknown','reopen cannot reset unresolved request')
now=now+3;rows[1].state='available';event('TRAINER_SHOW');request();w=debit(c,-250);used();eq(w.source,'training','later fresh visit can qualify')
c=setup();guid=nil;event('TRAINER_SHOW');assert(not T.visit);request(999);guid='Creature-Trainer-A';event('TRAINER_SHOW');request();w=debit(c,-250);used()
eq(w.source,'unknown','unidentifiable hook cannot be forgotten across a fresh visit')
now=now+3;rows[1].state='available';event('TRAINER_SHOW');request();w=debit(c,-250);used();eq(w.source,'training','later visit recovers after unknown attempt horizon')
c=setup();request();local firstRequestAt=now;now=now-10;request(999);now=firstRequestAt;event('TRAINER_SHOW');request();w=debit(c,-250);used()
eq(w.source,'unknown','rollback cannot shorten an earlier attempt horizon')
now=now+3;rows[1].state='available';event('TRAINER_SHOW');request();w=debit(c,-250);used();eq(w.source,'training','later open clears the high-water horizon')
-- Retained correction/reversal and strict private-reader parity.
c=setup();request();w=debit(c,-250);used();p=c.records[w.evidenceRefs[1]];local original=E.Copy(p)
local function corrupt(key,value)
 p[key]=value;S.Changed(c,p);TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','corrected '..key)
 p[key]=E.Copy(original[key]);S.Changed(c,p);TEST_PREPARE_HISTORY(c);eq(w.source,'training','restored '..key)
 eq(w.amount,-250);eq(w.before,10000);eq(w.after,9750)
end
corrupt('trainerType','Pet');corrupt('usedTrainerGUID','different');corrupt('requestQuotedCost',500);corrupt('initialServiceType','used')
corrupt('requestServiceType','used');corrupt('uniqueService',false);corrupt('usedService',{name='Other',level=10})
corrupt('serviceIndex',2);corrupt('requestIndex',2);corrupt('usedIndex',2)
corrupt('usedFilters',{available=true,unavailable=false,used=true})
corrupt('usedAt',p.ts+3);corrupt('quoteSequence',p.requestSequence);corrupt('walletWindow','other');corrupt('character','other')
local win=c.records[w.window];local ended=win.ended;win.ended=w.ts-1;S.Changed(c,win);TEST_PREPARE_HISTORY(c);eq(w.source,'unknown')
win.ended=ended;S.Changed(c,win);TEST_PREPARE_HISTORY(c);eq(w.source,'training')
assert(E.AuctionWalletReads.Certified())
local shadow=setmetatable({db=E.Copy(E.db),On=function()end,Emit=function()error('private writer')end,Collectors=setmetatable({handlers={}},{__index=C})},{__index=E})
for _,factory in ipairs(E.AuctionReaderFactories)do factory.create(shadow)end
local sc=shadow.db.characters[c.id];assert(shadow.Economy.ValidTrainingMoneyProof(sc,sc.records[p.id]));sc.records[p.id].usedService.name='Changed'
assert(not shadow.Economy.ValidTrainingMoneyProof(sc,sc.records[p.id]));assert(F.ValidTrainingMoneyProof(c,p))
F.Attribute(c,w.id,'training','confirmed',{p.id},false);p.quotedCost=999;S.Changed(c,p);TEST_PREPARE_HISTORY(c);eq(w.source,'training');eq(w.quality,'confirmed')
for _,name in ipairs(names)do _G[name]=saved[name]end
E.recordingGUID=saved.recordingGUID
E.current,C.session,A.Now=saved.current,saved.session,saved.now;T.visit,T.hooked,T.lastAttempt=saved.visit,saved.hooked,saved.lastAttempt
E.walletObservationSuspended,E.walletObservationGeneration=saved.walletObservationSuspended,saved.walletObservationGeneration
print('PASS training: actual trainer dispatch, fresh quotes/used transition, type and identity gates, overlapping and aggregate requests, corrections, private readers and raw balances')
