local _,E=...
local R,S,Q,F={},E.Store,E.Query,E.Economy;E.AuctionSettlement=R
local maximum,maximumQuantity=9007199254740991,67108864
local function integer(v,min,max)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=(max or maximum)end
local function sum(a,b)if not integer(a)or not integer(b)or b>maximum-a then return end;return a+b end
local function difference(a,b)if not integer(a,-maximum)or not integer(b,-maximum)then return end
 if b<0 and a>maximum+b or b>0 and a< -maximum+b then return end;return a-b
end
local function canonical(c,r,kind)return r and c.records[r.id]==r and r.character==c.id and r.kind==kind end
local function refs(c,out,id,role)
 if type(id)=='string'and c.records[id]and not out.seen[id]then
  out.seen[id]=true;out.refs[#out.refs+1]=id;out.references[#out.references+1]={character=c.id,record=id,role=role}
 end
end
-- A slice preserves the original integer-copper allocation through split
-- posting movements. It does not claim that a partial auction sale happened.
function R.Slice(info,offset,quantity)
 if not info or not integer(info.quantity,1,maximumQuantity)or not integer(offset,0,info.quantity)
  or not integer(quantity,1,info.quantity-offset)or type(info.parts)~='table'then return nil,'Invalid allocation interval.'end
 local out={quantity=quantity,knownCost=0,unknownQuantity=0,parts={}};local position=0
 for _,part in ipairs(info.parts)do
  if not integer(part.quantity,1,maximumQuantity)or position>info.quantity-part.quantity then return nil,'Invalid posting allocation quantity.'end
  local first,last=math.max(offset,position),math.min(offset+quantity,position+part.quantity)
  if last>first then
   local copy=E.Copy(part);copy.quantity=last-first
   if part.cost~=nil then
    local total,basis,start=part.baseCost or part.cost,part.baseQuantity or part.quantity,(part.baseOffset or 0)+first-position
    if not integer(total)or not integer(basis,1,maximumQuantity)or not integer(start,0,basis-copy.quantity)then return nil,'Invalid acquisition-cost basis.'end
    copy.cost,copy.baseCost,copy.baseQuantity,copy.baseOffset=F.Part(total,basis,start,copy.quantity),total,basis,start
    out.knownCost=sum(out.knownCost,copy.cost);if out.knownCost==nil then return nil,'Allocation total exceeds exact copper precision.'end
   else copy.cost=nil;copy.baseQuantity=part.baseQuantity or part.quantity;copy.baseOffset=(part.baseOffset or 0)+first-position;out.unknownQuantity=out.unknownQuantity+copy.quantity end
   out.parts[#out.parts+1]=copy
  end
  position=position+part.quantity
 end
 if position~=info.quantity then return nil,'Posting allocation quantities do not reconcile.'end
 if out.unknownQuantity==0 then out.cost=out.knownCost end
 return out
end
local postingIndexes=setmetatable({},{__mode='k'})
local function invalidatePosting(c)postingIndexes[c]=nil end
E.On('RECORD_ADDED',invalidatePosting);E.On('RECORD_CHANGED',invalidatePosting);E.On('RECORDS_REMOVED',invalidatePosting)
local function postingIndex(c)
 local index=postingIndexes[c];if index and index.revision==c.revision then return index end
 index={revision=c.revision,created={},unknown={},pools={}}
 for _,r in ipairs(Q.Kind(c,'auction'))do if r.source=='created'then
  if integer(r.auctionID,1)then local list=index.created[r.auctionID]or{};index.created[r.auctionID]=list;list[#list+1]=r
  else index.unknown[#index.unknown+1]=r end
 end end
 postingIndexes[c]=index;return index
end
local function pool(c,index,id)
 local cached=index.pools[id];if cached then return cached end
 local out,seen,near={},{},{}
 local function add(rows,seenRows,nearRows,created)
  -- A valid Plan uses the existing six-second query bound; incomplete
  -- request/creation claims retain their stricter five-second test below.
  for _,r in ipairs(Q.Range(c,created.ts-6,created.ts+1,'auction'))do
   if r.source=='post'and r.character==c.id and r.session==created.session then
    if not seenRows[r.id]then seenRows[r.id]=true;rows[#rows+1]=r end
    local linked=nearRows[r.id]or{};nearRows[r.id]=linked;linked[#linked+1]=created
   end
  end
 end
 for _,created in ipairs(index.created[id]or{})do add(out,seen,near,created)end
 if not index.unknownPool then
  local rows,keys,links={},{},{}
  for _,created in ipairs(index.unknown)do add(rows,keys,links,created)end
  index.unknownPool={rows=rows,near=links}
 end
 table.sort(out,S.Before);cached={rows=out,near=near};index.pools[id]=cached;return cached
end
local function posting(c,link)
 local candidates={};local matched;local index=postingIndex(c)
 local selected=pool(c,index,link.auctionID)
 local seen={}
 local function consider(r)
  if seen[r.id]then return end;seen[r.id]=true
  local plan=E.AuctionCosts.Plan(c,r);local d=r.auctionData or{};local possible=false
  if plan then possible=plan.created.auctionID==link.auctionID
  elseif r.ts<=link.from then
   local differentItem=integer(r.itemID,1)and d.itemID==r.itemID and r.itemID~=link.itemID
   if not differentItem and(not integer(d.quantity,1)or d.quantity>=link.quantity)then
    local function compatible(rows)
     for _,created in ipairs(rows)do
      if created.character==c.id and r.session==created.session and created.ts>=r.ts and created.ts<=r.ts+5 then return true end
     end
    end
    possible=compatible(selected.near[r.id]or{})or compatible(index.unknownPool.near[r.id]or{})
   end
  end
  if possible then candidates[#candidates+1]=r;matched=r end
 end
 for _,r in ipairs(selected.rows)do consider(r)end
 for _,r in ipairs(index.unknownPool.rows)do consider(r)end
 table.sort(candidates,S.Before)
 if #candidates~=1 then return nil,#candidates==0 and'No unique posting allocation supports this listing.'or'Multiple possible postings claim this auction.',candidates end
 local plan=E.AuctionCosts.Plan(c,matched)
 if not plan then return nil,'The possible posting has incomplete inventory or creation evidence.',candidates end
 if plan.itemID~=link.itemID or plan.quantity~=(link.partial and link.partial.postedQuantity or link.quantity) or (link.partial and matched.id~=link.partial.posting) or matched.ts>link.from then
  return nil,'Posting and sold quantities or chronology differ; partial-sale allocation remains unresolved.',candidates
 end
 return matched,nil,candidates
end

function R.Invoice(c,envelope)
 if not canonical(c,envelope,'mail')then return nil,'The invoice must belong to this character.'end
 local link,reason=E.AuctionLinks.Invoice(c,envelope);if not link then return nil,reason end
 local batch=E.AuctionProceeds.Collection(c,c.records[link.collection]);if not batch then return nil,'Collected proceeds are no longer supported.'end
 local invoice=link.invoice
 local out={envelope=envelope.id,collection=link.collection,auctionID=link.auctionID,itemID=link.itemID,quantity=link.quantity,
  quality='inferred',itemName=invoice.itemName,buyer=invoice.buyer,gross=invoice.gross,houseCut=invoice.cut,
  depositReturned=invoice.deposit,cashCollected=invoice.received,afterHouseCut=invoice.afterCut,
  observedFrom=batch.from,observedThrough=batch.through,saleTimeFrom=link.from,saleTimeThrough=link.through,
  dateMeaning='Observed collection interval; exact sale completion time unknown',knownCost=0,unknownQuantity=link.quantity,
  feeCoverage='House cut recorded; other nonrefundable fees and posting-deposit settlement unresolved',
  completeProfit=false,rejected=envelope.rejectAuctionSettlement==true,refs={},references={},seen={}}
 for _,id in ipairs({envelope.id,link.collection,link.listing,link.active})do refs(c,out,id,'sale link')end
 for _,id in ipairs(batch.wallets)do refs(c,out,id,'cash collection')end
 local post,why,candidates=posting(c,link)
 for _,r in ipairs(candidates)do refs(c,out,r.id,'possible posting');for _,id in ipairs(r.refs or{})do refs(c,out,id,'posting evidence')end end
 if not post then out.costReason=why;out.seen=nil;return out end
 out.posting=post.id
 local info;info,why=E.AuctionCosts.Info(c,post)
 if not info then out.costReason=why;out.seen=nil;return out end
 if not info.plan or not canonical(c,info.plan.created,'auction')or not canonical(c,info.plan.listing,'auction')then
  out.costReason='Original posting creation or listing evidence does not belong to this character.';out.seen=nil;return out
 end
 for _,movement in ipairs(info.movements or{})do
  if not canonical(c,movement,'stock_move')then out.costReason='Original posting movements do not belong to this character.';out.seen=nil;return out end
 end
 for _,part in ipairs(info.parts or{})do if part.lot then
  local lot=c.records[part.lot]
  if not lot or lot.character~=c.id then out.costReason='A local acquisition lot does not belong to this character.';out.seen=nil;return out end
 end end
 if link.partial then
  refs(c,out,link.partial.notice,'terminal sale notification')
  refs(c,out,link.partial.first,'original posted quantity')
  out.partial=true;out.postedQuantity=link.partial.postedQuantity;out.fifoOffset=link.partial.offset
  out.unresolvedEarlierQuantity=link.partial.offset
 end
 local slice;slice,why=R.Slice(info,link.partial and link.partial.offset or 0,link.quantity)
 if not slice then out.costReason=why;out.overflow=true;out.seen=nil;return out end
 out.knownCost,out.unknownQuantity,out.cost,out.allocations=slice.knownCost,slice.unknownQuantity,slice.cost,slice.parts
 for _,r in ipairs(info.movements)do refs(c,out,r.id,'original inventory disposal')end
 for _,part in ipairs(slice.parts)do
  refs(c,out,part.lot,'FIFO acquisition lot')
  if part.sourceCharacter and part.sourceRecord then
   if part.sourceCharacter==c.id then refs(c,out,part.sourceRecord,'original acquisition')
   else out.references[#out.references+1]={character=part.sourceCharacter,record=part.sourceRecord,role='transferred acquisition provenance'}end
  end
 end
 out.basisComplete=out.cost~=nil
 if out.basisComplete then
  out.marginAfterHouseCut=difference(out.afterHouseCut,out.cost)
  if out.marginAfterHouseCut==nil then out.overflow=true;out.costReason='Margin exceeds exact copper precision.'end
 else out.costReason='Some sold units have unknown acquisition cost.'end
 -- Even a zero returned deposit does not establish that no other posting
 -- expense occurred. Never call this subtotal complete net profit.
 out.marginMeaning='Sale price minus recorded house cut and FIFO acquisition cost; other fees excluded'
 if envelope.rejectAuctionSettlement then
  out.rejected=true;out.marginAfterHouseCut=nil;out.costReason='The inferred sale-cost association was rejected; original evidence is preserved.'
 end
 out.seen=nil;return out
end
function R.Reject(c,r,rejected)
 if not canonical(c,r,'mail')or not r.mailData or not r.mailData.invoice or r.mailData.invoice.type~='seller'then return false end
 if (r.rejectAuctionSettlement==true)==(rejected==true)then return true end
 r.rejectAuctionSettlement=rejected and true or nil;S.Changed(c,r);return true
end
local function summarize(c,proceeds,includeRows)
 local out={rows={},linked=0,unknownBasis=0,rejected=0,unlinked=0,matchedBasis=0,knownAllocatedCost=0,
  matchedGross=0,matchedHouseCut=0,matchedCost=0,marginAfterHouseCut=0,overflow=false,
  boundary=proceeds.boundary,excluded=proceeds.excluded,dateMeaning='Observed collection interval; exact sale completion time unknown',
  feeCoverage='House cuts only; other nonrefundable fees and deposit settlement remain unresolved'}
 local seen={}
 for _,invoice in ipairs(proceeds.rows)do if not seen[invoice.envelope]then
  seen[invoice.envelope]=true
  local row=R.Invoice(c,c.records[invoice.envelope])
  if row then
   if includeRows then out.rows[#out.rows+1]=row end
   out.linked=out.linked+1
   if row.rejected then out.rejected=out.rejected+1
   else
    if row.overflow then out.overflow=true end
    out.knownAllocatedCost=sum(out.knownAllocatedCost,row.knownCost);if not out.knownAllocatedCost then out.overflow=true end
    if row.marginAfterHouseCut~=nil then
     out.matchedBasis=out.matchedBasis+1
     out.matchedGross=sum(out.matchedGross,row.gross);out.matchedHouseCut=sum(out.matchedHouseCut,row.houseCut);out.matchedCost=sum(out.matchedCost,row.cost)
     out.marginAfterHouseCut=difference(out.marginAfterHouseCut,-row.marginAfterHouseCut)
     if not out.matchedGross or not out.matchedHouseCut or not out.matchedCost or not out.marginAfterHouseCut then out.overflow=true end
    else out.unknownBasis=out.unknownBasis+1 end
   end
  else out.unlinked=out.unlinked+1 end
 end end
 if out.overflow then out.knownAllocatedCost=nil;out.matchedGross=nil;out.matchedHouseCut=nil;out.matchedCost=nil;out.marginAfterHouseCut=nil
 elseif out.matchedBasis==0 then out.marginAfterHouseCut=nil end
 return out
end
function R.Report(c,from,through,query)
 return summarize(c,E.AuctionProceeds.Report(c,from,through,query),true)
end
function R.Proceeds(c,from,through,query)
 local proceeds=E.AuctionProceeds.Report(c,from,through,query)
 if not query or query=='' then
  -- Wallet debits identify posting cash for this character and date range;
  -- an invoice item/buyer filter cannot be applied to those debits.
  local flow={paid=0,count=0,inferred=0,invalid=0}
  for _,w in ipairs(Q.Range(c,from,through,'gold'))do
   if canonical(c,w,'gold') and w.source=='auctionDeposit' and (w.quality=='inferred' or w.quality=='confirmed')then
    if integer(w.amount,-maximum,-1)then
     flow.count=flow.count+1
     flow.paid=sum(flow.paid,-w.amount)
     if w.quality=='inferred' then flow.inferred=flow.inferred+1 end
    else flow.invalid=flow.invalid+1 end
   end
  end
  if flow.count>0 or flow.invalid>0 or (proceeds.deposit or 0)>0 then
   if flow.invalid==0 and proceeds.unresolved==0 and proceeds.excluded==0 and proceeds.boundary==0 then
    flow.net=difference(proceeds.deposit,flow.paid)
   end
   proceeds.depositFlow=flow
  end
 end
 return proceeds,summarize(c,proceeds,false)
end
-- Additional implicit retention edges for integration into Store.dependencies.
-- AuctionLinks already retains same-name listing / invoice competitors.
local evidenceKinds={auction=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,merchant=true,
 trade=true,trade_offer=true,trade_notice=true,mail_collection=true,mail=true,mail_scan=true,mail_request=true,
 mail_notice=true,mail_draft=true,craft_request=true,craft_begin=true,craft_result=true,crafted=true,gold=true,money_evidence=true,wallet_window=true}
function R.Retention(c,r,add,state)
 if r.kind~='auction'then return end
 local function tick()if state.work then state.work()end end
 if not state.auctionSettlement then
  local indexed={created={},unknownCreated={},rows={},posts={},auctions={}}
  for _,v in pairs(c.records)do tick()
   if evidenceKinds[v.kind]then indexed.rows[#indexed.rows+1]=v end
   if v.kind=='auction'and v.source=='created'then
    if integer(v.auctionID,1)then local list=indexed.created[v.auctionID]or{};indexed.created[v.auctionID]=list;list[#list+1]=v
    else indexed.unknownCreated[#indexed.unknownCreated+1]=v end
   end
  end
  if state.work then E.RetentionWork.Sort(indexed.rows,S.Before,state.work)else table.sort(indexed.rows,S.Before)end
  state.auctionSettlement=indexed
 end
 local indexed=state.auctionSettlement
 local function interval(first,through,visit)
  local lo,hi=1,#indexed.rows+1
  while lo<hi do tick();local mid=math.floor((lo+hi)/2);if indexed.rows[mid].ts<first then lo=mid+1 else hi=mid end end
  while indexed.rows[lo]and indexed.rows[lo].ts<through do tick();visit(indexed.rows[lo]);lo=lo+1 end
 end
 if r.source=='post'then
  if indexed.posts[r.id]then return end;indexed.posts[r.id]=true
  local first=r.inventoryAnchor and r.inventoryAnchor.ts or r.ts-15
  if type(first)~='number'or first>r.ts or first<r.ts-15 then first=r.ts-15 end
  -- A fresh inventory anchor can start later than the deposit comparison.
  -- Preserve only possible debit rivals in that otherwise uncovered prefix.
  if E.AuctionDeposits and first>r.ts-2 then
   interval(r.ts-2,first,function(v)
    if E.AuctionDeposits.CandidateDebit(r,v)then add(v.id,{kind='linked',source=r.id})end
   end)
  end
  interval(first,r.ts+6,function(v)if v.id~=r.id then add(v.id,{kind='linked',source=r.id})end end)
 elseif r.auctionID then
  if indexed.auctions[r.auctionID]then return end;indexed.auctions[r.auctionID]=true
  local function preserve(created)tick()
   add(created.id,{kind='linked',source=r.id})
   interval(created.ts-5,created.ts+1,function(post)
    if post.kind=='auction'and post.source=='post'and post.session==created.session then add(post.id,{kind='linked',source=r.id})end
   end)
  end
  for _,created in ipairs(indexed.created[r.auctionID]or{})do preserve(created)end
  if not indexed.unknownExpanded then indexed.unknownExpanded=true;for _,created in ipairs(indexed.unknownCreated)do preserve(created)end end
 end
end
