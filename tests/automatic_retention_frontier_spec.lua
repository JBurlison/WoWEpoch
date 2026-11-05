local S,H,R,A,Q=E.Store,E.History,E.Archive,E.API,E.Query
local now=1900000000;local old=now-90*86400;TEST_NOW(now);UnitAffectingCombat=function()return false end
local function event(n,...)E.frame.scripts.OnEvent(E.frame,n,...)end
event('ADDON_LOADED','MyEpoch');event('PLAYER_LOGIN');local c=E.current
assert(R.Configure(c,'chat',7));assert(R.Configure(c,'questKills',7));assert(R.Configure(c,'otherNotes',7));assert(R.SetAutomatic(c,true))
local junk=S.Add(c,'chat',old,{text='Unrelated eligible source'});local q=H.BeginQuest(c,991,'Active retained quest',now-1,true)
if CASE~='firstMembership'then H.QuestObserved(c,q,now-1)end
local kill=S.Add(c,'kill',old,{title='Potential quest kill'});local note='record:'..kill.id
S.Note(c,note,'Keep me with the newly protected kill',old)
local i=q.intervals[#q.intervals];local ks=S.QuestSequence(kill)
if CASE=='equal' then i.throughSequence=ks
elseif CASE=='above' then i.throughSequence=ks+1;c.seq=c.seq+2
elseif CASE=='orphan' then for j=#c.order,1,-1 do if c.order[j]==kill.id then table.remove(c.order,j);break end end;assert(c.records[kill.id]==kill)
elseif CASE=='partialStart' then i.fromSequence=nil
elseif CASE=='tooLarge' then i.throughSequence=9007199254740992
elseif CASE=='negative' then i.throughSequence=-1
elseif CASE=='negativeInfinity' then i.throughSequence=-math.huge
elseif CASE=='positiveInfinity' then i.throughSequence=math.huge
elseif CASE=='notANumber' then i.throughSequence=0/0
elseif CASE=='firstMembership' then i.throughSequence=ks
elseif CASE=='fractional' then i.throughSequence=ks+0.5
elseif CASE=='noEnd' then i.throughSequence=nil
elseif CASE=='legacy' then i.fromSequence=nil;i.throughSequence=nil
elseif CASE=='stringEnd' then i.throughSequence='unreadable'
elseif CASE=='invalidStart' then i.fromSequence='legacy'
elseif CASE=='unknownKill' then kill.observationSequence='not captured';assert(not S.QuestSequence(kill));S.Changed(c,kill)
elseif CASE=='newAtFrontier' or CASE=='extendAtFrontier' or CASE=='below' then
else error(CASE)end
S.Changed(c,q)
local initial=S.PreviewExpiry(c,now)
local before=initial.ids[kill.id]==true;local oldNote=initial.noteIDs[note]==true
assert(initial.ids[junk.id]);local notifications=0;E.On('RECORDS_REMOVED',function(who)if who==c then notifications=notifications+1 end end)
local job=assert(R.StartCleanup(c,nil,true));local stage=(CASE=='newAtFrontier' or CASE=='extendAtFrontier') and 'killFrontier' or 'preparing'
local n=0
repeat n=n+1;assert(n<30000 and not R.StepCleanup(1),'Failed before test phase')until job.phase==stage
local function change()
 if CASE=='newAtFrontier' then S.Add(c,'kill',old,{title='New after watermark scan started'}) end
 H.QuestObserved(c,q,now)
end
change()
local fresh=S.PreviewExpiry(c,now);local remain=fresh.ids[kill.id]==true;local noteRemains=fresh.noteIDs[note]==true
local eligibleNew=job.revision==c.revision
local state; repeat n=n+1;assert(n<30000);state=R.StepCleanup(25)until state
if state=='done' then
 assert((c.records[kill.id]==nil)==remain,'STALE KILL REMOVAL, now protected by current interval')
 assert((c.notes[note]==nil)==noteRemains,'STALE NOTE REMOVAL: inherited protection was lost')
 assert(not c.records[junk.id]and notifications==1)
else assert(c.records[kill.id]==kill and c.records[junk.id]==junk and c.notes[note].text=='Keep me with the newly protected kill' and notifications==0)end
if CASE=='equal' or CASE=='above' or CASE=='extendAtFrontier' or CASE=='unknownKill' then assert(state=='done','Valid neutral case stopped')end
if CASE=='newAtFrontier' or CASE=='below' or CASE=='orphan' or CASE=='noEnd' or CASE=='legacy' or CASE=='stringEnd' or CASE=='invalidStart' or CASE=='partialStart' or CASE=='fractional' or CASE=='tooLarge' or CASE=='negative' or CASE=='negativeInfinity' or CASE=='positiveInfinity' or CASE=='notANumber' or CASE=='firstMembership' then assert(state~='done','Unsafe case accepted')end
return {state=state,beforeEligible=before,beforeNoteEligible=oldNote,freshEligible=remain,freshNoteEligible=noteRemains,accepted=eligibleNew}
