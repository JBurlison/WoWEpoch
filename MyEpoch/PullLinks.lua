local _,E=...
local L,K,S={},E.Keepsakes,E.Store;E.PullLinks=L
local caches=setmetatable({},{__mode='k'})
local function state(c)
 local s=caches[c];if not s then s={generation=0};caches[c]=s end;return s
end
local function owned(c,r,kind)return K.Record(c,r,kind)end
local function number(n)return K.Number(n,0)end
local function checkpoint(work)if work then work()end end
-- An update context is evidence that this meter session was being observed.
-- Enumeration/read times are not fight times, and are never used as a window.
local function contextMatches(p,k,work)
 if not k.session or p.recordingSession~=k.session or not number(k.ts)then return false end
 for _,ctx in ipairs(p.contexts or{})do checkpoint(work)
  if number(ctx.from)and number(ctx.through)and k.ts>=ctx.from-2 and k.ts<=ctx.through+2
   and k.mapID and k.mapID==ctx.mapID
   and ((k.group and ctx.group==k.group)or(k.groupState=='solo'and ctx.groupState=='solo'and not ctx.group and not k.group))then return true end
 end
 return false
end
local function identity(p,k,work)
 local npc=false
 for _,snapshot in ipairs((p.snapshots or{}).EnemyDamageTaken or{})do
  for _,row in ipairs(snapshot.sources or{})do checkpoint(work)
   if row.sourceGUID and row.sourceGUID==k.victimGUID then return 'victim' end
   if not row.sourceGUID and K.ID(k.npcID)and row.sourceCreatureID==k.npcID then npc=true end
  end
 end
 return npc and 'creature' or nil
end
local function historyGaps(p,ranges,work)
 local rows,seen={},{}
 if #ranges==0 then return rows end
 for _,ctx in ipairs(p.contexts or{})do checkpoint(work)
  if number(ctx.from)and number(ctx.through)then
   for _,range in ipairs(ranges)do checkpoint(work)
    if range.from<=ctx.through+2 and range.through>=ctx.from-2 and not seen[range.record.id]then
     rows[#rows+1]=range.record;seen[range.record.id]=true
    end
   end
  end
 end
 return rows
end
function L.Build(c,work)
 local kills,bySession,ranges={},{},{}
 for _,r in pairs(c.records)do checkpoint(work)
  if owned(c,r,'pull')and r.recordingSession then
   local bucket=bySession[r.recordingSession]or{};bySession[r.recordingSession]=bucket;bucket[#bucket+1]=r
  elseif owned(c,r,'kill')and r.source=='PARTY_KILL'and type(r.victimGUID)=='string'and r.session then kills[#kills+1]=r
  elseif owned(c,r,'gap')then
   for _,kind in ipairs({'pulls','questKills'})do
    local range=r.removedRanges and r.removedRanges[kind]
    if type(range)=='table'and number(range.from)and number(range.through)and range.from<=range.through then
     ranges[#ranges+1]={from=range.from,through=range.through,record=r}
    end
   end
  end
 end
 local result={pulls={},kills={},evidence={pulls={},kills={},gaps={}}};local candidates={};local counts,creatures={},{}
 local gaps=result.evidence.gaps
 for _,kill in ipairs(kills)do
  local choices={}
  for _,pull in ipairs(bySession[kill.session]or{})do checkpoint(work)
   if contextMatches(pull,kill,work)then
    local basis=identity(pull,kill,work)
    if basis then choices[#choices+1]={pull=pull,kill=kill,basis=basis}end
   end
  end
  -- Resolve ambiguity before applying dismissals. Hiding a link cannot turn a
  -- competing candidate into proof for another pull.
  for _,entry in ipairs(choices)do checkpoint(work)
   entry.matches=#choices;candidates[#candidates+1]=entry
   local key=entry.pull.id..':'..tostring(kill.npcID)
   counts[key]=(counts[key]or 0)+1
   if entry.basis=='creature'then creatures[key]=true end
  end
 end
 for _,entry in ipairs(candidates)do checkpoint(work)
  local p,k=entry.pull,entry.kill
  local key=p.id..':'..tostring(k.npcID)
  local dismissed=p.dismissedKillLinks and p.dismissedKillLinks[k.id]
  -- Keep every rival that explains a rejected association. Otherwise cleanup
  -- can remove the ambiguity and manufacture a newly certain inferred link.
  -- An isolated, explicitly dismissed link can still release its protection.
  if not dismissed or entry.matches>1 or creatures[key]and counts[key]>1 then
   local pulls=result.evidence.pulls[p.id]or{};result.evidence.pulls[p.id]=pulls;pulls[#pulls+1]=entry
   local kills=result.evidence.kills[k.id]or{};result.evidence.kills[k.id]=kills;kills[#kills+1]=entry
  end
  if entry.basis=='creature'and gaps[p.id]==nil then gaps[p.id]=historyGaps(p,ranges,work)end
  -- A creature ID identifies a type, not a particular spawn. Multiple kills of
  -- that type remain unassigned unless the meter supplies the victim GUID.
  if entry.matches==1 and(entry.basis=='victim'or counts[key]==1 and #gaps[p.id]==0)and not dismissed then
   local list=result.pulls[p.id]or{};result.pulls[p.id]=list;list[#list+1]=entry;result.kills[k.id]=entry
  end
 end
 for _,list in pairs(result.pulls)do E.RetentionWork.Sort(list,function(a,b)return S.Before(a.kill,b.kill)end,work)end
 return result
end
function L.Get(c)
 if not K.Owned(c)then return end
 local s=state(c)
 if s.ready==s.generation then return s.result end
 if not K.Pending(c,'pull-kill-links')then
  K.Queue(c,'pull-kill-links',function(work)return L.Build(c,work)end,function(result)
   s.result=result;s.ready=s.generation;E.Emit('PULL_LINKS_READY',c)
  end,function()return s.generation end)
 end
 return nil
end
function L.Dismiss(c,p,k)
 if not owned(c,p,'pull')or not owned(c,k,'kill')then return false end
 p.dismissedKillLinks=p.dismissedKillLinks or{};p.dismissedKillLinks[k.id]=true;S.Changed(c,p);return true
end
function L.Restore(c,p)
 if not owned(c,p,'pull')then return false end
 p.dismissedKillLinks=nil;S.Changed(c,p);return true
end
function L.Retention(c,r,add,context)
 if r.kind~='pull'and r.kind~='kill'then return end
 context.pullKillLinks=context.pullKillLinks or L.Build(c,context.work)
 local evidence=context.pullKillLinks.evidence
 if r.kind=='pull'then
  for _,entry in ipairs(evidence.pulls[r.id]or{})do checkpoint(context.work);add(entry.kill.id,{kind='linked',source=r.id})end
  for _,gap in ipairs(evidence.gaps[r.id]or{})do checkpoint(context.work);add(gap.id,{kind='linked',source=r.id})end
 else for _,entry in ipairs(evidence.kills[r.id]or{})do checkpoint(context.work);add(entry.pull.id,{kind='linked',source=r.id})end end
end
E.On('HISTORY_TOUCHED',function(c,receipt)
 if receipt and(receipt.reason=='notes'or receipt.reason=='observation')then return end
 local r=receipt and receipt.detail and receipt.detail.record
 if not r or r.kind=='pull'or r.kind=='kill'or r.kind=='gap'then local s=state(c);s.generation=s.generation+1 end
end)
