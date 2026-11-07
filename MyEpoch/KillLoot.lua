local _,E=...
local L,K,S,W={},E.Keepsakes,E.Store,E.RetentionWork;E.KillLoot=L
L.seconds=90;L.distance=.05
local caches=setmetatable({},{__mode='k'})
local relevant={kill=true,kill_observation=true,loot_window=true,drop=true,loot=true,crafted=true,gathered=true,gather_action=true,gap=true}
local function integer(v)return K.Number(v,1,9007199254740991)and v%1==0 and v or nil end
local function text(v)return type(v)=='string'and v~=''and v or nil end
local function ordered(r)return integer(r.sequence)end
local function owned(c,r,kind)return K.Record(c,r,kind)end
local function empty()return {byKill={},byRecord={},windows={},unmatched={},evidence={},receiptLinks={},receiptSources={}}end
local function values(set,work)
 local rows={};for id in pairs(set or{})do work();rows[#rows+1]=id end
 W.Sort(rows,function(a,b)return tostring(a)<tostring(b)end,work);return rows
end
local function combine(a,b)return not a and b or a==b and a or 'mixed'end
local function annotations(c)
 local state=c.state and c.state.keepsakes
 return state and state.killLootDismissed
end
local function dismissed(c,kill,window)
 local all=annotations(c);local rows=all and all[kill.id]
 return rows and rows[window.id]==true or false
end
function L.ResolveKill(c,r)
 if not owned(c,r)then return end
 if r.kind=='kill'and r.source=='PARTY_KILL'then return r end
 if r.kind=='kill_observation'and r.canonical and text(r.victimGUID)then
  local k=c.records[r.canonical]
  if owned(c,k,'kill')and k.source=='PARTY_KILL'and r.victimGUID==k.victimGUID then return k end
 end
end
function L.HasDismissed(c,r)
 local k=L.ResolveKill(c,r);if not k then return false end
 local all=annotations(c);return all and all[k.id]and next(all[k.id])~=nil or false
end
function L.Dismiss(c,r,window)
 local kill=L.ResolveKill(c,r)
 if not kill or not owned(c,window,'loot_window')then return false end
 local report=L.Get(c);local info=report and report.windows[window.id]
 if not info or info.window~=window or info.basis~='inferred'or not info.encounters[1]or info.encounters[1].kill~=kill then return false end
 local state=K.State(c);state.killLootDismissed=state.killLootDismissed or{}
 local rows=state.killLootDismissed[kill.id]or{};state.killLootDismissed[kill.id]=rows
 if rows[window.id]then return true end
 rows[window.id]=true;S.Touch(c,'killLoot',{kill=kill.id,window=window.id});return true
end
function L.Restore(c,r,window)
 local kill=L.ResolveKill(c,r)
 if not kill or window and not owned(c,window,'loot_window')then return false end
 local all=annotations(c);local rows=all and all[kill.id]
 if not rows then return true end
 if window then rows[window.id]=nil;if not next(rows)then all[kill.id]=nil end else all[kill.id]=nil end
 S.Touch(c,'killLoot',{kill=kill.id,window=window and window.id});return true
end
local function receipt(r)
 return r.kind=='loot'and(not r.source or r.source=='unknown'or r.source=='CHAT_MSG_LOOT'or r.source=='loot')
  and not r.gathering and not r.gatheringOriginal and not r.purchase and not r.merchant and not r.craft
end
function L.DismissReceipt(c,r,window)
 if not owned(c,r,'loot')then return false end
 local report=L.Get(c);local link=report and report.receiptLinks[r.id]
 if not link or not link.inferred or window and link.window~=window then return false end
 local state=K.State(c);state.lootReceiptDismissed=state.lootReceiptDismissed or{}
 local rows=state.lootReceiptDismissed[r.id]or{};state.lootReceiptDismissed[r.id]=rows
 rows[link.window.id]=true;S.Touch(c,'killLoot',{record=r});return true
end
function L.RestoreReceipt(c,r)
 if not owned(c,r,'loot')then return false end
 local state=K.State(c)
 if state.lootReceiptDismissed then state.lootReceiptDismissed[r.id]=nil;S.Touch(c,'killLoot',{record=r})end
 return true
end
function L.ReceiptSource(c,r)
 if not owned(c,r,'loot')then return end
 local report=L.Get(c);return report and report.receiptSources[r.id],report and report.receiptLinks[r.id]
end
local function variant(r)return type(r.itemLink)=='string'and r.itemLink:match('|H(item:[^|]+)|h')end
-- A receipt may arrive just after auto-loot closes the window. Reconstruct
-- that association from retained item observations, without rewriting history.
local function receiptItem(info,r,work)
 local slots,source,sourceDrop,conflict={},nil,nil,false
 for _,d in ipairs(info.drops)do work()
  if d.itemID==r.itemID and(not variant(r)or not variant(d)or variant(r)==variant(d))then
   for _,sample in ipairs(type(d.snapshots)=='table'and d.snapshots or{})do work();local data=type(sample)=='table'and sample.data
    if type(data)=='table'and integer(sample.sequence)and sample.sequence>=(ordered(d)or math.huge)
     and sample.sequence>=(ordered(info.window)or math.huge)and data.itemID==r.itemID
     and not data.cleared and data.itemPresent~=false then
     if integer(d.slot)and integer(data.visibleQuantity)then slots[d.slot]=math.max(slots[d.slot]or 0,data.visibleQuantity)end
     if data.slotSources~=nil then
      local sources=data.slotSources;local s=type(sources)=='table'and #sources==1 and sources[1]
      if type(s)~='table'or not text(s.guid)or not integer(s.npcID)
       or(s.kind~='Creature'and s.kind~='Vehicle')or not s.guid:match('^'..s.kind..'%-')
       or s.quantity~=nil and(not integer(s.quantity)or data.visibleQuantity~=nil and s.quantity~=data.visibleQuantity)
       or source and source.guid~=s.guid then conflict=true
      else source=source or s;sourceDrop=sourceDrop or d end
     end
    end
   end
  end
 end
 local quantity=0;for _,value in pairs(slots)do work();quantity=quantity+value end
 return quantity,not conflict and source or nil,not conflict and sourceDrop or nil
end
local function groupMatches(a,b)
 return a.group and a.group==b.group or not a.group and not b.group and a.groupState=='solo'and b.groupState=='solo'
end
local function distance(a,b)
 local p,q=a.position,b.position
 if type(p)~='table'or type(q)~='table'then return end
 if p.mapID~=a.mapID or q.mapID~=b.mapID or p.mapID~=q.mapID or p.artID and q.artID and p.artID~=q.artID then return false end
 if not K.Number(p.x,0,1)or not K.Number(p.y,0,1)or not K.Number(q.x,0,1)or not K.Number(q.y,0,1)then return end
 return math.sqrt((p.x-q.x)^2+(p.y-q.y)^2)
end
local function choose(rows,work)
 local delay,tied=nil,{}
 for _,row in ipairs(rows)do work()
  if not delay or row.delay<delay then delay=row.delay;tied={row}
  elseif row.delay==delay then tied[#tied+1]=row end
 end
 if #tied==1 then return tied[1]end
 local best,tie
 for _,row in ipairs(tied)do work()
  if not row.distance then return end
  if not best or row.distance<best.distance-1e-8 then best=row;tie=false
  elseif math.abs(row.distance-best.distance)<=1e-8 then tie=true end
 end
 return not tie and best or nil
end
-- This is a separate association projection. Its private inferred source overlay
-- is never saved or passed to the exact-only mob-drop statistics interface.
function L.Build(c,work)
 work=work or function()end;local out=empty();if not K.Owned(c)then return out end
 local records,windows,drops,receipts,byGUID,gaps={},{},{},{},{},{}
 local function edge(a,b)
  if not a or not b or a==b or not owned(c,c.records[a])or not owned(c,c.records[b])then return end
  local aa=out.evidence[a]or{};out.evidence[a]=aa;aa[b]=true
  local bb=out.evidence[b]or{};out.evidence[b]=bb;bb[a]=true
 end
 for id,r in pairs(c.records)do work()
  if owned(c,r)and r.id==id then
   records[id]=r
   if r.kind=='loot_window'then windows[id]={window=r,drops={},receipts={},items={},candidates={},encounters={},last=r.ts}
   elseif r.kind=='drop'and r.source=='loot_window'then drops[#drops+1]=r
   elseif r.kind=='loot'or r.observedLootWindow and(r.kind=='crafted'or r.kind=='gathered')then receipts[#receipts+1]=r end
   if(r.kind=='kill'or r.kind=='kill_observation')and text(r.victimGUID)then
    local rows=byGUID[r.victimGUID]or{};byGUID[r.victimGUID]=rows;rows[#rows+1]=r
   elseif r.kind=='gap'then
    for _,category in ipairs({'questKills','loot','production'})do
     local range=r.removedRanges and r.removedRanges[category]
     if type(range)=='table'and K.Number(range.from)and K.Number(range.through)then gaps[#gaps+1]={record=r,from=range.from,through=range.through}end
    end
   end
  end
 end
 for _,r in ipairs(drops)do work();local info=windows[r.window]
  if info then info.drops[#info.drops+1]=r;edge(r.id,r.window)end
 end
 for _,r in ipairs(receipts)do work();local info=windows[r.observedLootWindow]
  if info then
   info.receipts[#info.receipts+1]=r;edge(r.id,info.window.id)
   if r.kind=='crafted'or r.kind=='gathered'or not receipt(r)then info.nonCombat=true end
  end
 end
 local fences={}
 for _,rows in pairs(byGUID)do
  W.Sort(rows,function(a,b)local aa,bb=ordered(a)or 0,ordered(b)or 0;return aa==bb and a.id<b.id or aa<bb end,work)
  local prior
  for _,r in ipairs(rows)do work()
   edge(rows[1].id,r.id)
   if ordered(r)then
    if r.kind=='kill'and r.source=='PARTY_KILL'then
     if prior then fences[prior.id]=math.min(fences[prior.id]or math.huge,r.sequence)end;prior=r
    elseif r.source=='unit_alive'and r.verifiedAlive and prior and r.priorKill==prior.id then
     fences[prior.id]=math.min(fences[prior.id]or math.huge,r.sequence)
    end
   end
  end
 end
 local orderedWindows={}
 for id,info in pairs(windows)do work();local window=info.window;out.windows[id]=info
  local seen={}
  info.excluded=window.fromItem==true or window.fishing==true or window.originConflict or info.nonCombat
   or type(window.gatherActions)=='table'and next(window.gatherActions)~=nil
  if info.excluded then records[id]=nil;info.reason='Non-combat loot origin.'end
  for _,drop in ipairs(info.drops)do work()
   for _,sample in ipairs(type(drop.snapshots)=='table'and drop.snapshots or{})do work()
    local data=type(sample)=='table'and sample.data
    if type(data)=='table'then
     if K.Number(sample.ts)then info.last=math.max(info.last or sample.ts,sample.ts)end
     if data.slotSources~=nil then
      info.explicit=true
      for _,source in ipairs(type(data.slotSources)=='table'and data.slotSources or{})do work()
       if type(source)=='table'then
        for _,r in ipairs(byGUID[source.guid]or{})do work();edge(window.id,r.id)end
       end
      end
     end
     if ordered(window)and ordered(drop)and integer(sample.sequence)and sample.sequence>=window.sequence and sample.sequence>=drop.sequence then
      local previous=seen[sample.sequence]
      if previous and(previous.record~=drop or not W.Same(previous.data,data,work))then info.invalidOrder=true end
      seen[sample.sequence]={record=drop,data=data}
      if not data.cleared and data.itemPresent~=false and integer(drop.slot)and integer(drop.itemID)and data.itemID==drop.itemID
       and(data.visibleQuantity==nil or integer(data.visibleQuantity))then info.items[drop.itemID]=true end
     end
    end
   end
  end
  orderedWindows[#orderedWindows+1]=info
 end
 W.Sort(orderedWindows,function(a,b)local aa,bb=ordered(a.window)or 0,ordered(b.window)or 0;return aa==bb and a.window.id<b.window.id or aa<bb end,work)
 -- Index visible items by login and time. Missing window IDs must not turn
 -- every receipt into a scan of the whole character's history.
 local receiptIndex={}
 for _,info in ipairs(orderedWindows)do work();local w=info.window
  if text(w.session)and S.Timestamp(w)then
   local session=receiptIndex[w.session]or{};receiptIndex[w.session]=session
   for item in pairs(info.items)do work();local rows=session[item]or{};session[item]=rows;rows[#rows+1]=info end
  end
 end
 for _,session in pairs(receiptIndex)do for _,rows in pairs(session)do
  W.Sort(rows,function(a,b)return a.window.ts==b.window.ts and(ordered(a.window)or 0)<(ordered(b.window)or 0)or a.window.ts<b.window.ts end,work)
 end end
 for _,r in ipairs(receipts)do work()
  if receipt(r)and integer(r.itemID)and integer(r.quantity)and S.Timestamp(r)and ordered(r)then
   local chosen,inferred
   if r.observedLootWindow then chosen=windows[r.observedLootWindow]
   elseif text(r.session)and integer(r.mapID)then
    local rows=receiptIndex[r.session]and receiptIndex[r.session][r.itemID]or{}
    local low,high=1,#rows+1
    while low<high do work();local mid=math.floor((low+high)/2);if rows[mid].window.ts<r.ts-L.seconds then low=mid+1 else high=mid end end
    local ambiguous=false
    for i=low,#rows do work();local info=rows[i];local w=info.window;if w.ts>r.ts then break end
     local close=w.closedAt or info.last or w.ts
     if ordered(w)and w.sequence<r.sequence and w.mapID==r.mapID and groupMatches(w,r)
      and r.ts<=close+2 and not info.excluded and not info.invalidOrder then
      local d=distance(w,r);local quantity=receiptItem(info,r,work)
      local missing=false
      for _,gap in ipairs(gaps)do work();if gap.from<=r.ts and gap.through>=w.ts then missing=true;edge(r.id,gap.record.id)end end
      if not missing and d~=false and(not d or d<=L.distance)and quantity>=r.quantity then
       edge(r.id,w.id);if chosen then ambiguous=true end;chosen=info
      end
     end
    end
    if ambiguous then chosen=nil end;inferred=chosen~=nil
   end
   if chosen then
    local w=chosen.window;local quantity,source,drop=receiptItem(chosen,r,work)
    if not chosen.excluded and not chosen.invalidOrder and r.session==w.session and ordered(w)and w.sequence<r.sequence
     and S.Timestamp(w)and r.ts>=w.ts and r.ts<=math.max(chosen.last or w.ts,w.closedAt or w.ts)+2 and quantity>=r.quantity then
     local state=c.state and c.state.keepsakes;local rejected=state and state.lootReceiptDismissed
     rejected=inferred and rejected and rejected[r.id]and rejected[r.id][w.id]or false
     out.receiptLinks[r.id]={window=w,inferred=inferred==true,rejected=rejected,source=source,drop=drop}
     edge(r.id,w.id)
     if inferred and not rejected then chosen.receipts[#chosen.receipts+1]=r end
    end
   end
  end
 end
 local view={id=c.id,records=records}
 local exact=E.MobDrops.Report(view,nil,work)
 local used,knownItems,lastWindow,killIndex={},{},{},{}
 for _,kill in ipairs(exact.kills)do work()
  if text(kill.session)and integer(kill.mapID)and S.Timestamp(kill)then
   local session=killIndex[kill.session]or{};killIndex[kill.session]=session
   local rows=session[kill.mapID]or{};session[kill.mapID]=rows;rows[#rows+1]=kill
  end
 end
 for _,session in pairs(killIndex)do for _,rows in pairs(session)do W.Sort(rows,function(a,b)return a.ts==b.ts and a.sequence<b.sequence or a.ts<b.ts end,work)end end
 local inferred={}
 for _,info in ipairs(orderedWindows)do work();local w=info.window
  -- Reserve exact encounters when their window is reached. A later exact
  -- reopening must not push an earlier source-less window onto another kill.
  for _,item in pairs(exact.byWindow[w.id]or{})do work();local id=item.kill.id
   used[id]=true;lastWindow[id]=w;knownItems[id]=knownItems[id]or{};knownItems[id][item.itemID]=true
  end
  if not info.excluded and not info.explicit and next(info.items)and not info.invalidOrder and ordered(w)and S.Timestamp(w)
   and w.fromItem==false and w.fishing==false and not w.gatherActionGap and text(w.session)and integer(w.mapID)then
   local rows=killIndex[w.session]and killIndex[w.session][w.mapID]or{}
   local low,high=1,#rows+1
   while low<high do work();local mid=math.floor((low+high)/2);if rows[mid].ts<w.ts-L.seconds then low=mid+1 else high=mid end end
   local available,reopened={},{}
   for index=low,#rows do work();local kill=rows[index];if kill.ts>w.ts then break end
    if kill.sequence<w.sequence and(not fences[kill.id]or fences[kill.id]>=w.sequence)and groupMatches(kill,w)then
     local d=distance(kill,w)
     if d~=false and(not d or d<=L.distance)then
      local candidate={kill=kill,delay=w.ts-kill.ts,distance=d};info.candidates[#info.candidates+1]=kill;edge(kill.id,w.id)
      if not used[kill.id]then available[#available+1]=candidate
      else
       local prior=lastWindow[kill.id];local overlap=false
       for item in pairs(info.items)do work();if knownItems[kill.id]and knownItems[kill.id][item]then overlap=true end end
       if prior and prior.sequence<w.sequence and w.ts>=prior.ts and w.ts-prior.ts<=30 and overlap then reopened[#reopened+1]=candidate end
      end
     end
    end
   end
   local missing=false
   for _,gap in ipairs(gaps)do work()
    if gap.from<=w.ts and gap.through>=w.ts-L.seconds then missing=true;edge(w.id,gap.record.id)end
   end
   local chosen=not missing and choose(#available>0 and available or reopened,work)
   if chosen and #available>0 and #reopened>0 then
    -- The same visible items can be a reopened corpse. Do not consume an older
    -- unmatched kill merely because the previous encounter already has loot.
    for _,candidate in ipairs(reopened)do work()
     local prior=lastWindow[candidate.kill.id]
     if chosen.kill.sequence<prior.sequence then chosen=nil;break end
    end
   end
   if chosen then
    local kill=chosen.kill;inferred[w.id]=kill
    info.basis='inferred';info.reason='Inferred from an earlier kill, matching session, map and group, with nearby player observations when available.'
    used[kill.id]=true;lastWindow[kill.id]=w;knownItems[kill.id]=knownItems[kill.id]or{}
    for item in pairs(info.items)do work();knownItems[kill.id][item]=true end
    for _,drop in ipairs(info.drops)do work();local clone=W.Copy(drop,work);records[drop.id]=clone
     for _,sample in ipairs(clone.snapshots or{})do work();local data=sample.data
      if type(data)=='table'and data.slotSources==nil and data.itemID==drop.itemID and(data.visibleQuantity==nil or integer(data.visibleQuantity))then
       data.slotSources={{guid=kill.victimGUID,npcID=kill.npcID,kind=kill.victimGUID:match('^(%a+)%-'),quantity=data.visibleQuantity}}
      end
     end
    end
   else info.reason=missing and 'Nearby history has expired; an inferred source cannot be chosen.'or #info.candidates>0 and 'Several nearby sources or previous loot encounters remain ambiguous.'or 'No nearby earlier kill with matching session, map and group.'end
  elseif not info.reason then info.reason=info.explicit and 'Explicit corpse or object sources are not replaced by proximity guesses.'or 'Loot origin, observation order or item details are unavailable.'end
 end
 local report=next(inferred)and E.MobDrops.Report(view,nil,work)or exact
 local refsByKill,recordSets,receiptTargets={},{},{}
 local function encounter(kill)
  local e=out.byKill[kill.id]
  if not e then e={id='kill-loot:'..kill.id,kill=kill,items={},byItem={},windows={},receipts={},refs={}};out.byKill[kill.id]=e;refsByKill[kill.id]={[kill.id]=true}end
  return e
 end
 local function map(id,e)
  recordSets[id]=recordSets[id]or{};recordSets[id][e.kill.id]=e;refsByKill[e.kill.id][id]=true
 end
 for windowID,peaks in pairs(report.byWindow)do work();local info=windows[windowID];local associations={}
  receiptTargets[windowID]={}
  for _,peak in pairs(peaks)do work();local kill=peak.kill
   local targets=receiptTargets[windowID][peak.itemID]or{};receiptTargets[windowID][peak.itemID]=targets;targets[kill.id]=true
   -- A rejected proximity guess must never hide later recorded corpse evidence.
   if inferred[windowID]~=kill or not dismissed(c,kill,info.window)then
    local e=encounter(kill);local a=associations[kill.id]
    if not a then
     local basis=inferred[windowID]==kill and 'inferred'or'exact'
     a={id=windowID,windowID=windowID,window=info.window,record=info.window,basis=basis,
      reason=basis=='exact'and 'Recorded corpse GUID and retained kill lifetime match.'or info.reason,items={},drops={},receipts={},refs={},_refs={}}
     associations[kill.id]=a;e.windows[#e.windows+1]=a;info.encounters[#info.encounters+1]=e;e.basis=combine(e.basis,basis)
     info.basis=combine(info.basis,basis)
    end
    local item={itemID=peak.itemID,name=peak.name,knownQuantity=peak.quantity,quantity=not peak.unknown and peak.quantity or nil,unknown=peak.unknown,basis=a.basis,refs=values(peak.refs,work)}
    a.items[#a.items+1]=item
    local total=e.byItem[item.itemID]
    if not total then total={itemID=item.itemID,name=item.name,knownQuantity=0,unknown=false,refs={},_refs={}};e.byItem[item.itemID]=total;e.items[#e.items+1]=total end
    total.knownQuantity=math.max(total.knownQuantity,item.knownQuantity);total.unknown=total.unknown or item.unknown;total.basis=combine(total.basis,a.basis)
    for _,id in ipairs(item.refs)do work();a._refs[id]=true;total._refs[id]=true;map(id,e);edge(kill.id,id)end
    map(kill.id,e);map(windowID,e);edge(kill.id,windowID)
   end
  end
  for _,a in pairs(associations)do work()
   a.refs=values(a._refs,work);a._refs=nil
   for _,id in ipairs(a.refs)do work();if owned(c,c.records[id],'drop')then a.drops[#a.drops+1]=c.records[id]end end
   W.Sort(a.items,function(x,y)return x.itemID<y.itemID end,work)
  end
 end
 for _,info in ipairs(orderedWindows)do work();local w=info.window
  for _,r in ipairs(info.receipts)do work()
   if receipt(r)and r.session==w.session and integer(r.itemID)and integer(r.quantity)and S.Timestamp(r)and S.Timestamp(w)
    and r.ts>=w.ts and r.ts<=math.max(info.last or w.ts,w.closedAt or w.ts)+2 then
    -- Resolve receipt ambiguity before dismissals. Hiding one area-loot victim
    -- cannot turn its shared receipt into evidence for the other victim.
    local target,ambiguous
    for id in pairs(receiptTargets[w.id]and receiptTargets[w.id][r.itemID]or{})do work();if target then ambiguous=true end;target=id end
    local found=not ambiguous and target and out.byKill[target];local association
    if found then for _,a in ipairs(found.windows)do work();if a.window==w then association=a;break end end end
    local link=out.receiptLinks[r.id]
    if found and association and not(link and link.rejected)then
     found.receipts[#found.receipts+1]=r;association.receipts[#association.receipts+1]=r;map(r.id,found);edge(found.kill.id,r.id)
     local name=link and link.source and link.source.guid==found.kill.victimGUID and link.source.name
     out.receiptSources[r.id]={npcID=found.kill.npcID,name=name or found.kill.npcName or found.kill.title,kill=found.kill,record=found.kill,window=w,
      basis=link and link.inferred and 'inferred'or association.basis}
    end
   end
  end
  if #info.encounters==0 then out.unmatched[#out.unmatched+1]={record=w.id,window=w,reason=info.reason or 'No retained item quantities could be associated.'}end
 end
 -- The client can identify a corpse even when its kill was not recorded.
 -- Show that recorded creature source and link the slot, never another kill
 -- of the same species merely because it happened nearby.
 for id,link in pairs(out.receiptLinks)do work()
  if not link.rejected and not out.receiptSources[id]and link.source then
   out.receiptSources[id]={npcID=link.source.npcID,name=link.source.name,record=link.drop,window=link.window,
    basis=link.inferred and 'inferred'or'exact'}
   edge(id,link.drop.id)
  end
 end
 for _,rows in pairs(byGUID)do for _,raw in ipairs(rows)do work();local kill=L.ResolveKill(c,raw);local e=kill and out.byKill[kill.id]
  if e then map(raw.id,e);edge(raw.id,kill.id)end
 end end
 for id,e in pairs(out.byKill)do work()
  W.Sort(e.items,function(a,b)return a.itemID<b.itemID end,work)
  W.Sort(e.windows,function(a,b)return S.Before(a.window,b.window)end,work)
  W.Sort(e.receipts,S.Before,work);e.refs=values(refsByKill[id],work)
  for _,item in ipairs(e.items)do work();item.quantity=not item.unknown and item.knownQuantity or nil;item.refs=values(item._refs,work);item._refs=nil end
 end
 for id,set in pairs(recordSets)do work();local rows={};out.byRecord[id]=rows
  for _,e in pairs(set)do work();rows[#rows+1]=e end;W.Sort(rows,function(a,b)return S.Before(a.kill,b.kill)end,work)
 end
 if not K.Owned(c)then return empty()end
 return out
end
local function state(c)
 local s=caches[c];if not s then s={generation=0};caches[c]=s end
 if s.records~=c.records then s.records=c.records;s.generation=s.generation+1 end
 return s
end
function L.Get(c)
 if not K.Owned(c)then return end
 local s=state(c);if s.ready==s.generation then return s.result end
 if not K.Pending(c,'kill-loot')then
  K.Queue(c,'kill-loot',function(work)return L.Build(c,work)end,function(result)
   s.result=result;s.ready=s.generation;E.Emit('KILL_LOOT_READY',c)
  end,function()return state(c).generation end)
 end
end
function L.Retention(c,r,add,context)
 if not relevant[r.kind]then return end
 context.killLoot=context.killLoot or L.Build(c,context.work)
 for id in pairs(context.killLoot.evidence[r.id]or{})do if context.work then context.work()end;add(id,{kind='linked',source=r.id})end
end
E.On('HISTORY_TOUCHED',function(c,receipt)
 if not K.Owned(c)then return end
 local reason=receipt and receipt.reason
 local detail=receipt and type(receipt.detail)=='table'and receipt.detail
 local r=detail and type(detail.record)=='table'and detail.record
 -- The projection reads retained records and its own dismissal annotations.
 -- State-only touches (location, inventory, preferences, recap reads) cannot
 -- change those inputs and must not continually restart a prepared report.
 if not receipt or reason=='killLoot'or reason=='retention'or r and(relevant[r.kind]or relevant[detail.previousKind])
  or reason=='record'and not r then local s=state(c);s.generation=s.generation+1 end
end)
