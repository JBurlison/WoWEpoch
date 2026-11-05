local _,E=...
local P,W={},E.RetentionWork;E.AuctionPreparation=P
local H=E.AuctionHistory
-- Only this live preparation owner can issue an action. A private reader's
-- Proposal ticket and editable presentation tables never authorize a write.
local returnActions=setmetatable({},{__mode='k'})
local reviewReceipts=setmetatable({},{__mode='k'})
local returnFields={'envelope','collection','posting','auctionID','closure','itemID','quantity','postedQuantity','unresolvedQuantity','quality','originQuality','warning','hasReview','status','reason'}
-- These are structural admission limits, not Lua heap byte guarantees.
P.CachePolicy={idleSeconds=30,lifetimeSeconds=120,maxUses=4,maxCharacters=128,
 maxRecords=4096,maxTables=16384,maxEntries=131072,maxStringBytes=2097152,maxCheckpoints=500000}
local function now()return E.API.Now()end
local function eligible(meta,audit,at,active)
 local limits=P.CachePolicy;local size=audit.size
 if not meta or not size or at<meta.lastUsed or at<meta.born then return false,'clock' end
 if(not active and at-meta.lastUsed>=limits.idleSeconds)or at-meta.born>=limits.lifetimeSeconds then return false,'expired' end
 if meta.uses>=limits.maxUses or meta.work>limits.maxCheckpoints then return false,'work' end
 if size.characters>limits.maxCharacters or size.records>limits.maxRecords or size.tables>limits.maxTables
  or size.entries>limits.maxEntries or size.stringBytes>limits.maxStringBytes then return false,'size' end
 return true
end
function P.ReleaseReusable(reason)P.reusable=nil;P.lastCacheRelease=reason or'explicit'end

local function pack(...)return {n=select('#',...),...}end
local function historyValid(state)
 return H.Valid(state.audit)
end
local function valid(state)return historyValid(state)and(not state.guard or state.guard())end
-- Private engines own every financial cache, including recursive bank busy
-- state. Cancelling one never changes a public engine or another page's basis.
local function engine(state,work)
 local shadow
 P.Prune()
 local prior=P.reusable
 if prior and prior.owner~=state.owner then P.ReleaseReusable('character');prior=nil end
 if prior and prior.owner==state.owner and H.Valid(prior.audit)then shadow=prior.engine;state.audit=prior.audit;state.cacheMeta=prior.meta;state.cacheMeta.lastUsed=now();state.walletAccess=shadow.PreparationWalletAccess;P.reusable=nil
 else
  state.cacheMeta={born=now(),lastUsed=now(),uses=0,work=0}
  state.phase='Snapshot'
  local snapshot=H.Snapshot(state.audit,function()state.snapshotCheckpoints=state.snapshotCheckpoints+1;work()end)
  shadow=setmetatable({db=snapshot,Collectors=setmetatable({handlers={}},{__index=E.Collectors}),On=function()end,Emit=function()error('Read-only auction preparation cannot emit events')end},{__index=E})
  if state.audit.walletTracked then state.walletAccess=E.AuctionWalletReads.Install(state.audit,work)end
  local access=state.walletAccess;shadow.PreparationWalletAccess=access
  shadow.RetentionWork={Copy=access and access.Copy or W.Copy,Same=access and access.Same or W.Same}
  if access then shadow.Copy=function(value)return access.Copy(value)end;shadow.Same=function(a,b)return access.Same(a,b)end end
  for _,factory in ipairs(E.AuctionReaderFactories or{})do work();factory.create(shadow)end
  -- This engine cannot observe a new generation. Keep private sorted kind
  -- directories, so repeated posting intervals use binary bounds rather than
  -- rescanning an entire same-day bucket. Each caller still gets a fresh array.
  local kind,range=shadow.Query.Kind,shadow.Query.Range
  local ordered=setmetatable({},{__mode='k'})
  local function rows(c,wanted)
   local cached=ordered[c];if not cached then cached={};ordered[c]=cached end
   if not cached[wanted]then cached[wanted]=kind(c,wanted)end
   return cached[wanted]
  end
  shadow.Query.Kind=function(c,wanted)
   local out={};for i,r in ipairs(rows(c,wanted))do shadow.PreparationWork();out[i]=r end;return out
  end
  shadow.Query.Range=function(c,first,through,wanted)
   if not wanted then return range(c,first,through,wanted)end
   local out={};if first>=through then return out end
   local source=rows(c,wanted);local lo,hi=1,#source+1
   while lo<hi do shadow.PreparationWork();local middle=math.floor((lo+hi)/2);if source[middle].ts<first then lo=middle+1 else hi=middle end end
   while source[lo]and source[lo].ts<through do shadow.PreparationWork();out[#out+1]=source[lo];lo=lo+1 end
   return out
  end
  for _,method in ipairs({'Open','Character','Add','Changed','Remove','RemoveMany'})do shadow.Store[method]=function()error('Read-only auction preparation cannot write records')end end
 end
 shadow.PreparationWork=work;shadow.PreparationState=state
 local function sort(rows,less,checkpoint)
  checkpoint=checkpoint or shadow.PreparationWork;less=less or function(a,b)return a<b end
  if #rows<2 then return end
  local original={};for i,r in ipairs(rows)do checkpoint();original[i]=r end
  W.Sort(rows,less,checkpoint)
  -- Preserve Lua's existing unstable-sort behavior when comparator ties exist.
  -- This fallback is deliberately measured and reported as an atomic boundary.
  for i=2,#rows do checkpoint();if not less(rows[i-1],rows[i])and not less(rows[i],rows[i-1])then
   for n,r in ipairs(original)do checkpoint();rows[n]=r end
   local current=shadow.PreparationState;current.atomicSorts=current.atomicSorts+1;current.largestAtomicSort=math.max(current.largestAtomicSort,#rows)
   table.sort(rows,less);return
  end end
 end
 shadow.PreparationSort=sort;shadow.RetentionWork.Sort=sort
 shadow.SortedKeys=function(t)local out={};for key in (shadow.PreparationWalletAccess and shadow.PreparationWalletAccess.Pairs or pairs)(t)do work();out[#out+1]=key end;sort(out,function(a,b)return tostring(a)<tostring(b)end);return out end
 state.engine=shadow;return shadow
end
local function build(shadow,c,spec,work,action)
 local out={links={},settlements={},postings={},listingLinks={},collections={},mailPlans={},mailCosts={},mailSent={},mailResolve={},mailPrices={}}
 local r=spec.record and c.records[spec.record]
 local function returnReview(record)
  if not action or not shadow.AuctionReturns then return end
  local review=record.auctionReturnReview
  if review==nil and record.mailData and record.mailData.invoice then return end
  local proposal,why=shadow.AuctionReturns.Proposal(c,record)
  -- Only a visible confirmation or reversal needs an exact-revision action.
  -- Ordinary mail follows the invoice's existing history validity checks.
  if not proposal and review==nil then return end
  local confirmed=proposal and shadow.AuctionReturns.MatchesBasis(review,proposal)and shadow.RetentionWork.Same(review.contents,record.mailData,work)
  local display={hasReview=review~=nil,status=confirmed and'confirmed'or review~=nil and'withdrawn'or'unconfirmed',reason=why}
  if proposal then for _,key in ipairs(returnFields)do work();if proposal[key]~=nil then display[key]=proposal[key]end end end
  if review~=nil and not confirmed then display.reason=why or'The saved confirmation no longer matches the retained parcel evidence.'end
  action.values={};for _,key in ipairs(returnFields)do work();action.values[key]=display[key]end
  action.display=display;action.posting=proposal and proposal.posting
  if proposal then
   action.review=shadow.AuctionReturns.ReviewBasis(proposal)
   action.review.contents=W.Copy(record.mailData,work)
  end
  out.returnReviews={[record.id]=display}
 end
 local function invoice(record)
  out.links[record.id]=pack(shadow.AuctionLinks.Invoice(c,record))
  out.settlements[record.id]=pack(shadow.AuctionSettlement.Invoice(c,record))
 end
 if spec.kind=='book'then
  if spec.chapter=='Gold'then
   out.range,out.rangeError=shadow.Economy.Range(c,spec.goldPreset or'last30',spec.now,spec.goldFrom,spec.goldThrough)
   if not out.range then out.range=shadow.Economy.Range(c,'last30',spec.now)end
   if spec.goldSection=='auctions'then
    if spec.auctionMode=='proceeds'and not r then
     out.proceeds,out.saleTotals=shadow.AuctionSettlement.Proceeds(c,out.range.from,out.range.through,spec.proceedsQuery)
     local page=math.max(1,math.min(spec.proceedsPage or 1,math.max(1,math.ceil(#out.proceeds.rows/6))))
     for i=(page-1)*6+1,math.min(#out.proceeds.rows,page*6)do work();local row=out.proceeds.rows[i];out.links[row.envelope]=pack(shadow.AuctionLinks.Invoice(c,c.records[row.envelope]))end
    else out.auctionRows=P.AuctionRows(shadow,c,spec,out.range,work)end
   elseif spec.goldSection=='mail'then
    out.mailRows=P.MailRows(shadow,c,spec,out.range,work)
    local page=math.max(1,math.min(spec.mailPage or 1,math.max(1,math.ceil(#out.mailRows/6))))
    for i=(page-1)*6+1,math.min(#out.mailRows,page*6)do work();local entry=out.mailRows[i]
     if entry.kind=='mail_collection'then out.mailCosts[entry.id]=pack(shadow.MailCosts.Plan(c,entry))end
    end
   end
  end
  if r and r.kind=='mail'then invoice(r);returnReview(r)
  elseif r and r.kind=='auction'then
   out.postings[r.id]=pack(r.source=='post'and shadow.AuctionCosts.Info(c,r));out.listingLinks[r.id]=pack(shadow.AuctionLinks.Listing(c,r))
  elseif r and r.kind=='mail_collection'then
   out.mailPlans[r.id]=pack(shadow.MailMoney.Plan(c,r));out.mailCosts[r.id]=pack(shadow.MailCosts.Plan(c,r))
   local sent=shadow.SentMailCosts.Plan(c,r);local refs={}
   for _,id in ipairs(sent and sent.refs or{})do work();refs[#refs+1]=id end
   out.mailSentRefs={[r.id]=pack(refs)}
   if r.sendRequest then out.mailSent[r.id]=pack(shadow.SentMailCosts.Info(c,r))end
   local receipt=out.mailCosts[r.id][1]
   if receipt then
    out.mailResolve[receipt.records[1].id]=pack(shadow.MailCosts.Resolve(c,receipt.records[1]))
    out.mailPrices[r.id]={};for id in pairs(receipt.items)do work();out.mailPrices[r.id][id]=pack(shadow.MailCosts.Price(c,r,id))end
   end
   out.collections[r.id]=pack(shadow.AuctionProceeds.Collection(c,r));local report=out.collections[r.id][1]
   if report then for _,row in ipairs(report.rows)do work();out.links[row.envelope]=pack(shadow.AuctionLinks.Invoice(c,c.records[row.envelope]))end end
  end
 elseif spec.kind=='return'then assert(r and r.kind=='mail','Parcel unavailable');returnReview(r)
 elseif spec.kind=='invoice'then assert(r,'Invoice unavailable');invoice(r)
 elseif spec.kind=='posting'then
  assert(r,'Posting unavailable');out.postings[r.id]=pack(shadow.AuctionCosts.Info(c,r));out.listingLinks[r.id]=pack(shadow.AuctionLinks.Listing(c,r))
 elseif spec.kind=='proceeds'then
  out.proceeds,out.saleTotals=shadow.AuctionSettlement.Proceeds(c,spec.from,spec.through,spec.query)
  local page=math.max(1,math.min(spec.page or 1,math.max(1,math.ceil(#out.proceeds.rows/6))))
  for i=(page-1)*6+1,math.min(#out.proceeds.rows,page*6)do work();local row=out.proceeds.rows[i];out.links[row.envelope]=pack(shadow.AuctionLinks.Invoice(c,c.records[row.envelope]))end
 elseif spec.kind=='report'then out.report=shadow.AuctionSettlement.Report(c,spec.from,spec.through,spec.query)
 elseif spec.kind=='allocation'then out.allocation=shadow.Economy.MovementAllocation(c,r)
 else error('Unsupported auction preparation request')end
 if P.CompactLists then P.CompactLists(shadow,c,out,spec,work)end
 return out
end
function P.Start(c,spec,guard)
 local copied={};for key,value in pairs(spec)do assert(type(value)~='table','Preparation arguments must be scalar');copied[key]=value end
 if copied.kind=='book'and copied.now==nil then copied.now=E.API.Now()end
 local state={owner=c,db=E.db,audit=H.Start(c,E.AuctionWalletReads and E.AuctionWalletReads.Certified()),guard=guard,spec=copied,status='preparing',checkpoints=0,snapshotCheckpoints=0,atomicSorts=0,largestAtomicSort=0,steps=0}
 local envelope=copied.record and c.records[copied.record]
 local action
 if envelope and envelope.kind=='mail'and(copied.kind=='return'or copied.kind=='book')then
  action={owner=c,db=E.db,envelope=envelope,id=envelope.id,guard=guard};returnActions[state]=action
 end
 state.worker=W.Start(function(work)local function checkpoint()state.checkpoints=state.checkpoints+1;work()end;local shadow=engine(state,checkpoint);if action then action.audit=state.audit end;local result=build(shadow,shadow.db.characters[c.id],state.spec,checkpoint,action);if state.walletAccess then state.walletAccess.FinishResult(result,checkpoint)end;return result end)
 if not state.worker then returnActions[state]=nil;state.status='unavailable';state.reason='Background preparation is unavailable.'end
 return state
end
function P.Step(state,budget)
 if state.listPage then return P.StepListPage(state,budget)end
 if state.status~='preparing'then return state.status,state.model end
 if not valid(state)then returnActions[state]=nil;state.status='cancelled';state.worker=nil;state.engine=nil;return state.status end
 local remaining=type(budget)=='number'and budget==budget and math.max(0,math.min(8000,math.floor(budget)))or 500
 local result,value
 while remaining>0 do
  local slice=math.min(1000,remaining);state.steps=state.steps+1
  result,value=W.Step(state.worker,slice);remaining=remaining-slice
  if result or not valid(state)then break end
 end
 if not valid(state)then returnActions[state]=nil;state.status='cancelled';state.worker=nil;state.engine=nil;return state.status end
 if result=='failed'then returnActions[state]=nil;state.status='failed';state.error=value;state.reason='The auction page could not be prepared. Saved records are unchanged.';state.engine=nil;state.worker=nil
 elseif result=='done'then
  local action=returnActions[state];if action and action.display then action.revision=action.owner.revision;action.ready=true end
  state.status='ready';state.model=value;if P.StampListPlan then P.StampListPlan(value.listPlan)end;state.worker=nil;state.engine.PreparationWork=nil
  local meta=state.cacheMeta;meta.uses=meta.uses+1;meta.work=meta.work+state.checkpoints-state.snapshotCheckpoints
  local at=now();local keep,reason=eligible(meta,state.audit,at,true)
  -- Remove the completed request from engine closures before optional reuse.
  -- A fresh request reinstalls these cooperative helpers when borrowing it.
  state.engine.PreparationState=nil;state.engine.SortedKeys=E.SortedKeys
  if keep then meta.lastUsed=at;P.reusable={owner=state.owner,audit=state.audit,db=E.db,engine=state.engine,meta=meta}
  else P.ReleaseReusable(reason)end
  state.engine=nil;state.walletAccess=nil
 end
 return state.status,state.model
end
function P.Valid(state)return valid(state)end
function P.HistoryValid(state)return historyValid(state)end
function P.Prune()
 local cached=P.reusable
 if cached then
  if not H.Valid(cached.audit)then P.ReleaseReusable('history')
  else local keep,reason=eligible(cached.meta,cached.audit,now());if not keep then P.ReleaseReusable(reason)end end
 end
end
function P.Cancel(state)if state then returnActions[state]=nil;state.status='cancelled';state.worker=nil;state.engine=nil;state.plan=nil end end
local function actionValid(action,state,c,r)
 return action and action.ready and state.status=='ready'and action.owner==c and action.envelope==r
  and action.db==E.db and E.db.characters[c.id]==c and c.records[action.id]==r and r.id==action.id
  and r.character==c.id and r.kind=='mail'and c.revision==action.revision and H.Valid(action.audit)
end
function P.ReturnReviewReceipt(c,r,receipt)
 local held=receipt and reviewReceipts[receipt];local detail=receipt and receipt.detail
 return held and held.owner==c and held.record==r and held.db==E.db and E.db.characters[c.id]==c
  and c.records[held.id]==r and r.id==held.id and r.kind=='mail'and r.character==c.id
  and r.mailData==held.mailData and r.auctionReturnReview==held.review and r.ts==held.ts
  and r.session==held.session and r.visit==held.visit and r.scan==held.scan
  and c.revision==held.revision and receipt.revision==held.revision
  and receipt.character==c and receipt.reason=='record'and detail==held.detail
  and detail.operation=='change'and detail.record==r
end
local function reviewChanged(c,r)
 local held={owner=c,record=r,id=r.id,db=E.db,mailData=r.mailData,review=r.auctionReturnReview,
  ts=r.ts,session=r.session,visit=r.visit,scan=r.scan,revision=c.revision+1}
 local detail={operation='change',record=r};held.detail=detail
 local receipt=E.Store.Touch(c,'record',detail)
 reviewReceipts[receipt]=held
 local ok,why=pcall(E.Emit,'RECORD_CHANGED',c,r,nil,receipt)
 reviewReceipts[receipt]=nil
 if not ok then error(why,0)end
end
local function performReturn(state,c,r,clear,uiGuard)
 local action=returnActions[state];returnActions[state]=nil
 if not actionValid(action,state,c,r)then return false,'The review changed; prepare it again.',false end
 if(action.guard and not action.guard())or(uiGuard and not uiGuard())then return false,'Open this parcel again before changing its confirmation.',false end
 -- Guards may run addon code. Recheck after them, immediately before publishing.
 if not actionValid(action,state,c,r)then return false,'The review changed; prepare it again.',false end
 for _,key in ipairs(returnFields)do if action.display[key]~=action.values[key]then return false,'The displayed review changed; prepare it again.',false end end
 if not clear and not action.review then return false,action.values.reason or'No complete return proposal is available.',false end
 if clear and r.auctionReturnReview==nil then return true,nil,false end
 P.ReleaseReusable('return confirmation');state.status='consumed'
 r.auctionReturnReview=not clear and action.review or nil
 -- Preserve the existing writer's reached prefix. An observer exception does
 -- not undo the assignment and cannot make this one-use action retryable.
 local ok,why=pcall(reviewChanged,c,r)
 if not ok then return false,tostring(why),true end
 return true,nil,true
end
function P.ConfirmReturn(state,c,r,uiGuard)return performReturn(state,c,r,false,uiGuard)end
function P.ClearReturn(state,c,r,uiGuard)return performReturn(state,c,r,true,uiGuard)end
function P.ReturnReview(state,c,r)
 local action=returnActions[state]
 if not actionValid(action,state,c,r)then return nil,'Prepare this parcel review before confirming.'end
 if not action.posting and not action.values.hasReview then return nil,action.values.reason end
 return action.display,action.values.reason
end
function P.ReturnCurrent(state)
 if not state or not state.model or not state.model.returnReviews then return true end
 local action=returnActions[state];return action and actionValid(action,state,action.owner,action.envelope)or false
end
function P.Unpack(value)if value then return unpack(value,1,value.n)end end
