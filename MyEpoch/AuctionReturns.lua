local _,E=...
local R,S,Q={},E.Store,E.Query;E.AuctionReturns=R
local function int(n,min)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=67108864 end
local function own(c,r,kind)return E.db.characters[c.id]==c and r and c.records[r.id]==r and r.character==c.id and r.kind==kind end
local caches=setmetatable({},{__mode='k'})
local tickets=setmetatable({},{__mode='k'})
local function invalidate(c)caches[c]=nil end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',invalidate)
-- Mail has no authored returned-auction identity. These are proposals only;
-- the user must confirm the exact parcel's origin before any cost projection.
local ownedSources={owned=true,created=true,cancelled=true,expired=true,sale_notice=true}
local function timeKnown(ts)return type(ts)=='number'and ts==ts and ts>-math.huge and ts<math.huge end
local function order(c,r)
 -- Do not infer historical observation order from an ID suffix or a missing
 -- counter. Both creation and any explicitly reserved observation must fit
 -- this character's monotonic recorded counter.
 local seq=r and r.sequence;local n=seq;if r and r.observationSequence~=nil then n=r.observationSequence end
 local function valid(v)return type(v)=='number'and v==v and v%1==0 and v>=1 and v<=9007199254740991 end
 if not valid(seq)or not valid(n)or not valid(c.seq)or n>seq or seq>c.seq then return end
 return n
end
local function groups(c)
 local out={};for _,r in ipairs(Q.Kind(c,'auction'))do if r.character==c.id and ownedSources[r.source]then
  local key=r.auctionID or('unknown:'..r.id);local g=out[key]
  if not g then g={id=r.auctionID,rows={},created={},notices={}};out[key]=g end
  if r.source=='sale_notice'then g.notices[#g.notices+1]=r else g.rows[#g.rows+1]=r end
  local d=r.auctionData or{}
  if r.source=='owned'then
   if not int(r.itemID,1)or d.itemID~=r.itemID or not int(d.quantity,1)or d.auctionID~=r.auctionID or d.coverage~='observed'then g.bad=true end
   if g.itemID and g.itemID~=r.itemID then g.bad=true end
   if g.quantity and g.quantity~=d.quantity then g.varied=true end
   g.itemID,g.quantity=r.itemID,d.quantity
   if d.statusLabel~='Active'then g.bad=true end
   local sequence=order(c,r)
   if not sequence or not timeKnown(r.ts)then g.unknownStart=true
   else g.firstOrder=math.min(g.firstOrder or sequence,sequence);g.firstTime=math.min(g.firstTime or r.ts,r.ts)end
   if not g.active or S.Before(r,g.active)then g.active=r end
  elseif r.source=='created'then g.created[#g.created+1]=r
  elseif r.source=='cancelled'or r.source=='expired'then
   if g.closed then g.bad=true end;g.closed=r
   if d.event~=(r.source=='cancelled'and'AUCTION_CANCELED'or'AUCTION_HOUSE_AUCTIONS_EXPIRED')or d.auctionID~=r.auctionID then g.bad=true end
  end
 end end
 for _,g in pairs(out)do
  if not g.active or not g.closed or not g.id or not S.Before(g.active,g.closed)then g.bad=true end
  if g.closed then for _,r in ipairs(g.rows)do
   if r.source=='owned'and(r.lastObservedAt or r.ts)>g.closed.ts then g.bad=true end
  end end
 end;return out
end
local function dense(rows,count,limit,work)
 if type(rows)~='table'or not int(count)or count>limit or #rows~=count then return false end
 local n=0;for key in pairs(rows)do if work then work()end
  if not int(key,1)or key>count then return false end;n=n+1
 end;return n==count
end
-- Shared by matching and protection: observed attachments are exhaustive only
-- with a complete, dense header/slot census. Losing identity adds a wildcard;
-- it can never make a competing collection disappear.
local function mailCandidates(c,row,emit,work)
 if not own(c,row,'mail')or type(row.mailData)~='table'then emit(nil);return end
 local d=row.mailData;local complete=d.complete==true and dense(d.items,d.itemCount,16,work)
 local slots={};local ids={}
 if type(d.items)=='table'then for _,item in pairs(d.items)do if work then work()end
  if type(item)~='table'then complete=false
  else
   local identified=item.isCurrency==true and int(item.currencyID,1)and item.itemID==nil
    or item.isCurrency~=true and int(item.itemID,1)and item.currencyID==nil
   if not item.complete or not identified or not int(item.quantity,1)or not int(item.slot,1)or item.slot>16 or slots[item.slot]then complete=false end
   if item.slot then slots[item.slot]=true end
   if int(item.itemID,1)then ids[item.itemID]=true end
  end
 end end
 if not complete then emit(nil);return end
 -- Only a fully readable purchase parcel can be positively excluded.
 if type(d.invoice)=='table'and d.invoice.type=='buyer'then return end
 for id in pairs(ids)do if work then work()end;emit(id,row.ts,row)end
end
local function collectionCandidates(c,b,emit,work)
 local scan=c.records[b.beforeScan]
 if not own(c,scan,'mail_scan')or scan.complete~=true or scan.session~=b.session or scan.visit~=b.visit
  or not int(scan.loaded)or scan.loaded~=scan.total or not dense(scan.entries,scan.loaded,100,work)then emit(nil)end
 if not scan or type(scan.entries)~='table'then return end
 local seen={};for _,id in pairs(scan.entries)do if work then work()end
  local row=c.records[id]
  if seen[id]or not own(c,row,'mail')or row.scan~=scan.id or row.session~=b.session or row.visit~=b.visit then emit(nil)
  else mailCandidates(c,row,emit,work)end
  seen[id]=true
 end
end
local function coverage(c,b)
 local out={items={}}
 collectionCandidates(c,b,function(id,ts,row)
  if not id then out.unknown=true
  else
   local item=out.items[id]or{};out.items[id]=item;local sequence=order(c,row)
   if not sequence or not timeKnown(ts)then item.unknownOrder=true
   else item.lastOrder=math.max(item.lastOrder or sequence,sequence);item.lastTime=math.max(item.lastTime or ts,ts)end
  end
 end)
 return out
end
local function possible(observed,g)
 if observed.unknown then return true end
 if g.itemID then local item=observed.items[g.itemID];if not item then return false end
  -- Exclusion needs both explicit earlier observation order and compatible
  -- wall time. A later observation with a rolled-back clock stays a rival;
  -- missing order and contradictory clocks never increase certainty.
  return item.unknownOrder or g.unknownStart or not item.lastOrder or not g.firstOrder
   or item.lastOrder>=g.firstOrder or item.lastTime>g.firstTime
 end
 return next(observed.items)~=nil
end
local function itemPayload(link,id)
 if type(link)~='string'then return end
 local payload=link:match('^|H(item:[^|]+)|h%[[^|]*%]|h$')
  or link:match('^|c%x%x%x%x%x%x%x%x|H(item:[^|]+)|h%[[^|]*%]|h|r$')
 if payload and tonumber(payload:match('^item:(%d+):')or payload:match('^item:(%d+)$'))==id then return payload end
end
local function parcel(c,b)
 if not own(c,b,'mail_collection')then return end
 for _,key in ipairs({'beforeScan','afterScan'})do local scan=c.records[b[key]]
  if not own(c,scan,'mail_scan')then return end
  for _,id in ipairs(scan.entries or{})do if not own(c,c.records[id],'mail')then return end end
 end
 for _,key in ipairs({'requests','notices'})do local kind=key=='requests'and'mail_request'or'mail_notice'
  for _,id in ipairs(b[key]or{})do if not own(c,c.records[id],kind)then return end end
 end
 local p=E.MailCosts.Plan(c,b)
 if not p or #p.components~=1 or p.gold~=0 then return end
 local part=p.components[1];local e=c.records[part.record];local d=e and e.mailData
 if not own(c,e,'mail')or not d or d.invoice or not dense(d.items,d.itemCount,16)
  or d.money~=0 or d.cod~=0 or part.money~=0 or part.cod~=0 then return end
 local itemID,quantity;for id,n in pairs(part.beforeItems)do if itemID then return end;itemID,quantity=id,n end
 if not int(itemID,1)or not int(quantity,1)or part.items[itemID]~=quantity then return end
 local stacked
 if #d.items~=1 then
  -- Multiple attachment slots can be one returned commodity. Require one
  -- complete auto-loot of the whole envelope and an identical item payload.
  local request=#b.requests==1 and c.records[b.requests[1]]
  if not request or request.method~='AutoLootMailItem'
   or #d.items<2 or #part.removed~=#d.items or d.invoiceUnavailable then return end
  for _,item in ipairs(d.items)do
   local key=itemPayload(item.itemLink,itemID)
   if item.itemID~=itemID or not key or stacked and key~=stacked then return end
   stacked=key
  end
 end
 if E.MailCosts.Resolve(c,p.records[1])~=b then return end
 return {collection=b.id,envelope=e.id,itemID=itemID,quantity=quantity,plan=p,parcel=e,stackedPayload=stacked}
end
-- A smaller parcel alone cannot identify the unsold tail of a posting.
-- Follow the collector's actual previous-observation chain through every
-- owned row to the closure, checking both order and wall time at each edge.
-- A notice proves some stock was reported sold but contains no quantity.
-- Each notice must fit a later observed decrease from its exact active row.
-- Without that witness the remaining parcel could overlap sold stock.
local function noticesFit(c,g,request)
 if #g.notices==0 then return true end
 local nextOwned={}
 for _,row in ipairs(g.rows)do
  if row.source=='owned'and row.previousObservation then nextOwned[row.previousObservation]=row end
 end
 local used={}
 for _,notice in ipairs(g.notices)do
  local prior=c.records[notice.previousObservation];local later=prior and nextOwned[prior.id]
  local d=notice.auctionData or{}
  if not later or prior.source~='owned'or prior.auctionID~=g.id or notice.session~=request.session
   or d.auctionID~=g.id or d.event~='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION'or d.notification~='AuctionSold'
   or not order(c,prior)or not order(c,notice)or not order(c,later)or order(c,prior)>=order(c,notice)or order(c,notice)>=order(c,later)
   or not timeKnown(notice.ts)or not timeKnown(prior.ts)or not timeKnown(prior.lastObservedAt or prior.ts)or not timeKnown(later.ts)
   or math.max(prior.ts,prior.lastObservedAt or prior.ts)>notice.ts or notice.ts>later.ts then return false end
  local count=(used[prior.id]or 0)+1;used[prior.id]=count
  if not int(prior.auctionData.quantity,1)or not int(later.auctionData.quantity,1)
   or prior.auctionData.quantity-later.auctionData.quantity<count then return false end
 end
 return true
end
local function remainingOffset(c,g,p,request,plan)
 if not noticesFit(c,g,request)then return end
 if not g.varied then
  if plan.quantity==p.quantity and g.quantity==p.quantity then return 0 end
  return
 end
 if request.auctionData.requestMethod~='PostCommodity' or plan.quantity<=p.quantity
  or #g.created~=1 or plan.created~=g.created[1] or plan.created.previousObservation~=nil
  or plan.created.auctionData.auctionID~=g.id or not timeKnown(p.parcel.ts)then return end
 local function precedes(a,b)
  local first,last=order(c,a),order(c,b)
  local through=a.lastObservedAt or a.ts
  return first and last and first<last and timeKnown(a.ts)and timeKnown(through)and timeKnown(b.ts)
   and a.ts<=through and through<=b.ts
 end
 if not precedes(request,plan.created)or not precedes(g.closed,p.parcel)then return end
 local nextRow=g.closed
 local expected=p.quantity
 local count=0
 while nextRow.previousObservation~=plan.created.id do
  local row=c.records[nextRow.previousObservation]
  if not own(c,row,'auction')or row.source~='owned'or row.auctionID~=g.id or row.session~=request.session
   or nextRow.session~=request.session or not precedes(row,nextRow) then return end
  local data=row.auctionData
  if type(data.itemKey)~='table' or data.itemKey.itemID~=p.itemID then return end
  local quantity=data.quantity
  if count==0 and quantity~=expected or quantity<expected then return end
  expected=quantity
  count=count+1
  nextRow=row
 end
 if count+2~=#g.rows or nextRow~=plan.listing or expected~=plan.quantity
  or not precedes(plan.created,nextRow)then return end
 return plan.quantity-p.quantity
end
local function posting(c,g,p)
 local candidates={};for _,r in ipairs(Q.Kind(c,'auction'))do if r.source=='post'and r.character==c.id then
  local plan=E.AuctionCosts.Plan(c,r);local may=plan and plan.created.auctionID==g.id
  if not plan and(not r.itemID or r.itemID==p.itemID)then
   for _,made in ipairs(g.created)do if r.session==made.session and r.ts<=made.ts and made.ts<=r.ts+6 then may=true end end
  end
  if may then candidates[#candidates+1]={record=r,plan=plan}end
 end end
 if #candidates~=1 then return end
 local r,plan=candidates[1].record,candidates[1].plan
 if not plan or plan.itemID~=p.itemID or not S.Before(r,g.closed)then return end
 if not own(c,plan.created,'auction')or not own(c,plan.listing,'auction')then return end
 if p.stackedPayload and (r.auctionData.requestMethod~='PostCommodity'
  or itemPayload(r.auctionData.itemLink,p.itemID)~=p.stackedPayload
  or itemPayload(plan.listing.auctionData.itemLink,p.itemID)~=p.stackedPayload)then return end
 if E.AuctionCosts.Resolve(c,r)~=plan then return end
 local offset=remainingOffset(c,g,p,r,plan)
 if offset==nil then return end
 local movements,total={},0
 for _,inv in ipairs(plan.records)do local raw
  for _,id in ipairs(inv.refs or{})do local v=c.records[id]
   if own(c,v,'stock_move')and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==p.itemID and v.quantity==plan.rows[inv.id].quantity then
    if raw then return end;raw=v
   end
  end
  if not raw or not S.Before(raw,p.parcel)then return end
  movements[#movements+1]=raw;total=total+raw.quantity
 end
 if total~=plan.quantity then return end
 return r,plan,movements,offset
end
local function index(c)
 local old=caches[c];if old and old.revision==c.revision then return old end
 local out={revision=c.revision,byBatch={},byEnvelope={}};local gs=groups(c);local batches=Q.Kind(c,'mail_collection')
 local claims={};for _,b in ipairs(batches)do local pool={};local observed=coverage(c,b)
  for key,g in pairs(gs)do if possible(observed,g)then pool[#pool+1]=g;claims[key]=(claims[key]or 0)+1 end end
  out.byBatch[b.id]={pool=pool}
 end
 for _,b in ipairs(batches)do local entry=out.byBatch[b.id];local p=parcel(c,b);local g=#entry.pool==1 and entry.pool[1]
  if p then out.byEnvelope[p.envelope]=entry;entry.proposal=p end
  if p and g and claims[g.id]==1 and not g.bad and g.itemID==p.itemID and S.Before(g.closed,p.parcel)then
   local post,plan,movements,offset=posting(c,g,p)
   if post then p.posting,p.auctionID,p.closure,p.movements,p.postPlan=post.id,g.id,g.closed.id,movements,plan
    p.postedQuantity,p.unresolvedQuantity=plan.quantity,offset
    p.quality='inferred';p.originQuality='requires user confirmation';entry.valid=true
   end
  end
 end
 caches[c]=out;return out
end
function R.Proposal(c,envelope)
 if not own(c,envelope,'mail')then return nil,'Select a retained parcel belonging to this character.'end
 local entry=index(c).byEnvelope[envelope.id]
 if not entry or not entry.valid then return nil,'No unique matching posting, closure and collected parcel are available.'end
 local p=entry.proposal
 local proposal={envelope=p.envelope,collection=p.collection,posting=p.posting,auctionID=p.auctionID,closure=p.closure,itemID=p.itemID,quantity=p.quantity,
  postedQuantity=p.postedQuantity,unresolvedQuantity=p.unresolvedQuantity,
  quality='inferred',originQuality='requires user confirmation',warning='The client does not identify auction return mail. Confirm only if this parcel is the returned stock from this listing.'}
 tickets[proposal]={owner=c,envelope=envelope,posting=p.posting,revision=c.revision};return proposal
end
-- Version 1 confirms a full posting. Partial returns bind the reviewed
-- quantity and closure so corrections cannot silently change the FIFO tail.
function R.ReviewBasis(p)
 if p.unresolvedQuantity>0 then
  return {version=2,posting=p.posting,postedQuantity=p.postedQuantity,quantity=p.quantity,closure=p.closure,collection=p.collection}
 end
 return {version=1,posting=p.posting}
end
function R.MatchesBasis(review,p)
 if type(review)~='table'then return false end
 for key,value in pairs(R.ReviewBasis(p))do if review[key]~=value then return false end end
 return true
end
function R.Confirm(c,envelope,proposal)
 if type(proposal)~='table'then return false,'Inspect a fresh proposal before confirming.'end
 local ticket=tickets[proposal];tickets[proposal]=nil
 if not ticket or ticket.owner~=c or ticket.envelope~=envelope or ticket.revision~=c.revision then return false,'The review changed; inspect a fresh proposal.'end
 local p,why=R.Proposal(c,envelope);if not p or p.posting~=ticket.posting then return false,why or'The proposed posting changed.'end
 local review=R.ReviewBasis(p)
 review.contents=E.Copy(envelope.mailData)
 envelope.auctionReturnReview=review
 S.Changed(c,envelope);return true
end
function R.Clear(c,envelope)
 if not own(c,envelope,'mail')then return false end
 if envelope.auctionReturnReview~=nil then envelope.auctionReturnReview=nil;S.Changed(c,envelope)end;return true
end
function R.Project(c,r)
 if not own(c,r,'cost_lot')or r.source~='inventory observation'then return end
 local inv=c.records[r.evidence];local batch=E.MailCosts.Resolve(c,inv);if not batch then return end
 local entry=index(c).byBatch[batch.id];if not entry or not entry.valid then return end
 local p=entry.proposal;local review=p.parcel.auctionReturnReview
 if not R.MatchesBasis(review,p)or not E.Same(review.contents,p.parcel.mailData)then return end
 local part=p.plan.rows[inv.id][r.itemID]
 if r.itemID~=p.itemID or not part or part.quantity~=r.quantity then return end
 -- One accounting receipt per inventory/item; duplicate raw rows never create
 -- a second restoration or consume a second interval.
 local found;for _,id in ipairs(inv.refs or{})do local v=c.records[id]
  if v and v.kind=='cost_lot'and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==r.itemID then if found then return end;found=v end
 end
 if found~=r then return end
 local copy=E.Copy(r);copy.kind='stock_return';copy.returnParts={};copy.auctionReturn=p.envelope;copy.quality='inferred';copy.title='Returned auction stock (origin confirmed; cost inferred)'
 local start=p.unresolvedQuantity+part.offset
 local offset=0;for _,move in ipairs(p.movements)do
  local first,last=math.max(start,offset),math.min(start+part.quantity,offset+move.quantity)
  if last>first then copy.returnParts[#copy.returnParts+1]={sale=move.id,offset=first-offset,quantity=last-first}end;offset=offset+move.quantity
 end
 return {copy}
end
-- Item-connected candidates survive together. Unreadable identity is a wildcard,
-- not permission to remove a rival and manufacture uniqueness after cleanup.
local evidenceKinds={auction=true,mail=true,mail_collection=true,mail_scan=true,mail_request=true,mail_notice=true,
 inventory=true,inventory_gap=true,bank=true,bank_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,
 craft_request=true,craft_begin=true,craft_result=true,crafted=true,mail_draft=true,stock_move=true,cost_lot=true}
function R.Retention(c,r,add,state)
 if r.kind~='auction'and r.kind~='mail'and r.kind~='mail_collection'then return end
 local function tick()if state.work then state.work()end end
 local wildcard='unknown';local ix=state.auctionReturnRetention
 if not ix then
  ix={items={},members={},auctions={},seen={},intervals={},rows={}};state.auctionReturnRetention=ix
  local function join(id,key)
   key=key or wildcard;ix.items[key]=ix.items[key]or{};ix.items[key][id]=true
   ix.members[id]=ix.members[id]or{};ix.members[id][key]=true
  end
  for id,row in pairs(c.records)do tick()
   if evidenceKinds[row.kind]then ix.rows[#ix.rows+1]=row end
   if row.kind=='auction'and(row.source=='owned'or row.source=='post')then
    local key=int(row.itemID,1)and row.itemID or wildcard;join(id,key)
    if row.auctionID then local a=ix.auctions[row.auctionID]or{};ix.auctions[row.auctionID]=a;a[key]=true end
   elseif row.kind=='mail'then mailCandidates(c,row,function(key)join(id,key)end,tick)
   end
  end
  for id,row in pairs(c.records)do tick()
   if row.kind=='auction'and ownedSources[row.source]then
    local keys=ix.auctions[row.auctionID];if keys then for key in pairs(keys)do tick();join(id,key)end else join(id,wildcard)end
   elseif row.kind=='mail_collection'then collectionCandidates(c,row,function(key)join(id,key)end,tick)
   end
  end
  if state.work then E.RetentionWork.Sort(ix.rows,S.Before,state.work)else table.sort(ix.rows,S.Before)end
 end
 local function expand(key)
  tick();if ix.seen[key]then return end;ix.seen[key]=true
  for id in pairs(ix.items[key]or{})do tick();if id~=r.id then add(id,{kind='linked',source=r.id})end end
 end
 local keys=ix.members[r.id]
 if keys then
  for key in pairs(keys)do expand(key)end;expand(wildcard)
  if keys[wildcard]then for key in pairs(ix.items)do expand(key)end end
 end
 if r.kind=='mail_collection'and not ix.intervals[r.id]then
  ix.intervals[r.id]=true
  -- These fields are source ownership even if an incomplete collector record
  -- has not yet appended its ordinary refs. Keep the scan and observed rows.
  for _,key in ipairs({'beforeScan','afterScan'})do tick();local scan=c.records[r[key]]
   if scan then add(scan.id,{kind='linked',source=r.id})
    if type(scan.entries)=='table'then for _,id in pairs(scan.entries)do tick();if c.records[id]then add(id,{kind='linked',source=r.id})end end end
   end
  end
  for _,key in ipairs({'requests','notices'})do for _,id in ipairs(r[key]or{})do tick();if c.records[id]then add(id,{kind='linked',source=r.id})end end end
  local first=r.inventoryAnchor and r.inventoryAnchor.ts or r.ts-15
  if type(first)~='number'or first>r.ts or first<r.ts-15 then first=r.ts-15 end
  local through=type(r.settledAt)=='number'and r.settledAt+1 or(r.lastRequestAt or r.ts)+6
  local lo,hi=1,#ix.rows+1
  while lo<hi do tick();local mid=math.floor((lo+hi)/2);if ix.rows[mid].ts<first then lo=mid+1 else hi=mid end end
  while ix.rows[lo]and ix.rows[lo].ts<through do tick();local row=ix.rows[lo];if row.id~=r.id then add(row.id,{kind='linked',source=r.id})end;lo=lo+1 end
 end
end
