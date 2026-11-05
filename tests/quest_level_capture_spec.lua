local S,C,A=E.Store,E.Collectors,E.API
local oldBinding=E.recordingGUID
local oldPlayer,oldSession,oldLevel,oldGUID,oldTime=E.current,C.session,UnitLevel,UnitGUID,A.Now()
local c=S.Character('quest-level-capture-test',{name='Quest level reader',level=12})
E.current=c; E.recordingGUID=c.id; C.session=c.id..':login:1'; c.state.level=12
local observed,id=12,c.id
UnitGUID=function(unit)if unit=='player' then return id end return oldGUID(unit) end
UnitLevel=function()return observed end
local function poll(t)TEST_NOW(oldTime+t); C.RefreshIdentity(); return c.state.questLevelObservation end
local function event(value)E.frame.scripts.OnEvent(E.frame,'PLAYER_LEVEL_UP',value)end
local first=poll(0); assert(first.level==12 and first.session==C.session)
local revision=c.revision
assert(poll(1)==first and c.revision==revision,'unchanged heartbeat rewrote the identical observation')
observed=13; assert(poll(2).level==13 and c.state.level==12,'poll must preserve the level-up milestone baseline')
event(13)
local recorded
for _,r in pairs(c.records)do if r.milestoneType=='level' and r.after==13 then recorded=r end end
assert(recorded and recorded.before==12)
observed=12
local eventReading=c.state.questLevelObservation
assert(poll(3)==eventReading and poll(3)==eventReading and c.identity.level==13)
observed=nil; assert(poll(7)==eventReading)
observed=12;assert(poll(8)==eventReading and poll(12)==eventReading)
assert(poll(13).level==12 and c.identity.level==12 and c.state.level==13,'two spaced reads can confirm a lower correction')
event(14); observed=14; assert(poll(14).level==14)
observed=15; assert(poll(15).level==15,'agreement with an event releases the temporary guard')
local latest=c.state.questLevelObservation
for _,bad in ipairs({0,-1,15.5,'15',0/0,math.huge})do observed=bad;assert(poll(16)==latest);event(bad);assert(c.state.questLevelObservation==latest)end
observed=8;id='different-player';assert(poll(17)==latest and c.identity.level==15)
id=c.id;event(16);observed=8;assert(poll(18).level==16)
C.session=c.id..':login:2';local fresh=poll(18)
assert(fresh.level==8 and fresh.session==C.session,'old session guard leaked into the next session')
E.recordingGUID=oldBinding
UnitGUID,UnitLevel,E.current,C.session=oldGUID,oldLevel,oldPlayer,oldSession
TEST_NOW(oldTime)
print('PASS quest level capture: owned observations, event ordering, lower correction, unchanged polls, invalid samples, session change and milestone baseline')
