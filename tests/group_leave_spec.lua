-- Run in a fresh test VM. Drive actual collector dispatch as group APIs catch up.
local c=E.Store.Character('group-leave-owner',{name='Keeper',realm='Test'})
local C,A=E.Collectors,E.API
E.current=c; C.session='group-leave-test'
local now=2000123000
local count,member=2,'old-companion'
A.Now=function()return now end
IsInRaid=function()return false end
GetNumGroupMembers=function()return count end
UnitGUID=function(u)if u=='player'then return c.id elseif u=='party1'then return member end end
UnitFullName=function(u)return UnitGUID(u),'Test'end
local function event(name,...)E.frame.scripts.OnEvent(E.frame,name,...)end
event('GROUP_JOINED',1,'old-party')
local old=c.records[c.state.group]
now=now+1;member='new-companion'
event('GROUP_JOINED',1,'new-party')
local fresh=c.records[c.state.group]
assert(old.ended and fresh.id~=old.id and fresh.partyGUID=='new-party')
event('GROUP_LEFT',1,'old-party')
assert(C.partyGUID=='new-party' and C.CurrentGroup()==fresh.id,'A late leave must not discard the newer party identity')
event('GROUP_LEFT',2,'outside-category')
assert(C.partyGUID=='new-party' and not fresh.ended)
event('GROUP_LEFT',1,'new-party') -- Unit slots still read as two members.
assert(fresh.ended==now and not c.state.group and not C.CurrentGroup(),'An identified leave closes immediately')
local context=C.Context({})
assert(not context.group and context.groupState=='unknown','A stale positive read cannot create a group at the leave boundary')
event('GROUP_LEFT',1,'new-party')
assert(not c.state.group,'A duplicate leave cannot start another session')
event('GROUP_JOINED',1,'third-party') -- Same second, fresh identity.
assert(C.partyGUID=='third-party' and c.records[c.state.group].partyGUID=='third-party')
event('GROUP_LEFT',1,'third-party'); count=0;C.Roster()
assert(C.Context({}).groupState=='solo')
-- Reloaded mid-party with no identity event. Only an independently readable empty roster can close it.
now=now+2;count=2;C.Roster()
local anonymous=c.records[c.state.group];assert(anonymous and anonymous.partyGUID==nil)
event('GROUP_LEFT',1,'unverified-party')
assert(not anonymous.ended)
count=0;event('GROUP_LEFT',1,'unverified-party')
assert(anonymous.ended==now and not c.state.group)
print('PASS group leave: delayed/foreign/duplicate events, stale positive roster, same-second rejoin and unbound identity reconciliation')
