local _,E=...
local L,Q,S={},E.Query,E.Store;E.AuctionLinks=L
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function name(v)if type(v)=='string'and v~=''then return v:lower()end end
local function itemName(r)
 local d=r.auctionData or{};local link=d.itemLink
 if type(link)=='string'and tonumber(link:match('item:(%d+)'))==r.itemID then return name(link:match('%[(.-)%]'))end
end
local function sequenced(c,row)
 return row and c.records[row.id]==row and row.character==c.id and integer(row.sequence,1)and integer(c.seq)and row.sequence<=c.seq
  and row.id==c.id..':'..tostring(row.sequence)and integer(row.ts)
end
local function before(c,a,b)
 return sequenced(c,a)and sequenced(c,b)and a.sequence<b.sequence and a.ts<=b.ts
end
-- Verify only the terminal remainder. Older quantity reductions cannot identify
-- earlier buyers or their individual invoices.
local function terminal(c,g)
 if not g.varied or not g.sold or not g.firstActive then return end
 local ordered,notices={},{}
 for _,v in ipairs(g.rows)do
  if not sequenced(c,v)or v.session~=g.firstActive.session then return end
  if v.source=='sale_notice'then notices[#notices+1]=v
  elseif v.source=='owned'or v.source=='created'then ordered[#ordered+1]=v
  else return end
 end
 table.sort(ordered,function(a,b)return a.sequence<b.sequence end)
 local made,first,last,sold=ordered[1],ordered[2],ordered[#ordered-1],ordered[#ordered]
 if #ordered<4 or not made or made.source~='created' or made.previousObservation or type(made.auctionData)~='table'or made.auctionData.event~='AUCTION_HOUSE_AUCTION_CREATED'
  or made.auctionData.auctionID~=g.id or first~=g.firstActive or last~=g.active or sold~=g.sold then return end
 local started=first.auctionData.quantity;local following={}
 for i=2,#ordered do
  local row,prior=ordered[i],ordered[i-1];local data=row.auctionData
  if not before(c,prior,row)or row.previousObservation~=prior.id or not integer(prior.lastObservedAt or prior.ts)
   or (prior.lastObservedAt or prior.ts)>row.ts or (prior.lastObservedAt or prior.ts)<prior.ts or row.source~='owned' or data.auctionID~=g.id
   or data.coverage~='observed' or data.cacheFull~=true or not integer(row.itemID,1) or data.itemID~=row.itemID or row.itemID~=g.itemID
   or type(data.itemKey)~='table'or data.itemKey.itemID~=g.itemID or not itemName(row)or itemName(row)~=g.name or not integer(data.quantity,1)
   or data.statusLabel~=(i==#ordered and 'Reported sold' or 'Active') then return end
  if i>2 and data.quantity>prior.auctionData.quantity then return end
  if i>2 and row~=sold then following[prior.id]=row end
 end
 if not g.buyer or not integer(g.price,1)or started-g.quantity>=g.quantity or started<=sold.auctionData.quantity or last.auctionData.quantity~=sold.auctionData.quantity then return end
 local final;local counted={}
 for _,notice in ipairs(notices)do
  local d=notice.auctionData or{}
  if d.event~='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION'or d.notification~='AuctionSold'or d.auctionID~=g.id
   or not before(c,made,notice)or not before(c,notice,sold) then return end
  if notice.previousObservation==last.id then
   if final or not before(c,last,notice)or (last.lastObservedAt or last.ts)>notice.ts then return end
   final=notice
  else
   local prior=c.records[notice.previousObservation];local newer=prior and following[prior.id]
   if not newer or not before(c,prior,notice)or not before(c,notice,newer)or (prior.lastObservedAt or prior.ts)>notice.ts then return end
   local count=(counted[prior.id]or 0)+1;counted[prior.id]=count
   if count>prior.auctionData.quantity-newer.auctionData.quantity then return end
  end
 end
 if not final then return end
 local requests={}
 for _,request in ipairs(Q.Range(c,made.ts-5,made.ts+1,'auction'))do
  if request.source=='post'and request.session==made.session then requests[#requests+1]=request end
 end
 if #requests~=1 then return end
 local request=requests[1];local d=request.auctionData or{};local plan=E.AuctionCosts.Plan(c,request)
 if not before(c,request,made)or d.requestMethod~='PostCommodity'or not integer(d.unitPrice,1)
  or d.quantity~=started or not plan or plan.listing~=first or plan.created~=made or plan.itemID~=g.itemID
  or d.unitPrice>math.floor(9007199254740991/g.quantity)or d.unitPrice*g.quantity~=g.price then return end
 return {posting=request.id,postedQuantity=started,offset=started-g.quantity,notice=final.id,created=made.id,first=first.id}
end
local function groups(c)
 local out,anonymous,notices={},{},{}
 for _,r in ipairs(Q.Kind(c,'auction'))do if r.character==c.id then
  if r.source=='sale_notice'then notices[#notices+1]=r end
  if not integer(r.auctionID,1)then anonymous[#anonymous+1]=r else
  local g=out[r.auctionID];if not g then g={id=r.auctionID,rows={}};out[r.auctionID]=g end
  g.rows[#g.rows+1]=r
 end end end
 for _,g in pairs(out)do
  for _,r in ipairs(g.rows)do local d=r.auctionData or{}
   -- Closure notices conflict with a full-sale claim; they do not prove a return.
   if r.source=='cancelled'or r.source=='expired'then g.conflict=true end
   if r.source=='owned'then
    local n=itemName(r)
    if not n or d.coverage~='observed'or not integer(r.itemID,1)or not integer(d.quantity,1)
      or d.itemID~=r.itemID or d.auctionID~=r.auctionID then g.conflict=true end
    if g.quantity and g.quantity~=d.quantity then g.varied=true end
    if g.itemID and(g.itemID~=r.itemID or g.quantity~=d.quantity or g.name~=n)then g.conflict=true end
    g.itemID,g.quantity,g.name=r.itemID,d.quantity,n
    if d.statusLabel=='Active'then
     if not g.active or S.Before(g.active,r)then g.active=r end
     if not g.firstActive or S.Before(r,g.firstActive)then g.firstActive=r end
    elseif d.statusLabel=='Reported sold'then
     local buyer=name(d.bidder)
     if not buyer or not integer(d.bidAmount,1)then g.conflict=true end
     if g.sold and(g.buyer~=buyer or g.price~=d.bidAmount)then g.conflict=true end
     g.buyer,g.price=buyer,d.bidAmount
     if not g.sold or S.Before(r,g.sold)then g.sold=r end
    else g.conflict=true end
   end
  end
  if not g.active or not g.sold or not S.Before(g.active,g.sold)or
    (g.active.lastObservedAt or g.active.ts)>g.sold.ts then g.conflict=true end
  g.partial=terminal(c,g)
  if g.partial then g.conflict=false end
 end
 return out,anonymous,notices
end
local caches=setmetatable({},{__mode='k'})
local function invalidate(c)caches[c]=nil end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',invalidate)
-- Index known identity fields separately; missing fields stay in wildcard
-- buckets. Candidate rejection/support never removes a possible identity.
local unknown={}
local function candidateFrom(g)
 -- Contradictory or incomplete lifecycle evidence cannot establish a start
 -- bound. Reserve it; only a consistent full-sale history can exclude time.
 return g and not g.conflict and g.firstActive and g.firstActive.ts or -math.huge
end
local function directory()return {all={},fields={{},{},{},{}}}end
local function include(index,row)
 index.all[#index.all+1]=row
 for field=1,4 do local key=row.values[field]or unknown;local bucket=index.fields[field][key]
  if not bucket then bucket={};index.fields[field][key]=bucket end;bucket[#bucket+1]=row
 end
end
local function ready(index)
 local function before(a,b)return a.ts<b.ts end
 table.sort(index.all,before)
 for field=1,4 do for _,bucket in pairs(index.fields[field])do table.sort(bucket,before)end end
end
local function bounds(rows,first,through)
 if not rows then return 1,0 end
 local lo,hi=1,#rows+1
 while lo<hi do local mid=math.floor((lo+hi)/2);if rows[mid].ts<first then lo=mid+1 else hi=mid end end
 local start=lo;hi=#rows+1
 while lo<hi do local mid=math.floor((lo+hi)/2);if rows[mid].ts<=through then lo=mid+1 else hi=mid end end
 return start,lo-1
end
local function visit(index,values,first,through,fn)
 local a,b=index.all,nil;local af,al=bounds(a,first,through);local bf,bl=1,0;local size=al-af+1
 for field=1,4 do if values[field]~=nil then
  local exact,wild=index.fields[field][values[field]],index.fields[field][unknown]
  local ef,el=bounds(exact,first,through);local wf,wl=bounds(wild,first,through);local count=el-ef+1+wl-wf+1
  if count<size then a,b,af,al,bf,bl,size=exact,wild,ef,el,wf,wl,count end
 end end
 local function run(rows,start,last)
  for i=start,last do local row=rows[i];local compatible=true
   for field=1,4 do local x,y=values[field],row.values[field];if x~=nil and y~=nil and x~=y then compatible=false;break end end
   if compatible and fn(row)==false then return false end
  end
 end
 if run(a,af,al)==false then return end;run(b,bf,bl)
end
-- The terminal buyer comes from the Sold row. Earlier fill buyers are
-- unknown. A same-size earlier fill must remain possible if the unresolved
-- prefix is large enough (checked in terminal). Active-only rivals and
-- unsupported seller mail also reserve the identity.
local function unknownScan(c,scan,work)
 if scan.complete~=true or not integer(scan.loaded)or scan.loaded>100 or scan.total~=scan.loaded or type(scan.entries)~='table' then return true end
 local count=0
 for slot,id in pairs(scan.entries)do
  if work then work()end
  local row=c.records[id]
  if not integer(slot,1)or slot>scan.loaded or not row or row.kind~='mail'or row.character~=c.id
   or row.scan~=scan.id or row.session~=scan.session or row.visit~=scan.visit or row.index~=slot then return true end
  count=count+1
 end
 return count~=scan.loaded
end
local function unknownEnvelope(d)
 return type(d)~='table' or d.complete~=true and not d.invoice
end
-- A later observation alone does not date the posting. A later posting
-- needs its own unique request, creation, first listing and outflow.
local function origin(c,g)
 local first=g.firstActive;local made=first and c.records[first.previousObservation]
 if not made or made.source~='created'or made.auctionID~=g.id or made.previousObservation
  or not before(c,made,first)or not integer(first.itemID,1)then return false end
 local event=made.auctionData
 if type(event)~='table'or event.auctionID~=g.id or event.event~='AUCTION_HOUSE_AUCTION_CREATED'then return false end
 for _,row in ipairs(g.rows)do
  local data=row.auctionData
  if row.session~=made.session or type(data)~='table'or data.auctionID~=g.id
   or row~=made and (row.source=='created'or not before(c,made,row))then return false end
  if row.source=='owned'and (row.itemID~=first.itemID or data.itemID~=row.itemID or type(data.itemKey)~='table'
   or data.itemKey.itemID~=row.itemID or not itemName(row)or data.coverage~='observed')then return false end
 end
 for _,r in ipairs(Q.Range(c,made.ts-5,made.ts+1,'auction'))do
  if r.source=='post'and r.session==made.session and before(c,r,made)then
   local plan=E.AuctionCosts.Plan(c,r)
   if plan and plan.created==made and plan.listing==first then return r,plan end
  end
 end
 return false
end
-- Both tables live only for one call to index(). Neither failed nor positive
-- proofs can cross snapshot, character or revision boundaries.
local function cachedOrigin(c,g,proofs)
 local result=proofs.origins[g]
 if result==nil then
  local request,plan=origin(c,g)
  result=request and {request=request,plan=plan}or false;proofs.origins[g]=result
 end
 return result
end
-- The two records are checked at the boundary where a snapshot proof
-- enters the index. Their relative order still depends on the current invoice.
local function ordered(row,envelope)
 return row.sequence<envelope.sequence and row.ts<=envelope.ts
end
local function createdAfter(c,g,envelope,proofs)
 local first=g.firstActive
 if not first or type(first.ts)~='number'or type(first.sequence)~='number'or not ordered(envelope,first)then return false end
 local result=cachedOrigin(c,g,proofs)
 return result and ordered(envelope,result.request)
end
local function invoiceRival(invoice,buyer,quantity,gross)
 -- Seller mail supplies a localized name but no item ID or source locale.
 return (not name(invoice.player)or name(invoice.player)==buyer)
  and(not integer(invoice.count,1)or invoice.count==quantity)
  and(not integer(invoice.bid,1)or invoice.bid==gross)
end
local function partialSafe(c,g,groups,anonymous,envelope,mailRows,scans,proofs)
 local t=g.partial
 if not before(c,g.sold,envelope)then return false end
 local request=c.records[t.posting]
 for _,other in pairs(groups)do if other~=g then
  local possible=false
  for _,row in ipairs(other.rows)do
   if row.source=='owned'then
    local n=itemName(row)
    if not n or row.itemID==g.itemID or n==g.name then possible=true;break end
   elseif not other.name and (row.source=='created'or row.source=='sale_notice'or row.source=='expired'or row.source=='cancelled') then possible=true;break end
  end
  if possible and not createdAfter(c,other,envelope,proofs)then return false end
 end end
 for _,row in ipairs(anonymous)do
  if row~=request then
   if row.source=='post'and not before(c,envelope,row)then
    local d=row.auctionData or{}
    if (not itemName(row)or row.itemID==g.itemID or itemName(row)==g.name)
      and (not integer(d.quantity,1)or d.quantity>=g.quantity)
      and (d.requestMethod~='PostCommodity'or not integer(d.unitPrice,1)or d.unitPrice==request.auctionData.unitPrice)then return false end
   elseif row.source=='sale_notice'or row.source=='created'or row.source=='owned'and(not itemName(row)or row.itemID==g.itemID or itemName(row)==g.name)then return false end
  end
 end
 for _,row in ipairs(mailRows)do if row~=envelope and not before(c,row,request)then
  local d=row.mailData
  if unknownEnvelope(d)then return false end
  if E.AuctionProceeds.PotentialSeller(d)then
   local invoice=d.invoice or{}
   if invoiceRival(invoice,g.buyer,g.quantity,g.price)then return false end
  end
 end end
 for _,scan in ipairs(scans)do if not before(c,scan,request)and unknownScan(c,scan)then return false end end
 return true
end
-- A formatted sold notification has no buyer, quantity or price. Its
-- preceding owned observation can identify an item, never a particular invoice.
local function noticeIdentity(c,r)
 local d=r.auctionData
 if not integer(r.auctionID,1)or type(d)~='table'or d.auctionID~=r.auctionID
  or d.notification~='AuctionSold'or d.event~='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION'then return end
 local prior=c.records[r.previousObservation]
 if not prior then return r.auctionID end
 if prior.kind~='auction'or prior.auctionID~=r.auctionID or prior.session~=r.session or not before(c,prior,r)then return end
 if prior.source~='owned'then return r.auctionID end
 local v=prior.auctionData
 if type(v)~='table'or v.coverage~='observed'or v.auctionID~=r.auctionID or not integer(prior.itemID,1)
  or v.itemID~=prior.itemID or type(v.itemKey)~='table'or v.itemKey.itemID~=prior.itemID or not itemName(prior)then return r.auctionID end
 return r.auctionID,prior.itemID,itemName(prior)
end
local function noticeClaims(c,rows)
 local ix={items={},names={},unknown={}}
 local function add(row)
  local auctionID,itemID,n=noticeIdentity(c,row)
  local key=auctionID or row.id
  if not itemID then ix.unknown[key]=true;return end
  ix.items[itemID]=ix.items[itemID]or{};ix.items[itemID][key]=true
  ix.names[n]=ix.names[n]or{};ix.names[n][key]=true
 end
 for _,row in ipairs(rows)do add(row)end
 return ix
end
-- An earlier notice cannot explain a second invoice when that posting's
-- entire original quantity was observed sold in one independently settled lot.
local function fullSaleProof(c,other,invoices,observations,proofs)
 if other.conflict or other.varied or #other.rows~=4 or not other.sold or other.firstActive~=other.active then return false end
 local result=cachedOrigin(c,other,proofs)
 if not result then return false end
 local request,plan=result.request,result.plan
 if plan.quantity~=other.quantity or request.auctionData.requestMethod~='PostCommodity'then return false end
 local unit=request.auctionData.unitPrice
 if not integer(unit,1)or unit>math.floor(9007199254740991/other.quantity)or unit*other.quantity~=other.price then return false end
 local active,sold=other.active,other.sold
 if active.auctionData.cacheFull~=true or sold.auctionData.cacheFull~=true or sold.previousObservation~=active.id then return false end
 local notice
 for _,r in ipairs(other.rows)do if r.source=='sale_notice'then notice=r end end
 if not notice or notice.previousObservation~=active.id or noticeIdentity(c,notice)~=other.id
  or not before(c,active,notice)or not before(c,notice,sold)or (active.lastObservedAt or active.ts)>notice.ts then return false end
 local values={other.name,other.buyer,other.quantity,other.price}
 local count,receipt=0,nil
 visit(invoices,values,-math.huge,math.huge,function(row)
  count=count+1;receipt=row.candidate;return count<2
 end)
 if count~=1 or not receipt.supported then return false end
 local inv=receipt.invoice;local prior=c.records[inv.envelope];local batch=c.records[inv.collection]
 if name(inv.itemName)~=other.name or name(inv.buyer)~=other.buyer or inv.quantity~=other.quantity or inv.gross~=other.price
  or not before(c,sold,prior)or prior.rejectAuctionLink or not sequenced(c,batch)or not integer(batch.settledAt)then return false end
 local rival=false;visit(observations,values,-math.huge,prior.ts,function(row)
  if row.id~=other.id then rival=true;return false end
 end)
 if not rival then return {invoice=prior,batch=batch}end
 return false
end
local function earlierFullSale(c,other,target,envelope,invoices,observations,proofs)
 if not other.sold or other.buyer==target.buyer and other.price==target.price and other.quantity==target.quantity then return false end
 local result=proofs.sales[other]
 if result==nil then
  result=fullSaleProof(c,other,invoices,observations,proofs);proofs.sales[other]=result
 end
 return result and ordered(result.invoice,envelope)and ordered(result.batch,envelope)and result.batch.settledAt<=envelope.ts
end
local function noticeRival(c,g,envelope,groups,ix,invoices,observations,proofs)
 local validEnvelope=sequenced(c,envelope)
 local visited={}
 local function possible(bucket)
  for key in pairs(bucket or{})do
   if key~=g.id and not visited[key]then
    visited[key]=true;local other=groups[key]
    if not other or not validEnvelope or not createdAfter(c,other,envelope,proofs)and not earlierFullSale(c,other,g,envelope,invoices,observations,proofs)then return true end
   end
  end
 end
 return possible(ix.unknown)or possible(ix.items[g.itemID])or possible(ix.names[g.name])
end
local function index(c)
 local cached=caches[c];if cached and cached.revision==c.revision then return cached end
 local out={revision=c.revision,byEnvelope={},byAuction={}};local listings,anonymous,noticeRows=groups(c)
 local proofs={origins={},sales={}}
 local observations,invoices=directory(),directory();local identities={};local mailRows,scans,notices
 local function observe(r,id,g)
  local d=r.auctionData or{}
  if r.source~='owned'or d.statusLabel=='Active'then return end
  local values={itemName(r),name(d.bidder),integer(d.quantity,1)and d.quantity or nil,integer(d.bidAmount,1)and d.bidAmount or nil}
  -- A refresh can reveal the sold identity after its invoice was collected.
  -- Earlier active evidence makes that identity a possible historical claim;
  -- incomplete/conflicting groups still reserve it but cannot establish a link.
  -- Without an earlier active anchor, observation time cannot establish when
  -- this auction began. It can reserve a historical claim, never prove a link.
  local possibleFrom=candidateFrom(g)
  -- Repeated observations of one identity contribute its earliest time, not
  -- duplicate work or extra claims. Conflicting identities remain separate.
  local branch=identities[id];if not branch then branch={};identities[id]=branch end
  for field=1,4 do local key=values[field]or unknown;branch[key]=branch[key]or{};branch=branch[key]end
  if branch.row then branch.row.ts=math.min(branch.row.ts,possibleFrom)
  else local row={id=id,group=g,values=values,ts=possibleFrom};branch.row=row;include(observations,row)end
 end
 for _,g in pairs(listings)do for _,r in ipairs(g.rows)do observe(r,g.id,g)end end
 for _,r in ipairs(anonymous)do observe(r,'record:'..r.id)end
 local candidates=E.AuctionProceeds.LinkCandidates(c)
 for _,candidate in ipairs(candidates)do local row=candidate.invoice;local envelope=c.records[row.envelope]
  if envelope then include(invoices,{candidate=candidate,values={name(row.itemName),name(row.buyer),row.quantity,row.gross},ts=envelope.ts})end
 end
 ready(observations);ready(invoices)
 for _,candidate in ipairs(candidates)do local row=candidate.invoice;local envelope=c.records[row.envelope]
  local n,buyer=name(row.itemName),name(row.buyer)
  local entry={invoice=row,reason='No unique recorded listing matches this collected invoice.'};out.byEnvelope[row.envelope]=entry
  if envelope then
   local seen,possibilities,only={},0,nil
   visit(observations,{n,buyer,row.quantity,row.gross},-math.huge,envelope.ts,function(observation)
    if not seen[observation.id]then seen[observation.id]=true;possibilities=possibilities+1;only=observation.group end
    return possibilities<2
   end)
   if possibilities==1 and only and candidate.supported and n and buyer and integer(row.quantity,1)and not only.conflict
     and only.name==n and only.buyer==buyer and only.quantity==row.quantity and only.price==row.gross
     and only.active.ts<=envelope.ts
     and (only.sold.ts<=envelope.ts or(only.active.lastObservedAt or only.active.ts)<envelope.ts)then
    if only.partial then
     mailRows=mailRows or Q.Kind(c,'mail');scans=scans or Q.Kind(c,'mail_scan')
     if partialSafe(c,only,listings,anonymous,envelope,mailRows,scans,proofs)then entry.group=only
     else entry.reason='Incomplete or competing evidence prevents a unique terminal partial sale.'end
    elseif #noticeRows==0 then entry.group=only
    else
     notices=notices or noticeClaims(c,noticeRows)
     if noticeRival(c,only,envelope,listings,notices,invoices,observations,proofs)then entry.reason='Another recorded sale notification could belong to this invoice.'
     else entry.group=only end
    end
   elseif possibilities>1 then entry.reason='Competing or incomplete listing observations prevent a unique match.'end
  end
 end
 local claims={}
 for id,entry in pairs(out.byEnvelope)do local g=entry.group
  if g then
   if claims[g.id]==nil then
    local count=0
    -- Invert the competing-invoice query. Only groups that could establish a
    -- unique link need a count, and a second claim already proves ambiguity.
    visit(invoices,{g.name,g.buyer,g.quantity,g.price},candidateFrom(g),math.huge,function()count=count+1;return count<2 end)
    claims[g.id]=count
   end
   if claims[g.id]~=1 then entry.reason='Multiple collected invoices could claim this listing.'
   elseif c.records[id].rejectAuctionLink then entry.reason='This inferred listing link was rejected. Original observations are preserved.'
   else
    entry.reason=nil;entry.link={auctionID=g.id,itemID=g.itemID,listing=g.sold.id,active=g.active.id,
     envelope=id,collection=entry.invoice.collection,quantity=g.quantity,quality='inferred',
     from=g.active.ts,through=math.min(g.sold.ts,c.records[id].ts),soldObservedAt=g.sold.ts,
     invoiceBeforeSold=c.records[id].ts<g.sold.ts,invoice=entry.invoice,partial=g.partial and E.Copy(g.partial)}
    out.byAuction[g.id]=entry.link
   end
  end
 end
 caches[c]=out;return out
end

function L.Invoice(c,r)
 if not r or c.records[r.id]~=r or r.character~=c.id or r.kind~='mail'then return end
 local entry=index(c).byEnvelope[r.id]
 if entry then return entry.link,entry.reason end
 return nil,'No supported collected seller invoice is available.'
end
function L.Listing(c,r)
 if not r or c.records[r.id]~=r or r.kind~='auction'or r.character~=c.id then return end
 return index(c).byAuction[r.auctionID]
end
function L.Reject(c,r,rejected)
 if not r or c.records[r.id]~=r or r.kind~='mail'or r.character~=c.id or not r.mailData or not r.mailData.invoice or r.mailData.invoice.type~='seller'then return false end
 r.rejectAuctionLink=rejected and true or nil;S.Changed(c,r);return true
end
-- Retain candidate evidence as well as the selected link: cleanup must not
-- manufacture uniqueness by deleting the competing invoice or listing.
-- This is deliberately conservative by invoice item name, not financial proof.
function L.Retention(c,r,add,state)
 if r.kind~='auction'and r.kind~='mail'and r.kind~='mail_collection'and r.kind~='mail_scan'then return end
 local work=state.work;local function tick()if work then work()end end
 local unknown='\001unknown-auction-item'
 if not state.auctionLinkGroups then
  local byName,byRecord,byAuction={},{},{}
  local quantities,varied,items,noticeItems={},{},{},{}
  local function join(n,id)
   if not n then return end
   byName[n]=byName[n]or{};byName[n][id]=true
   byRecord[id]=byRecord[id]or{};byRecord[id][n]=true
  end
  for id,v in pairs(c.records)do tick()
   if v.kind=='auction'and v.source=='owned'then local n=itemName(v)or unknown;join(n,id)
    if v.auctionID then
     if n then byAuction[v.auctionID]=byAuction[v.auctionID]or{};byAuction[v.auctionID][n]=true end
     local quantity=v.auctionData and v.auctionData.quantity
     if quantity and quantities[v.auctionID]and quantity~=quantities[v.auctionID]then varied[v.auctionID]=true end
     quantities[v.auctionID]=quantity or quantities[v.auctionID]
     if integer(v.itemID,1)then items[v.auctionID]=items[v.auctionID]or{};items[v.auctionID][v.itemID]=true end
    end
   elseif v.kind=='auction'and v.source=='sale_notice'then
    local _,itemID,n=noticeIdentity(c,v)
    if itemID then noticeItems[itemID]=true;join(n,id);join('\002auction-item-'..itemID,id)
    else join(unknown,id)end
   elseif v.kind=='mail'and E.AuctionProceeds.PotentialSeller(v.mailData)then join(name((v.mailData.invoice or{}).itemName)or unknown,id)end
  end
  local partialNames,byItem,identities={},{},{}
  for auctionID in pairs(varied)do for n in pairs(byAuction[auctionID]or{})do
   tick();partialNames[n]=true
   for itemID in pairs(items[auctionID]or{})do tick();byItem[itemID]=byItem[itemID] or{};byItem[itemID][n]=true end
  end end
  for id,v in pairs(c.records)do tick()
   if v.kind=='auction'and (v.source=='post'or v.source=='created'or v.source=='sale_notice'or v.source=='expired'or v.source=='cancelled')then
    -- Keep anonymous or unpaired rivals without connecting unrelated full-sale books.
    if not v.auctionID or not byAuction[v.auctionID]then
     local n=v.source=='post'and itemName(v)
     if n then
      if partialNames[n]then join(n,id)end
      for possible in pairs(byItem[v.itemID]or{})do tick();join(possible,id)end
     else for possible in pairs(partialNames)do tick();join(possible,id)end end
    end
   end
   if v.kind=='auction'and v.source=='owned'then
    if noticeItems[v.itemID]then join('\002auction-item-'..v.itemID,id)end
    for n in pairs(byItem[v.itemID]or{})do tick();join(n,id)end
    if varied[v.auctionID]and v.auctionData and v.auctionData.statusLabel=='Reported sold'then
     local d=v.auctionData;identities[#identities+1]={name=itemName(v)or unknown,buyer=name(d.bidder),quantity=d.quantity,gross=d.bidAmount}
    end
   end
   if next(partialNames) and (v.kind=='mail'and unknownEnvelope(v.mailData)or v.kind=='mail_scan'and unknownScan(c,v,work))then
    for possible in pairs(partialNames)do tick();join(possible,id)end
   end
   if v.kind=='auction'and v.auctionID then for n in pairs(byAuction[v.auctionID]or{})do tick();join(n,id)end
   elseif v.kind=='mail_collection'then local scan=c.records[v.beforeScan]
    for _,key in ipairs(scan and scan.entries or{})do tick();for n in pairs(byRecord[key]or{})do tick();join(n,id)end end
   end
  end
  if #identities>0 then
   for id,v in pairs(c.records)do tick()
    if v.kind=='mail'and E.AuctionProceeds.PotentialSeller(v.mailData)then
     for _,claim in ipairs(identities)do tick()
      if invoiceRival(v.mailData.invoice or{},claim.buyer,claim.quantity,claim.gross)then join(claim.name,id)end
     end
    end
   end
  end
  state.auctionLinkGroups={names=byName,records=byRecord,seen={}}
 end
 local g=state.auctionLinkGroups
 local function expand(n)
  tick();if g.names[n]and not g.seen[n]then
   g.seen[n]=true;for id in pairs(g.names[n])do tick();if id~=r.id then add(id,{kind='linked',source=r.id})end end
  end
 end
 local membership=g.records[r.id]
 if membership then
  for n in pairs(membership)do expand(n)end
  expand(unknown)
  if membership[unknown]then for n in pairs(g.names)do expand(n)end end
 end
end
