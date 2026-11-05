local _,E=...
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.SentMailCosts=K
local caches=setmetatable({},{__mode='k'})
local function integer(v,min,max)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=(max or 67108864)end
local function contains(rows,id)for _,v in ipairs(rows or{})do if v==id then return true end end end
local function counts(r)
 if not r or r.kind~='inventory'or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
 local out={};for _,map in ipairs({r.carried,r.equipment})do for id,n in pairs(map)do
  if not integer(id,1)or not integer(n)then return end;out[id]=(out[id]or 0)+n;if not integer(out[id])then return end
 end end;return out
end
local function same(a,b)
 for id,n in pairs(a)do if n~=(b[id]or 0)then return false end end
 for id,n in pairs(b)do if n~=(a[id]or 0)then return false end end;return true
end
local function attachments(data)
 if not data or data.complete~=true or type(data.items)~='table'or #data.items>12 then return end
 local out,slots={},{};for _,v in ipairs(data.items)do
  if not integer(v.slot,1,12)or slots[v.slot]or not integer(v.itemID,1)or not integer(v.quantity,1)then return end
  slots[v.slot]=true;out[v.itemID]=(out[v.itemID]or 0)+v.quantity;if not integer(out[v.itemID],1)then return end
 end;return out
end
local function build(c,b)
 if not b or b.kind~='mail_collection'or b.character~=c.id or not b.session or not b.visit or not b.settledAt or b.interrupted or b.failed or b.overflow
  or #(b.requests or{})~=1 or #(b.notices or{})~=1 or b.requests[1]~=b.sendRequest then return end
 local r,n=c.records[b.sendRequest],c.records[b.notices[1]]
 if not r or r.kind~='mail_request'or r.character~=c.id or r.method~='SendMail'or r.unavailable or r.collection~=b.id or r.session~=b.session or r.visit~=b.visit
  or not n or n.kind~='mail_notice'or n.character~=c.id or n.collection~=b.id or n.session~=b.session or n.visit~=b.visit or n.unavailable or n.event~='MAIL_SEND_SUCCESS'
  or n.ts<r.ts or n.ts>r.ts+5 or n.ts>b.settledAt or S.Sequence(n)<=S.Sequence(r)then return end
 local d=r.sendData;local expected=d and attachments({complete=d.attachmentsComplete,items=d.items});if not expected or not next(expected)then return end
 local anchor=b.inventoryAnchor;local draft=d.draft and c.records[d.draft];local draftBased=false
 if d.draft then
  if not draft or draft.kind~='mail_draft'or draft.character~=c.id or draft.session~=b.session or draft.visit~=b.visit or draft.interrupted
   or #(draft.requests or{})~=1 or draft.requests[1]~=r.id or type(draft.snapshots)~='table'or not integer(d.draftSnapshot,1)or not draft.snapshots[d.draftSnapshot]then return end
  local previous,stamp={},draft.ts
  for i=1,d.draftSnapshot do local snap=draft.snapshots[i];local amounts=attachments(snap.data)
   if not amounts or snap.ts<stamp or snap.ts>r.ts then return end
   for id,qty in pairs(previous)do if (amounts[id]or 0)<qty then return end end
   for id,qty in pairs(amounts)do if qty>(expected[id]or 0)then return end end
   previous=amounts;stamp=snap.ts
  end
  if not same(previous,expected)then return end
  if draft.inventoryAnchor then
   local first=attachments(draft.snapshots[1].data)
   if not first or next(first)then return end
   anchor=draft.inventoryAnchor;draftBased=true
  end
 end
 if not anchor or anchor.session~=b.session or anchor.scope~='bags and equipment'or not integer(anchor.sequence,0,9007199254740991)
  or type(anchor.ts)~='number'or anchor.ts>(draftBased and draft.ts or b.ts)or(draftBased and draft.ts or b.ts)-anchor.ts>15
  or anchor.sequence>=S.Sequence(draftBased and draft or b)then return end
 local base=c.records[anchor.record];local current=counts(base)
 if not current or base.character~=c.id or base.session~=b.session or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
 local left=E.Copy(expected);local remaining=0;for id,qty in pairs(left)do if qty>(current[id]or 0)then return end;remaining=remaining+qty end
 local plan={batch=b,request=r,notice=n,draft=draft,anchor=anchor,items=expected,quantity=remaining,records={},rows={},refs={r.id,n.id,base.id}}
 if draft then plan.refs[#plan.refs+1]=draft.id end
 local successors={};for _,inv in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'inventory'))do if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
  if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
 end end
 local previous,stamp,sequence=base.id,anchor.ts,anchor.sequence
 while remaining>0 do local inv=successors[previous];local actual=counts(inv)
  if not actual or inv.character~=c.id or inv.baseline or inv.session~=b.session or S.Sequence(inv)<=sequence
   or not inv.observedFrom or inv.observedFrom<stamp or inv.ts<inv.observedFrom or inv.ts>r.ts+5 or inv.ts>b.settledAt
   or(inv.accountingTime or inv.ts)~=inv.ts or not E.Same(base.equipment,inv.equipment)then return end
  local rows,changed={},0
  for _,v in ipairs(inv.items or{})do
   if not left[v.itemID]or rows[v.itemID]or not integer(v.before)or not integer(v.after)or v.before~=(current[v.itemID]or 0)
    or v.delta~=v.after-v.before or v.delta>=0 or -v.delta>left[v.itemID]then return end
   rows[v.itemID]={quantity=-v.delta};left[v.itemID]=left[v.itemID]+v.delta;current[v.itemID]=v.after;changed=changed-v.delta
  end
  if changed==0 or not same(current,actual)then return end
  remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows;plan.refs[#plan.refs+1]=inv.id
  previous,stamp,sequence=inv.id,inv.ts,S.Sequence(inv)
 end
 if successors[previous]~=nil then return end
 for _,gap in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'inventory_gap'))do if S.Sequence(gap)>anchor.sequence then return end end
 for _,other in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'mail_request'))do if other.id~=r.id and S.Sequence(other)>anchor.sequence then return end end
 for _,other in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'mail_notice'))do if other.id~=n.id and S.Sequence(other)>anchor.sequence then return end end
 return plan
end
local function cache(c)
 local out=caches[c];if not out or out.revision~=c.revision then out={revision=c.revision,plans={}};caches[c]=out end;return out
end
function K.Plan(c,r)
 if not r then return end;local saved=cache(c)
 if saved.plans[r.id]==nil then saved.plans[r.id]=build(c,r)or false end;return saved.plans[r.id]or nil
end
function K.Claim(c,inv)
 if not inv or inv.kind~='inventory'then return false end
 local saved=cache(c)
 if not saved.claims then
  saved.claims={};for _,b in ipairs(Q.Kind(c,'mail_collection'))do local p=K.Plan(c,b)
   if p then for _,r in ipairs(p.records)do local rows=saved.claims[r.id]or{};saved.claims[r.id]=rows;rows[#rows+1]=b end end
  end
 end
 return saved.claims[inv.id]and #saved.claims[inv.id]>0 or false,saved.claims[inv.id]
end
function K.Resolve(c,b)
 local p=K.Plan(c,b);if not p then return nil,'No complete send, attachment and continuous inventory match.'end
 if b.rejectSentItems then return nil,'This inferred outgoing-item match was rejected.'end
 for _,inv in ipairs(p.records)do
  if E.CraftCosts and E.CraftCosts.Claim(c,inv)then return nil,'Crafting and outgoing mail evidence overlap; item costs remain unknown.'end
  local _,claims=K.Claim(c,inv);if not claims or #claims~=1 then return nil,'More than one send claims these items.'end
  if E.AuctionCosts.Claim(c,inv)or E.TradeCosts.Claim(c,inv)or E.MailCosts.Claim(c,inv)then return nil,'Other transaction evidence also claims these items.'end
  for _,id in ipairs(inv.merchantCandidates or{})do if E.CostMatch.Compatible(c,inv,c.records[id])then return nil,'Merchant evidence overlaps these items.'end end
  for _,bank in ipairs(Q.Range(c,inv.ts,inv.ts+1,'bank'))do if bank.inventoryRecord==inv.id and #(bank.transfers or{})>0 then return nil,'Bank evidence overlaps these items.'end end
 end
 return p,'Send success, attachments and uninterrupted inventory decreases agree; outgoing items are inferred, delivery remains unknown.'
end
function K.Project(c,r)
 if r.kind~='stock_move'or r.source~='inventory observation'then return end
 local inv=c.records[r.evidence];local _,claims=K.Claim(c,inv)
 if not claims or #claims~=1 then return end
 local p=K.Resolve(c,claims[1]);local row=p and p.rows[inv.id][r.itemID]
 if not row or row.quantity~=r.quantity then return end
 local copy=E.Copy(r);copy.sentMail=claims[1].id;copy.quality='inferred';copy.title='Inferred outgoing mailed items';copy.reason='Outgoing mail / recipient delivery not observed';return {copy}
end
function K.Info(c,b)
 local p,why=K.Resolve(c,b);if not p then return nil,why end
 local out={plan=p,items={},quantity=p.quantity,knownCost=0,unknownQuantity=0,movements={}}
 for _,inv in ipairs(p.records)do for itemID,row in pairs(p.rows[inv.id])do local raw
  for _,id in ipairs(inv.refs or{})do local r=c.records[id]
   if r and r.kind=='stock_move'and r.source=='inventory observation'and r.evidence==inv.id and r.itemID==itemID and r.quantity==row.quantity then
    if raw then return nil,'Duplicate accounting movements prevent a unique cost match.'end;raw=r
   end
  end
  if not raw then return nil,'The original inventory outflow is unavailable.'end
  local info=F.Replay(c,math.huge,S.Sequence(raw)).movements[raw.id]
  if not info or info.record.kind~='stock_move'or info.record.sentMail~=b.id then return nil,'The original FIFO movement is unavailable or disputed.'end
  local item=out.items[itemID]or{quantity=0,knownCost=0,unknownQuantity=0,parts={}};out.items[itemID]=item
  item.quantity=item.quantity+row.quantity;item.knownCost=item.knownCost+info.knownCost;item.unknownQuantity=item.unknownQuantity+info.unknownQuantity
  for _,part in ipairs(info.allocations)do item.parts[#item.parts+1]=E.Copy(part)end
  out.knownCost=out.knownCost+info.knownCost;out.unknownQuantity=out.unknownQuantity+info.unknownQuantity;out.movements[#out.movements+1]=raw
 end end
 for _,item in pairs(out.items)do if item.unknownQuantity==0 then item.cost=item.knownCost end end
 if out.unknownQuantity==0 then out.cost=out.knownCost end;return out,why
end
local function linkRecord(c,r)
 local batches
 if r.kind=='mail_collection'then batches={r}
 elseif r.kind=='inventory'then batches=Q.Kind(c,'mail_collection')
 else
  batches={};local ids=r.kind=='mail_draft'and r.requests or{r.id}
  for _,id in ipairs(ids or{})do local source=c.records[id];local batch=source and c.records[source.collection]
   if batch then batches[#batches+1]=batch end
  end
 end
 for _,b in ipairs(batches)do local p=K.Plan(c,b)
  if p then local changed=false;b.refs=b.refs or{}
   for _,id in ipairs(p.refs)do if not contains(b.refs,id)then b.refs[#b.refs+1]=id;changed=true end end
   for _,inv in ipairs(p.records)do inv.refs=inv.refs or{};if not contains(inv.refs,b.id)then inv.refs[#inv.refs+1]=b.id;S.Changed(c,inv)end end
   if changed then S.Changed(c,b)end
  end
 end
end
local link=E.Inventory.CostLinkHandler(K,'SentMailCosts',function(_,r)
 return r.kind=='mail_collection'or r.kind=='inventory'or r.kind=='mail_request'or r.kind=='mail_notice'or r.kind=='mail_draft'
end,linkRecord)
E.On('RECORD_ADDED',link);E.On('RECORD_CHANGED',link)
E.On('RECORDS_REMOVED',function(c)caches[c]=nil end)
