-- Standalone lifecycle fixture. The driver gives every phase a new TOC-loaded VM.
local phase=assert(TEST_OWNER_PHASE)
local first,second='Player-TEST-11111','Player-TEST-22222'
local token=(phase=='cutoff' or phase:match('^logout')) and first or second
local peer=token..'-friend'
local wallet=(phase=='cutoff' or phase:match('^logout')) and 200 or phase=='seed' and 800 or 3333
local clock=2000000000+(phase=='seed' and 0 or phase=='cutoff' and 20 or 50)
TEST_NOW(clock)
local secret={};issecretvalue=function(v)return rawequal(v,secret)end
UnitGUID=function(unit)if unit=='player'then return token elseif unit=='party1'then return peer end end
UnitFullName=function(unit)return unit=='player'and 'Scribe' or 'Companion','Realm' end
GetMoney=function()return wallet end
GetNumGroupMembers=function()return 2 end
IsInRaid=function()return false end
local photographed=0;Screenshot=function()photographed=photographed+1 end
local function event(name,...)E.frame.scripts.OnEvent(E.frame,name,...)end
local function frame(delta)E.frame.scripts.OnUpdate(E.frame,delta)end
local function texts(c)
 local result={}
 for _,r in pairs(c.records)do if r.kind=='chat' then assert(r.character==c.id);result[r.text]=r end end
 return result
end
local function chat(text)event('CHAT_MSG_PARTY',text,'Companion')end
local function incoming(text)
 event('GROUP_JOINED',1,'Party-'..text);event('GROUP_ROSTER_UPDATE');event('PLAYER_MONEY');chat(text)
end
event('ADDON_LOADED','MyEpoch')
event('PLAYER_LOGIN')
local c=assert(E.current);assert(c.id==token and E.db.characters[token]==c)
if phase=='seed' then
 incoming('Seed second character');assert(texts(c)['Seed second character'] and c.state.wallet.amount==800)
 event('PLAYER_LOGOUT')
 return
elseif phase=='logout_then_switch' then
 local other=assert(E.db.characters[second]);local sequence=other.state.sessionSequence
 event('PLAYER_LOGOUT') -- departing player is still readable while logout is delivered
 token=second;wallet=15432
 for i=1,8 do frame(.25)end -- no entering-world or login after logout
 assert(E.current~=other and other.state.sessionSequence==sequence,'Verified old-owner logout acquired the new player during teardown frames')
 event('PLAYER_LOGIN');for i=1,8 do frame(.25);if E.current==other then break end end
 assert(E.current==other and other.state.sessionSequence==sequence+1,'Genuine new-character login did not clear logout fence')
 return
elseif phase=='logout' then
 local snapshot=E.Copy(E.db.characters[second])
 token=second;wallet=19876
 event('PLAYER_LOGOUT')
 for i=1,8 do frame(.25)end
 assert(E.Same(snapshot,E.db.characters[second]),'Logout silently acquired the other owner')
 assert(c.state.wallet.amount==200,'Logout wrote foreign wallet to previous character')
 token=first;wallet=240;event('PLAYER_LOGIN');for i=1,8 do frame(.25)end
 event('PLAYER_MONEY');chat('departing owner relogged')
 assert(E.current==c and c.state.wallet.amount==240 and texts(c)['departing owner relogged'],'A genuine login did not restore the original character')
 return
elseif phase=='reload' then
 local prior=assert(E.db.characters[first])
 assert(texts(prior)['same owner resumed'] and not texts(prior)['alternate after reload'])
 assert(prior.state.wallet.amount==225,'Old character wallet changed while another owner logged in')
 incoming('alternate after reload')
 local t=texts(c);assert(t['Seed second character'] and t['alternate after reload'] and t['live alternate party'])
 assert(not t['foreign before zone']  and not t['same owner resumed'])
 assert(c.state.wallet.amount==3333 and photographed==0)
 return
end
local offline=assert(E.db.characters[second]);local offlineBefore=E.Copy(offline)
assert(c.state.wallet.amount==200)
incoming('first character party');assert(texts(c)['first character party'])
local originalGroup=c.records[c.state.group];assert(originalGroup and originalGroup.partyGUID=='Party-first character party')
local function unavailable(value,msg)
 token=value;wallet=9999
 event('PLAYER_MONEY');chat(msg);event('GROUP_ROSTER_UPDATE')
 assert(c.state.wallet.amount==200 and not texts(c)[msg], 'Unreadable player GUID accepted '..msg)
 token=first;wallet=200
end
local firstSession=E.Collectors.session;local firstSequence=c.state.sessionSequence
unavailable(nil,'nil GUID');unavailable(secret,'restricted GUID')
wallet=225;event('PLAYER_MONEY');chat('same owner resumed')
assert(c.state.wallet.amount==225 and texts(c)['same owner resumed'],'Temporary unavailable GUID blocked same-owner recovery')
event('PLAYER_ENTERING_WORLD',false,false);frame(.1)
assert(E.current==c and E.Collectors.session==firstSession and c.state.sessionSequence==firstSequence,'Ordinary same-owner world entry reopened the session')
E.Book.Open()
local shot=assert(MyEpoch_Capture());assert(shot.status=='pending' and E.Capture.pending,'Real deferred book-hidden capture was not queued')
token=second;peer=second..'-friend';wallet=7777;clock=clock+1;TEST_NOW(clock)
event('PLAYER_MONEY') -- Identity changed before any world transition notification.
assert(c.state.wallet.amount==225,'A foreign wallet overwrote the old owner before PLAYER_ENTERING_WORLD')
assert(E.Same(offline,offlineBefore),'First mismatched event transitioned or mutated the offline owner')
-- Add a chat message while the token is unreadable, then return to the second GUID.
token=secret;chat('foreign before zone');event('GROUP_ROSTER_UPDATE')
token=second;event('PLAYER_ENTERING_WORLD',false,false)
for i=1,80 do TEST_NOW(clock+math.floor(i/4));frame(.25);if E.current==offline then break end end
assert(E.current==offline,'Verified new player never resumed recording in this Lua VM')
assert(E.current.state.sessionSequence==offlineBefore.state.sessionSequence+1,'New owner did not receive exactly one fresh session')
assert(c.state.wallet.amount==225,'World entry sampled foreign wallet into previous owner')
assert(offline.state.wallet.amount==7777 and texts(offline)['Seed second character'],'New wallet/session obscured retained history')
for _,r in pairs(offline.records)do
 if r.kind=='gold'then assert(r.amount~=7777-800,'Offline wallet difference was reported as a live transaction')end
end
wallet=7800;incoming('live alternate party')
assert(offline.state.wallet.amount==7800 and texts(offline)['live alternate party'])
assert(c.state.wallet.amount==225 and not texts(c)['live alternate party'] and not texts(c)['foreign before zone'])
local group=offline.records[offline.state.group];assert(group and group.partyGUID=='Party-live alternate party' and group.memberships[second] and group.memberships[peer])
assert(originalGroup.partyGUID=='Party-first character party' and not originalGroup.memberships[second] and not originalGroup.memberships[peer], 'Foreign roster was observed in old group')
for i=1,3 do frame(.25)end
assert(photographed==0,'Old queued screenshot called the new player camera')
event('PLAYER_LOGOUT')
