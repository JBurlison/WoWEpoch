local _,E=...
local H,W={},E.RetentionWork;E.AuctionHistory=H
-- Closed allowlist, not a financial-kind allowlist: future/unknown evidence
-- remains invalidating. Gap is descriptive coverage, never inventory_gap.
local ignored={quest=true,quest_attempt=true,objective=true,credit=true,kill=true,kill_observation=true,
 group=true,encounter=true,chat=true,pull=true,milestone=true,death=true,spell=true,
 memory=true,screenshot=true,recap=true,diary=true,note=true,play=true,gap=true}
local epoch=0
local ledgers=setmetatable({},{__mode='k'})
local audits=setmetatable({},{__mode='k'})
local receipts=setmetatable({},{__mode='k'})
local function invalidate()epoch=epoch+1;if E.AuctionPreparation then E.AuctionPreparation.reusable=nil end end
local function ledger(c,before)
 local l=ledgers[c]
 if not l then l={revision=before or c.revision,ignored=0,records=c.records,order=c.order,kinds={},trustQuery=true};ledgers[c]=l end
 return l
end
-- Store.Add keys end in ':<sequence>'. Use this only to locate a possible
-- dictionary owner, never to infer ownership. Foreign/legacy dictionary keys
-- remain indexed too, including duplicate claims in other characters.
local function keyOwner(id)
 if type(id)=='string'then return id:match('^(.*):%d+$')end
end
local function rememberException(a,owner,id)
 if a.lookupOpen and keyOwner(id)~=owner then
  local owners=a.exceptions[id];if not owners then owners={};a.exceptions[id]=owners end
  owners[owner]=true
 end
end
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function walletExtension(c,detail,same)
 local r,b=type(detail)=='table'and detail.record,type(detail)=='table'and detail.before
 if type(r)~='table'or type(b)~='table'or r.kind~='wallet_window'or r.character~=c.id or c.records[r.id]~=r then return end
 if not finite(r.ended)or not finite(b.ended)or not finite(r.ts)or r.ts>b.ended or (same and r.ended~=b.ended or not same and r.ended<=b.ended)or r.ended-b.ended>15 then return end
 for _,key in ipairs({'id','character','session','ts','opening','closing','transactionCount'})do if r[key]~=b[key]then return end end
 if not finite(r.opening)or not finite(r.closing)or r.opening<0 or r.closing<0 or r.opening%1~=0 or r.closing%1~=0
  or not finite(r.transactionCount)or r.transactionCount<0 or r.transactionCount%1~=0 then return end
 return r
end
local function watched(id)
 for audit in pairs(audits)do if audit.watched[id]then audit.invalid=true end end
end
E.On('HISTORY_TOUCHED',function(c,receipt)
 local l=ledger(c,receipt.revision-1)
 local known=l.revision+1==receipt.revision and receipt.revision==c.revision
 local reason,detail=receipt.reason,receipt.detail
 local safe=false
 local unchanged=reason=='walletUnchanged'and walletExtension(c,detail,true)
 local extending=reason=='walletExtension'and walletExtension(c,detail)
 if unchanged then safe=true;receipts[receipt]=true
 elseif extending then
  safe=true;receipts[receipt]=true
  if E.AuctionPreparation then E.AuctionPreparation.reusable=nil end
  for a in pairs(audits)do
   if a.snapshotOpen then
    if not a.walletQueued[extending]then a.walletQueued[extending]=true;a.walletQueue[#a.walletQueue+1]=extending end
   elseif (a.walletInstalling or a.walletGuarded)and not a.walletReads[extending]then a.walletDrift[extending]=true
   else a.invalid=true end
  end
 elseif reason=='record'and type(detail)=='table'then
  local r=detail.record;local previous=r and l.kinds[r.id]
  if detail.previousKind then previous=detail.previousKind end
  if r and not previous and l.trustQuery and E.Query and E.Query.RecordedKind then previous=E.Query.RecordedKind(c,r.id)end
  if r then
   -- Record additions can precede discovery of a referenced string. Keep
   -- exceptional keys from audit start, even before this owner's scan runs.
   if detail.operation=='add'and ignored[r.kind]then
    for a in pairs(audits)do
     rememberException(a,c.id,r.id)
     -- An insertion can rehash a live pairs iterator. Abandon this owner's
     -- dictionary scan at its next checkpoint and look it up directly instead.
     if a.dictionaryOwner==c.id then a.uncertainOwners[c.id]=true end
    end
   end
   watched(r.id)
   safe=c.records[r.id]==r and ignored[r.kind]and(detail.operation=='add'and(not previous or ignored[previous])or detail.operation=='change'and ignored[previous])
   l.kinds[r.id]=r.kind
  end
  receipts[receipt]=true
 elseif reason=='retention'and type(detail)=='table'and type(detail.ids)=='table'and type(detail.batch)=='table'and type(detail.batch.kinds)=='table'then
  safe=true
  for kind in pairs(detail.batch.kinds)do if not ignored[kind]then safe=false end end
  -- Store expiry IDs are a set, not an array. Do not scan a lifetime-sized
  -- deletion batch in its atomic commit callback. Only captured ancillary
  -- dependencies can be affected by a positively journal-only batch; missing
  -- or not-yet-read ancillary records can safely remain absent in the snapshot.
  for audit in pairs(audits)do for id in pairs(audit.ancillary)do if detail.ids[id]then audit.invalid=true end end end
  l.kinds={}
  receipts[receipt]=true
 elseif reason=='notes'or reason=='location'or reason=='identity'or reason=='observation'or reason=='questAtlas'or reason=='inventoryUnchanged'or reason=='bankUnchanged'then safe=true end
 -- Only a typed retention commit may replace the canonical survivor maps.
 if reason~='retention'and(l.records~=c.records or l.order~=c.order)then known=false end
 if not known or not safe then
  invalidate()
  if not known or(reason~='record'and reason~='retention')then l.kinds={};l.trustQuery=false end
 else l.ignored=l.ignored+1 end
 l.revision=receipt.revision;l.records=c.records;l.order=c.order
end)
local function recordEvent(c,r,unused,receipt)
 if receipt and receipts[receipt]and receipt.character==c and (receipt.reason=='record'or receipt.reason=='walletExtension'or receipt.reason=='walletUnchanged')and receipt.detail.record==r then receipts[receipt]=nil
 else invalidate();local l=ledger(c);l.kinds={};l.trustQuery=false;if r and r.id then l.kinds[r.id]=r.kind end end
end
E.On('RECORD_ADDED',recordEvent);E.On('RECORD_CHANGED',recordEvent)
E.On('RECORDS_REMOVED',function(c,ids,batch,receipt)
 if receipt and receipts[receipt]and receipt.character==c and receipt.reason=='retention'and receipt.detail.ids==ids and receipt.detail.batch==batch then receipts[receipt]=batch.migrated and'migration'or nil
 else invalidate();local l=ledger(c);l.kinds={};l.trustQuery=false end
end)
E.On('DATA_MIGRATED',function(c,receipt)
 if receipt and receipts[receipt]=='migration'and receipt.character==c then receipts[receipt]=nil
 else
  invalidate()
  for _,owner in pairs(E.db.characters)do if not c or c==owner then local l=ledger(owner);l.kinds={};l.trustQuery=false end end
 end
end)
local function source(a,c)
 local l=ledger(c)
 local s={owner=c,id=c.id,revision=c.revision,ignored=l.ignored,order=c.order,count=#c.order,sequence=c.seq,firstObserved=c.state.firstObserved}
 a.sources[c.id]=s;return s
end
function H.Start(c,trackWallets)
 -- Recover on a fresh request from untyped external replacement/jumps, while
 -- invalidating all older audits. Never silently rebase an in-flight audit.
 for _,owner in pairs(E.db.characters)do
  local l=ledger(owner)
  if l.revision~=owner.revision or l.records~=owner.records or l.order~=owner.order then
   invalidate();l.revision=owner.revision;l.records=owner.records;l.order=owner.order;l.kinds={};l.trustQuery=false
  end
 end
 local a={epoch=epoch,db=E.db,directory=E.db.characters,owner=c,ownerID=c.id,sources={},watched={},ancillary={},queue={},exceptions={},uncertainOwners={},lookupOpen=true,size={characters=0,records=0,tables=0,entries=0,stringBytes=0}}
 a.count=0
 for _,owner in pairs(a.directory)do source(a,owner);a.count=a.count+1 end
 a.complete=true;a.walletTracked=trackWallets==true;a.walletReads={};a.walletDrift={};a.snapshotOpen=true;a.walletQueue={};a.walletQueued={};a.walletCopies={};audits[a]=true;return a
end
function H.Valid(a)
 if not a or a.invalid or a.epoch~=epoch or a.db~=E.db or a.directory~=E.db.characters or E.db.characters[a.ownerID]~=a.owner then return false end
 local count=0
 for id,c in pairs(a.directory)do
  count=count+1;local s=a.sources[id]
  if a.complete and not s then return false end
  if s then
   local l=ledgers[c]
   -- Normal journal additions advance the counter without changing earlier
   -- order. A rollback or previously out-of-counter financial row can
   -- change eligibility and requires a fresh private read.
   if s.sequence~=c.seq and (not finite(s.sequence) or not finite(c.seq)
    or c.seq%1~=0 or c.seq>9007199254740991 or c.seq<s.sequence or s.uncertainOrder)then return false end
   if s.owner~=c or c.id~=s.id or not l or c.revision~=l.revision or c.revision-s.revision~=l.ignored-s.ignored
    or c.records~=l.records or c.order~=l.order or c.state.firstObserved~=s.firstObserved then return false end
  end
 end
 if a.complete and count~=a.count then return false end
 return true
end
-- Every string in financial evidence is conservatively treated as a possible
-- record ID, including missing IDs and cross-character provenance. A closure
-- of referenced ancillary records preserves their full fields (not fake stubs).
local function watch(a,value)
 if type(value)=='string'and not a.watched[value]then a.watched[value]=true;a.queue[#a.queue+1]=value end
end
local function copy(a,value,work,seen)
 if type(value)~='table'then if type(value)=='string'then a.size.stringBytes=a.size.stringBytes+#value end;watch(a,value);return value end
 seen=seen or{};if seen[value]then return seen[value]end
 local out={};seen[value]=out;a.size.tables=a.size.tables+1
 if value.kind=='wallet_window'then local copies=a.walletCopies[value]or{};a.walletCopies[value]=copies;copies[#copies+1]=out end
 for key,v in pairs(value)do work();a.size.entries=a.size.entries+1;watch(a,key);out[copy(a,key,work,seen)]=copy(a,v,work,seen)end
 return out
end
local function watchOrder(s,r)
 if (r.kind=='mail' or r.kind=='auction') and finite(r.sequence)
  and (not finite(s.sequence) or s.sequence%1~=0 or s.sequence>9007199254740991 or r.sequence>s.sequence)then s.uncertainOrder=true end
end
function H.Snapshot(a,work,includeUnordered)
 local db={characters={},settings={},schema=a.db.schema,bankOrder=a.db.bankOrder}
 local sources={}
 -- Directory construction contains no yield, so character membership is stable.
 -- It scales with character count, not lifetime record count.
 for _,c in pairs(a.directory)do local s=a.sources[c.id]or source(a,c);sources[#sources+1]=s;s.lookupOrdinal=#sources end
 a.complete=true;a.count=#sources
 for _,s in ipairs(sources)do
  work();local c=s.owner;a.size.characters=a.size.characters+1
  local target={id=c.id,seq=s.sequence,revision=0,records={},order={},state={firstObserved=s.firstObserved}}
  db.characters[c.id]=target
  for i=1,s.count do
   work();local id=s.order[i];local r=c.records[id]
   if r then
    ledger(c).kinds[id]=r.kind
    watchOrder(s,r)
    if not ignored[r.kind]then a.size.records=a.size.records+1;target.records[id]=copy(a,r,work);target.order[#target.order+1]=id end
   end
  end
  -- Include referenced legacy/orphan keys without changing normal capture
  -- order. Never call next again after an insertion mutates this iterator.
  a.dictionaryOwner=s.id
  for id in pairs(c.records)do
   work();if a.uncertainOwners[s.id]then
    -- The personal-record/item-story reader includes canonical financial
    -- negatives outside display order too. An interrupted dictionary scan
    -- must not publish an incomplete set of those claims.
    if includeUnordered then a.invalid=true end
    break
   end
   rememberException(a,s.id,id)
   local r=c.records[id]
   if includeUnordered and r and not target.records[id]and not ignored[r.kind]then
    ledger(c).kinds[id]=r.kind;watchOrder(s,r)
    a.size.records=a.size.records+1;target.records[id]=copy(a,r,work);target.order[#target.order+1]=id
   end
   if includeUnordered and a.uncertainOwners[s.id]then a.invalid=true;break end
  end
  a.dictionaryOwner=nil
 end
 local cursor=1
 while cursor<=#a.queue do
  local id=a.queue[cursor];cursor=cursor+1
  work()
  local owners={};local direct=keyOwner(id);local candidate=direct and a.sources[direct]
  if candidate then owners[#owners+1]=candidate end
  for owner in pairs(a.exceptions[id]or{})do
   work();if owner~=direct and a.sources[owner]then owners[#owners+1]=a.sources[owner]end
  end
  for owner in pairs(a.uncertainOwners)do
   work();if owner~=direct and not(a.exceptions[id]and a.exceptions[id][owner])and a.sources[owner]then owners[#owners+1]=a.sources[owner]end
  end
  -- Preserve the predecessor's source visitation order when an ID is claimed
  -- by several characters; newly discovered ancillary strings keep that order.
  if #owners>1 then W.Sort(owners,function(x,y)return x.lookupOrdinal<y.lookupOrdinal end,work)end
  for _,s in ipairs(owners)do
   work();local target=db.characters[s.id]
   if not target.records[id]then
    local r=s.owner.records[id]
    if r then
     watchOrder(s,r)
     a.size.records=a.size.records+1
     if ignored[r.kind]then a.ancillary[id]=true end
     target.records[id]=copy(a,r,work);target.order[#target.order+1]=id
    end
   end
  end
 end
 -- Only the ended scalar can change through walletExtension. Refresh every
 -- primary, foreign-key and embedded copy, including a copy yielded mid-field.
 -- The stable queue is insertion-safe across work yields; a repeated extension
 -- requeues an in-progress row, so sealing cannot leave earlier copies stale.
 local walletCursor=1
 while walletCursor<=#a.walletQueue do
  local r=a.walletQueue[walletCursor];walletCursor=walletCursor+1;a.walletQueued[r]=nil
  for _,out in ipairs(a.walletCopies[r]or{})do work();out.ended=r.ended end
 end
 -- No yielding between the final refresh and sealing the revision stamps.
 for _,s in ipairs(sources)do
  local l=ledger(s.owner);s.revision=s.owner.revision;s.ignored=l.ignored
  s.order=nil;s.count=nil;s.lookupOrdinal=nil
 end
 a.snapshotOpen=false;a.sealedAt=E.API.Now();a.walletQueue=nil;a.walletQueued=nil;if not a.walletTracked then a.walletCopies=nil end
 a.queue=nil;a.exceptions=nil;a.uncertainOwners=nil;a.dictionaryOwner=nil;a.lookupOpen=false
 return db
end
