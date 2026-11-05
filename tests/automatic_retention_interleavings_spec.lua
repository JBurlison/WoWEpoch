local S,H,R,A,Q=E.Store,E.History,E.Archive,E.API,E.Query
local now=1900000000;local old=now-90*86400
TEST_NOW(now);UnitAffectingCombat=function()return false end
local function event(n,...)E.frame.scripts.OnEvent(E.frame,n,...)end
event('ADDON_LOADED','MyEpoch');event('PLAYER_LOGIN')
local c=E.current; local session=E.Collectors.session
assert(R.Configure(c,'chat',7));assert(R.SetAutomatic(c,true))
local mem=E.Memories.Create(c,now);local victim=S.Add(c,'chat',old,{text='May become protected'})
local junk=S.Add(c,'chat',old,{text='Control eligible chat'})
for i=1,23 do S.Add(c,'memory',now,{title='A safe memory '..i})end
local quest,kill
if CASE=='questInterval' then
 assert(R.Configure(c,'questKills',7))
 quest=H.BeginQuest(c,777,'An overlapping interval',now-1,true)
 kill=S.Add(c,'kill',old,{title='Old kill timestamp',mobName='Sample mob'})
end
local pre=S.PreviewExpiry(c,now);assert(pre.ids[victim.id] and pre.ids[junk.id]);if kill then assert(pre.ids[kill.id])end
local other,after,added,changed,replaced
local removals=0;E.On('RECORDS_REMOVED',function(owner)if owner==c then removals=removals+1 end end)
local function inject()
 if changed then return end
 changed=true
 if CASE=='star' then victim.starred=true;S.Changed(c,victim)
 elseif CASE=='link' or CASE=='nested' or CASE=='commitLink' then assert(E.Memories.Link(c,mem.id,victim.id));assert(mem.userRefs[victim.id])
 elseif CASE=='financial' then added=E.Economy.Lot(c,now,{itemID=2770,quantity=1,cost=12,evidence=victim.id,quality='inferred',source='Review'},'protected')
 elseif CASE=='note' then S.Note(c,'record:'..victim.id,'Concurrent words from the player',now)
 elseif CASE=='replace' then local seq=c.seq;c.seq=S.Sequence(victim)-1;replaced=S.Add(c,'memory',now,{title='Fresh same-ID memory'});c.seq=math.max(c.seq,seq);assert(replaced.id==victim.id)
 elseif CASE=='otherCleanup' then local snap=S.PreviewExpiry(c,now);S.ApplyExpiry(c,snap);other=true
 elseif CASE=='queue' or CASE=='commitQueue' then c.state.inventoryCostLinks={version=2,rows={}} -- actual publication veto, independent of any notification
 elseif CASE=='questInterval' then H.QuestObserved(c,quest,now);assert(not S.PreviewExpiry(c,now).ids[kill.id])
 end
end
local job=assert(R.StartCleanup(c,nil,true))
local function neutral()
 local prior=c.revision
 H.Wallet(c,now,12345,session);assert(job.revision==c.revision and c.revision>prior,'Real unchanged-wallet receipt did not advance automatic review')
 H.Play(c,now,false,session);assert(job.revision==c.revision,'Real matching play extension cancelled automatic review')
end
local previous=Q.PrepareExpiry
Q.PrepareExpiry=function(...)
 local candidate=previous(...)
 if not other and CASE~='neutral' and CASE~='nested' and not CASE:match('^commit') then
  -- Enter only once: a second real S.ApplyExpiry is allowed to run to completion as a rival publish.
  if not changed then inject()end
 end
 return candidate
end
local n=0;repeat n=n+1;assert(n<20000);local state=R.StepCleanup(1);assert(not state,'Failed before private preparation')until job.phase=='preparing'
neutral()
if CASE:match('^commit') then
 local orig=A.Now
 A.Now=function()
  if not changed and job.phase=='commit' then inject() end
  return orig()
 end
end
if CASE=='nested' then
 local armed=true
 E.On('HISTORY_TOUCHED',function(owner,receipt)if armed and owner==c and receipt.reason=='walletUnchanged'then armed=false;inject()end end)
 H.Wallet(c,now,12345,session)
end
local state,msg
repeat n=n+1;assert(n<20000);state,msg=R.StepCleanup(19)until state
Q.PrepareExpiry=previous
if CASE=='neutral' then
 assert(state=='done' and not c.records[junk.id] and not c.records[victim.id] and removals==1)
elseif CASE=='otherCleanup'then
 assert(changed and state~='done' and removals==1 and not c.records[victim.id] and not c.records[junk.id],'Stale prepared snapshot was republished')
elseif CASE=='replace' then
 assert(changed and state~='done' and c.records[victim.id]==replaced and c.records[junk.id]==junk and removals==0)
else
 assert(changed and state~='done' and removals==0 and c.records[junk.id]==junk and c.records[victim.id]==victim,'Stale cleanup published')
 if CASE=='link' or CASE=='nested' or CASE=='commitLink' then assert(c.records[mem.id]==mem and mem.refs[1]==victim.id and not S.PreviewExpiry(c,now).ids[victim.id])end
 if CASE=='star' or CASE=='financial' then assert(not S.PreviewExpiry(c,now).ids[victim.id]);if added then assert(c.records[added.id]==added)end end
 if CASE=='note' then assert(c.notes['record:'..victim.id].text=='Concurrent words from the player')end
 if CASE=='questInterval' then assert(c.records[kill.id]==kill and not S.PreviewExpiry(c,now).ids[kill.id])end
end
return {state=state,removalNotifications=removals,steps=n}
