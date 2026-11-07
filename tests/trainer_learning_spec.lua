local T,A,C,S,H,F,Q=E.TrainerLearning,E.API,E.Collectors,E.Store,E.History,E.Economy,E.Query
local savedNow=A.Now
local now,cash,rows,kind,guid=1793900000,1000,{},0,'Creature-Trainer'
A.Now=function()return now end
Enum={TrainerType={General=0,Tradeskills=2,Pet=3}}
C_Trainer={GetTrainerType=function()return kind end}
UnitGUID=function(unit)return unit=='npc'and guid or E.recordingGUID end
GetNumTrainerServices=function()return #rows end
GetTrainerServiceInfo=function(i)local r=rows[i];if r then return r.name,r.state,1,1,r.rank,1 end end
GetTrainerServiceCost=function(i)return rows[i]and rows[i].cost end
GetMoney=function()return cash end
local hooks={};BuyTrainerService=function()end
hooksecurefunc=function(name,fn)local old=hooks[name];hooks[name]=function(...)if old then old(...)end;fn(...)end end
T.hooked=nil
local serial=0
local function setup(trainerKind)
 serial=serial+1;now=1793900000+serial*100;cash=1000;kind=trainerKind or 0;guid='Creature-Trainer'
 rows={{name='A useful lesson',state='available',cost=200}}
 local c=S.Character('trainer-learning-'..serial,{name='Apprentice'});E.current=c;E.recordingGUID=c.id;C.session='learning-'..serial
 H.Wallet(c,now,cash,C.session);T.Open();return c
end
local function learn(c,name)
 return S.Add(c,'spell',now,{subject=c.id,spellID=123,spellName=name or 'A useful lesson',observedEvent='LEARNED_SPELL_IN_SKILL_LINE',notifications={{session=C.session,ts=now}}})
end
local function debit(c,amount)cash=cash-(amount or 200);return H.Wallet(c,now,cash,C.session)end
local function settle()now=now+4;T.Tick();TEST_PREPARE_HISTORY(E.current)end
local function request()hooks.BuyTrainerService(1)end
-- A recipe disappears and its successor takes the index before the secure post-hook.
local c=setup(2);rows={{name='The next recipe',state='available',cost=500}};T.Refresh();request();local l=learn(c);local w=debit(c);settle()
assert(w.source=='training'and w.quality=='inferred')
local p=c.records[w.evidenceRefs[1]];assert(F.ValidTrainingLearningProof(c,p)and p.learnedID==l.id and p.walletID==w.id)
-- Source corrections revoke automatic attribution; restoring evidence restores it.
l.spellName='Different';S.Changed(c,l);TEST_PREPARE_HISTORY(c);assert(w.source=='unknown')
l.spellName='A useful lesson';S.Changed(c,l);TEST_PREPARE_HISTORY(c);assert(w.source=='training')
assert(w.amount==-200 and w.after==800)
-- A later competing observation with the same original timestamp revokes uniqueness.
local ts=l.ts;local duplicate=S.Add(c,'spell',ts,{subject=c.id,spellName=l.spellName,observedEvent=l.observedEvent,notifications={{session=C.session,ts=ts}}})
TEST_PREPARE_HISTORY(c);assert(w.source=='unknown')

-- Synchronous learning and debit may precede the post-hook.
c=setup();rows[1].state='used';T.Refresh();l=learn(c);w=debit(c);request();settle();assert(w.source=='training')
-- No invented causes for unrelated learning, absent debits, or unsupported pet points.
c=setup();request();learn(c,'Unrelated');w=debit(c);settle();assert(w.source=='unknown')
c=setup();request();learn(c);w=debit(c,201);settle();assert(w.source=='unknown')
c=setup(3);request();learn(c);w=debit(c);settle();assert(w.source=='unknown')
c=setup();request();learn(c);w=debit(c);debit(c);settle();assert(w.source=='unknown')
c=setup();request();learn(c);learn(c);w=debit(c);settle();assert(w.source=='unknown')
c=setup();request();request();learn(c);w=debit(c);settle();assert(w.source=='unknown','overlap cannot assign an aggregate debit')
c=setup();guid='Creature-Other';request();learn(c);w=debit(c);settle();assert(w.source=='unknown')
c=setup();request();learn(c);w=debit(c);C.session='other';settle();assert(w.source=='unknown')
-- Closing the panel after purchase does not lose the result.
c=setup();request();learn(c);w=debit(c);T.visit.closed=true;settle();assert(w.source=='training')
-- Waiting at the trainer is supported; cached prices still require the exact debit.
c=setup();for i=1,4 do now=now+5;H.Wallet(c,now,cash,C.session)end;rows={};T.Refresh();request();learn(c);w=debit(c);settle();assert(w.source=='training')
A.Now=savedNow
print('PASS trainer learning: removed/reordered rows, synchronous callbacks, exact quotes and debits, recipe/spell learning, corrections, ownership and ambiguity')
