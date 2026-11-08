local _,E=...
local K,A,S,H,C={},E.API,E.Store,E.History,E.Collectors; E.QuestKills=K
S.categories.kill_observation='questKills'
-- Only accessible PARTY_KILL identities are counted. Counters and UNIT_DIED
-- do not prove a player/party kill or a victim-to-quest objective link.
local function plain(v)
 local ok,value,hidden=pcall(A.Plain,v)
 if ok and not hidden then return value end
end
local function stringValue(v)
 local value=plain(v)
 if type(value)=='string'and #value>0 and #value<=256 then return value end
end
local function call(label,fn,...)
 local ok,value=pcall(A.Call,label,fn,...)
 if ok then return plain(value)end
end
local function integer(v)
 return type(v)=='number'and v==v and v>0 and v<9007199254740992 and v%1==0
end
local function current()
 local live=K.live
 if live and E.current==live.c and live.owner==live.c.id and C.session==live.session
  and live.c.state.questKillCapture==live.state and (not live.counting or live.state.owner==live.owner)then return live end
end
function K.Start(c,session)
 K.live=nil
 if not c or c~=E.current or type(session)~='string'or session~=C.session then return end
 local state=c.state.questKillCapture
 if state==nil and not c.state.questKillCaptureInitialized then
  state={version=1,owner=c.id,victims={}};c.state.questKillCapture=state;c.state.questKillCaptureInitialized=true
 end
 local counting=type(state)=='table'and state.version==1 and state.owner==c.id and type(state.victims)=='table'
 K.live={c=c,owner=c.id,session=session,state=state,counting=counting,tokens={},tokenOrder={}}
 K.coverage=counting and 'Accessible PARTY_KILL observations only; objective credit is not linked automatically'
  or 'Victim identity continuity unavailable; raw notifications only, unique kills disabled'
 A.status.questKills=K.coverage
 return true
end
function K.Stop() K.live=nil end
local function attemptFor(live, questID)
 local c = live.c
 local id = c.state.activeQuests and c.state.activeQuests[questID]
 local q = id and c.records[id]
 if q and q.id == id and q.character == c.id and q.kind == "quest_attempt"
    and q.questID == questID and q.status == "active" and not q.ended
    and not (C.removed and C.removed[questID]) then return q end
end

function K.WatchUpdate(questID)
 local live = current()
 questID = plain(questID)
 if not live or not integer(questID) then return end
 local q = attemptFor(live, questID)
 if q then C.ObserveQuestCounters(live.c,q,A.Now(),function() return current()==live end) end
end

-- A criterion tree identifies its own reported count. Neither the tree ID
-- nor its localized description identifies a particular PARTY_KILL victim.
local function counter(value)
 return type(value) == "number" and value >= 0 and value < math.huge
end
function K.CriteriaUpdate(questID, treeID, description, fulfilled, required)
 local live = current()
 if not live then return end
 questID, treeID = plain(questID), plain(treeID)
 fulfilled, required = plain(fulfilled), plain(required)
 if not integer(questID) or not integer(treeID) or not counter(fulfilled) or not counter(required) then return end
 description = plain(description)
 if type(description) ~= "string" or description == "" then description = nil end
 local c, ts = live.c, A.Now()
 local q = attemptFor(live, questID)
 if not q or A.OnQuest(questID) ~= true or attemptFor(live, questID) ~= q then q = nil end
 if current() ~= live then return end
 local title = description or ("Quest criterion "..treeID)
 local priorID = q and type(q.lastCriteria) == "table" and q.lastCriteria[treeID]
 local prior = priorID and c.records[priorID]
 if prior and prior.kind == "objective" and prior.character == c.id and prior.attempt == q.id
    and prior.questID == questID and prior.criterionTreeID == treeID and prior.source == "QUEST_LOG_CRITERIA_UPDATE"
    and prior.after == fulfilled and prior.required == required and prior.title == title then return prior end
 local r = S.Add(c, "objective", ts, {
  title=title, questID=questID, criterionTreeID=treeID, after=fulfilled, required=required,
  source="QUEST_LOG_CRITERIA_UPDATE", session=live.session, attribution="reported criterion counter",
  attempt=q and q.id, attemptBasis=q and "active at observation", refs=q and {q.id} or {}, text="Quest "..questID.." reported "..fulfilled.." / "..required
    .." for criterion "..treeID.."."..(q and "" or " The quest occurrence could not be verified.")
 })
 if q and current() == live and attemptFor(live, questID) == q and c.records[r.id] == r then
  if type(q.lastCriteria) ~= "table" then q.lastCriteria = {} end
  if q.lastCriteria[treeID] == (priorID or nil) then
   q.lastCriteria[treeID] = r.id
   S.Changed(c, q)
  end
 end
 return r
end
local function rememberToken(live,guid,token)
 local tokens=live.tokens
 if tokens[guid]==nil then
  -- Fixed 64-entry ring: evict the oldest remembered identity without shifting.
  local order=live.tokenOrder;local slot=live.tokenSlot or(#order%64+1)
  local oldest=order[slot];if oldest~=nil then tokens[oldest]=nil end
  order[slot]=guid;live.tokenSlot=slot%64+1
 end
 if tokens[guid]~=token then tokens[guid]=token end
end
-- Unit events arrive for every nameplate and group member. Readable strings
-- skip the guarded copy; anything else still goes through stringValue.
local function unitText(v)
 if type(v)=='string'and not A.Secret(v)and(type(canaccessvalue)~='function'or canaccessvalue(v)==true)then
  if #v>0 and #v<=256 then return v end
  return
 end
 return stringValue(v)
end
local function victimName(live,guid)
 if not guid then return end
 local tokens={'target','mouseover',live.tokens[guid]}
 for _,token in ipairs(tokens)do
  if stringValue(call('killNameGUID',UnitGUID,token))==guid then
   local name=stringValue(call('killUnitName',UnitName,token))
   if name and stringValue(call('killNameGUIDCheck',UnitGUID,token))==guid and current()==live then return name,token end
  end
 end
end
local function raw(live,ts,data)
 data.session=live.session;data.source='PARTY_KILL';data.refs=data.refs or {}
 return S.Add(live.c,'kill_observation',ts,data)
end
local function active(live,ts)
 local c,verified=live.c,{}
 -- This is the current quest log, never a scan of retained quest history.
 local ids={};for questID in pairs(c.state.activeQuests or {})do if integer(questID)then ids[#ids+1]=questID end end
 table.sort(ids)
 for _,questID in ipairs(ids)do
  local q=c.records[c.state.activeQuests[questID]]
  if q and q.kind=='quest_attempt'and q.character==c.id and q.questID==questID and q.status=='active'then
   local member=call('killQuestMembership',C_QuestLog and C_QuestLog.IsOnQuest,questID)
   if current()~=live then return nil end
   if member==true then
    local interval=q.intervals and q.intervals[#q.intervals]
    if not interval or interval.closed or not q.membershipObserved or ts<interval.through or ts-interval.through>15 then
     H.QuestObserved(c,q,ts)
    end
    verified[#verified+1]=q
   elseif member==false then
    H.PauseQuest(c,q,ts,'Quest no longer active at kill observation')
    H.RemoveQuest(c,questID,ts,live.session,'no longer active; end reason unconfirmed')
   else H.PauseQuest(c,q,ts,'Quest membership unavailable at kill observation')end
  end
 end
 return verified
end
local function validCanonical(c,id,guid)
 local r=type(id)=='string'and c.records[id]
 if r and r.kind=='kill'and r.character==c.id and r.victimGUID==guid and r.source=='PARTY_KILL'then return r end
end
local function aliveProof(c,entry,guid)
 local r=type(entry.alive)=='string'and c.records[entry.alive]
 if r and r.kind=='kill_observation'and r.character==c.id and r.source=='unit_alive'
  and r.verifiedAlive==true and r.victimGUID==guid and r.priorKill==entry.record
  and type(r.sequence)=='number'and type(entry.sequence)=='number'and r.sequence>entry.sequence then return r end
end
function K.Notify(attacker,victim)
 local live=current();if not live then return end
 local c,ts=live.c,A.Now()
 local guid,attackerGUID=stringValue(victim),stringValue(attacker)
 local npcID=guid and call('killCreatureID',C_CreatureInfo and C_CreatureInfo.GetCreatureID,guid)
 if not integer(npcID)then npcID=nil end
 local name,nameUnit=victimName(live,guid)
 local context=C.Context({title='Party kill notification',victimGUID=guid,attackerGUID=attackerGUID,npcID=npcID,npcName=name,nameUnit=nameUnit,
  quality=guid and npcID and 'accessible identity'or 'identity unavailable',counted=false,positionMeaning='Observer location'})
 if current()~=live then return end
 local notification=raw(live,ts,context)
 if current()~=live then return notification end
 local verified=active(live,ts);if not verified then return notification end
 notification.activeAttempts={}
 for _,q in ipairs(verified)do notification.activeAttempts[#notification.activeAttempts+1]=q.id;notification.refs[#notification.refs+1]=q.id end
 if not live.counting then
  notification.reason='Victim identity continuity unavailable; raw notification preserved without a canonical kill'
  notification.text=notification.reason;S.Changed(c,notification);return notification
 end
 if not guid or not npcID then
  notification.reason='Victim GUID or creature ID unavailable; unique kill not counted';notification.text=notification.reason;S.Changed(c,notification)
  return notification
 end
 local entry=live.state.victims[guid]
 local proof=type(entry)=='table'and aliveProof(c,entry,guid)
 if entry~=nil and not proof then
  local prior=type(entry)=='table'and validCanonical(c,entry.record,guid)
  notification.reason='Repeated victim identity without a new verified alive observation; not counted again'
  notification.text=notification.reason
  if prior then notification.canonical=prior.id;notification.refs[#notification.refs+1]=prior.id end
  S.Changed(c,notification);return notification
 end
 local data=C.Context({title=name or ('Creature '..npcID),npcID=npcID,victimGUID=guid,npcName=name,nameUnit=nameUnit,
  attackerGUID=attackerGUID,source='PARTY_KILL',quality='reported kill',session=live.session,
  notification=notification.id,notificationSequence=notification.sequence,refs={notification.id},
  creditCoverage='No direct victim-to-objective credit evidence',positionMeaning='Observer location',
  text='Creature ID '..npcID..'. Reported PARTY_KILL observation; quest-objective attribution is unconfirmed. The position records your character, not the creature.'})
 if current()~=live then return notification end
 for _,q in ipairs(verified)do data.refs[#data.refs+1]=q.id end
 if proof then data.aliveEvidence=proof.id;data.refs[#data.refs+1]=proof.id end
 -- The canonical record gets its own sequence after membership was verified.
 -- A raw receipt sequence must not move it before a reopened interval.
 local kill=H.Kill(c,ts,data,'partyKill:'..notification.id)
 live.state.victims[guid]={record=kill.id,sequence=kill.sequence}
 notification.canonical=kill.id;notification.counted=true;notification.refs[#notification.refs+1]=kill.id
 notification.text='Counted once from an accessible PARTY_KILL victim identity. Linked quest attempts were verified active; no objective-credit link is inferred.'
 S.Changed(c,notification)
 for _,q in ipairs(verified)do
  if c.state.activeQuests[q.questID]==q.id then H.QuestObserved(c,q,ts)end
 end
 return notification,kill
end
function K.Alive(unit)
 local live=current();if not live then return end
 local token=unitText(unit);if not token then return end
 local guid=unitText(A.Call1('killAliveGUID',UnitGUID,token));if not guid then return end
 rememberToken(live,guid,token)
 if not live.counting then return end
 local entry=live.state.victims[guid]
 if type(entry)~='table'or aliveProof(live.c,entry,guid)or type(entry.record)~='string'or type(entry.sequence)~='number'
  or entry.record:sub(1,#live.owner+1)~=live.owner..':'then return end
 if call('killAliveExists',UnitExists,token)~=true or call('killAliveDead',UnitIsDeadOrGhost,token)~=false then return end
 local health=call('killAliveHealth',UnitHealth,token,false)
 if type(health)~='number'or health~=health or health<=0 or health==math.huge then return end
 if stringValue(call('killAliveGUIDCheck',UnitGUID,token))~=guid or current()~=live then return end
 local c=live.c
 local r=S.Add(c,'kill_observation',A.Now(),{title='Victim observed alive again',source='unit_alive',session=live.session,
  victimGUID=guid,verifiedAlive=true,priorKill=entry.record,refs={},
  text='Matching unit identity existed, was not dead or a ghost, and had positive accessible health. This is alive evidence, not a kill.'})
 local prior=validCanonical(c,entry.record,guid);if prior then r.refs[1]=prior.id;S.Changed(c,r)end
 entry.alive=r.id
 return r
end
local function wrap(event,fn)
 local old=C.handlers[event]
 C.handlers[event]=function(...)if old then old(...)end;return fn(...)end
end
wrap('PARTY_KILL',K.Notify)
wrap('QUEST_WATCH_UPDATE',K.WatchUpdate)
wrap('QUEST_LOG_CRITERIA_UPDATE',K.CriteriaUpdate)
wrap('UNIT_FLAGS',K.Alive)
wrap('UNIT_HEALTH',K.Alive)
wrap('PLAYER_LOGOUT',K.Stop)
