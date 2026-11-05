local bindWallet,restoreWallet=TEST_WALLET_SESSION()
local A,B,C,H,Q,S,V=E.API,E.Book,E.Collectors,E.History,E.Query,E.Store,E.CalendarView
local oldNow,oldOwner,oldRoster,oldCharacter=A.Now(),E.current,A.Roster,B.character
local fields={"session","partyGUID","partyCategory","rosterAt","rosterObserved","rosterSize","lastRoster","chatGap"}
local saved={};for _,k in ipairs(fields) do saved[k]=C[k] end
local day=A.ParseDay("2026-11-01");local second=A.ShiftDay(day,1);local third=A.ShiftDay(day,2)
local c=S.Character("calendar-roster-day",{name="Rook"})
bindWallet(c,"roster-day");C.partyGUID="roster-day-party"
local members={{id=c.id,name="Rook",isLeader=true},{id="friend",name="Friend",isLeader=false}}
A.Roster=function()return members end
local function roster(ts)TEST_NOW(ts);E.frame.scripts.OnEvent(E.frame,"GROUP_ROSTER_UPDATE")end
local function at(owner,d,id)
 local rep=V.Report(owner,d);local stamp=rep.continuedGroups[id]
 return stamp and stamp.ts,rep
end
roster(day-3);local g=assert(c.records[c.state.group])
TEST_NOW(day+12);C.Heartbeat();assert(at(c,day,g.id)==day+12,"silent party observed by actual heartbeat")
-- Actual context (including a meter update) performs a fresh positive roster read.
TEST_NOW(day+8);assert(C.Context({}).group==g.id)
assert(at(c,day,g.id)==day+8)
roster(day+6);assert(at(c,day,g.id)==day+6,"rollback retains earliest observed same-day timestamp")
local early=S.Add(c,"memory",day+1,{title="Early"})
local chat=S.Add(c,"chat",day+14,{group=g.id,text="later"})
local stamp,rep=at(c,day,g.id)
local indices={};for i,r in ipairs(rep.records)do indices[r]=i end;assert(stamp==day+6 and rep.counts.group==1 and indices[early]<indices[g] and indices[g]<indices[chat])
members=nil;roster(second+60);members={};roster(third+60)
assert(not V.Report(c,second).counts.group and not V.Report(c,third).counts.group,"gap and solo leave cannot place a group")
local other=S.Character("calendar-day-other",{name="Rook",realm="Different realm"})
assert(not V.Report(other,day).counts.group)
local legacy=S.Add(other,"group",day-70,{memberships={},gaps={{from=day+100,through=third+200}},ended=third+240,observedThrough=third+190})
legacy.memberships[other.id]={intervals={{from=day-70,through=day+23,ended=second+1},{from=third+110,through=third+190}},identities={{from=day-70}}}
S.Changed(other,legacy)
assert(at(other,day,legacy.id)==day+23 and at(other,third,legacy.id)==third+110 and not V.Report(other,second).counts.group)
legacy.memberships[other.id].intervals[1].through=second+30;S.Changed(other,legacy)
assert(not at(other,day,legacy.id) and at(other,second,legacy.id)==second+30)
legacy.kind="memory";S.Changed(other,legacy);assert(not at(other,second,legacy.id))
legacy.kind="group";S.Changed(other,legacy);assert(at(other,second,legacy.id)==second+30)
legacy.character=c.id;S.Changed(other,legacy);assert(not V.Report(other,second).counts.group)
legacy.character=other.id;S.Changed(other,legacy);assert(V.Report(other,second).counts.group==1)
other.retention.groups=1;S.ApplyExpiry(other,S.PreviewExpiry(other,third+86400*3));assert(not other.records[legacy.id] and not at(other,second,legacy.id))
-- A continued pre-upgrade party must match a fresh rebuild even when
-- multiple sources share an old through timestamp and one member leaves.
local resume=S.Character("calendar-legacy-resume",{})
local party={{id=resume.id,name="Owner",isLeader=true},{id="friend",name="Friend",isLeader=false}}
local lg=S.Add(resume,"group",day-10,{session="old",observedThrough=day+1,memberships={
 [resume.id]={name="Owner",intervals={{from=day-10,through=day+1}}},
 friend={name="Friend",intervals={{from=day-10,through=day+1}}}},
 leadership={{from=day-10,through=day+1,candidates={{id=resume.id,name="Owner"}},leaderID=resume.id}}})
resume.state.group=lg.id;assert(at(resume,day,lg.id)==day+1)
local function parity()
 local points={day-10,day+1,day+4,day+5,day+7,day+8,second+1}
 local before={};for i,t in ipairs(points)do before[i]=Q.RosterDay(resume,t,t+1)[lg.id] end
 S.Changed(resume,lg)
 for i,t in ipairs(points)do assert(before[i]==Q.RosterDay(resume,t,t+1)[lg.id],"resumed legacy endpoint drift at "..t)end
end
H.Group(resume,day+4,{party[1]},"old");parity();assert(at(resume,day,lg.id)==day+1)
H.Group(resume,day+5,party,"old");parity()
party[2].name="Renamed";party[2].isLeader=true;party[1].isLeader=false
H.Group(resume,day+7,party,"old");parity()
H.Group(resume,day+8,party,"old");parity()
H.Group(resume,second+1,party,"old");parity();assert(at(resume,second,lg.id)==second+1)
lg.memberships.friend.intervals[1].through=day-7;S.Changed(resume,lg)
assert(at(resume,day,lg.id)==day+4,"withdraw old date source without losing modern observation")
local receipts={}
E.On("RECORD_CHANGED",function(owner,r,_,receipt)
 if owner==c and r==early then receipts[#receipts+1]=receipt.detail end
end)
S.Changed(c,early,nil);S.Changed(c,early,false)
local context={operation="add",record=g,probe=19};S.Changed(c,early,context)
assert(#receipts==3 and receipts[3].probe==19 and context.record==g)
for _,detail in ipairs(receipts)do assert(detail.record==early and detail.operation=="change")end
assert(g.ts==day-3 and c.records[g.id]==g)
A.Roster=oldRoster;E.current=oldOwner;TEST_NOW(oldNow);for _,k in ipairs(fields)do C[k]=saved[k]end
if oldCharacter then B.ChangeCharacter(oldCharacter)end
print("PASS canonical local-day group witness, context/roster, rollback, chronology, recording gap/solo leave, offline same-name owners, legacy corrections, reclassification and retention")

restoreWallet()
