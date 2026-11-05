local _,E=...
-- Load before MailMoney: invalidate receipt plans before cash proofs are rechecked.
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.MailCosts=K
local relevant={mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,inventory=true,inventory_gap=true,
 bank=true,bank_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,gold=true,money_evidence=true,wallet_window=true}
local caches=setmetatable({},{__mode='k'})
local dependencies=setmetatable({},{__mode='k'})
local function depend(c,batch,id)
 if not batch or type(batch.id)~='string'or type(id)~='string'then return end
 local index=dependencies[c];if not index then index={};dependencies[c]=index end
 index[id]=index[id]or{};index[id][batch.id]=true
end
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]or dependencies[c]and dependencies[c][r.id]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c);dependencies[c]=nil end)
local function integer(n,min,max)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=(max or 67108864)end
local function contains(list,id)for _,v in ipairs(list or{})do if v==id then return true end end end
local function identity(d)local v=E.Mail.Comparable(d,true);v.items=nil;v.itemCount=nil;v.cod=nil;return v end
local function itemKey(v)return {itemID=v.itemID,currencyID=v.currencyID,quantity=v.quantity,itemLink=v.itemLink}end
local function items(d)
 if not d.complete or not integer(d.money,0,9007199254740991)or not integer(d.cod,0,9007199254740991)or type(d.items)~='table'or d.itemCount~=#d.items then return end
 local slots={};for _,v in ipairs(d.items)do
  local identified=v.isCurrency and integer(v.currencyID,1)and v.itemID==nil or not v.isCurrency and integer(v.itemID,1)and v.currencyID==nil
  if not v.complete or not identified or not integer(v.quantity,1)or not integer(v.slot,1,16)or slots[v.slot]then return end
  slots[v.slot]=v
 end
 return slots
end
local function scan(c,id,r)
 local s=c.records[id];if not s or s.kind~='mail_scan'or not s.complete or s.session~=r.session or s.visit~=r.visit or s.loaded~=s.total or type(s.entries)~='table'or #s.entries~=s.loaded then return end
 local rows,seen={},{};for _,id in ipairs(s.entries)do local row=c.records[id]
  if seen[id]or not row or row.kind~='mail'or row.character~=c.id or row.scan~=s.id or row.session~=r.session or row.visit~=r.visit or not row.mailData or not items(row.mailData)then return end
  seen[id]=true;rows[#rows+1]=row
 end
 return rows,s
end
local function changes(c,r)
 if not r or r.kind~='mail_collection'or r.character~=c.id or not r.settledAt or r.interrupted or r.failed or r.overflow then return end
 local before,old=scan(c,r.beforeScan,r);local after,new=scan(c,r.afterScan,r)
 if not before or not after or S.Sequence(old)>=S.Sequence(r)or S.Sequence(new)<=r.lastRequestSequence or new.ts<r.lastRequestAt or new.finishedAt>r.settledAt then return end
 local plan={items={},components={},gold=0,removedStacks=0};local matched={};local changed={}
 for i,row in ipairs(before)do local d=row.mailData;local key=identity(d);local found
  for j=1,i-1 do if E.Same(key,identity(before[j].mailData))then return end end
  for j,nextRow in ipairs(after)do if E.Same(key,identity(nextRow.mailData))then if found then return end;found=j end end
  if found then if matched[found]then return end;matched[found]=true end
  local nextData=found and after[found].mailData or{items={},money=0,cod=0}
  local used={};for _,item in ipairs(nextData.items)do local match
   for n,original in ipairs(d.items)do if not used[n]and E.Same(itemKey(item),itemKey(original))then match=n;break end end
   if not match then return end;used[match]=true
  end
  local part={record=row.id,items={},removed={},beforeItems={},cod=0,money=0}
  for n,item in ipairs(d.items)do
   if item.isCurrency and not used[n]then return end
   if item.itemID then part.beforeItems[item.itemID]=(part.beforeItems[item.itemID]or 0)+item.quantity end
   if not used[n]then
    part.items[item.itemID]=(part.items[item.itemID]or 0)+item.quantity;part.removed[#part.removed+1]=item;plan.removedStacks=plan.removedStacks+1
    local total=plan.items[item.itemID]or{quantity=0,used=0};total.quantity=total.quantity+item.quantity;if not integer(total.quantity,1)then return end;plan.items[item.itemID]=total
   end
  end
  if nextData.money~=d.money and nextData.money~=0 or nextData.cod~=d.cod and nextData.cod~=0 then return end
  part.money=d.money-nextData.money;part.cod=d.cod-nextData.cod
  if part.cod>0 and #part.removed==0 then return end
  if #part.removed>0 or part.money>0 or part.cod>0 then
   changed[i]=part;plan.components[#plan.components+1]=part;plan.gold=plan.gold+part.money-part.cod
   if not integer(math.abs(plan.gold),0,9007199254740991)then return end
  elseif not found then return end
 end
 for i in ipairs(after)do if not matched[i]then return end end
 if plan.removedStacks==0 or #r.requests==0 or #r.requests>100 or #r.notices<#r.requests or #r.notices>#r.requests+plan.removedStacks then return end
 local seen={};for n,id in ipairs(r.requests)do local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_request'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.unavailable
   or not integer(v.index,1,#before)or v.ts<r.ts or v.ts>r.lastRequestAt then return end;seen[id]=true
  if v.method~='TakeInboxItem'and v.method~='AutoLootMailItem'and v.method~='TakeInboxMoney'then return end
  if v.method=='TakeInboxItem'and not integer(v.slot,1,16)then return end
  if n==1 then
   local part=changed[v.index];if not part then return end
   if v.method=='TakeInboxMoney'and part.money==0 then return end
   if v.method=='TakeInboxItem'then
    local target=items(before[v.index].mailData)[v.slot];local found=false
    for _,item in ipairs(part.removed)do if target and E.Same(itemKey(item),itemKey(target))then found=true end end
    if not found then return end
   end
  end
 end
 for _,id in ipairs(r.notices)do local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_notice'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.unavailable or v.event~='MAIL_SUCCESS'
   or v.ts<r.ts or v.ts>r.lastRequestAt+5 or v.itemID and not plan.items[v.itemID]then return end;seen[id]=true
 end
 return plan
end
local function counts(r)
 if not r or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
 local out={};for _,map in ipairs({r.carried,r.equipment})do for id,n in pairs(map)do
  if not integer(id,1)or not integer(n)then return end;out[id]=(out[id]or 0)+n;if not integer(out[id])then return end
 end end;return out
end
local function equal(a,b)
 for id,n in pairs(a)do if n~=(b[id]or 0)then return false end end
 for id,n in pairs(b)do if n~=(a[id]or 0)then return false end end;return true
end
local function build(c,r)
 local plan=changes(c,r);local anchor=r and r.inventoryAnchor
 if not plan or not anchor or anchor.session~=r.session or anchor.scope~='bags and equipment'or not integer(anchor.sequence,0,9007199254740991)
  or type(anchor.ts)~='number'or anchor.ts>r.ts or r.ts-anchor.ts>15 or anchor.sequence>=S.Sequence(r)then return end
 local base=c.records[anchor.record];local current=counts(base)
 if not current or base.kind~='inventory'or base.character~=c.id or base.session~=r.session or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
 local successors={};for _,inv in ipairs(Q.Range(c,anchor.ts,r.settledAt+1,'inventory'))do
  depend(c,r,inv.id)
  if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
  if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
 end end
 local remaining=0;for _,v in pairs(plan.items)do remaining=remaining+v.quantity end
 plan.records={};plan.rows={};local previous,ts,seq=base.id,anchor.ts,anchor.sequence
 while remaining>0 do local inv=successors[previous];local actual=counts(inv)
  if not actual or inv.character~=c.id or inv.baseline or inv.session~=r.session or S.Sequence(inv)<=seq or S.Sequence(inv)<=S.Sequence(r)
   or not inv.observedFrom or inv.observedFrom<ts or inv.ts<inv.observedFrom or inv.ts<r.ts or inv.ts>r.lastRequestAt+5
   or inv.ts>r.settledAt or(inv.accountingTime or inv.ts)~=inv.ts or not E.Same(base.equipment,inv.equipment)then return end
  local rows={};local changed=0;for _,v in ipairs(inv.items or{})do local expected=plan.items[v.itemID]
   if not expected or rows[v.itemID]or not integer(v.before)or not integer(v.after)or v.before~=(current[v.itemID]or 0)
    or v.delta~=v.after-v.before or v.delta<=0 or expected.used+v.delta>expected.quantity then return end
   rows[v.itemID]={quantity=v.delta,offset=expected.used};expected.used=expected.used+v.delta;current[v.itemID]=v.after;changed=changed+v.delta
  end
  if changed==0 or not equal(current,actual)then return end
  remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows;previous,ts,seq=inv.id,inv.ts,S.Sequence(inv)
 end
 if successors[previous]~=nil then return end
 for _,gap in ipairs(Q.Range(c,anchor.ts,r.settledAt+1,'inventory_gap'))do depend(c,r,gap.id);if S.Sequence(gap)>anchor.sequence then return end end
 return plan
end
function K.Plan(c,r)
 if not r then return end
 local cache=caches[c];if not cache then cache={};caches[c]=cache end
 if cache[r.id]==nil then
  depend(c,r,r.id);if r.inventoryAnchor then depend(c,r,r.inventoryAnchor.record)end
  -- MailMoney owns wallet-window identity checks; ordinary balance heartbeats
  -- must not become receipt-dependency edits just because refs include a window.
  for _,id in ipairs(r.refs or{})do local row=c.records[id]
   if row and row.kind~='wallet_window'and row.kind~='gold'and row.kind~='money_evidence'then depend(c,r,id)end
  end
  cache[r.id]=build(c,r)or false
 end;return cache[r.id]or nil
end
function K.Claim(c,inv)
 for _,id in ipairs(inv and inv.mailCandidates or{})do local plan=K.Plan(c,c.records[id]);if plan and plan.rows[inv.id]then return true end end
 return false
end
function K.Resolve(c,inv)
 local match;for _,id in ipairs(inv and inv.mailCandidates or{})do local r=c.records[id];local plan=K.Plan(c,r)
  if plan and plan.rows[inv.id]then if match then return nil,'Overlapping mail collections claim these items.'end;match=r end
 end
 if not match then return nil,'No complete mail collection matches these inventory changes.'end
 for _,part in ipairs(K.Plan(c,match).records)do
  if E.CraftCosts and E.CraftCosts.Claim(c,part)then return nil,'Crafting and mail evidence overlap; item costs remain unknown.'end
  if E.AuctionCosts and E.AuctionCosts.Claim(c,part)then return nil,'Auction and mail evidence overlap; item costs remain unknown.'end
  for _,id in ipairs(part.mailCandidates or{})do local p=K.Plan(c,c.records[id]);if id~=match.id and p and p.rows[part.id]then return nil,'Another collection overlaps these items.'end end
  if E.SentMailCosts and E.SentMailCosts.Claim(c,part)then return nil,"Incoming and outgoing mail evidence overlap."end
  if E.TradeCosts.Claim(c,part)then return nil,'Mail and trade evidence overlap; item costs remain unknown.'end
  for _,id in ipairs(part.merchantCandidates or{})do if E.CostMatch.Compatible(c,part,c.records[id])then return nil,'Mail and merchant evidence overlap; item costs remain unknown.'end end
  for _,bank in ipairs(Q.Range(c,part.ts,part.ts+1,'bank'))do
   depend(c,match,bank.id)
   if bank.inventoryRecord==part.id and #(bank.transfers or{})>0 then return nil,'Mail and bank evidence overlap; item costs remain unknown.'end
  end
 end
 return match,'Mail requests, success notifications, removed attachments and continuous inventory counts match; receipt is inferred.'
end
function K.Cash(c,r)
 local plan=K.Plan(c,r);if not plan or plan.gold==0 then return end
 if K.Resolve(c,plan.records[1])~=r then return end
 local anchor=r.walletAnchor;local window=anchor and c.records[anchor.window]
 if not anchor or anchor.session~=r.session or not integer(anchor.amount,0,9007199254740991)or not integer(anchor.sequence,0,9007199254740991)or type(anchor.ts)~='number'or r.ts<anchor.ts or r.ts-anchor.ts>15
  or not window or window.kind~='wallet_window'or window.session~=r.session then return end
 local balance=anchor.amount;local seen={};local wallets={}
 for _,id in ipairs(r.wallets or{})do local w=c.records[id]
  if seen[id]or not w or w.kind~='gold'or w.session~=r.session or w.window~=window.id or w.before~=balance or not integer(w.after,0,9007199254740991)
   or w.amount~=w.after-w.before or w.amount*plan.gold<=0 or S.Sequence(w)<=anchor.sequence or w.ts<r.ts or w.ts>r.lastRequestAt+5 or w.ts>r.settledAt then return end
  seen[id]=true;balance=w.after;wallets[#wallets+1]=w
 end
 if #wallets==0 or balance~=r.walletAfter or balance-anchor.amount~=plan.gold then return end
 return {wallets=wallets,amount=plan.gold,source='mail',components=plan.components},'Collected attachments and net mail gold match the observed inventory and wallet chains; attribution is inferred.'
end
function K.Price(c,r,itemID)
 local plan=K.Plan(c,r);if not plan then return nil,'Mail receipt evidence is incomplete.'end
 local part;for _,v in ipairs(plan.components)do if v.items[itemID]then if part then return nil,'Multiple envelopes contribute this item; price ordering is unresolved.'end;part=v end end
 if not part then return nil,'This item has no linked envelope.'end
 local data=c.records[part.record].mailData;local quantity=part.beforeItems[itemID];local types=0;for _ in pairs(part.beforeItems)do types=types+1 end
 if types~=1 then return nil,'A bundled price needs an explicit allocation across item types.'end
 local invoice=data.invoice
 local named=invoice and type(invoice.itemName)=='string';for _,item in ipairs(data.items)do if not invoice or item.name~=invoice.itemName then named=false end end
 if named and invoice.type=='buyer'and data.cod==0 and integer(invoice.bid,0,9007199254740991)and integer(invoice.count,1)and quantity<=invoice.count then
  return {amount=invoice.bid,quantity=invoice.count,offset=invoice.count-quantity,envelope=part.record},'Cost inferred from the reported auction purchase invoice; no additional gold transaction is created.'
 end
 if part.cod>0 and part.items[itemID]==quantity then
  local cash=K.Cash(c,r);if not cash then return nil,'The COD payment does not match the wallet evidence.'end
  for _,w in ipairs(cash.wallets)do if w.source~='mail'or(w.quality~='inferred'and w.quality~='confirmed')then return nil,'The COD payment source is unknown or disputed.'end end
  return {amount=part.cod,quantity=quantity,offset=0,envelope=part.record},'Cost inferred from a full single-item COD collection and matching payment.'
 end
 return nil,'No complete purchase invoice or supported COD payment establishes an acquisition cost.'
end
local affecting={mail_collection=true,inventory=true,inventory_gap=true,bank=true,merchant=true,trade=true,trade_offer=true,trade_notice=true}
local function linkRecord(c,r,saved)
 local prior=dependencies[c]and dependencies[c][r.id]
 local batches=r.kind=='mail_collection'and{r}or Q.Range(c,r.ts-1015,r.ts+1,'mail_collection')
 local function include(id)
  local active=c.records[id]
  if active and active.kind=='mail_collection' and active.character==c.id and not contains(batches,active)then batches[#batches+1]=active end
 end
 if saved then for id in pairs(saved)do include(id)end else include(c.state.activeMailCollection)end
 local parent=r.trade and c.records[r.trade]or r;local refs=E.Copy(parent.refs or{});refs[#refs+1]=r.inventoryRecord or r.id
 local linked={};for key in pairs(prior or{})do local batch=c.records[key]
  if batch and batch.kind=='mail_collection'then linked[key]=true;if not contains(batches,batch)then batches[#batches+1]=batch end end
 end
 for _,id in ipairs(refs)do local inv=c.records[id];if inv and inv.kind=='inventory'then for _,key in ipairs(inv.mailCandidates or{})do
  local batch=c.records[key];if batch then linked[batch.id]=true;if not contains(batches,batch)then batches[#batches+1]=batch end end
 end end end
 for _,batch in ipairs(batches)do
  local affects=batch.settledAt and batch.inventoryAnchor and(linked[batch.id]or r.ts>=batch.inventoryAnchor.ts and r.ts<=batch.settledAt)
  if affects then depend(c,batch,r.id)end
  local plan=K.Plan(c,batch);if plan then for _,inv in ipairs(plan.records)do
  if not contains(inv.mailCandidates,batch.id)then
   inv.mailCandidates=inv.mailCandidates or{};inv.mailCandidates[#inv.mailCandidates+1]=batch.id
   inv.refs=inv.refs or{};if not contains(inv.refs,batch.id)then inv.refs[#inv.refs+1]=batch.id end
   batch.refs=batch.refs or{};if not contains(batch.refs,inv.id)then batch.refs[#batch.refs+1]=inv.id end
   S.Changed(c,inv);S.Changed(c,batch)
  end
 end end
  if r.kind~='mail_collection'and affects then S.Changed(c,batch)end
 end
end
local update=E.Inventory.CostLinkHandler(K,'MailCosts',function(c,r,receipt)
 if E.AuctionPreparation and E.AuctionPreparation.ReturnReviewReceipt(c,r,receipt)then return false end
 return affecting[r.kind]or affecting[Q.PreviousKind(c,r.id)]or dependencies[c]and dependencies[c][r.id]
end,linkRecord,function(c)return c.state.activeMailCollection end)
E.On('RECORD_ADDED',update);E.On('RECORD_CHANGED',update)
function K.Project(c,r)
 if r.kind~='cost_lot'or r.source~='inventory observation'then return end
 local inv=c.records[r.evidence];local batch=K.Resolve(c,inv);if not batch then return end
 local price=K.Price(c,batch,r.itemID);local part=K.Plan(c,batch).rows[inv.id][r.itemID]
 if not price or not part or part.quantity~=r.quantity then return end
 local copy=E.Copy(r);copy.cost=F.Part(price.amount,price.quantity,price.offset+part.offset,r.quantity)
 copy.baseCost,copy.baseQuantity,copy.baseOffset=price.amount,price.quantity,price.offset+part.offset
 copy.mailReceipt=batch.id;copy.quality='inferred';copy.title='Inferred mail acquisition cost';return {copy}
end
