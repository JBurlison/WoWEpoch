local _,E=...
local D,S,Q,F={},E.Store,E.Query,E.Economy;E.AuctionDeposits=D
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function canonical(c,r,kind)return type(r)=='table'and c.records[r.id]==r and r.character==c.id and r.kind==kind end
local function posting(c,r)
 if not canonical(c,r,'auction')or r.source~='post'or r.rejectAuctionDeposit then return end
 local d,a=r.auctionData,r.walletAnchor
 if type(d)~='table'or d.coverage~='request arguments observed'or not integer(d.depositQuote,1)or d.depositQuoteAt~=r.ts
  or not integer(d.duration,1)or not integer(d.quantity,1)or not integer(r.itemID,1)or d.itemID~=r.itemID
  or not integer(r.ts)or type(r.session)~='string'or r.session==''then return end
 local method=d.requestMethod=='PostItem'and'CalculateItemDeposit'or d.requestMethod=='PostCommodity'and'CalculateCommodityDeposit'
 if not method or d.depositQuoteMethod~=method then return end
 if type(a)~='table'or a.session~=r.session or not integer(a.amount)or not integer(a.ts)or a.ts>r.ts or r.ts-a.ts>15
  or not integer(a.sequence)or a.sequence>=S.Sequence(r)then return end
 local window=c.records[a.window]
 if not canonical(c,window,'wallet_window')or window.session~=r.session or not integer(window.ts)or not integer(window.ended)
  or window.ts>a.ts then return end
 local plan=E.AuctionCosts.Resolve(c,r);if not plan then return end
 if not canonical(c,plan.created,'auction')or not canonical(c,plan.listing,'auction')
  or not integer(plan.created.auctionID,1)or plan.listing.auctionID~=plan.created.auctionID
  or plan.itemID~=r.itemID or plan.quantity~=d.quantity or not plan.listing.auctionData
  or plan.listing.auctionData.itemID~=r.itemID then return end
 for _,id in ipairs(plan.refs)do local source=c.records[id];if not source or source.character~=c.id then return end end
 return plan,window
end
-- This is only the rival census. A debit that precedes the request can
-- prevent a unique match even though it cannot itself establish a deposit.
function D.CandidateDebit(post,wallet)
 local quote=type(post.auctionData)=='table'and post.auctionData.depositQuote
 local anchor=post.walletAnchor
 return wallet.kind=='gold'and integer(quote,1)and type(anchor)=='table'and anchor.window~=nil
  and type(post.session)=='string'and wallet.session==post.session and wallet.window==anchor.window
  and wallet.amount==-quote and integer(post.ts)and type(wallet.ts)=='number'and math.abs(wallet.ts-post.ts)<=2
end
function D.ValidProof(c,p)
 if not canonical(c,p,'money_evidence')or p.source~='auctionDeposit'or p.auctionDepositVersion~=1
  or p.observationType~='auction_posting_deposit'or p.withdrawnReason then return false end
 local r=c.records[p.posting];local plan,window=posting(c,r);if not plan then return false end
 local d,a=r.auctionData,r.walletAnchor
 if p.ts~=r.ts or p.session~=r.session or p.amount~=-d.depositQuote or p.quotedDeposit~=d.depositQuote
  or p.quoteMethod~=d.depositQuoteMethod or p.itemID~=r.itemID or p.quantity~=d.quantity or p.duration~=d.duration
  or p.created~=plan.created.id or p.listing~=plan.listing.id or p.auctionID~=plan.created.auctionID
  or p.walletWindow~=window.id or p.requestSequence~=S.Sequence(r)then return false end
 local found,count=nil,0
 for _,w in ipairs(Q.Range(c,r.ts-2,r.ts+3,'gold'))do
  if D.CandidateDebit(r,w)then found=w;count=count+1 end
 end
 -- A post-hook quote cannot establish an earlier debit. Earlier callbacks stay
 -- unknown until an independently captured pre-request quote is available.
 return count==1 and canonical(c,found,'gold')and found.ts>=r.ts and S.Sequence(found)>S.Sequence(r)
  and S.Sequence(found)>a.sequence and found.before==a.amount and integer(found.after)
  and found.after-found.before==p.amount and window.ended>=found.ts
end
function D.Reject(c,r,rejected)
 if not canonical(c,r,'auction')or r.source~='post'then return false end
 r.rejectAuctionDeposit=rejected and true or nil;S.Changed(c,r);return true
end
local busy=false
local function capture(c,r)
 if busy or E.db.characters[c.id]~=c then return end
 local key='auction-deposit:'..r.id
 if c.dedup and c.dedup['money_evidence:'..key]then return end
 local plan,window=posting(c,r);if not plan then return end
 busy=true
 local d=r.auctionData
 local ok,why=pcall(F.Evidence,c,r.ts,{title='Posting deposit / inferred',source='auctionDeposit',amount=-d.depositQuote,session=r.session,
  auctionDepositVersion=1,observationType='auction_posting_deposit',posting=r.id,created=plan.created.id,listing=plan.listing.id,
  auctionID=plan.created.auctionID,itemID=r.itemID,quantity=d.quantity,duration=d.duration,quotedDeposit=d.depositQuote,
  quoteMethod=d.depositQuoteMethod,requestSequence=S.Sequence(r),walletWindow=window.id,
  refs={r.id,plan.created.id,plan.listing.id,window.id},
  evidenceNote='Inferred posting-deposit cash outflow. Recoverable deposit; refund, forfeiture and complete profit are unresolved.'},key)
 busy=false
 if not ok then error(why,0)end
end
local relevant={auction=true,inventory=true,inventory_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,
 mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,bank=true,bank_gap=true,
 craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true}
local stamps=setmetatable({},{__mode='k'});local changes=setmetatable({},{__mode='k'})
local function stamp(r)
 local out={kind=r.kind,ts=r.ts}
 if r.kind=='auction'then out.source=r.source;out.character=r.character;out.session=r.session;out.auctionID=r.auctionID;out.itemID=r.itemID
  out.data=E.Copy(r.auctionData);out.anchor=E.Copy(r.walletAnchor);out.inventory=E.Copy(r.inventoryAnchor)
  out.rejectDeposit=r.rejectAuctionDeposit;out.rejectPosting=r.rejectPostingCosts end
 return out
end
E.On('HISTORY_TOUCHED',function(c,receipt)
 local d=receipt and receipt.detail;local r=type(d)=='table'and d.record
 if receipt and receipt.reason=='record'and type(r)=='table'then
  local oldKind=d.operation=='change'and Q.RecordedKind(c,r.id)
  if relevant[r.kind]or relevant[oldKind]or stamps[r]then
   if d.operation=='change'then changes[receipt]={record=r,prior=stamps[r],oldKind=oldKind,unanchoredOffer=Q.RecordedUnanchoredOffer(c,r.id)};stamps[r]=stamp(r)
   elseif d.operation=='add'then stamps[r]=stamp(r)end
  end
 end
end)
local function reviewAt(c,ts)
 for _,r in ipairs(Q.Range(c,ts-20,ts+21,'auction'))do if r.source=='post'then capture(c,r)end end
 for _,proof in ipairs(Q.Range(c,ts-22,ts+23,'money_evidence'))do
  if proof.source=='auctionDeposit'then E.GoldChecks.RequestDepositHistory(c,proof.id)end
 end
end
-- A cold receipt only schedules its timestamp. The financial worker checks
-- the original time window after Query finishes its cooperative preparation.
function D.Defer(c,ts,linkCosts)
 local pending=c.state.auctionDepositTimes
 if not pending then
  pending={first=1,last=0,times={}}
  c.state.auctionDepositTimes=pending
 end
 if pending.times[pending.last]~=ts then
  pending.last=pending.last+1
  pending.times[pending.last]=ts
 end
 if linkCosts then
  pending.linkCosts=pending.linkCosts or{}
  pending.linkCosts[pending.last]=true
 end
 E.GoldChecks.RequestDepositReview(c)
end
local function near(c,ts)
 if E.db.characters[c.id]~=c then return end
 if not integer(ts)then E.GoldChecks.RequestDepositHistory(c);return end
 if Q.EnsureWarm(c)=='ready'then reviewAt(c,ts)
 else D.Defer(c,ts)end
end
function D.ProcessDeferred(c)
 local pending=c.state.auctionDepositTimes
 if not pending then return false end
 local first=pending.first
 if pending.linkCosts and pending.linkCosts[first]then E.AuctionCosts.LinkAt(c,pending.times[first])end
 reviewAt(c,pending.times[first])
 if pending.linkCosts then pending.linkCosts[first]=nil end
 pending.times[first]=nil
 if first==pending.last then c.state.auctionDepositTimes=nil
 else pending.first=first+1 end
 return true
end
E.On('RECORD_ADDED',function(c,r,_,receipt)
 local d=receipt and receipt.detail
 if type(d)=='table'and d.previousKind and(relevant[d.previousKind]or relevant[r.kind])then E.GoldChecks.RequestDepositHistory(c)end
 if relevant[r.kind]then near(c,r.ts)end
 if r.kind=='auction'and r.source=='owned'and integer(r.auctionID,1)then E.GoldChecks.RequestDepositHistory(c,r.auctionID)end
end)
E.On('RECORD_CHANGED',function(c,r,_,receipt)
 local entry=receipt and changes[receipt];if receipt then changes[receipt]=nil end
 -- TradeCosts.Plan requires the accepted offer's inventory anchor. When
 -- neither observation can claim items, Trades owns the wallet correction.
 if entry and entry.record==r and entry.unanchoredOffer and c.records[r.id]==r
  and r.kind=='trade_offer'and r.inventoryAnchor==nil then return end
 if E.AuctionPreparation and E.AuctionPreparation.ReturnReviewReceipt(c,r,receipt)then return end
 local prior=entry and entry.record==r and entry.prior
 local oldKind=entry and entry.oldKind or Q.PreviousKind(c,r.id)
 if not relevant[r.kind]and not(prior and relevant[prior.kind])and not relevant[oldKind]then return end
 local fresh=stamps[r]or stamp(r)
 -- Repeated owned-list observations change lastObservedAt only. They are not
 -- corrections and must not trigger archive-wide review during normal polling.
 if prior and prior.kind=='auction'and r.kind=='auction'and E.Same(prior,fresh)then return end
 near(c,r.ts)
 if prior then near(c,prior.ts)end
 -- A corrected earlier owned listing can contradict first-use of its ID far
 -- outside the local posting window. Unknown prior membership is conservative.
 -- Inventory dependencies are canonical IDs, not a time radius: an unchanged
 -- poll can retain a very old baseline beneath a fresh posting anchor. Every
 -- correction is conservative, including refs and intermediate claim fields.
 -- Only Inventory's exact in-flight bookkeeping receipt avoids a full review.
 local inventory= r.kind=='inventory'or oldKind=='inventory'or prior and prior.kind=='inventory'
 local bookkeeping=inventory and E.Inventory and E.Inventory.AccountingReceipt(c,r,receipt)
 if not prior or inventory and not bookkeeping then
  E.GoldChecks.RequestDepositHistory(c)
 else
  if prior.kind=='auction'and prior.source=='owned'and integer(prior.auctionID,1)then E.GoldChecks.RequestDepositHistory(c,prior.auctionID)end
  if r.kind=='auction'and r.source=='owned'and integer(r.auctionID,1)then E.GoldChecks.RequestDepositHistory(c,r.auctionID)end
 end
end)
