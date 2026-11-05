local _,E=...
local L,A,S,C,F={},E.API,E.Store,E.Collectors,E.Economy;E.LootMoney=L
local function integer(v,zero)return type(v)=='number'and v==v and v%1==0 and v>=(zero and 0 or 1)and v<=9007199254740991 end
-- Group totals are not personal receipts. Missing/secret group state is unknown.
local function solo()
 local home,instance=A.Plain(LE_PARTY_CATEGORY_HOME),A.Plain(LE_PARTY_CATEGORY_INSTANCE)
 if not integer(home)or not integer(instance)or home==instance then return false end
 return A.Call('lootMoneyHomeGroup',IsInGroup,home)==false
  and A.Call('lootMoneyInstanceGroup',IsInGroup,instance)==false
  and A.Call('lootMoneyRaid',IsInRaid)==false
  and A.Call('lootMoneyGroupCount',GetNumGroupMembers)==0
end
local function invalidate(state,reason)
 for _,window in pairs(state.windows)do window.conflict=reason end
 for _,proof in ipairs(state.proofs)do if state.c.records[proof.id]==proof and not proof.lootMoneyConflict then
  proof.lootMoneyConflict=reason;S.Changed(state.c,proof);F.ReconcileEvidence(state.c,proof.session,proof.ts,proof)
 end end
end
local function live()
 local c=E.current;local now=A.Now()
 if not c or E.db.characters[c.id]~=c or type(C.session)~='string'then return end
 local state=L.live
 if not state or state.c~=c or state.session~=C.session then
  state={c=c,session=C.session,windows={},proofs={},wallets={},observations=0,now=now};L.live=state
 elseif now<state.now then
  invalidate(state,'Observation clock moved backwards');state.blocked=true;state.clockRollback=true
 end
 state.now=now
 local keep={};for _,r in ipairs(state.wallets)do if c.records[r.id]==r and now-r.ts<=4 then keep[#keep+1]=r end end;state.wallets=keep
 keep={};for _,p in ipairs(state.proofs)do if c.records[p.id]==p and now-p.ts<=4 then keep[#keep+1]=p end end;state.proofs=keep
 for id,w in pairs(state.windows)do if w.closedAt and now-w.closedAt>4 then state.windows[id]=nil end end
 state.observations=0;for _,w in pairs(state.windows)do for _ in pairs(w.slots)do state.observations=state.observations+1 end end
 if not next(state.windows)and not state.clockRollback then state.blocked=nil end
 return state
end
local function match(state,p)
 if p.amount~=0 or p.lootMoneyConflict or not p.soloObserved or state.blocked then return end
 local chosen,coin,count=nil,nil,0
 for _,w in ipairs(state.wallets)do
  if w.session==p.session and w.window==p.walletWindow and integer(w.amount)and w.ts>=p.slotObservedAt
   and math.abs(w.ts-p.ts)<=2 and S.Sequence(w)>p.slotObservedSequence then
   local formatted=A.Call('lootMoneyCoinText',C_CurrencyInfo and C_CurrencyInfo.GetCoinText,w.amount)
   if type(formatted)=='string'and formatted==p.slotName then chosen,coin,count=w,formatted,count+1 end
  end
 end
 if count==1 then
  -- The slot name is an independent amount observation. The wallet supplies
  -- only a candidate number for the client's exact localized round-trip.
  p.amount=chosen.amount;p.formattedAmount=chosen.amount;p.walletID=chosen.id;p.coinText=coin;p.moneyMatch='exact client coin text'
  p.title='Looted money / inferred slot match';S.Changed(state.c,p)
  F.ReconcileEvidence(state.c,p.session,p.ts,p)
 end
end
function L.Slot(index,changed)
 local state=live();if not state or state.blocked or A.Secret(index)or not integer(index)then return end
 local id=state.c.state.activeLootWindow;local window=state.windows[id]
 if not window then return end
 if not solo()then window.conflict='Grouped or group status unavailable' end
 local slot=window.slots[index]
 local kind=A.Call('lootMoneySlotType',GetLootSlotType,index)
 local money=Enum and Enum.LootSlotType and A.Plain(Enum.LootSlotType.Money)
 if slot and slot.cleared then
  -- Repeated open sampling is harmless, but an explicit new money slot at
  -- this cleared index is ambiguous without a source-object identity.
  if changed and money==2 and kind==money then
   local p=state.c.records[slot.proof]
   if p and not p.lootMoneyConflict then p.lootMoneyConflict='Cleared money slot changed or was reused';S.Changed(state.c,p);F.ReconcileEvidence(state.c,p.session,p.ts,p)end
  end
  return
 end
 if money~=2 or kind~=money then if slot then slot.conflict='Money slot changed before clearing' end;return end
 local _,name=A.Call('lootMoneySlotInfo',GetLootSlotInfo,index)
 if type(name)~='string'or name==''or #name>1024 then if slot then slot.conflict='Money label unavailable' end;return end
 if slot then if slot.name~=name then slot.conflict='Money label changed before clearing' end;return end
 if state.observations>=64 then invalidate(state,'Money observation capacity exceeded');state.blocked=true;return end
 local wallet=state.c.state.wallet;local walletWindow=state.c.records[state.c.state.walletWindow]
 if not wallet or wallet.session~=state.session or wallet.ts>state.now or state.now-wallet.ts>15
  or not walletWindow or walletWindow.kind~='wallet_window'or walletWindow.session~=state.session then return end
 state.observations=state.observations+1
 window.slots[index]={name=name,slot=index,ts=state.now,sequence=S.ReserveObservation(state.c),walletWindow=walletWindow.id}
end
function L.Open()
 local state=live();if not state or state.blocked then return end
 local id=state.c.state.activeLootWindow;local r=state.c.records[id]
 if not r or r.kind~='loot_window'or r.session~=state.session then return end
 if not state.windows[id]then state.windows[id]={slots={},conflict=not solo()and'Grouped or group status unavailable'or nil}end
 local count=A.Call('lootMoneySlotCount',GetNumLootItems)
 if not integer(count,true)or count>10000 then state.windows[id].conflict='Slot count unavailable';return end
 for index=1,count do L.Slot(index)end
end
function L.Cleared(index)
 local state=live();if not state or state.blocked or A.Secret(index)or not integer(index)then return end
 local id=state.c.state.activeLootWindow;local window=state.windows[id];local slot=window and window.slots[index]
 if not slot or slot.cleared then return end
 slot.cleared=true
 if not solo()then window.conflict='Grouped or group status unavailable' end
 if window.conflict or slot.conflict or state.now<slot.ts or state.now-slot.ts>120 then return end
 local p=S.Add(state.c,'money_evidence',state.now,{title='Cleared money slot / receipt unmatched',source='loot',amount=0,
  session=state.session,lootMoneyVersion=1,observationType='loot_money_slot',lootWindow=id,slot=index,slotType=2,slotName=slot.name,
  slotObservedAt=slot.ts,slotObservedSequence=slot.sequence,clearedAt=state.now,soloObserved=true,
  walletWindow=slot.walletWindow,refs={id},coverage='Exact localized money-slot match; solo only; personal receipt inferred'},
  'loot-money-slot:'..id..':'..index)
 slot.proof=p.id;state.proofs[#state.proofs+1]=p;match(state,p)
end
function L.Close()
 local state=live();if not state then return end
 for id,w in pairs(state.windows)do if id~=state.c.state.activeLootWindow and not w.closedAt then w.closedAt=state.now end end
 -- Capacity applies to a burst, not the entire login. Closed windows cannot
 -- produce more observations; pending cleared proofs have a two-second bound.
 if not next(state.windows)and not state.clockRollback then state.observations=0;state.blocked=nil end
end
function L.GroupChanged()
 local state=live();if state and not solo()then invalidate(state,'Grouped or group status unavailable')end
end
E.On('RECORD_ADDED',function(c,r)
 if r.kind~='gold'or c~=E.current then return end
 local state=live();if not state or state.c~=c or state.blocked or r.session~=state.session then return end
 if #state.wallets>=64 then invalidate(state,'Wallet observation capacity exceeded');state.blocked=true;return end
 state.wallets[#state.wallets+1]=r
 for _,p in ipairs(state.proofs)do match(state,p)end
end)
local function wrap(event,fn)local prior=C.handlers[event];C.handlers[event]=function(...)if prior then prior(...)end;return fn(...)end end
wrap('LOOT_READY',L.Open);wrap('LOOT_OPENED',L.Open);wrap('LOOT_SLOT_CHANGED',function(index)L.Slot(index,true)end)
wrap('LOOT_SLOT_CLEARED',L.Cleared);wrap('LOOT_CLOSED',L.Close)
wrap('GROUP_ROSTER_UPDATE',L.GroupChanged)
-- Bootstrap routes identity events directly rather than through handlers.
local groupIdentity=C.GroupIdentity
function C.GroupIdentity(event,...)
 groupIdentity(event,...)
 local state=live();if state then invalidate(state,'Group membership changed during loot observation')end
end
