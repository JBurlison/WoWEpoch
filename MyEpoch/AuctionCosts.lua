local _,E=...
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.AuctionCosts=K
-- A derived posting association, never an accepted-action callback or a sale.
local caches=setmetatable({},{__mode='k'})
local relevant={auction=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,merchant=true,
 trade=true,trade_offer=true,trade_notice=true,mail_collection=true,mail=true,mail_scan=true,mail_request=true,mail_notice=true,mail_draft=true,gold=true,money_evidence=true,wallet_window=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function counts(r)
 if not r or r.kind~='inventory'or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
 local out={};for _,map in ipairs({r.carried,r.equipment})do for id,n in pairs(map)do
  if not integer(id,1)or not integer(n)or n>67108864 then return end;out[id]=(out[id]or 0)+n;if out[id]>67108864 then return end
 end end;return out
end
local function equal(a,b)
 for id,n in pairs(a)do if n~=(b[id]or 0)then return false end end
 for id,n in pairs(b)do if n~=(a[id]or 0)then return false end end;return true
end
local ownedIndexes=setmetatable({},{__mode='k'})
local function invalidateOwned(c)ownedIndexes[c]=nil end
E.On('RECORD_ADDED',invalidateOwned);E.On('RECORD_CHANGED',invalidateOwned);E.On('RECORDS_REMOVED',invalidateOwned)
local function firstOwned(c,id,session)
 local index=ownedIndexes[c]
 if not index or index.revision~=c.revision then
  index={revision=c.revision,ids={}}
  for _,v in ipairs(Q.Kind(c,'auction'))do
   if v.source=='owned'and integer(v.auctionID,1)and v.session~=nil then
    local sessions=index.ids[v.auctionID];if not sessions then sessions={};index.ids[v.auctionID]=sessions end
    local first=sessions[v.session];if not first or v.ts<first then sessions[v.session]=v.ts end
   end
  end
  ownedIndexes[c]=index
 end
 local sessions=index.ids[id];return sessions and sessions[session]
end
local function build(c,r)
 if not r or r.kind~='auction'or r.source~='post'or r.character~=c.id or not r.session then return end
 local d=r.auctionData or{};local a=r.inventoryAnchor
 if d.requestMethod~='PostItem'and d.requestMethod~='PostCommodity'then return end
 if d.coverage~='request arguments observed'or not integer(r.itemID,1)or d.itemID~=r.itemID or not integer(d.quantity,1)or d.quantity>67108864
  or not a or a.session~=r.session or a.scope~='bags and equipment'or not integer(a.sequence)or type(a.ts)~='number'
  or a.ts>r.ts or r.ts-a.ts>15 or a.sequence>=S.Sequence(r)then return end
 local base=c.records[a.record];local current=counts(base)
 if not current or base.character~=c.id or base.session~=r.session or base.ts>a.ts or S.Sequence(base)>a.sequence or(current[r.itemID]or 0)<d.quantity then return end
 local created,listing;local observations=Q.Range(c,r.ts-5,r.ts+6,'auction')
 for _,v in ipairs(observations)do if v.session==r.session then
  -- Even an unreadable competing request can own the creation notification.
  if v.source=='post'and v.id~=r.id then return end
  if v.source=='created'and v.ts>=r.ts then
   if created or not integer(v.auctionID,1)or not v.auctionData or v.auctionData.event~='AUCTION_HOUSE_AUCTION_CREATED'then return end;created=v
  end
 end end
 if not created then return end
 for _,v in ipairs(observations)do if v.session==r.session and v.source=='owned'and v.auctionID==created.auctionID then
  if v.ts<r.ts then return end
  if not listing or S.Before(v,listing)then listing=v end
 end end
 local ld=listing and listing.auctionData
 if not ld or listing.itemID~=r.itemID or ld.quantity~=d.quantity or(ld.statusLabel~='Active'and ld.statusLabel~='Reported sold')then return end
 -- A prior observation of this ID in the same session contradicts a new post.
 local prior=firstOwned(c,created.auctionID,r.session);if prior and prior<r.ts then return end
 local successors={}
 for _,v in ipairs(Q.Range(c,a.ts,r.ts+6,'inventory'))do if v.previousRecord and S.Sequence(v)>a.sequence then
  if successors[v.previousRecord]~=nil then successors[v.previousRecord]=false else successors[v.previousRecord]=v end
 end end
 local plan={request=r,created=created,listing=listing,records={},rows={},quantity=d.quantity,itemID=r.itemID,refs={base.id,created.id,listing.id}}
 local previous,stamp,sequence,left=base.id,a.ts,a.sequence,d.quantity
 while left>0 do
  local v=successors[previous];local actual=counts(v)
  if not actual or v.character~=c.id or v.baseline or v.session~=r.session or S.Sequence(v)<=sequence or S.Sequence(v)<=S.Sequence(r)
   or not v.observedFrom or v.observedFrom<stamp or v.ts<v.observedFrom or v.ts<r.ts or(v.accountingTime or v.ts)~=v.ts
   or not E.Same(base.equipment,v.equipment)or #(v.items or{})~=1 then return end
  local row=v.items[1]
  if row.itemID~=r.itemID or not integer(row.before)or not integer(row.after)or row.before~=(current[r.itemID]or 0)
   or row.delta~=row.after-row.before or row.delta>=0 or -row.delta>left then return end
  current[r.itemID]=row.after;if not equal(current,actual)then return end
  plan.records[#plan.records+1]=v;plan.rows[v.id]={quantity=-row.delta,offset=d.quantity-left};plan.refs[#plan.refs+1]=v.id
  left=left+row.delta;previous,stamp,sequence=v.id,v.ts,S.Sequence(v)
 end
 if successors[previous]~=nil then return end
 for _,gap in ipairs(Q.Range(c,a.ts,r.ts+6,'inventory_gap'))do if S.Sequence(gap)>a.sequence then return end end
 return plan
end
function K.Plan(c,r)
 if not r then return end;local cache=caches[c];if not cache then cache={};caches[c]=cache end
 if cache[r.id]==nil then cache[r.id]=build(c,r)or false end;return cache[r.id]or nil
end
function K.Claim(c,inv)
 if not inv or inv.kind~='inventory'then return false end
 for _,r in ipairs(Q.Range(c,inv.ts-5,inv.ts+1,'auction'))do local p=K.Plan(c,r);if p and p.rows[inv.id]then return true end end
 return false
end
function K.Resolve(c,r)
 local plan=K.Plan(c,r);if not plan then return nil,'No unique posting and inventory match.'end
 -- Rejection hides the derived association, never the conflicting source
 -- evidence. Claim intentionally continues to use Plan so another matcher
 -- cannot relabel the same outflow merely because this inference was rejected.
 if r.rejectPostingCosts then return nil,'This inferred posting-cost match was rejected.'end
 for _,inv in ipairs(plan.records)do
  if E.CraftCosts and E.CraftCosts.Claim(c,inv)then return nil,'Crafting and auction evidence overlap; item costs remain unknown.'end
  if E.SentMailCosts and E.SentMailCosts.Claim(c,inv)then return nil,"Outgoing mail and auction evidence overlap."end
  if E.TradeCosts.Claim(c,inv)or E.MailCosts.Claim(c,inv)then return nil,'Trade or mail also claims this inventory interval.'end
  for _,id in ipairs(inv.merchantCandidates or{})do if E.CostMatch.Compatible(c,inv,c.records[id])then return nil,'Merchant evidence overlaps this posting.'end end
  for _,bank in ipairs(Q.Range(c,inv.ts,inv.ts+1,'bank'))do if bank.inventoryRecord==inv.id and #(bank.transfers or{})>0 then return nil,'Bank evidence overlaps this posting.'end end
 end
 return plan,'Inferred from a unique request, new-auction notification, listing and continuous inventory changes.'
end
function K.Info(c,r)
 local plan,reason=K.Resolve(c,r);if not plan then return nil,reason end
 local out={plan=plan,quantity=plan.quantity,knownCost=0,unknownQuantity=0,parts={},movements={}}
 for _,inv in ipairs(plan.records)do local raw
  for _,id in ipairs(inv.refs or{})do local v=c.records[id]
   if v and v.kind=='stock_move'and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==plan.itemID and v.quantity==plan.rows[inv.id].quantity then
    if raw then return nil,'More than one accounting movement claims this inventory record.'end;raw=v
   end
  end
  if not raw then return nil,'The original inventory accounting movement is unavailable.'end
  local info=F.MovementAllocation(c,raw)
  if not info then return nil,'The original FIFO allocation is unavailable.'end
  out.movements[#out.movements+1]=raw;out.knownCost=out.knownCost+info.knownCost;out.unknownQuantity=out.unknownQuantity+info.unknownQuantity
  for _,part in ipairs(info.allocations)do out.parts[#out.parts+1]=E.Copy(part)end
 end
 if out.unknownQuantity==0 then out.cost=out.knownCost end
 return out,reason
end
local linking=setmetatable({},{__mode='k'})
local function linkAt(c,ts)
 for _,post in ipairs(Q.Range(c,ts-5,ts+6,'auction'))do local p=K.Plan(c,post)
  if p then local changed=false;local seen={};for _,id in ipairs(post.refs or{})do seen[id]=true end;post.refs=post.refs or{}
   for _,id in ipairs(p.refs)do if not seen[id]then post.refs[#post.refs+1]=id;seen[id]=true;changed=true end end
   if changed then S.Changed(c,post)end
  end
 end
end
function K.LinkAt(c,ts)
 if linking[c]then return end
 linking[c]=true
 local ok,why=pcall(linkAt,c,ts)
 linking[c]=nil
 if not ok then error(why,0)end
end
local function link(c,r)
 if (r.kind~='auction'and r.kind~='inventory')or E.db.characters[c.id]~=c then return end
 if Q.EnsureWarm(c)=='ready'then K.LinkAt(c,r.ts)
 else E.AuctionDeposits.Defer(c,r.ts,true)end
end
E.On('RECORD_ADDED',link);E.On('RECORD_CHANGED',link)
