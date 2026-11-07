local _,E=...
local M,S,W={},E.Store,E.RetentionWork;E.MobDrops=M
local function integer(v)return type(v)=='number'and v==v and v>0 and v<=9007199254740991 and v%1==0 end
local function text(v)return type(v)=='string'and v~=''and v end
local function creature(guid)return text(guid)and(guid:match('^Creature%-%w[%w%-]*$')or guid:match('^Vehicle%-%w[%w%-]*$'))end
local function owned(c,key,r,kind)return type(r)=='table'and r.id==key and r.character==c.id and(not kind or r.kind==kind)end
local function sorted(set,work)
 local out={};for key in pairs(set)do work();out[#out+1]=key end
 W.Sort(out,function(a,b)return tostring(a)<tostring(b)end,work);return out
end
local function sequence(r)return integer(r.sequence)and r.sequence or nil end
local function inRange(r,o)
 local ts=S.Timestamp(r)
 return ts and(not o.from or ts>=o.from)and(not o.through or ts<o.through)and(not o.mapID or r.mapID==o.mapID)
end
local function sourceName(r)return text(r.npcName)or text(r.name)or('NPC '..r.npcID)end
-- All joins use retained observation order, never a time/proximity guess.
function M.Report(c,options,work)
 local o=options or {};work=work or function()end
 local out={killCount=0,kills={},items={},byItem={},byWindow={},mobs={},unmatched={},excluded={},refs={},
  coverage='Observed item drops per recorded PARTY_KILL; unseen loot is not inferred. Units are the largest observed simultaneous quantity per kill and item across reopened windows.'}
 if not c or type(c.records)~='table'then return out end
 local events,drops,timelines,mobs,refSet={},{},{},{},{}
 local function mob(id,name)
  if not integer(id)then return end
  local row=mobs[id]
  if not row then row={npcID=id,name=name or('NPC '..id),killCount=0,unmatchedCount=0};mobs[id]=row end
  if name and row.name=='NPC '..id then row.name=name end
  return row
 end
 local function exclude(r,reason)out.excluded[#out.excluded+1]={record=r.id,reason=reason}end
 for key,r in pairs(c.records)do
  work()
  if owned(c,key,r)then
   if r.kind=='kill'and r.source=='PARTY_KILL'and creature(r.victimGUID)and integer(r.npcID)and text(r.session)and sequence(r)then
    events[#events+1]=r
   elseif r.kind=='kill_observation'and r.source=='unit_alive'and r.verifiedAlive==true and creature(r.victimGUID)and sequence(r)then events[#events+1]=r
   elseif r.kind=='drop'and r.source=='loot_window'then drops[#drops+1]=r end
  end
 end
 W.Sort(events,function(a,b)if a.sequence~=b.sequence then return a.sequence<b.sequence end;return a.id<b.id end,work)
 local last,proofs={},{}
 for _,r in ipairs(events)do
  work();local guid=r.victimGUID;local prior=last[guid]
  local timeline=timelines[guid]or{};timelines[guid]=timeline
  if r.kind=='kill_observation'then
   if prior and r.priorKill==prior.id and r.sequence>prior.sequence and text(r.session)then
    proofs[r.id]=r;timeline[#timeline+1]={sequence=r.sequence,alive=true}
   end
  else
   local proof=r.aliveEvidence and proofs[r.aliveEvidence]
   local valid=not prior and not r.aliveEvidence or prior and proof and proof.priorKill==prior.id
    and proof.victimGUID==guid and proof.session==r.session and proof.sequence<r.sequence and prior.npcID==r.npcID
   if valid then
    last[guid]=r;timeline[#timeline+1]={sequence=r.sequence,kill=r}
    if inRange(r,o)then
     local m=mob(r.npcID,sourceName(r));m.killCount=m.killCount+1
     if not o.npcID or r.npcID==o.npcID then
      out.killCount=out.killCount+1;out.kills[#out.kills+1]=r;refSet[r.id]=true
      if proof then refSet[proof.id]=true;refSet[proof.priorKill]=true end
     end
    end
   else
    -- An invalid new lifetime fences later loot; it must not attach to an older corpse.
    timeline[#timeline+1]={sequence=r.sequence,ambiguous=true};exclude(r,'Kill lifetime lacks retained verified alive evidence')
   end
  end
 end
 local function match(source,seq,session)
  if not creature(source.guid)or not integer(source.npcID)then return nil,'Creature identity unavailable' end
  local line=timelines[source.guid];if not line then return nil,'No recorded canonical kill' end
  local lo,hi=1,#line
  while lo<=hi do work();local mid=math.floor((lo+hi)/2);if line[mid].sequence<seq then lo=mid+1 else hi=mid-1 end end
  local state=line[hi];local k=state and state.kill
  if not k then return nil,state and state.alive and 'Creature was observed alive again' or 'Kill lifetime unavailable or ambiguous' end
  if k.session~=session then return nil,'Kill and loot belong to different sessions' end
  if k.npcID~=source.npcID then return nil,'Creature IDs disagree' end
  return k
 end
 local windows,unmatched={},{ }
 local function unmatchedRow(r,sample,source,reason,units)
  if not inRange({ts=sample.ts,mapID=r.mapID},o)then return end
  local npc=source and source.npcID
  if o.npcID and npc~=o.npcID then return end
  local id=tostring(r.id)..':'..tostring(source and source.guid or '')..':'..reason
  local row=unmatched[id]
  if not row then
   row={record=r.id,window=r.window,itemID=r.itemID,npcID=npc,name=sample.data and sample.data.name or r.title,
    reason=reason,label=reason,refs={r.id,r.window},ratePercent=nil};unmatched[id]=row
   local m=mob(npc,source and source.name);if m then m.unmatchedCount=m.unmatchedCount+1 end
  end
  if units then row.observedUnits=math.max(row.observedUnits or 0,units)end
 end
 for _,r in ipairs(drops)do
  work();local window=c.records[r.window]
  if not owned(c,r.window,window,'loot_window')then exclude(r,'Loot window unavailable')
  elseif window.fromItem==true or window.fishing==true or window.originConflict then exclude(r,'Item, fishing or conflicting loot origin')
  elseif not text(r.session)or r.session~=window.session then exclude(r,'Loot window session unavailable or inconsistent')
  elseif not integer(r.itemID)or not integer(r.slot)then exclude(r,'Item or slot identity unavailable')
  else
   local rows=windows[window.id]or{};windows[window.id]=rows
   for _,sample in ipairs(type(r.snapshots)=='table'and r.snapshots or {})do
    work();local data=type(sample)=='table'and sample.data
    if type(data)=='table'and integer(sample.sequence)and sample.sequence>=(sequence(r)or math.huge)and sample.sequence>=(sequence(window)or math.huge)then
     rows[#rows+1]={record=r,sample=sample,sequence=sample.sequence}
    elseif type(data)=='table'then unmatchedRow(r,sample,nil,'Loot observation order unavailable')end
   end
  end
 end
 local byKill={}
 for windowID,eventsInWindow in pairs(windows)do
  work();W.Sort(eventsInWindow,function(a,b)if a.sequence~=b.sequence then return a.sequence<b.sequence end;return a.record.id<b.record.id end,work)
  local first=1
  while first<=#eventsInWindow do
   work();local last=first;local head=eventsInWindow[first];local conflicting=false
   while last<#eventsInWindow and eventsInWindow[last+1].sequence==head.sequence do
    work();last=last+1;local peer=eventsInWindow[last]
    if peer.record~=head.record or not W.Same(peer.sample.data,head.sample.data,work)then conflicting=true end
   end
   if last>first then for index=first,last do work();eventsInWindow[index].conflicting=conflicting;eventsInWindow[index].duplicate=not conflicting and index>first end end
   first=last+1
  end
  local slots,totals,peaks={},{},{}
  local function adjust(rows,sign)
   for _,entry in ipairs(rows or{})do
    work();local key=entry.kill.id..':'..entry.itemID
    local total=totals[key]or{kill=entry.kill,itemID=entry.itemID,name=entry.name,quantity=0,unknown=0,present=0,refs={}}
    totals[key]=total;total.quantity=total.quantity+sign*(entry.quantity or 0);total.unknown=total.unknown+sign*(entry.quantity and 0 or 1);total.present=total.present+sign
    total.refs[entry.record.id]=true;total.refs[windowID]=true
    if sign>0 then
     local peak=peaks[key]or{kill=entry.kill,itemID=entry.itemID,name=entry.name,quantity=0,unknown=false,refs={}};peaks[key]=peak
     peak.quantity=math.max(peak.quantity,total.quantity);peak.unknown=peak.unknown or total.unknown>0
     for id in pairs(total.refs)do work();peak.refs[id]=true end
    end
   end
  end
  for _,event in ipairs(eventsInWindow)do
   work();local r,sample=event.record,event.sample;local data=sample.data
   if not event.duplicate then
   adjust(slots[r.slot],-1);local entries={};slots[r.slot]=entries
   if event.conflicting then
    for _,source in ipairs(type(data.slotSources)=='table'and data.slotSources or{})do
     work();if type(source)=='table'then unmatchedRow(r,sample,source,'Conflicting loot observations share an order')end
    end
   elseif not data.cleared and data.itemPresent~=false then
    local sources=data.slotSources;local count,sum,known,seen=0,0,true,{};local valid=type(sources)=='table'and data.itemID==r.itemID
    if data.visibleQuantity~=nil and not integer(data.visibleQuantity)then valid=false end
    for _,source in ipairs(type(sources)=='table'and sources or{})do
     work();count=count+1
     if type(source)~='table'or not text(source.guid)or seen[source.guid]then valid=false
     else
      seen[source.guid]=true
      if integer(source.quantity)then sum=sum+source.quantity elseif source.quantity==nil then known=false else valid=false end
     end
    end
    if count==0 then valid=false end
    if valid and count>1 and(not known or sum~=data.visibleQuantity)then valid=false end
    if valid and known and data.visibleQuantity~=nil and sum~=data.visibleQuantity then valid=false end
    if not valid then
     local attributed=false
     for _,source in ipairs(type(sources)=='table'and sources or{})do
      work();if type(source)=='table'and(source.kind=='Creature'or source.kind=='Vehicle')and integer(source.npcID)then
       unmatchedRow(r,sample,source,'Loot source breakdown unavailable or inconsistent');attributed=true
      end
     end
     if not attributed then unmatchedRow(r,sample,nil,'Loot source breakdown unavailable or inconsistent')end
    else
     for _,source in ipairs(sources)do
      work();local units=integer(source.quantity)and source.quantity or count==1 and integer(data.visibleQuantity)and data.visibleQuantity or nil
      if source.kind=='Creature'or source.kind=='Vehicle'then
       local k,reason=match(source,sample.sequence,r.session)
       if k and inRange(k,o)then
        mob(source.npcID,source.name)
        if not o.npcID or k.npcID==o.npcID then entries[#entries+1]={kill=k,itemID=r.itemID,name=text(data.name)or r.title,quantity=units,record=r}end
       elseif not k then unmatchedRow(r,sample,source,reason,units)end
      else unmatchedRow(r,sample,source,'Source is not a creature',units)end
     end
    end
   end
   adjust(entries,1)
   end
  end
  out.byWindow[windowID]=peaks
  for _,peak in pairs(peaks)do
   work();local items=byKill[peak.kill.id]or{};byKill[peak.kill.id]=items
   local value=items[peak.itemID]or{kill=peak.kill,itemID=peak.itemID,name=peak.name,quantity=0,unknown=false,refs={}};items[peak.itemID]=value
   value.quantity=math.max(value.quantity,peak.quantity);value.unknown=value.unknown or peak.unknown
   for id in pairs(peak.refs)do work();value.refs[id]=true end
  end
 end
 local query=type(o.query)=='string'and o.query:lower()or''
 local function fits(row)return query==''or(tostring(row.itemID or'')..' '..tostring(row.name or'')):lower():find(query,1,true)end
 for killID,items in pairs(byKill)do
  work()
  for itemID,value in pairs(items)do
   work();local row=out.byItem[itemID]
   if not row then row={itemID=itemID,name=value.name,killsWithItem=0,knownObservedUnits=0,unknownQuantityKills=0,refs={},killIDs={},_refs={}};out.byItem[itemID]=row end
   row.killsWithItem=row.killsWithItem+1;row.knownObservedUnits=row.knownObservedUnits+value.quantity
   if value.unknown then row.unknownQuantityKills=row.unknownQuantityKills+1 end
   row.killIDs[#row.killIDs+1]=killID;row._refs[killID]=true
   local k=value.kill;if k.aliveEvidence then row._refs[k.aliveEvidence]=true end
   for id in pairs(value.refs)do work();row._refs[id]=true end
  end
 end
 for _,row in pairs(out.byItem)do
  work();row.ratePercent=out.killCount>0 and row.killsWithItem*100/out.killCount or nil
  if row.unknownQuantityKills==0 then row.observedUnits=row.knownObservedUnits end
  row.refs=sorted(row._refs,work);row._refs=nil
  W.Sort(row.killIDs,function(a,b)return a<b end,work)
  if fits(row)then out.items[#out.items+1]=row;for _,id in ipairs(row.refs)do work();refSet[id]=true end end
 end
 for _,row in pairs(unmatched)do work();if fits(row)then out.unmatched[#out.unmatched+1]=row end end
 for _,row in pairs(mobs)do work();out.mobs[#out.mobs+1]=row end
 W.Sort(out.items,function(a,b)if a.killsWithItem~=b.killsWithItem then return a.killsWithItem>b.killsWithItem end;return a.itemID<b.itemID end,work)
 W.Sort(out.mobs,function(a,b)if a.name~=b.name then return a.name<b.name end;return a.npcID<b.npcID end,work)
 W.Sort(out.unmatched,function(a,b)if a.record~=b.record then return a.record<b.record end;return a.reason<b.reason end,work)
 out.refs=sorted(refSet,work);out.byKill=byKill
 return out
end
function M.List(c,options,work)return M.Report(c,options,work).mobs end
