local _,E=...
local P,K,S,A,W={},E.Keepsakes,E.Store,E.API,E.RetentionWork;E.PersonalRecords=P
P.categories={
 {key='loot_value',label='Best day of personal loot',unit='coin'},
 {key='craft_profit',label='Best day of crafting profit',unit='coin'},
 {key='death_free',label='Longest death-free stretch',unit='seconds'},
 {key='quests',label='Most quests in a day',unit='count'},
 {key='mobs',label='Most mobs defeated in a day',unit='count'},
 {key='crafted',label='Most items crafted in a day',unit='count'},
 {key='gathered',label='Most items gathered in a day',unit='count'},
 {key='net_gold',label='Best day of net gold',unit='coin'},
}
local definitions={};for _,v in ipairs(P.categories)do definitions[v.key]=v end
local interested={loot=true,crafted=true,gathered=true,quest=true,kill=true,kill_observation=true,gold=true,play=true,death=true,gap=true,
 cost_lot=true,item_sale=true,stock_move=true,stock_reset=true,sale_return=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,
 craft_request=true,craft_begin=true,craft_result=true,auction=true,merchant=true,trade=true,mail=true,mail_collection=true,wallet_window=true}
local economic={cost_lot=true,item_sale=true,stock_move=true,stock_reset=true,sale_return=true}
local financialKinds={cost_lot=true,item_sale=true,stock_move=true,stock_reset=true,sale_return=true,inventory=true,inventory_gap=true,
 bank=true,bank_gap=true,craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true,auction=true,merchant=true,
 trade=true,trade_offer=true,trade_notice=true,mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,
 mail_draft=true,money_evidence=true,gold=true,wallet_window=true}
for kind in pairs(financialKinds)do interested[kind]=true end
local busy=setmetatable({},{__mode='k'});local completed=setmetatable({},{__mode='k'})
local generations=setmetatable({},{__mode='k'});local playVersions=setmetatable({},{__mode='k'})
local requested=setmetatable({},{__mode='k'})
local deferred=setmetatable({},{__mode='k'})
local financialGeneration=0
local function ready(c)
 local waiting=deferred[c];if not waiting then return true end
 local now=A.Now()
 if now<waiting.first or now<waiting.changed then waiting.first=now;waiting.changed=now end
 -- Wait for five quiet seconds. A rebuild started during continuous activity
 -- is cancelled by the next receipt, so an earlier deadline only wastes work.
 if now-waiting.changed<5 then return false end
 deferred[c]=nil;return true
end
local function finite(v)return K.Number(v,-9007199254740991,9007199254740991)end
local function positive(v)return finite(v)and v>0 and v end
local function state(c)
 local s=K.State(c);if not s then return end
 if type(s.personalRecords)~='table'then s.personalRecords={enabled={},ids={}}end
 local p=s.personalRecords;p.enabled=p.enabled or{};p.ids=p.ids or{};return p
end
function P.Enabled(c,key)local s=state(c);return s and definitions[key]and s.enabled[key]~=false or false end
function P.Label(key)return definitions[key]and definitions[key].label or'Personal record'end
function P.SetEnabled(c,key,enabled)
 local s=state(c);if not s or not definitions[key]or type(enabled)~='boolean'then return false end
 if s.enabled[key]==enabled then return true end
 s.enabled[key]=enabled
 -- Enabling a category later establishes its existing best quietly too.
 if enabled then s.quietThrough=s.quietThrough or{};s.quietThrough[key]=s.through or A.DayStart(A.Now())end
 generations[c]=(generations[c]or 0)+1;S.Touch(c,'personalRecordPreferences');completed[c]=nil;P.Ensure(c);return true
end

-- A private checkpointed financial environment is also used by item stories.
-- It never installs live collectors, shares caches or writes into saved history.
function P.ReadEngine(work,owner)
 work=work or function()end
 local generation=financialGeneration;local liveDB=E.db
 -- Reuse the financial reader's audited snapshot. A whole-account deep copy
 -- also duplicated every milestone, pull, note and journal payload on each
 -- financial invalidation. The snapshot keeps all dates and account owners,
 -- plus the full transitive closure of referenced non-financial evidence.
 local history=E.AuctionHistory
 owner=owner or E.current
 if not K.Owned(owner)then owner=nil;for _,c in pairs(liveDB.characters)do owner=c;break end end
 local audit=owner and history.Start(owner)
 local db=audit and history.Snapshot(audit,work,true)or{characters={},settings={},schema=liveDB.schema,bankOrder=liveDB.bankOrder}
 local shadow=setmetatable({db=db,On=function()end,Emit=function()error('Personal record preparation is read-only')end,
  Collectors=setmetatable({handlers={}},{__index=E.Collectors})},{__index=E})
 shadow.PreparationWork=work;shadow.PreparationState={phase='Personal records'}
 shadow.RetentionWork={Copy=W.Copy,Same=W.Same,Sort=W.Sort}
 shadow.PreparationSort=function(rows,less)return W.Sort(rows,less or function(a,b)return a<b end,work)end
 shadow.Copy=function(v)return W.Copy(v,work)end;shadow.Same=function(a,b)return W.Same(a,b,work)end
 shadow.SortedKeys=function(t)local out={};for key in pairs(t)do work();out[#out+1]=key end;W.Sort(out,function(a,b)return tostring(a)<tostring(b)end,work);return out end
 assert(type(E.AuctionReaderFactories)=='table','Checkpointed financial readers unavailable')
 for _,factory in ipairs(E.AuctionReaderFactories)do work();factory.create(shadow)end
 for _,method in ipairs({'Open','Character','Add','Changed','Touch','Remove','RemoveMany','Note','ReserveObservation'})do shadow.Store[method]=function()error('Personal record preparation cannot write')end end
 shadow.db=false
 for _,c in pairs(db.characters)do work();shadow.Query.WarmSnapshot(c,work)end
 shadow.db=db
 shadow.PreparationValid=function()return liveDB==E.db and generation==financialGeneration and(not audit or history.Valid(audit))end
 return shadow
end
local function references(c,set,work)
 local ids={};for id in pairs(set)do work();if K.Record(c,c.records[id])then ids[#ids+1]=id end end
 W.Sort(ids,function(a,b)return S.Before(c.records[a],c.records[b])end,work);return ids
end
local function add(bucket,kind,value,r,incomplete,inferred)
 local row=bucket[kind]
 if not row then row={value=0,refs={},incomplete=false,inferred=false};bucket[kind]=row end
 if finite(value)and finite(row.value+value)then row.value=row.value+value else row.incomplete=true end
 if r then row.refs[r.id]=true end
 row.incomplete=row.incomplete or incomplete or false;row.inferred=row.inferred or inferred or false
 return row
end
local function craftOrigin(shadow,c,allocation,work)
 if allocation.sourceCharacter~=c.id then return end
 local id=allocation.sourceRecord or allocation.lot;local lot=c.records[id]
 if not lot or lot.character~=c.id or lot.kind~='cost_lot'then return end
 local receipt=c.records[lot.evidence]
 if receipt and receipt.kind=='crafted'and receipt.character==c.id and receipt.recipient==c.id and receipt.itemID==lot.itemID then
  return {lot.id,receipt.id},lot.quality=='inferred'
 end
 local projected=shadow.CraftCosts and shadow.CraftCosts.Project(c,lot)
 for _,r in ipairs(projected or{})do work()
  if r.id==lot.id and r.craftRequest then
   local request=c.records[r.craftRequest]
   if request and request.kind=='craft_request'and request.subject==c.id then
    local refs={lot.id,request.id};for _,ref in ipairs(request.refs or{})do work();refs[#refs+1]=ref end
    return refs,true
   end
  end
 end
end
local function financial(c,through,days,work)
 local shadow=P.ReadEngine(work,c);local owner=shadow.db.characters[c.id]
 local replay=shadow.Economy.Replay(owner,through)
 for _,info in ipairs(replay.order)do work()
  local r=info.record;local at=r.ts
  if finite(at)and at<through then
   local day=A.DayStart(at);days[day]=days[day]or{};local bucket=days[day]
   local offset=0
   for _,allocation in ipairs(info.allocations or{})do work()
    local refs,inferred=craftOrigin(shadow,owner,allocation,work)
    if refs then
     local known=finite(allocation.cost)and finite(r.quantity)and r.quantity>0 and finite(allocation.quantity)
     local income,fee
     if r.kind=='item_sale'then income=r.gross;fee=r.fees
     elseif r.kind=='sale_return'then income=r.refund;fee=r.feeRefund end
     local amount
     if known and finite(income)and finite(fee)then
      local proceeds=shadow.Economy.Part(income,r.quantity,offset,allocation.quantity)
      local fees=shadow.Economy.Part(fee,r.quantity,offset,allocation.quantity)
      amount=r.kind=='sale_return'and allocation.cost-proceeds+fees or proceeds-allocation.cost-fees
     end
     local row=add(bucket,'craft_profit',amount or 0,r,amount==nil,inferred or info.inferred)
     row.known=(row.known or 0)+(amount~=nil and allocation.quantity or 0)
     for _,id in ipairs(refs)do work();row.refs[id]=true end
    end
    offset=offset+(allocation.quantity or 0)
   end
  end
 end
 for day,bucket in pairs(days)do work();if bucket.net_gold then
  local coverage=shadow.Economy.WalletCoverage(owner,day,A.ShiftDay(day,1))
  bucket.net_gold.incomplete=not(coverage and coverage.complete)
 end end
 return shadow.PreparationValid
end

-- Boundary sweep counts overlapping active intervals once, AFK never, and
-- unknown intervals break a stretch. Cross-session pauses need explicit proof.
local function deathFree(c,rows,through,work)
 local boundaries,play,points={},{},{}
 local function point(ts)local p=points[ts];if not p then p={at=ts,start={},finish={},stop={}};points[ts]=p;boundaries[#boundaries+1]=p end;return p end
 for _,r in ipairs(rows)do work()
  if r.kind=='play'and finite(r.ended)and r.ended>r.ts and r.ts<through then
   play[r.id]=r;point(r.ts).start[#point(r.ts).start+1]=r;local last=math.min(through,r.ended);point(last).finish[#point(last).finish+1]=r
   local day=A.ShiftDay(A.DayStart(r.ts),1)
   while day<last do work();point(day);day=A.ShiftDay(day,1)end
  elseif r.ts<through and(r.kind=='death'and r.subject==c.id or r.kind=='gap'and not r.group)then point(r.ts).stop[#point(r.ts).stop+1]=r end
 end
 W.Sort(boundaries,function(a,b)return a.at<b.at end,work)
 local live,stretches,run={}, {},nil;local lastKnown
 local function finish(at)
  if run and run.value>0 then run.through=at;stretches[#stretches+1]=run end;run=nil
 end
 local function witness(nextPlay)
  local proof=nextPlay.previousVerifiedLogout;local before=proof and play[proof]
  local ending=before and before.verifiedLogout
  return before and ending and ending.session==before.session and finite(ending.at)and ending.at>=before.ended
   and ending.at<=nextPlay.ts and before.session~=nextPlay.session and lastKnown and lastKnown.id==before.id
 end
 for i,p in ipairs(boundaries)do work()
  for _,r in ipairs(p.finish)do work();live[r.id]=nil;if r.status~='unknown'and(not lastKnown or r.ended>lastKnown.ended)then lastKnown=r end end
  if #p.stop>0 then
   if run then for _,r in ipairs(p.stop)do work();run.refs[r.id]=true end end
   finish(p.at);lastKnown=nil
  end
  local hadLive=next(live)~=nil
  for _,r in ipairs(p.start)do work()
   if run and not hadLive and run.endAt and p.at>run.endAt and not witness(r)then finish(run.endAt)end
   live[r.id]=r
  end
  local nextPoint=boundaries[i+1];local untilAt=nextPoint and nextPoint.at or p.at
  if untilAt>p.at then
   local active,afk,unknown=false,false,false;local refset={}
   for id,r in pairs(live)do work();refset[id]=true
    if r.status=='active'then active=true elseif r.status=='afk'then afk=true else unknown=true end
   end
   if unknown then finish(p.at);lastKnown=nil
   elseif active or afk then
    if not run then run={value=0,from=p.at,through=untilAt,refs={},key='stretch:'..tostring(p.at)}end
    if active and not afk then run.value=run.value+untilAt-p.at end
    for id in pairs(refset)do work();run.refs[id]=true end
    run.endAt=untilAt
    if run.value>0 and A.DayStart(untilAt)==untilAt then
     local checkpoint=W.Copy(run,work);checkpoint.through=untilAt;stretches[#stretches+1]=checkpoint
    end
   elseif run then
    -- Keep a pending run only when its final known interval has a normal
    -- logout witness. The next session must explicitly refer back to it.
    if not(lastKnown and lastKnown.verifiedLogout and run.refs[lastKnown.id])then finish(p.at);lastKnown=nil end
   end
  end
 end
 finish(run and run.endAt or through)
 return stretches
end
function P.Build(c,through,work)
 work=work or function()end
 if not K.Owned(c)or not finite(through)then return end
 local days,rows,hasEconomy={}, {},false;local generation=financialGeneration
 for _,r in pairs(c.records)do work();if K.Record(c,r)and finite(r.ts)then
  if interested[r.kind]then rows[#rows+1]=r end
  if economic[r.kind]or r.kind=='gold'or r.kind=='wallet_window'then hasEconomy=true end
  if r.ts<through then
   local day=A.DayStart(r.ts);days[day]=days[day]or{};local bucket=days[day]
   if r.kind=='loot'and r.recipient==c.id and positive(r.quantity)then
    local price=finite(r.vendorUnitValue)and r.vendorUnitValue>=0 and r.vendorUnitValue or nil
    local row=add(bucket,'loot_value',price and price*r.quantity or 0,r,price==nil)
    row.known=(row.known or 0)+(price~=nil and r.quantity or 0)
   elseif(r.kind=='crafted'or r.kind=='gathered')and r.recipient==c.id and positive(r.quantity)then
    add(bucket,r.kind,r.quantity,r,false,r.quality=='inferred'or E.Gathering and E.Gathering.Inferred(r))
   elseif r.kind=='quest'and r.status=='completed'then add(bucket,'quests',1,r)
   elseif r.kind=='gold'and finite(r.amount)then add(bucket,'net_gold',r.amount,r,true,r.quality=='inferred')end
  end
 end end
 W.Sort(rows,S.Before,work)
 -- Use the same canonical mob-lifetime validation as the loot-drop report.
 if E.MobDrops then
  local report=E.MobDrops.Report(c,{through=through},work)
  for _,r in ipairs(report.kills)do work();local day=A.DayStart(r.ts);days[day]=days[day]or{};add(days[day],'mobs',1,r)end
 end
 local financialValid=hasEconomy and financial(c,through,days,work)
 local candidates={};for day,bucket in pairs(days)do work();for key,row in pairs(bucket)do work()
  if positive(row.value)and(not row.known or row.known>0)then
   candidates[#candidates+1]={recordType=key,value=row.value,from=day,through=A.ShiftDay(day,1),refs=references(c,row.refs,work),
    incomplete=row.incomplete,inferred=row.inferred,key=key..':'..A.Day(day)}
  end
 end end
 for _,row in ipairs(deathFree(c,rows,through,work))do work()
  candidates[#candidates+1]={recordType='death_free',value=row.value,from=row.from,through=row.through,refs=references(c,row.refs,work),
   incomplete=false,inferred=false,key='death_free:'..tostring(row.from)..':'..tostring(row.through)}
 end
 W.Sort(candidates,function(a,b)if a.through~=b.through then return a.through<b.through end;if a.from~=b.from then return a.from<b.from end;return a.key<b.key end,work)
 local s=state(c);local quiet=s.baselineThrough or through;local best,desired={},{}
 for _,row in ipairs(candidates)do work();local key=row.recordType
  if P.Enabled(c,key)and(not best[key]or row.value>best[key].value)then
   best[key]=row
   row.quiet=row.through<=quiet
   row.unread=not row.quiet and row.through>math.max(s.publishedThrough or quiet,s.quietThrough and s.quietThrough[key]or quiet)
   if row.quiet then desired['baseline:'..key]=row else desired[row.key]=row end
  end
 end
 local result={desired={},best={},ids={},through=through,operations={},financialGeneration=generation,financialValid=financialValid}
 for key,row in pairs(desired)do work()
  row.recordKey=key;row.unit=definitions[row.recordType].unit;result.desired[key]=row
 end
 -- Rebuild the small record index from canonical facts, including reloads.
 local saved={}
 for _,r in pairs(c.records)do work();if K.Record(c,r,'personal_record')then
  result.ids[#result.ids+1]=r.id;saved[r.recordKey]=r
  if P.Enabled(c,r.recordType)and not desired[r.recordKey]and r.valid~=false then result.operations[#result.operations+1]={record=r.id,invalid=true}end
 end end
 for key,row in pairs(result.desired)do work()
  local r=saved[key];if r then
   row.id=r.id
   local equal=r.valid==true and r.value==row.value and r.from==row.from and r.through==row.through and r.incomplete==row.incomplete and r.inferred==row.inferred and W.Same(r.refs,row.refs,work)
   if not equal then result.operations[#result.operations+1]={record=r.id,data=row}end
  else result.operations[#result.operations+1]={data=row}end
 end
 for key,row in pairs(best)do work();result.best[key]=row.recordKey end
 W.Sort(result.operations,function(a,b)local x=a.data and a.data.key or a.record;local y=b.data and b.data.key or b.record;return x<y end,work)
 return result
end
local function publish(c,result)
 if not result or not K.Owned(c)then return end
 if requested[c]and result.through~=requested[c]then completed[c]=nil;P.Ensure(c,requested[c]);return end
 if result.financialGeneration~=financialGeneration or result.financialValid and not result.financialValid()then completed[c]=nil;P.Ensure(c,result.through,true);return end
 local s=state(c);busy[c]=true
 s.baselineThrough=s.baselineThrough or result.through;s.through=result.through;s.ids=result.ids
 local changed=false
 for index=1,math.min(16,#result.operations)do
  local operation=result.operations[index];local r=operation.record and c.records[operation.record]
  if operation.invalid and K.Record(c,r,'personal_record')then
   r.valid=false;r.unread=false;r.revisedAt=A.Now();S.Changed(c,r);changed=true
  elseif operation.data then
   local d=operation.data
   if r then
    r.ts=d.through-1;r.value=d.value;r.from=d.from;r.through=d.through;r.refs=d.refs;r.incomplete=d.incomplete;r.inferred=d.inferred;r.valid=true;r.revisedAt=A.Now()
    -- Corrections revise evidence, but never manufacture another unread win.
    S.Changed(c,r);changed=true
   else
    r=S.Add(c,'personal_record',d.through-1,{title=P.Label(d.recordType),subject=c.id,recordType=d.recordType,recordKey=d.recordKey,
     value=d.value,unit=d.unit,from=d.from,through=d.through,refs=d.refs,incomplete=d.incomplete,inferred=d.inferred,
     valid=true,unread=d.unread,baseline=d.quiet},'personal-record:'..d.recordKey)
    s.ids[#s.ids+1]=r.id;changed=true
   end
  end
 end
 busy[c]=nil;completed[c]=result.through
 if changed then E.Emit('PERSONAL_RECORDS_UPDATED',c)end
 if #result.operations>16 then completed[c]=nil;P.Ensure(c,result.through)
 else s.publishedThrough=math.max(s.publishedThrough or 0,result.through)end
end
function P.Ensure(c,through,automatic)
 local s=state(c);if not s then return end
 through=through or c.state.recapLoginThrough
 if not finite(through)then return end
 through=math.min(A.DayStart(through),A.DayStart(A.Now()))
 if automatic then
  local now=A.Now();local waiting=deferred[c]or{first=now};waiting.changed=now;deferred[c]=waiting
 else deferred[c]=nil end
 if completed[c]==through or K.Pending(c,'personal-records')and requested[c]==through then return end
 requested[c]=through
 -- Persist the first-use quiet horizon before background work starts; reloads
 -- cannot turn a half-finished historical baseline into a burst of new wins.
 s.baselineThrough=s.baselineThrough or through
 K.Queue(c,'personal-records',function(work)return P.Build(c,through,work)end,function(result)publish(c,result)end,
  function()return tostring(generations[c]or 0)..':'..financialGeneration..':'..tostring(requested[c])end,function()return ready(c)end)
end
function P.Login(c,now)
 if not K.Owned(c)then return end
 local s=state(c);s.through=A.DayStart(now);completed[c]=nil;P.Ensure(c,s.through)
end
function P.Rows(c)
 local out={};local s=state(c);if not s then return out end
 for _,id in ipairs(s.ids)do local r=c.records[id];if K.Record(c,r,'personal_record')then out[#out+1]=r end end
 table.sort(out,S.Before);return out
end
function P.Unread(c)local count=0;for _,r in ipairs(P.Rows(c))do if r.valid~=false and r.unread then count=count+1 end end;return count end
function P.MarkRead(c,r)
 if not K.Record(c,r,'personal_record')then return false end
 if r.unread then r.unread=false;S.Changed(c,r);E.Emit('PERSONAL_RECORDS_UPDATED',c)end;return true
end
local function changed(c,r,_,receipt)
 if busy[c]or not K.Owned(c)then return end
 if r.kind=='wallet_window'and receipt and(receipt.reason=='walletUnchanged'or receipt.reason=='walletExtension')then
  local before=receipt.detail and receipt.detail.before;local cutoff=c.state.recapLoginThrough
  if receipt.reason=='walletUnchanged'or cutoff and before and finite(before.ended)and before.ended>=cutoff then return end
 end
 -- A revised type may no longer be in the set; Query retains that prior kind.
 local prior=E.Query.PreviousKind and E.Query.PreviousKind(c,r.id)
 if interested[r.kind]or prior and interested[prior]then
  local through=c.state.recapLoginThrough
  if r.kind=='play'and through and finite(r.ended)then
   local fingerprint=table.concat({tostring(r.ts),tostring(math.min(r.ended,through)),tostring(r.status),tostring(r.session),tostring(r.previousVerifiedLogout),tostring(r.verifiedLogout and r.verifiedLogout.at)},':')
   local old=playVersions[r];playVersions[r]=fingerprint
   if old==fingerprint then return end
  end
  local financial=financialKinds[r.kind]or financialKinds[prior]
  if financial then financialGeneration=financialGeneration+1 end
  completed[c]=nil
  if through and(r.ts<through or economic[r.kind]or economic[prior])then
   generations[c]=(generations[c]or 0)+1
   if not financial then K.Cancel(c,'personal-records');P.Ensure(c,through,true)end
  end
  if financial then
   for _,owner in pairs(E.db.characters)do if owner.state.keepsakes and owner.state.keepsakes.personalRecords then
    completed[owner]=nil;K.Cancel(owner,'personal-records');P.Ensure(owner,requested[owner],true)
   end end
  end
 end
end
E.On('RECORD_ADDED',changed);E.On('RECORD_CHANGED',changed)
E.On('RECORDS_REMOVED',function(c)if not busy[c]then financialGeneration=financialGeneration+1;generations[c]=(generations[c]or 0)+1;for _,owner in pairs(E.db.characters)do if owner.state.keepsakes and owner.state.keepsakes.personalRecords then completed[owner]=nil;K.Cancel(owner,'personal-records');P.Ensure(owner,requested[owner],true)end end end end)
-- Installed after JournalJobs and Collectors. Their existing verified-login
-- contract supplies the next-day publication cutoff.
local login=E.JournalJobs.Login
E.JournalJobs.Login=function(c,now)login(c,now);P.Login(c,now)end
local latest=setmetatable({},{__mode='k'})
local function play(c,r)
 if r.kind~='play'or not K.Record(c,r)then return end
 latest[c]=r.id
 local s=state(c);local saved=s and s.logout
 if saved and saved.session~=r.session then
  local prior=c.records[saved.record]
  if prior and prior.verifiedLogout and prior.session==saved.session and r.ts>=saved.at and c==E.current and r.session==E.Collectors.session then
   r.previousVerifiedLogout=prior.id;r.refs=r.refs or{};r.refs[#r.refs+1]=prior.id;s.logout=nil
   S.Changed(c,r)
  else s.logout=nil end
 end
end
E.On('RECORD_ADDED',play);E.On('RECORD_CHANGED',play)
local logout=E.Collectors.handlers.PLAYER_LOGOUT
E.Collectors.handlers.PLAYER_LOGOUT=function(...)
 local c=E.current;local session=E.Collectors.session
 local verified=c and E.RecorderReady()and A.RecordingPlayerGUID()==c.id
 if logout then logout(...)end
 local r=c and c.records[latest[c]]
 if verified and K.Record(c,r,'play')and r.session==session then
  local at=A.Now();r.verifiedLogout={session=session,at=at};state(c).logout={record=r.id,session=session,at=at};S.Changed(c,r)
 end
end
