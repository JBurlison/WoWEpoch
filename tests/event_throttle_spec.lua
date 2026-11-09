local A,C,K=E.API,E.Collectors,E.QuestKills
local function event(name,...)E.frame.scripts.OnEvent(E.frame,name,...)end
local unitRegistrations={}
E.frame.RegisterUnitEvent=function(self,name,unit)unitRegistrations[name]=unit end
MyEpochDB=nil;event('ADDON_LOADED','MyEpoch');TEST_NOW(1000);event('PLAYER_LOGIN')
local c=assert(E.current)
-- Player-only unit events are registered for the player; all-unit events stay global.
for _,name in ipairs({'UNIT_COMBAT','UNIT_MAXHEALTH','UNIT_FACTION','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED'})do
 assert(unitRegistrations[name]=='player'and not E.frame.events[name],name)
end
assert(E.frame.events.UNIT_HEALTH and E.frame.events.UNIT_FLAGS and not unitRegistrations.UNIT_HEALTH)
-- Without per-unit registration, other units' player-only events still stop at the dispatcher.
local seen=0;local combat=C.handlers.UNIT_COMBAT
C.handlers.UNIT_COMBAT=function(...)seen=seen+1;return combat(...)end
event('UNIT_COMBAT','nameplate1','WOUND','',50,1);assert(seen==0)
event('UNIT_COMBAT','player','WOUND','',50,1);assert(seen==1)
C.handlers.UNIT_COMBAT=combat
-- Nameplate health and flags keep the kill tracker's token memory without allocating.
local guids,units={},{}
for i=1,20 do units[i]='nameplate'..i;guids[units[i]]='Creature-0-1-0-1-'..(100+i)..'-0000'..i end
UnitGUID=function(unit)if unit=='player'then return c.id end;return guids[unit]end
for i=1,20 do event('UNIT_HEALTH',units[i])end
assert(K.live.tokens[guids.nameplate3]=='nameplate3')
collectgarbage('collect');collectgarbage('stop');local before=collectgarbage('count')
for n=1,2000 do event('UNIT_HEALTH',units[n%20+1]);event('UNIT_FLAGS',units[n%20+1])end
local grown=(collectgarbage('count')-before)*1024;collectgarbage('restart')
assert(grown<2048,'nameplate events allocated '..grown..' bytes')
-- The token ring keeps the newest 64 identities.
for i=1,70 do local unit='raid'..i;guids[unit]='Player-1-'..i;event('UNIT_HEALTH',unit)end
local remembered=0;for _ in pairs(K.live.tokens)do remembered=remembered+1 end
assert(remembered==64 and #K.live.tokenOrder==64 and K.live.tokens['Player-1-70']=='raid70'and K.live.tokens['Player-1-6']==nil)
-- Quest-log bursts: one immediate read, then held while only neutral events arrive.
local reads=0;local read=C.Quests
C.Quests=function(...)reads=reads+1;return read(...)end
C.Tick(1)
event('QUEST_LOG_UPDATE');assert(reads==1)
event('UNIT_HEALTH','nameplate1');event('QUEST_LOG_UPDATE');event('QUEST_LOG_UPDATE')
assert(reads==1 and C.questLogPending)
C.Tick(0.1);assert(reads==1)
C.Tick(0.2);assert(reads==2 and not C.questLogPending,'a held read runs when the window ends')
-- A quest-relevant event runs a held read first and makes the next update immediate.
event('QUEST_LOG_UPDATE');assert(reads==2 and C.questLogPending)
local order={};local watch=C.handlers.QUEST_WATCH_UPDATE
C.handlers.QUEST_WATCH_UPDATE=function(...)order[#order+1]=reads;return watch(...)end
event('QUEST_WATCH_UPDATE',601);assert(reads==3 and order[1]==3 and not C.questLogPending)
event('QUEST_LOG_UPDATE');assert(reads==4,'an update after a quest event reads at once')
C.handlers.QUEST_WATCH_UPDATE=watch
-- A failed read never holds the retry.
C.Tick(1);local questLog=A.QuestLog;A.QuestLog=function()error('read failed')end
assert(not pcall(event,'QUEST_LOG_UPDATE'))
A.QuestLog=questLog;local count=reads;event('QUEST_LOG_UPDATE');assert(reads==count+1,'a failed read does not hold the retry')
C.Quests=read
-- Player flag changes heartbeat at once, then at most once a second.
local beats=0;local heartbeat=C.Heartbeat
C.Heartbeat=function(...)beats=beats+1;return heartbeat(...)end
C.Tick(1)
event('UNIT_FLAGS','player');event('UNIT_FLAGS','player');event('UNIT_FLAGS','player')
assert(beats==1 and C.flagBeatPending)
C.Tick(0.5);assert(beats==1);C.Tick(0.5);assert(beats==2 and not C.flagBeatPending)
event('UNIT_FLAGS','nameplate2');C.Tick(1);assert(beats==2,'other units never heartbeat')
C.Heartbeat=heartbeat
print('PASS event throttles: per-unit registration, dropped nameplate events, allocation-free health/flags, 64-entry token ring, held quest-log bursts with ordered flushes and failed-read retry, one flag heartbeat per second')
