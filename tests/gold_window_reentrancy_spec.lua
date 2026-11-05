local S,H,Q,K,F=E.Store,E.History,E.Query,E.GoldChecks,E.Economy
local function ready(c)TEST_PREPARE_HISTORY(c);assert(not K.Pending(c))end
local function fixture(id)
 local c=S.Character('independent-window-'..id,{name='Independent window test'})
 H.Wallet(c,100,1000,'one');local seq=S.ReserveObservation(c);local w=H.Wallet(c,101,1100,'one')
 local p=F.Evidence(c,101,{source='loot',amount=100,session='one',lootMoneyVersion=1,observationType='loot_money_slot',
  slotType=2,slot=1,soloObserved=true,formattedAmount=100,slotName='100',coinText='100',moneyMatch='exact client coin text',
  slotObservedSequence=seq,slotObservedAt=100,clearedAt=101,walletID=w.id,walletWindow=w.window},'proof')
 assert(F.ValidLootMoneyProof(c,p));ready(c);assert(w.source=='loot');return c,w,p,c.records[w.window]
end
local c,w,p,win=fixture('full-dirty')
for i=1,40 do S.Add(c,'gold',200+i,{amount=1,before=i,after=i+1,session='other',source='unknown',quality='unknown'})end
ready(c);K.Request(c,true);K.Step(c,1);win.ended=100;S.Changed(c,win);ready(c)
assert(w.source=='unknown','full pass must revisit the already processed first wallet')
win.ended=101;S.Changed(c,win);ready(c);assert(w.source=='loot')
local replacement=E.Copy(win);replacement.session='corrected';c.records[win.id]=replacement;S.Changed(c,replacement);ready(c);assert(w.source=='unknown')
replacement.session='one';S.Changed(c,replacement);ready(c);assert(w.source=='loot')
print('PASS independent full-pass dirty and canonical window replacement')

local live=S.Character('independent-live-transactions',{name='Live transitions'});H.Wallet(live,100,1000,'live');ready(live)
local request=K.Request;local count=0;K.Request=function(owner,...)if owner==live then count=count+1 end;return request(owner,...)end
for i=1,1000 do H.Wallet(live,100+i,1000+i,'live');H.Wallet(live,100+i,1000+i,'live')end
assert(count==0 and not K.Pending(live),'real appends and same-time heartbeats must not enqueue full reviews')
K.Request=request;print('PASS independent 1000 real appends plus 1000 unchanged heartbeats: no full requests')

-- A second ordinary listener can re-emit a correction before GoldChecks runs.
-- Query then loses the outer event's prior membership unless it is receipt-bound.
local rc,rw,rp,rwin=fixture('reentrant')
local listeners=E.listeners.RECORD_CHANGED;local entered=false
local function reenter(owner,row)
 if owner==rc and row==rwin and not entered then entered=true;S.Changed(owner,row)end
end
table.insert(listeners,2,reenter)
rwin.kind='chat';S.Changed(rc,rwin)
table.remove(listeners,2)
assert(not F.ValidLootMoneyProof(rc,rp))
print('REENTRANT_RESULT pending='..tostring(K.Pending(rc))..' source='..rw.source..' previousKind='..tostring(Q.PreviousKind(rc,rwin.id)))
assert(K.Pending(rc),'reentrant window-to-chat change must retain outer previous membership')

ready(rc);assert(rw.source=="unknown","nested change withdraws stale attribution")
print("PASS reentrant window correction retains outer membership and withdraws inference")
