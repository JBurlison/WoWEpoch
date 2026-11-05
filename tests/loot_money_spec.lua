local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local S,H,F,A,C,D,L,Q=E.Store,E.History,E.Economy,E.API,E.Collectors,E.Drops,E.LootMoney,E.Query
local function eq(a,b,label)assert(a==b,(label or'Loot money')..': '..tostring(a)..' ~= '..tostring(b))end
local saved={current=E.current,session=C.session,drop=D.live,live=L.live,roster=A.Roster,location=A.Location,item=A.Item}
local names={'Enum','LE_PARTY_CATEGORY_HOME','LE_PARTY_CATEGORY_INSTANCE','IsInGroup','IsInRaid','GetNumGroupMembers','GetLootSlotType','GetLootSlotInfo','GetNumLootItems','GetLootSlotLink','IsFishingLoot','C_CurrencyInfo','GetMoney','issecretvalue'}
for _,key in ipairs(names)do saved[key]=_G[key]end
local now=A.ParseDay('2026-11-03')+40000;local serial=0;local grouped=false;local instance=false;local raid=false;local count=0;local slots;local balance=1000
local function at(value)now=value;TEST_NOW(now)end
Enum={LootSlotType={None=0,Item=1,Money=2,Currency=3}}
LE_PARTY_CATEGORY_HOME=1;LE_PARTY_CATEGORY_INSTANCE=2
IsInGroup=function(category)return category==2 and instance or grouped end
IsInRaid=function()return raid end;GetNumGroupMembers=function()return count end
GetNumLootItems=function()return #slots end
GetLootSlotType=function(i)return slots[i]and slots[i].type end
GetLootSlotInfo=function(i)local r=slots[i];if r then return 1,r.name,r.quantity,nil,1,false end end
GetLootSlotLink=function()end;IsFishingLoot=function()return false end
C_CurrencyInfo={GetCoinText=function(value)return tostring(value)..' localized copper'end}
GetMoney=function()return balance end
A.Roster=function()return {}end;A.Location=function()return {zone='Synthetic money review'}end;A.Item=function()end
local function fresh()
 serial=serial+1;at(now+50);local c=S.Character('loot-money-'..serial,{name='Synthetic loot money'})
 bindWallet(c,'loot-money-session-'..serial);D.live=nil;L.live=nil
 grouped,instance,raid,count=false,false,false,0;balance=1000
 slots={{type=2,name='100 localized copper',quantity=999999}} -- Quantity is deliberately unrelated.
 H.Wallet(c,now,balance,C.session);return c
end
local function open()C.handlers.LOOT_READY(false);C.handlers.LOOT_OPENED(false,false)end
local function wallet(c,amount,delta)
 at(now+(delta or 1));balance=balance+amount;C.handlers.PLAYER_MONEY()
 return Q.Kind(c,'gold')[#Q.Kind(c,'gold')]
end
local function clear(index)C.handlers.LOOT_SLOT_CLEARED(index or 1)end
local function proofs(c)return Q.Kind(c,'money_evidence')end
local c=fresh();open();local window=c.state.activeLootWindow
local w=wallet(c,100);eq(w.source,'unknown','visible alone is not a receipt')
clear();local p=proofs(c)[1];assert(p and F.ValidLootMoneyProof(c,p))
eq(p.amount,100);eq(p.formattedAmount,100);eq(p.slotName,'100 localized copper');eq(p.slot,1);eq(p.lootWindow,window)
eq(p.walletWindow,w.window);eq(p.walletID,w.id);eq(w.source,'loot');eq(w.quality,'inferred')
eq(w.amount,100);eq(w.before,1000);eq(w.after,1100)
eq(F.Report(c,now-5,now+1).attributedOperatingIn,100);eq(F.Report(c,now-5,now+1).operatingIn,0)
assert(E.AuctionWalletReads.Certified())
local shadow=setmetatable({db=E.Copy(E.db),On=function()end,Emit=function()error('private writer')end,
 Collectors=setmetatable({handlers={}},{__index=C})},{__index=E})
for _,factory in ipairs(E.AuctionReaderFactories)do factory.create(shadow)end
local sc=shadow.db.characters[c.id];assert(shadow.Economy.ValidLootMoneyProof(sc,sc.records[p.id]),'private reader validates isolated proof')
sc.records[p.id].slotName='Changed privately';assert(not shadow.Economy.ValidLootMoneyProof(sc,sc.records[p.id]));assert(F.ValidLootMoneyProof(c,p),'private proof correction cannot leak to public engine')
w.starred=true;local keep=S.Protected(c);assert(keep[p.id]and keep[window]and keep[w.window],'starred wallet retains proof and linked source windows');w.starred=nil
clear();C.handlers.LOOT_READY(false);C.handlers.LOOT_OPENED(false,false);eq(#proofs(c),1,'duplicate clear/ready/open observations do not multiply evidence')
C.handlers.LOOT_CLOSED();eq(w.source,'loot')
c=fresh();open();w=wallet(c,100);clear();C.handlers.LOOT_SLOT_CHANGED(1)
eq(w.source,'unknown','explicit reuse of a cleared money index is ambiguous')

-- Clear-before-money and close-before-money are accepted inside the two-second bound.
c=fresh();open();clear();p=proofs(c)[1];eq(p.amount,0);C.handlers.LOOT_CLOSED();w=wallet(c,100,2)
eq(w.quality,'inferred');eq(p.walletID,w.id);assert(F.ValidLootMoneyProof(c,p))
local raw={amount=w.amount,before=w.before,after=w.after,ts=w.ts}
F.Evidence(c,p.ts,{source='quest',amount=100,session=C.session},'competing')
eq(w.source,'unknown','other source with equal amount revokes loot inference')
for k,v in pairs(raw)do eq(w[k],v)end

-- A duplicate equal wallet receipt must revoke, not exploit the selected wallet ID.
c=fresh();open();w=wallet(c,100);clear();p=proofs(c)[1]
local duplicate=wallet(c,100,1);eq(w.source,'unknown');eq(duplicate.source,'unknown');assert(not F.ValidLootMoneyProof(c,p))
do
local rawDate=duplicate.ts
local function blocked()
 local status,reason=E.Query.EnsureWarm(c);assert(status=="failed" and reason:find(duplicate.id,1,true),reason)
 assert(not E.Query.IsWarm(c) and E.Query.WalletKeys(c)==nil)
 local ok,valid=pcall(F.ValidLootMoneyProof,c,p);assert(not ok or not valid,"ambiguous proof falsely accepted")
 pcall(F.CheckWallet,c,w);assert(w.source=="unknown" and c.records[duplicate.id]==duplicate)
end
-- Direct historical mutation notification against an already-published index.
assert(Q.IsWarm(c));duplicate.ts=nil
local notified,why=pcall(S.Changed,c,duplicate)
assert(notified,why)
blocked()
-- Independent cold rebuild must fail closed, including retry without repair.
E.Emit("RECORDS_REMOVED",c,{},{});blocked();Q.RetryWarm(c);blocked()
-- An unrelated owner can still open a normal journal.
local other=S.Character("undamaged-money",{});S.Add(other,"chat",now,{text="unrelated owner"})
assert(Q.EnsureWarm(other)=="ready" and #Q.Kind(other,"chat")==1)
-- Restoring the rival's genuine date leaves the original ambiguity intact.
duplicate.ts=rawDate;S.Changed(c,duplicate);TEST_PREPARE_HISTORY(c)
assert(Q.IsWarm(c) and not F.ValidLootMoneyProof(c,p) and w.source=="unknown")
-- A genuine timed correction moving the rival outside the applicable window
-- restores the prior uniquely justified reading without changing balances.
duplicate.ts=rawDate+10;S.Changed(c,duplicate);TEST_PREPARE_HISTORY(c)
assert(F.ValidLootMoneyProof(c,p));F.CheckWallet(c,w);assert(w.source=="loot" and w.quality=="inferred")
duplicate.ts=rawDate;S.Changed(c,duplicate);TEST_PREPARE_HISTORY(c);eq(w.source,"unknown")

end
c.records[duplicate.id]=nil;E.Emit('RECORDS_REMOVED',c,{[duplicate.id]=true},{kinds={gold=true}});TEST_PREPARE_HISTORY(c);eq(w.source,'loot','removing a conflicting receipt restores the remaining unique inference')
p.slotName='Corrected label';S.Changed(c,p);TEST_PREPARE_HISTORY(c);eq(w.source,'unknown')
p.slotName=p.coinText;S.Changed(c,p);TEST_PREPARE_HISTORY(c);eq(w.source,'loot')
p.formattedAmount=101;S.Changed(c,p);TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','corrected amount cannot reuse former coin-text proof')

-- Multiple equal money slots produce competing proofs, not a summed or chosen receipt.
c=fresh();slots[2]={type=2,name=slots[1].name,quantity=1};open();w=wallet(c,100);clear(1);clear(2)
eq(#proofs(c),2);eq(w.source,'unknown')

-- Negative, unmatched, late, missing-clear and localized exact-match boundaries.
for _,case in ipairs({{amount=90},{amount=-100},{amount=100,late=3},{amount=100,noClear=true},{amount=100,name='100 Copper (unverified syntax)'}})do
 c=fresh();if case.name then slots[1].name=case.name end;open();if not case.noClear then clear()end
 w=wallet(c,case.amount,case.late or 1);eq(w.source,'unknown','unsupported receipt remains unknown')
end
c=fresh();slots[1].name='100 pièces';C_CurrencyInfo.GetCoinText=function(value)return value..' pièces'end;open();clear();w=wallet(c,100)
eq(w.source,'loot','exact localized client formatting needs no English parser')
C_CurrencyInfo.GetCoinText=function(value)return value..' localized copper'end

-- Group/home/instance/raid/unknown state excludes shared totals; transitions are sticky.
for _,mode in ipairs({'home','instance','raid','count','unknown'})do
 c=fresh();if mode=='home'then grouped=true elseif mode=='instance'then instance=true elseif mode=='raid'then raid=true elseif mode=='count'then count=2 else IsInGroup=nil end
 open();clear();w=wallet(c,100);eq(w.source,'unknown',mode..' excluded')
 IsInGroup=function(category)return category==2 and instance or grouped end
end
c=fresh();open();grouped=true;L.GroupChanged();grouped=false;clear();w=wallet(c,100);eq(w.source,'unknown','a group transition invalidates the window')
c=fresh();open();C.GroupIdentity('GROUP_JOINED',1,'synthetic-group');C.partyGUID=nil;C.partyCategory=nil;clear();w=wallet(c,100);eq(w.source,'unknown','Bootstrap direct group-identity route invalidates even before roster APIs update')
c=fresh();open();clear();w=wallet(c,100);eq(w.source,'loot');grouped=true;L.GroupChanged();TEST_PREPARE_HISTORY(c);eq(w.source,'unknown','group uncertainty during matching window withdraws inference')

-- No cross-window/session/owner claim, no historical backfill, no clock rollback claim.
c=fresh();open();clear();p=proofs(c)[1];local oldWindow=p.walletWindow
c.state.wallet=nil;H.Wallet(c,now,1000,C.session);w=wallet(c,100);assert(w.window~=oldWindow);eq(w.source,'unknown')
c=fresh();open();clear();C.session='replacement-session';H.Wallet(c,now,1000,C.session);w=wallet(c,100);eq(w.source,'unknown')
c=fresh();open();clear();local abandoned=proofs(c)[1];local other=fresh();open();w=wallet(other,100);eq(abandoned.amount,0);eq(w.source,'unknown')
c=fresh();open();local first=now;at(first-1);clear();at(first);w=wallet(c,100);eq(w.source,'unknown')
c=fresh();w=wallet(c,100);open();clear();eq(w.source,'unknown','wallet preceding slot observation is not a receipt match')
c=fresh();open();at(now+121);clear();H.Wallet(c,now,balance,C.session);w=wallet(c,100);eq(w.source,'unknown','long-idle slot is outside the explicit capture bound')

-- Replaced/unknown slot data, missing formatting API and inaccessible data fail closed.
c=fresh();open();slots[1].name='101 localized copper';C.handlers.LOOT_SLOT_CHANGED(1);clear();w=wallet(c,100);eq(w.source,'unknown')
c=fresh();open();slots[1].type=3;C.handlers.LOOT_SLOT_CHANGED(1);clear();w=wallet(c,100);eq(w.source,'unknown')
c=fresh();open();clear();local formatter=C_CurrencyInfo.GetCoinText;C_CurrencyInfo.GetCoinText=nil;w=wallet(c,100);eq(w.source,'unknown');C_CurrencyInfo.GetCoinText=formatter
c=fresh();issecretvalue=function(v)return v==slots[1].name end;open();clear();w=wallet(c,100);eq(w.source,'unknown');issecretvalue=saved.issecretvalue

-- A bounded live burst fails closed and resumes after old closed windows age out.
c=fresh();for i=2,65 do slots[i]={type=2,name='100 localized copper',quantity=1}end
open();assert(L.live.blocked);clear();w=wallet(c,100);eq(w.source,'unknown');eq(#proofs(c),0)
C.handlers.LOOT_CLOSED();at(now+5);H.Wallet(c,now,balance,C.session);slots={{type=2,name='100 localized copper'}}
open();clear();w=wallet(c,100);eq(w.source,'loot','a completed capacity burst does not disable the entire login')

-- Confirmed/manual decisions are preserved; corrections cannot alter another owner's records.
c=fresh();open();w=wallet(c,100);local evidence=F.Evidence(c,now,{source='quest',amount=100,session=C.session},'manual')
F.Attribute(c,w.id,'quest','confirmed',{evidence.id},false);clear();eq(w.source,'quest');eq(w.quality,'confirmed')
local untouched=E.Copy(c.records);other=fresh();open();clear();wallet(other,100);assert(E.Same(c.records,untouched))

-- Historical window corrections must revoke even when no review is running.
c=fresh();open();w=wallet(c,100);clear();p=proofs(c)[1];TEST_PREPARE_HISTORY(c)
local K=E.GoldChecks;assert(not K.Pending(c));local win=c.records[w.window]
local originalEnd,originalSession,originalTS=win.ended,win.session,win.ts
local function windowChange(key,value,expected)
 win[key]=value;S.Changed(c,win);assert(K.Pending(c),'window correction schedules retained proof review')
 TEST_PREPARE_HISTORY(c);eq(w.source,expected,'window '..key..' correction');eq(w.amount,100);eq(w.before,1000);eq(w.after,1100)
end
windowChange('ended',w.ts-1,'unknown');windowChange('ended',originalEnd,'loot')
windowChange('session','corrected-session','unknown');windowChange('session',originalSession,'loot')
windowChange('ts',p.slotObservedAt+1,'unknown');windowChange('ts',originalTS,'loot')
windowChange('kind','chat','unknown');windowChange('kind','wallet_window','loot')
-- A queued subset must expand to include the wallet affected by this edit.
local unrelated=S.Add(c,'gold',now+20,{amount=1,before=1100,after=1101,session='other',source='unknown',quality='unknown'})
TEST_PREPARE_HISTORY(c);K.RequestWallets(c,{unrelated});windowChange('ended',w.ts-1,'unknown')
windowChange('ended',originalEnd,'loot')
-- Earlier installed review version must recheck previously stale assignments.
win.ended=w.ts-1;c.state.goldSourceReviewVersion=3;K.Ensure(c);TEST_PREPARE_HISTORY(c)
eq(w.source,'unknown');eq(c.state.goldSourceReviewVersion,5)
windowChange('ended',originalEnd,'loot')
F.Attribute(c,w.id,'loot','confirmed',{p.id},false);windowChange('session','manual-preserved','loot');eq(w.quality,'confirmed')

for _,key in ipairs(names)do _G[key]=saved[key]end
E.current,C.session,D.live,L.live=saved.current,saved.session,saved.drop,saved.live
A.Roster,A.Location,A.Item=saved.roster,saved.location,saved.item
print('PASS loot money: actual collector ordering, exact localized round-trip, duplicate/ambiguous/late/group exclusions, corrections, wallet boundaries, owner isolation and unchanged raw balances')

restoreWallet()
