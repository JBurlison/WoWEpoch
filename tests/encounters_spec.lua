local X,C,S,A,Q,B=E.Encounters,E.Collectors,E.Store,E.API,E.Query,E.Book
local function eq(a,b,label)assert(a==b,(label or 'Encounter mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local saved={current=E.current,now=A.Now(),session=C.session,roster=A.Roster,location=A.Location,secret=issecretvalue,party=C.partyGUID,
    observed=C.rosterObserved,rosterAt=C.rosterAt,lastRoster=C.lastRoster,rosterSize=C.rosterSize}
local t=A.ParseDay('2026-11-01')+3600;TEST_NOW(t)
local c=S.Character('encounter-owner',{name='Aldren'});local other=S.Character('encounter-other',{name='Mira'})
local buddy={id='encounter-buddy',name='Rook',realm='Test'}
A.Location=function()return {zone='Westfall',mapID=1,subzone='Test encounter'}end
A.Roster=function()return {{id=E.current.id,name=E.current.identity.name,realm='Test'},buddy}end
local function activate(owner,session)E.current=owner;C.session=session;C.partyGUID=nil;C.rosterObserved=false;X.Start(owner)end
activate(c,'first')
for _,event in ipairs({'ENCOUNTER_START','ENCOUNTER_END','BOSS_KILL','PLAYER_LEAVING_WORLD'})do assert(E.frame.events[event],event..' registered')end
local started=C.handlers.ENCOUNTER_START(101,'Captain Test',1,5)
eq(started.phase,'start');eq(c.state.activeEncounter,started.id);eq(#Q.Major(c),0)
assert(S.Protected(c)[started.id],'active start remains protected')
TEST_NOW(t+30)
local hidden=setmetatable({},{__index=function()error('Boss health must not be read')end})
local ended=C.handlers.ENCOUNTER_END(101,'Captain Test',1,5,1,hidden)
eq(ended.startObservation,started.id);eq(started.endObservation,ended.id);eq(c.state.activeEncounter,nil)
assert(ended.pairing:find('Inferred',1,true));eq(ended.duration,nil,'no invented duration')
eq(#Q.Major(c),1);local milestone=Q.Major(c)[1]
eq(milestone.subject,c.id);eq(milestone.milestoneType,'encounter');eq(milestone.sourceRecord,ended.id)
eq(milestone.group,ended.group);eq(S.Sequence(milestone),S.Sequence(ended))
local boss=C.handlers.BOSS_KILL(101,'Captain Test');eq(boss.difficultyID,nil);eq(#Q.Major(c),1)
local duplicate=C.handlers.ENCOUNTER_END(101,'Captain Test',1,5,1)
eq(duplicate.startObservation,nil);eq(#Q.Major(c),1);eq(#Q.Kind(c,'encounter'),4,'notifications retained, not deduplicated into kills')
local changed=C.handlers.ENCOUNTER_START(101,'Same boss, harder mode',2,5)
local failed=C.handlers.ENCOUNTER_END(101,'Same boss, harder mode',2,5,0)
eq(failed.success,0);assert(not X.IsVictory(failed));eq(changed.endObservation,failed.id);eq(#Q.Major(c),1)
local afterBoss=C.handlers.BOSS_KILL(102,'Another captain');local beforeEnd=#Q.Major(c)
C.handlers.ENCOUNTER_END(102,'Another captain',1,5,1);eq(#Q.Major(c),beforeEnd,'reverse notification order creates one first')
-- Unknown fields never become success, difficulty, group size or paired identity.
local secret={};issecretvalue=function(v)return v==secret end
local unsafe=C.handlers.ENCOUNTER_START(103,secret,secret,secret)
eq(unsafe.encounterName,'Encounter 103');eq(unsafe.difficultyID,nil);eq(unsafe.reportedGroupSize,nil)
local unknown=C.handlers.ENCOUNTER_END(103,'Unknown outcome',1,5,secret)
eq(unknown.success,nil);eq(unknown.startObservation,nil);assert(not X.IsVictory(unknown));assert(unsafe.continuity)
local previous=#Q.Kind(c,'encounter');C.handlers.BOSS_KILL(secret,'Do not infer');C.handlers.BOSS_KILL(0/0,'Invalid')
eq(#Q.Kind(c,'encounter'),previous);eq(#Q.Kind(c,'gap'),1,'consecutive unavailable identities coalesce a coverage gap')
issecretvalue=saved.secret
for _,invalid in ipairs({-1,math.huge,1.5,'104'})do assert(not C.handlers.BOSS_KILL(invalid,'Malformed'))end
local malformed=C.handlers.ENCOUNTER_END(104,'Unknown status',1,5,2);assert(not X.IsVictory(malformed))
-- A matching name is not identity. New starts, reloads and world gaps do not fabricate ends.
local replaced=C.handlers.ENCOUNTER_START(110,'Same name',1,5)
local current=C.handlers.ENCOUNTER_START(111,'Same name',1,5);assert(replaced.continuity);eq(replaced.endObservation,nil)
local unmatched=C.handlers.ENCOUNTER_END(110,'Same name',1,5,1);eq(unmatched.startObservation,nil);assert(current.continuity)
local reload=C.handlers.ENCOUNTER_START(112,'Reload test',1,5);activate(c,'second');assert(reload.continuity)
eq(C.handlers.ENCOUNTER_END(112,'Reload test',1,5,1).startObservation,nil)
local crossing=C.handlers.ENCOUNTER_START(113,'World gap',1,5);C.handlers.PLAYER_LEAVING_WORLD();assert(crossing.continuity)
eq(C.handlers.ENCOUNTER_END(113,'World gap',1,5,1).startObservation,nil)
local clock=C.handlers.ENCOUNTER_START(114,'Clock test',1,5);TEST_NOW(t-5)
eq(C.handlers.ENCOUNTER_END(114,'Clock test',1,5,1).startObservation,nil);assert(clock.continuity);TEST_NOW(t+40)
-- Start and end keep their own group context, including an observed roster loss.
local grouped=C.handlers.ENCOUNTER_START(115,'Roster test',1,5);local originalGroup=grouped.group
A.Roster=function()return nil end;C.rosterObserved=false
local gapEnd=C.handlers.ENCOUNTER_END(115,'Roster test',1,5,1)
eq(gapEnd.group,nil);eq(grouped.group,originalGroup);eq(gapEnd.startObservation,grouped.id)
for _,r in ipairs(E.CompanyLayout.Report(c,c.records[originalGroup]).encounters)do assert(r.id~=gapEnd.id,'unobserved end cannot inherit old companions')end
-- Offline scrapbook selection does not change the recording owner.
B.ChangeCharacter(other.id);local own=C.handlers.BOSS_KILL(116,'Owner only');eq(own.character,c.id);eq(#Q.Major(other),0)
activate(other,'other-login');local their=C.handlers.BOSS_KILL(101,'Captain Test');eq(their.subject,other.id);eq(#Q.Major(other),1)
activate(c,'third')
local facts=E.Diary.Facts(c,t-10,t+100);eq(#facts.refs,0,'boss observations and milestones stay out of recaps')
E.JournalJobs.pending[c]={};E.JournalJobs.QueueRecord(c,ended,t+100,0)
for _,job in pairs(E.JournalJobs.pending[c])do eq(job.kind,'daily')end
local text,refs=E.Diary.Daily(c,t-10,t+100);assert(text:find('Boss victory notifications:',1,true))
local used={};for _,id in ipairs(refs)do used[id]=true end;assert(used[ended.id]and used[boss.id],'daily provenance retains both notifications')
local calendar=E.CalendarView.Report(c,A.DayStart(t));local shown={};for _,r in ipairs(calendar.records)do shown[r.id]=true end;assert(shown[ended.id])
local hits=E.Search.Find(c,'101','encounter');assert(hits.total>=4)
B.ChangeCharacter(c.id);assert(E.SearchView.Open({character=c.id,record=ended.id}));eq(B.chapter,'Company');eq(B.selected,ended.id);TEST_PREPARE_BOOK()
local function click(label,page)
    for _,kind in ipairs({'button','companyControl'})do for i=1,(page or B.right).used[kind]or 0 do
        local f=(page or B.right).pool[kind][i];if f.text:GetText()==label then f:Click();return end
    end end;return TEST_UI_CLICK(label)
end
click('Recording details');eq(B.encounterEvidence,ended.id)
local hasPairing=false;for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find('Inferred from the current session',1,true)then hasPairing=true end end;assert(hasPairing)
click('Hide recording details');eq(B.encounterEvidence,nil)
click('View recorded start');eq(B.selected,started.id);click('View recorded end');eq(B.selected,ended.id)
assert(E.SearchView.Open({character=c.id,record=milestone.id}));click('Open victory record');eq(B.selected,ended.id)
click("Read this group's chat");eq(B.groupTab,'chat');eq(B.selected,ended.group)
click('Bosses');eq(B.groupTab,'encounters');assert(#E.CompanyLayout.lastSession.encounters>=4)
local rects={};for i=1,B.right.used.companyControl or 0 do local f=B.right.pool.companyControl[i]
    local point=assert(f.point);local x=point[4];assert(x>=12 and x+f:GetWidth()<=772,'group controls stay on the page')
    rects[#rects+1]={x=x,y=point[5],w=f:GetWidth()}
end
table.sort(rects,function(a,b)return a.y==b.y and a.x<b.x or a.y<b.y end)
for i=2,#rects do local a,b=rects[i-1],rects[i];if a.y==b.y then assert(a.x+a.w<=b.x,'Bosses tab cannot overlap Keep session')end end
assert(E.SearchView.Open({character=c.id,record=gapEnd.id}));eq(B.companySessionFocus,nil,'unlinked encounter does not show an unrelated session')
click('Open this day in Calendar');eq(B.chapter,'Calendar')
milestone.starred=true;S.Changed(c,milestone);local protected=S.Protected(c)
assert(protected[ended.id]and protected[started.id],'starred victory protects both paired observations')
S.Note(c,'record:'..ended.id,'Our celebration',t+50)
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do
    UIParent:SetSize(size[1],size[2]);B.Fit();E.SearchView.Open({character=c.id,record=ended.id});eq(B.frame:GetWidth(),1760);eq(B.frame:GetHeight(),940)
end
eq(c.notes['record:'..ended.id].text,'Our celebration');UIParent:SetSize(1920,1080);B.Fit()
local expiring=S.Character('encounter-expiry',{name='Archivist'});activate(expiring,'expiry')
C.handlers.BOSS_KILL(77,'Earlier victory');expiring.retention.groups=1;expiring.retention.milestones=1
S.ApplyExpiry(expiring,S.PreviewExpiry(expiring,t+10*86400));eq(#Q.Major(expiring),0)
C.handlers.BOSS_KILL(77,'Later victory');eq(#Q.Major(expiring),0,'expired first victory is never recreated as a new first')
local dense=S.Character('encounter-dense',{name='Raider'});activate(dense,'dense')
A.Roster=function()return {{id=dense.id,name='Raider'},buddy}end;C.rosterObserved=false
for i=1,1200 do C.handlers.BOSS_KILL(901,'Repeated boss notification')end
eq(#Q.Major(dense),1);local group=dense.records[dense.state.group]
B.ChangeCharacter(dense.id);TEST_PREPARE_BOOK();B.SetChapter('Company');B.selected=group.id;B.groupTab='encounters';B.Render(true)
eq(#E.CompanyLayout.lastSession.encounters,1200);assert((B.right.used.companyRow or 0)<=8,'bounded encounter rows')
click('More entries');eq(B.companyEventPage,2)
E.current=saved.current
C.session=saved.session;C.partyGUID=saved.party;C.rosterObserved=saved.observed;C.rosterAt=saved.rosterAt;C.rosterSize=saved.rosterSize;C.lastRoster=saved.lastRoster
A.Roster=saved.roster;A.Location=saved.location;issecretvalue=saved.secret;TEST_NOW(saved.now)
print('PASS encounters: guarded notifications, first victories, ambiguous/reload/world/clock gaps, roster provenance, expiry memory, recap exclusion, calendar/diary/search/chat links and 1,200-row pagination')
