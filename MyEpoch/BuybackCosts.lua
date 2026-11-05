local _,E=...
local B,K,Q,S={},E.CostMatch,E.Query,E.Store;E.BuybackCosts=B
local caches=setmetatable({},{__mode='k'})
-- Resolved returns depend on both merchant batches remaining unambiguous.
-- An already-linked competing source can change without touching inventory.
local relevant={merchant=true,inventory=true,inventory_gap=true,cost_lot=true,stock_move=true,gold=true,money_evidence=true,wallet_window=true,
 auction=true,trade=true,trade_offer=true,trade_notice=true,bank=true,bank_gap=true,
 mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,
 craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function key(origin)return origin.receipt..':'..origin.attempt end
local function cacheFor(c)
 local cache=caches[c];if cache then return cache end
 cache={claims={},plans={}};caches[c]=cache
 for _,r in ipairs(Q.Kind(c,'merchant'))do if r.source=='buyback' then
  local origin=E.Buyback.Origins(c,r)[1]
  if origin then local k=key(origin);if cache.claims[k]==nil then cache.claims[k]=r.id else cache.claims[k]=false end end
 end end
 return cache
end
local function rawSale(c,inv,itemID,quantity)
 local found
 for _,id in ipairs(inv.refs or {})do local r=c.records[id]
  if r and r.kind=='stock_move' and r.source=='inventory observation' and r.evidence==inv.id and r.itemID==itemID and r.quantity==quantity then
   if found then return end;found=r
  end
 end
 return found
end
local function build(c,r,cache)
 local plan=K.Plan(c,r);if not plan or K.Resolve(c,plan.records[1])~=r then return end
 local origin=E.Buyback.Origins(c,r)[1];if not origin or cache.claims[key(origin)]~=r.id then return end
 local sale=c.records[origin.receipt];local salePlan=K.Plan(c,sale)
 if not salePlan or sale.source~='vendorSale' or K.Resolve(c,salePlan.records[1])~=sale then return end
 local op=r.attempts[1]
 if #r.attempts~=1 or op.itemID~=origin.itemID or op.quantity~=origin.quantity or -op.amount~=origin.amount then return end
 local segments={};local total=0
 for _,inv in ipairs(salePlan.records)do local item=salePlan.rows[inv.id][origin.itemID]
  if item then
   local raw=rawSale(c,inv,origin.itemID,item.quantity)
   if not raw or raw.ts>r.ts or S.Sequence(raw)>=S.Sequence(r) then return end
   for _,part in ipairs(item.parts)do if part.order==origin.attempt then
    segments[#segments+1]={sale=raw.id,start=part.requestOffset,offset=part.intervalOffset,quantity=part.quantity}
    total=total+part.quantity
   end end
  end
 end
 if total~=op.quantity then return end
 return {receipt=r,origin=origin,plan=plan,segments=segments}
end
function B.Plan(c,r)
 if not r or r.source~='buyback' then return end
 local cache=cacheFor(c);if cache.plans[r.id]==nil then cache.plans[r.id]=build(c,r,cache) or false end
 return cache.plans[r.id] or nil
end
function B.Project(c,raw,receipt)
 local binding=B.Plan(c,receipt);if not binding then return end
 local item=binding.plan.rows[raw.evidence] and binding.plan.rows[raw.evidence][raw.itemID]
 if not item or item.quantity~=raw.quantity then return end
 local parts={};local quantity,refund=0,0
 for _,part in ipairs(item.parts)do
  refund=refund+part.amount
  for _,segment in ipairs(binding.segments)do
   local first=math.max(part.requestOffset,segment.start)
   local last=math.min(part.requestOffset+part.quantity,segment.start+segment.quantity)
   if last>first then
    parts[#parts+1]={sale=segment.sale,offset=segment.offset+first-segment.start,quantity=last-first}
    quantity=quantity+last-first
   end
  end
 end
 if quantity~=raw.quantity then return end
 local copy=E.Copy(raw);copy.kind='sale_return';copy.returnParts=parts;copy.refund=refund;copy.feeRefund=0
 copy.merchantReceipt=receipt.id;copy.originalMerchant=binding.origin.receipt;copy.quality='inferred';copy.title='Inferred vendor buyback return'
 return {copy}
end
