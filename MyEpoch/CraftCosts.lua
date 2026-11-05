local _,E=...
local K,S,Q,F,A={},E.Store,E.Query,E.Economy,E.API;E.CraftCosts=K
local caches=setmetatable({},{__mode='k'})
-- A donor character's changed bank costs can change crafted material basis here.
local function invalidate()caches=setmetatable({},{__mode='k'})end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',invalidate)
local function integer(v,min,max)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=(max or 67108864)end
local function contains(list,id)for _,v in ipairs(list or{})do if v==id then return true end end end
local function dense(t,limit)
 if type(t)~='table'or #t>limit then return false end
 local n=0;for k in pairs(t)do if not integer(k,1,limit)then return false end;n=n+1 end
 return n==#t
end
local function cache(c)
 local out=caches[c];if not out or out.revision~=c.revision then out={revision=c.revision,plans={},costs={}};caches[c]=out end;return out
end
function K.Capture(r,incomplete)
 r.materialCoverage='Recipe material requirements unavailable.'
 if r.requestMethod~='CraftRecipe'or r.orderID or incomplete or(r.reagentCoverage~='observed argument list'and r.reagentCoverage~='not supplied')then return end
 local spec=A.Call('craftMaterialSchematic',C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic,r.recipeID,false,r.recipeLevel)
 if A.status.craftMaterialSchematic~='call succeeded; client behavior still needs validation'or type(spec)~='table'or spec.recipeID~=r.recipeID
  or spec.isRecraft~=false or spec.recipeType~=1 or not integer(spec.outputItemID,1)or not integer(spec.quantityMin,1)
  or not integer(spec.quantityMax,spec.quantityMin)or not dense(spec.reagentSlotSchematics,128)then return end
 local selected={};for _,v in ipairs(r.requestedReagents or{})do
  if v.quantity>0 then
   if not v.itemID or v.currencyID then r.materialCoverage='Currency material costs remain unknown.';return end
   local slot=selected[v.slot]or{};selected[v.slot]=slot;slot[v.itemID]=(slot[v.itemID]or 0)+v.quantity
  end
 end
 local amounts,slots={},{}
 for _,slot in ipairs(spec.reagentSlotSchematics)do
  if not integer(slot.dataSlotIndex,1)or slots[slot.dataSlotIndex]or slot.dataSlotType~=1 or type(slot.required)~='boolean'
   or not integer(slot.quantityRequired)or not dense(slot.reagents,128)or not dense(slot.variableQuantities,128)or #slot.variableQuantities>0 then
   r.materialCoverage='Variable, modified or incomplete material requirements remain unknown.';return
  end
  slots[slot.dataSlotIndex]=true;local choices={}
  for _,v in ipairs(slot.reagents)do if not integer(v.itemID,1)or v.currencyID or choices[v.itemID]then return end;choices[v.itemID]=true end
  local allocation=selected[slot.dataSlotIndex]
  if not allocation and slot.required then
   if #slot.reagents~=1 then r.materialCoverage='A required reagent choice was not recorded.';return end
   allocation={[slot.reagents[1].itemID]=slot.quantityRequired}
  end
  local total=0
  for id,n in pairs(allocation or{})do
   if not choices[id]or not integer(n,1)then return end
   total=total+n;amounts[id]=(amounts[id]or 0)+n;if not integer(amounts[id],1)then return end
  end
  if (slot.required or allocation)and total~=slot.quantityRequired then r.materialCoverage='Selected quantities do not match the recipe requirements.';return end
 end
 for id in pairs(selected)do if not slots[id]then r.materialCoverage='Selected inputs include an unknown recipe slot.';return end end
 if not next(amounts)or amounts[spec.outputItemID]then r.materialCoverage='Material-free or same-item transformations have no supported cost allocation.';return end
 local items={};for _,id in ipairs(E.SortedKeys(amounts))do items[#items+1]={itemID=id,quantity=amounts[id]}end
 r.materialSpec={items=items,outputItemID=spec.outputItemID,quantityMin=spec.quantityMin,quantityMax=spec.quantityMax,
  recipeID=spec.recipeID,recipeLevel=r.recipeLevel,source='C_TradeSkillUI.GetRecipeSchematic',meaning='requirements per cast, not observed consumption'}
 r.materialCoverage='Fixed item requirements observed; consumption still unconfirmed.'
end
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
local function outputPayload(link,itemID)
 if type(link)~='string'then return end
 local payload=link:match('|H(item:[^|]+)|h')
 if payload and tonumber(payload:match('^item:(%d+):')or payload:match('^item:(%d+)$'))==itemID then return payload end
end
local function build(c,r,asClosure)
 local spec=r and r.materialSpec;local anchor=r and r.inventoryAnchor
 if not r or r.kind~='craft_request'or r.character~=c.id or r.subject~=c.id or not r.session or r.requestMethod~='CraftRecipe'or r.orderID or r.npcCrafting~=false
  or not integer(r.requestCasts,1,1000)or not spec or spec.recipeID~=r.recipeID or not dense(spec.items,128)
  or not integer(spec.outputItemID,1)or not integer(spec.quantityMin,1)or not integer(spec.quantityMax,spec.quantityMin)
  or not anchor or anchor.session~=r.session or anchor.scope~='bags and equipment'or not integer(anchor.sequence,0,9007199254740991)
  or type(anchor.ts)~='number'or anchor.ts>r.ts or r.ts-anchor.ts>15 or anchor.sequence>=S.Sequence(r)then return end
 local base=c.records[anchor.record];local current=counts(base)
 if not current or base.character~=c.id or base.session~=r.session or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
 local inputs,perCast={},{};for _,v in ipairs(spec.items)do
  if not integer(v.itemID,1)or not integer(v.quantity,1)or inputs[v.itemID]or v.itemID==spec.outputItemID then return end
  local n=v.quantity*r.requestCasts;if not integer(n,1)or v.quantity>(current[v.itemID]or 0)then return end
  inputs[v.itemID]=n;perCast[v.itemID]=v.quantity
 end
 if not next(inputs)then return end
 -- A bounded window is only a candidate search. Starts, results, personal
 -- creation receipts and every inventory delta must independently agree.
 local finish=r.ts+math.min(7200,r.requestCasts*60+10);local boundary=math.huge
 for _,other in ipairs(Q.Range(c,r.ts-15,finish+1,'craft_request'))do if other.id~=r.id and S.Sequence(other)>S.Sequence(base) then
  if S.Sequence(other)<S.Sequence(r)then return end
  boundary=math.min(boundary,S.Sequence(other))
 end end
 local multicraftPayload
 local starts,results,receipts={},{},{};local quantity,last,lastSequence=0,r.ts,S.Sequence(r)
 local function eligible(v)return v.ts>=r.ts and S.Sequence(v)>S.Sequence(r)and S.Sequence(v)<boundary end
 for _,v in ipairs(Q.Range(c,r.ts,finish+1,'craft_begin'))do if eligible(v)then
  if v.character~=c.id or v.session~=r.session or v.subject~=c.id or v.recipeID~=r.recipeID or v.npcCrafting~=false then return end
  starts[#starts+1]=v;last=math.max(last,v.ts);lastSequence=math.max(lastSequence,S.Sequence(v))
 end end
 if #starts~=r.requestCasts then return end
 for _,v in ipairs(Q.Range(c,r.ts,finish+1,'craft_result'))do if eligible(v)then local d=v.result
  if v.character~=c.id or v.session~=r.session or v.subject~=c.id or v.npcCrafting~=false or v.coverage~='notification observed'or v.unresolvedCraftRequestAtObservation or not d
   or d.itemID~=spec.outputItemID or not integer(d.quantity,1) or not integer(d.multicraft)
   or d.isEnchant~=false or d.firstCraftReward~=false or d.bonusCraft~=false
   or(d.resourcesCoverage~='observed'and d.resourcesCoverage~='none reported')or not dense(d.resourcesReturned,128)
   or d.resourcesCoverage=='none reported'and #d.resourcesReturned>0 then return end
  -- The result item count already includes any separately reported multicraft
  -- units. Check the implied ordinary output against the schematic, then
  -- require the observed total in both the personal receipt and bag chain.
  if not integer(d.quantity-d.multicraft,spec.quantityMin,spec.quantityMax)then return end
  if d.multicraft>0 then
   if r.requestCasts~=1 or not integer(r.recipeID,1)or r.subject~=c.id or c.records[r.id]~=r
    or r.source~='C_TradeSkillUI.CraftRecipe' or c.records[v.id]~=v or v.source~='TRADE_SKILL_ITEM_CRAFTED_RESULT'
    or v.multicraftRequestAtObservation~=r.id or v.itemID~=spec.outputItemID or c.records[starts[1].id]~=starts[1] or starts[1].source~='TRADE_SKILL_CRAFT_BEGIN' then return end
   multicraftPayload=outputPayload(d.hyperlink,spec.outputItemID)
   if not multicraftPayload then return end
  end
  local returned={};for _,a in ipairs(d.resourcesReturned)do
   if a.currencyID or not inputs[a.itemID]or not integer(a.quantity,1)or a.quantity>inputs[a.itemID]then return end
   returned[a.itemID]=(returned[a.itemID]or 0)+a.quantity;if returned[a.itemID]>perCast[a.itemID]then return end
   inputs[a.itemID]=inputs[a.itemID]-a.quantity
  end
  results[#results+1]=v;quantity=quantity+d.quantity;last=math.max(last,v.ts);lastSequence=math.max(lastSequence,S.Sequence(v))
 end end
 if #results~=r.requestCasts or not integer(quantity,1)then return end
 for i,v in ipairs(results)do if not S.Before(starts[i],v)or S.Sequence(starts[i])>=S.Sequence(v)then return end end
 local received=0
 for _,v in ipairs(Q.Range(c,r.ts,finish+1,'crafted'))do if eligible(v)and v.recipient==c.id then
  if v.character~=c.id or v.session~=r.session or v.itemID~=spec.outputItemID or not integer(v.quantity,1)or not S.Before(starts[1],v)or S.Sequence(starts[1])>=S.Sequence(v)then return end
  receipts[#receipts+1]=v;received=received+v.quantity;last=math.max(last,v.ts);lastSequence=math.max(lastSequence,S.Sequence(v))
 end end
 if received~=quantity then return end
 if multicraftPayload then
  local receipt=receipts[1]
  if #receipts~=1 or c.records[receipt.id]~=receipt or receipt.observationType~='receipt'
   or outputPayload(receipt.itemLink,spec.outputItemID)~=multicraftPayload then return end
 end
 local expected={};local remaining=quantity
 for id,n in pairs(inputs)do if n>0 then expected[id]=-n;remaining=remaining+n end end;expected[spec.outputItemID]=quantity
 local plan={request=r,anchor=anchor,base=base,inputs=inputs,outputItemID=spec.outputItemID,quantity=quantity,records={},rows={},raw={},refs={base.id},starts=starts,results=results,receipts=receipts}
 for _,rows in ipairs({starts,results,receipts})do for _,v in ipairs(rows)do plan.refs[#plan.refs+1]=v.id end end
 local successors={}
 for _,inv in ipairs(Q.Range(c,anchor.ts,last+3,'inventory'))do if inv.previousRecord and S.Sequence(inv)>anchor.sequence and S.Sequence(inv)<boundary then
  if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
 end end
 local previous,stamp,sequence=base.id,anchor.ts,anchor.sequence;local left=E.Copy(expected);local outputOffset=0
 while remaining>0 do
  local inv=successors[previous];local actual=counts(inv)
  if not actual or inv.character~=c.id or inv.baseline or inv.session~=r.session or S.Sequence(inv)<=sequence or inv.ts<r.ts
   or not inv.observedFrom or inv.observedFrom<stamp or inv.ts<inv.observedFrom or inv.ts>last+2
   or(inv.accountingTime or inv.ts)~=inv.ts or not E.Same(base.equipment,inv.equipment)then return end
  local rows,changed={},0
  for _,v in ipairs(inv.items or{})do
   if not left[v.itemID]or rows[v.itemID]or not integer(v.before)or not integer(v.after)or v.before~=(current[v.itemID]or 0)
    or v.delta~=v.after-v.before or v.delta==0 or v.delta*left[v.itemID]<=0 or math.abs(v.delta)>math.abs(left[v.itemID])then return end
   rows[v.itemID]={quantity=math.abs(v.delta),input=v.delta<0,offset=v.delta>0 and outputOffset or nil}
   if v.delta>0 then outputOffset=outputOffset+v.delta end
   left[v.itemID]=left[v.itemID]-v.delta;current[v.itemID]=v.after;changed=changed+math.abs(v.delta)
  end
  if changed==0 or not same(current,actual)then return end
  for itemID,row in pairs(rows)do local raw
   for _,id in ipairs(inv.refs or{})do local v=c.records[id]
    if v and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==itemID and v.kind==(row.input and'stock_move'or'cost_lot')then
     if raw or v.quantity~=row.quantity or v.character~=c.id or v.ts~=inv.ts then return end;raw=v
    end
   end
   if not raw then return end;row.raw=raw.id;plan.raw[raw.id]=row;lastSequence=math.max(lastSequence,S.Sequence(raw))
  end
  remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows;plan.refs[#plan.refs+1]=inv.id
  previous,stamp,sequence=inv.id,inv.ts,S.Sequence(inv)
 end
 if successors[previous]~=nil then return end
 plan.finish=math.max(last,stamp);plan.finishSequence=lastSequence
 -- A prior request needs evidence of completion before the next call. Rows
 -- observed at or after that call cannot interrupt the prior observation
 -- interval, even if the wall clock is unchanged. Keep the public cost
 -- plan's conservative full-window reconciliation intact.
 local cutoff=asClosure and math.min(boundary,lastSequence+1) or math.huge
 for _,gap in ipairs(Q.Range(c,anchor.ts,plan.finish+1,'inventory_gap'))do if S.Sequence(gap)>anchor.sequence and S.Sequence(gap)<cutoff then return end end
 -- No hidden accounting changes may alter the starting FIFO stock between its
 -- observation and the matched material outflows.
 for _,kind in ipairs({'cost_lot','stock_move','stock_reset','item_sale','sale_return'})do
  for _,v in ipairs(Q.Range(c,anchor.ts,plan.finish+1,kind))do if S.Sequence(v)>anchor.sequence and S.Sequence(v)<cutoff and not plan.raw[v.id]then return end end
 end
 for _,kind in ipairs({'loot','gathered'})do for _,v in ipairs(Q.Range(c,anchor.ts,plan.finish+1,kind))do
  if S.Sequence(v)>anchor.sequence and S.Sequence(v)<cutoff and v.recipient==c.id then return end
 end end
 return plan
end
local function otherClaim(c,inv)
  if E.AuctionCosts.Claim(c,inv)or E.TradeCosts.Claim(c,inv)or E.MailCosts.Claim(c,inv)or E.SentMailCosts.Claim(c,inv)then return 'Other transaction evidence also claims these items.'end
  for _,id in ipairs(inv.merchantCandidates or{})do if E.CostMatch.Compatible(c,inv,c.records[id])then return 'Merchant evidence overlaps these items.'end end
  for _,bank in ipairs(Q.Range(c,inv.ts,inv.ts+1,'bank'))do if bank.inventoryRecord==inv.id and #(bank.transfers or{})>0 then return 'Bank evidence overlaps these items.'end end
end
local function closedPrior(c,p,checks)
 local id=p.request.id
 if checks[id]==nil then
  local closed=not p.request.rejectCraftCosts and not p.request.rejectProductionAssociation
  if closed then for _,inv in ipairs(p.records)do if otherClaim(c,inv)then closed=false;break end end end
  checks[id]=closed
 end
 return checks[id]
end
function K.Plan(c,r)
 if not r or r.kind~='craft_request' or c.records[r.id]~=r then return end
 local cacheEntry=cache(c);local plans=cacheEntry.plans
 cacheEntry.closed=cacheEntry.closed or{};cacheEntry.priorPlans=cacheEntry.priorPlans or{}
 if plans[r.id]~=nil then return plans[r.id]or nil end
 -- A later hook cannot extinguish an earlier possible request. Prove each
 -- competitor finished before this request, following older proofs without
 -- Lua recursion. Caches belong to the current canonical revision.
 local stack={}
 local function push(request,asClosure)
  local target=asClosure and cacheEntry.priorPlans or plans
  local p=build(c,request,asClosure)
  if p then stack[#stack+1]={target=target,request=request,plan=p,priors=Q.CraftPredecessors(c,request,p.finishSequence),next=1}
  else target[request.id]=false end
 end
 push(r)
 while #stack>0 do
  local top=stack[#stack];local prior=top.priors[top.next]
  if not prior then top.target[top.request.id]=top.plan;stack[#stack]=nil
  elseif prior.kind~='craft_request' or prior.character~=c.id or not prior.id or c.records[prior.id]~=prior
    or S.Sequence(prior)<=0 or S.Sequence(prior)>=S.Sequence(top.request) then
   top.target[top.request.id]=false;stack[#stack]=nil
  else
   local previous=cacheEntry.priorPlans[prior.id]
   if previous==nil then push(prior,true)
   elseif not previous or previous.finishSequence>=S.Sequence(top.request) or previous.finish>top.request.ts or not closedPrior(c,previous,cacheEntry.closed) then
    top.target[top.request.id]=false;stack[#stack]=nil
   else top.next=top.next+1 end
  end
 end
 return plans[r.id]or nil
end
function K.Claim(c,inv)
 if not inv or inv.kind~='inventory'then return false end
 local saved=cache(c)
 saved.claims=saved.claims or{}
 if saved.claims[inv.id]==nil then
  local list={}
  -- A valid plan starts before its inventory observation and ends within the
  -- 7200-second result horizon plus its observation allowance. Keep the same
  -- conservative 7215-second window used by evidence linking.
  for _,r in ipairs(Q.Range(c,inv.ts-7215,inv.ts+1,'craft_request'))do local p=K.Plan(c,r)
   if p and p.rows[inv.id]then list[#list+1]=r end
  end
  saved.claims[inv.id]=#list>0 and list or false
 end
 return saved.claims[inv.id]and #saved.claims[inv.id]>0 or false,saved.claims[inv.id]or nil
end
function K.Resolve(c,r)
 local p=K.Plan(c,r);if not p then return nil,'No complete recipe, result, personal receipt and inventory match.'end
 if r.rejectCraftCosts then return nil,'This inferred crafting cost was rejected.'end
 for _,inv in ipairs(p.records)do
  local _,claims=K.Claim(c,inv);if not claims or #claims~=1 then return nil,'Multiple requests claim these material changes.'end
  local why=otherClaim(c,inv);if why then return nil,why end
 end
 return p,'Recipe requirements, starts, results, personal creation receipts and continuous inventory changes agree. Material costs are inferred.'
end
function K.Info(c,r)
 local p,why=K.Resolve(c,r);if not p then return nil,why end
 local saved=cache(c);if saved.costs[r.id]then return saved.costs[r.id],why end
 -- The anchor is strictly before this craft. Earlier crafted inputs can retain
 -- their own inferred cost without replaying this output recursively.
 local state=F.Replay(c,math.huge,p.anchor.sequence)
 local out={plan=p,items={},knownCost=0,unknownQuantity=0,quantity=p.quantity}
 for _,id in ipairs(E.SortedKeys(p.inputs))do local n=p.inputs[id]
  if n>0 then
   local item={itemID=id,quantity=n,knownCost=0,unknownQuantity=0,parts={}};local left=n
   for _,lot in ipairs(state.stock[id]or{})do
    local take=math.min(left,lot.quantity-lot.used)
    if take>0 then
     local cost,total,basis,offset=F.SliceCost(lot,lot.used,take)
     item.parts[#item.parts+1]={lot=lot.id,quantity=take,cost=cost,baseCost=total,baseQuantity=basis,baseOffset=offset}
     if cost==nil then item.unknownQuantity=item.unknownQuantity+take
     elseif item.knownCost>9007199254740991-cost then item.overflow=true
     else item.knownCost=item.knownCost+cost end
     left=left-take
    end
    if left==0 then break end
   end
   item.unknownQuantity=item.unknownQuantity+left
   if item.overflow or out.knownCost>9007199254740991-item.knownCost then out.overflow=true
   else out.knownCost=out.knownCost+item.knownCost end
   if item.overflow then item.knownCost=nil elseif item.unknownQuantity==0 then item.cost=item.knownCost end
   out.items[#out.items+1]=item;out.unknownQuantity=out.unknownQuantity+item.unknownQuantity
  end
 end
 if out.overflow then out.knownCost=nil elseif out.unknownQuantity==0 then out.cost=out.knownCost end
 saved.costs[r.id]=out;return out,why
end
function K.Project(c,r)
 if r.source~='inventory observation'or(r.kind~='cost_lot'and r.kind~='stock_move')then return end
 local inv=c.records[r.evidence];local _,claims=K.Claim(c,inv);if not claims or #claims~=1 then return end
 local p=K.Resolve(c,claims[1]);local row=p and p.raw[r.id];if not row or row.quantity~=r.quantity then return end
 local copy=E.Copy(r);copy.craftRequest=claims[1].id;copy.quality='inferred'
 if row.input then copy.title='Inferred crafting material consumption';copy.reason='Materials used for a matched crafting request'
 else
  local info=K.Info(c,claims[1]);if not info then return end
  copy.cost=F.Part(info.cost,p.quantity,row.offset,r.quantity);copy.baseCost=info.cost;copy.baseQuantity=p.quantity;copy.baseOffset=row.offset
  copy.title='Inferred crafted-item material cost'
 end
 return {copy}
end
local function linkRecord(c,r)
 for _,request in ipairs(Q.Range(c,r.ts-7215,r.ts+1,'craft_request'))do local p=K.Plan(c,request)
  if p then
   local changed=false;request.refs=request.refs or{}
   for _,id in ipairs(p.refs)do if not contains(request.refs,id)then request.refs[#request.refs+1]=id;changed=true end end
   for _,inv in ipairs(p.records)do inv.refs=inv.refs or{};if not contains(inv.refs,request.id)then inv.refs[#inv.refs+1]=request.id;S.Changed(c,inv)end end
   if changed then S.Changed(c,request)end
  end
 end
end
local link=E.Inventory.CostLinkHandler(K,'CraftCosts',function(_,r)
 return r.kind=='craft_request'or r.kind=='craft_begin'or r.kind=='craft_result'or r.kind=='crafted'or r.kind=='inventory'
end,linkRecord)
E.On('RECORD_ADDED',link);E.On('RECORD_CHANGED',link)
E.On('RECORDS_REMOVED',function(c)caches[c]=nil end)
