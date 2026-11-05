local _,E=...
local K,Q,S={},E.Query,E.Store;E.GoldChecks=K
local pending=setmetatable({},{__mode='k'})
local running=setmetatable({},{__mode='k'})
local reviewingDeposits=setmetatable({},{__mode='k'})
local queue,head,tail={},1,0
local reviewVersion=5
local appended=setmetatable({},{__mode='k'})
local priorKinds=setmetatable({},{__mode='k'})
local relevant={gold=true,money_evidence=true,wallet_window=true,trade=true,trade_offer=true,trade_notice=true,
 mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,inventory=true,inventory_gap=true,
 bank=true,bank_gap=true,merchant=true}
local function enqueue(state)tail=tail+1;queue[tail]=state end
function K.Pending(c)return pending[c]~=nil end
function K.Status(c)
 local state=pending[c];if not state then return 'ready'end
 if state.error then return 'failed','Gold source evidence could not be fully checked. Original wallet observations are preserved.'end
 return 'preparing','Checking retained gold source evidence. Your ledger will appear when those checks finish.'
end
function K.Step(c,budget)
 local state=pending[c];if not state then return end
 if E.db.characters[c.id]~=c then pending[c]=nil;return end
 if state.error or Q.EnsureWarm(c)~='ready'then return end
 budget=math.min(64,math.max(0,math.floor(budget or 16)))
 if budget==0 or reviewingDeposits[c]then return end
 if c.state.inventoryCostLinks or c.state.auctionDepositTimes then
  reviewingDeposits[c]=true
  local service=c.state.inventoryCostLinks and E.Inventory.ProcessCostLinks or E.AuctionDeposits.ProcessDeferred
  local ok,why=pcall(service,c)
  reviewingDeposits[c]=nil
  if not ok and pending[c]then pending[c].error=tostring(why)end
  return
 end
 if state.depositWork or state.allDeposits or state.depositIDs then
  -- RequestWallets intentionally ignores recursive attribution. Keep this
  -- work pending until it can actually enqueue the affected wallets.
  if not running[c] and not E.Economy.Attributing(c)then K.StepDepositReview(c,state,budget)end
  return
 end
 local keys=state.targets and state.targets.keys or Q.WalletKeys(c)
 if state.keys~=keys or state.records~=c.records then state.keys=keys;state.records=c.records;state.cursor=1;state.dirty=nil end
 while budget>0 do
  local id=keys[state.cursor]
  if not id then
   if state.dirty then state.cursor=1;state.dirty=nil;return end
   pending[c]=nil;c.state.goldChecksPending=nil
   if not state.targets then c.state.goldSourceReviewVersion=reviewVersion end
   S.Touch(c);return 'done'
  end
  local r=c.records[id]
  if state.targets then state.targets.seen[id]=nil end
  if r and r.kind=='gold'then
   running[c]=true
   local ok,why=pcall(function()E.Trades.CheckWallet(c,r);E.MailMoney.CheckWallet(c,r);E.Economy.CheckWallet(c,r)end)
   running[c]=nil
   if not ok then state.error=tostring(why);return end
  end
  if pending[c]~=state then return end
  state.cursor=state.cursor+1;budget=budget-1
 end
end
function K.Request(c,deferred)
 if not c.state.goldChecksPending then c.state.goldChecksPending=true;S.Touch(c)end
 local state={owner=c,cursor=1,records=c.records};pending[c]=state;enqueue(state)
 if not deferred and Q.EnsureWarm(c)=='ready'then K.Step(c,64)end
end
-- A cold correction can involve wallets not yet present in the private
-- index. Keep one full review and revisit an already consumed prefix.
function K.RequestColdReview(c)
 local state=pending[c]
 if state and not state.targets and not state.error then
  if state.cursor>1 then state.dirty=true end
 else K.Request(c,true)end
end
local function ensureTargetedReview(c)
 local state=pending[c]
 if not state then
  state={owner=c,cursor=1,records=c.records,targets={keys={},seen={}}}
  pending[c]=state
  enqueue(state)
  c.state.goldChecksPending=true
  S.Touch(c)
 end
 return state
end
-- Unknown old deposit dependencies require checking stored deposit proofs and
-- their possible debits. Other wallets keep their existing attribution.
-- A string identifies a saved proof. A numeric client auction ID selects
-- proofs for that listing. No ID means the old dependency is unknown.
function K.RequestDepositHistory(c,proofID)
 local subjects=Q.DepositSubjects(c)
 if subjects and (#subjects==0 or type(proofID)=='number'and not Q.DepositListingProofs(c,proofID))then return end
 local state=ensureTargetedReview(c)
 if not state.targets then
  if state.cursor>1 then state.dirty=true end
 elseif not proofID then
  state.allDeposits=true
  state.depositIDs=nil
 elseif not state.allDeposits then
  local ids=state.depositIDs or{keys={},seen={}}
  if not ids.seen[proofID]then ids.seen[proofID]=true;ids.keys[#ids.keys+1]=proofID end
  state.depositIDs=ids
 end
end
local function depositWallets(c,record,work)
 if record.kind=='gold' and record.source=='auctionDeposit' then K.RequestWallets(c,{record});return end
 if record.kind~='money_evidence' or record.source~='auctionDeposit'or type(record.ts)~='number'then return end
 for bucket=math.floor((record.ts-2)/5),math.floor((record.ts+2)/5)do
  local keys=Q.DepositWallets(c,record.walletWindow,record.amount,bucket)
  local single=type(keys)=='string'
  for n=1,single and 1 or keys and #keys or 0 do
   work()
   local wallet=c.records[single and keys or keys[n]]
   if wallet and wallet.kind=='gold' and wallet.session==record.session and wallet.window==record.walletWindow
      and wallet.amount==record.amount and math.abs(wallet.ts-record.ts)<=2 then K.RequestWallets(c,{wallet})end
  end
 end
end
function K.StepDepositReview(c,state,budget)
 if not state.depositWork then
  local keys=state.allDeposits and Q.DepositSubjects(c) or state.depositIDs.keys
  state.allDeposits=nil;state.depositIDs=nil
  state.depositWork=E.RetentionWork.Start(function(work)
   for n=1,#keys do
    work()
    local key=keys[n]
    if type(key)=='number'then
     local linked=Q.DepositListingProofs(c,key)
     for i=1,linked and #linked or 0 do
      work()
      local proof=c.records[linked[i]]
      if proof and proof.auctionID==key then depositWallets(c,proof,work)end
     end
    else
     local record=c.records[key]
     if record then depositWallets(c,record,work)end
    end
   end
  end)
  if not state.depositWork then state.error='Deferred deposit review unavailable';return end
 end
 local result,why=E.RetentionWork.Step(state.depositWork,budget)
 if result=='failed'then state.error=tostring(why)
 elseif result=='done'then state.depositWork=nil end
end
function K.RequestDepositReview(c)
 ensureTargetedReview(c)
end
K.RequestInventoryReview=K.RequestDepositReview
function K.RequestWallets(c,rows)
 if running[c]or E.Economy.Attributing(c)or #rows==0 then return end
 local state=ensureTargetedReview(c)
 if not state.targets then state.dirty=true;return end
 for _,r in ipairs(rows)do if r.kind=='gold'and c.records[r.id]==r and not state.targets.seen[r.id]then
  state.targets.seen[r.id]=true;state.targets.keys[#state.targets.keys+1]=r.id
 end end
end
function K.Ensure(c)
 if (c.state.goldChecksPending or c.state.inventoryCostLinks or c.state.auctionDepositTimes or c.state.goldSourceReviewVersion~=reviewVersion)and not pending[c]then K.Request(c)end
 return K.Status(c)
end
function K.Retry(c)if pending[c]then K.Request(c)end end
function K.Process()
 local state=queue[head];if not state then return end
 queue[head]=nil;head=head+1;if head>tail then queue={};head,tail=1,0 end
 if pending[state.owner]==state then
  K.Step(state.owner,16)
  if pending[state.owner]==state and not state.error then enqueue(state)end
 end
end
E.On('RECORDS_REMOVED',function(c,ids,batch)if not S.JournalOnlyRemoval(batch)then K.Request(c)end end)
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function whole(v)return finite(v)and v>=0 and v%1==0 end
-- Keep the outer change's membership even if another listener emits a nested
-- change for the same row before this listener gets its turn.
E.On('HISTORY_TOUCHED',function(c,receipt)
 local d=receipt and receipt.detail
 if receipt and receipt.reason=='record'and type(d)=='table'and d.operation=='change'and type(d.record)=='table'then
  priorKinds[receipt]={owner=c,record=d.record,kind=Q.RecordedKind(c,d.record.id)}
 end
end)
-- Live observation receipts describe the entire transition. A reason string
-- alone must never hide a correction to the bounds or owner of saved evidence.
E.On('RECORD_ADDED',function(c,r,_,receipt)
 local d=receipt and receipt.detail
 if type(d)=='table'and d.previousKind and (relevant[d.previousKind]or relevant[r.kind])then K.Request(c,true)end
 appended[c]=receipt and receipt.character==c and receipt.reason=='record'and type(d)=='table'and d.operation=='add'
  and not d.previousKind and d.record==r and r.kind=='gold'and c.records[r.id]==r and r or nil
end)
local function liveWindow(c,r,receipt,append)
 if not receipt or receipt.character~=c then return end
 local reason,d=receipt.reason,receipt.detail
 if reason~='walletUnchanged'and reason~='walletExtension'and reason~='walletTransaction'then return end
 local b=type(d)=='table'and d.before
 if type(b)~='table'or d.record~=r or c.records[r.id]~=r or r.kind~='wallet_window'or r.character~=c.id then return end
 for _,key in ipairs({'id','character','session','ts','opening'})do if r[key]~=b[key]then return end end
 if not finite(r.ts)or not finite(b.ended)or not finite(r.ended)or r.ts>b.ended or r.ended<b.ended or r.ended-b.ended>15
  or not whole(r.opening)or not whole(b.closing)or not whole(r.closing)or not whole(b.transactionCount)or not whole(r.transactionCount)then return end
 if reason=='walletTransaction'then
  local tx=d.transaction
  return type(tx)=='table'and tx==append and c.records[tx.id]==tx and tx.kind=='gold'and tx.character==c.id and tx.window==r.id
   and tx.session==r.session and tx.ts==r.ended and tx.before==b.closing and tx.after==r.closing
   and finite(tx.amount)and tx.amount~=0 and tx.amount==r.closing-b.closing and r.transactionCount==b.transactionCount+1
 end
 return r.closing==b.closing and r.transactionCount==b.transactionCount
  and (reason=='walletUnchanged'and r.ended==b.ended or reason=='walletExtension'and r.ended>b.ended)
end
E.On('RECORD_CHANGED',function(c,r,_,receipt)
 local append=appended[c];appended[c]=nil
 local prior=receipt and priorKinds[receipt];if receipt then priorKinds[receipt]=nil end
 if running[c]or E.Economy.Attributing(c)then return end
 if liveWindow(c,r,receipt,append)then return end
 local state=pending[c]
 local old=Q.PreviousKind(c,r.id)
 if prior and prior.owner==c and prior.record==r then old=prior.kind end
 local correction=not old or r.kind=='gold'or r.kind=='money_evidence'or r.kind=='wallet_window'
  or old=='gold'or old=='money_evidence'or old=='wallet_window'
 if state and state.targets and correction then
  K.Request(c,true);return
 end
 -- Historical generic proof/wallet corrections need review even when no
 -- cleanup was already running. Do not start archive scans for live heartbeats.
 if not state then
  if correction then K.Request(c,true)end
  return
 end
 -- A corrected source can affect a wallet already visited by this pass.
 -- Unknown old membership is conservatively revisited. Ordinary chat/group
 -- updates do not perpetually restart a large financial review.
 if not old or relevant[old]or relevant[r.kind]then state.dirty=true end
end)
