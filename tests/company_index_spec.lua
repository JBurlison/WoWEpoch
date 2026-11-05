local S,Q,C,L,X,W=E.Store,E.Query,E.Company,E.CompanyLayout,E.Search,E.RetentionWork
local c=S.Character('company-index-large',{name='Indexed owner'})
local now=E.API.ParseDay('2026-11-02')+12000;TEST_NOW(now)
local function raw(kind,data)
 c.seq=c.seq+1;c.revision=c.revision+1
 local r={id=c.id..':'..c.seq,character=c.id,sequence=c.seq,ts=now,kind=kind,category=S.categories[kind]}
 for k,v in pairs(data or{})do r[k]=v end
 c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
for i=1,100000 do raw('chat',{text='Unrelated archive text',group=i%2==0 and'other-session'or nil})end
local function member(name)return{name=name,intervals={{from=now-100,through=now+100,firstSequence=0}}}end
local g1=raw('group',{memberships={[c.id]=member('Owner'),buddy=member('Buddy')}})
local g2=raw('group',{memberships={[c.id]=member('Owner'),someone=member('Someone')}})
local quest=raw('quest',{group=g1.id,status='completed',title='Together'})
local loot=raw('loot',{group=g1.id,quantity=3,recipient='buddy'})
raw('loot',{group=g1.id,quantity=2})
raw('milestone',{group=g1.id,subject=c.id,major=true})
raw('milestone',{group=g1.id,subject='buddy',major=true})
local quote=raw('chat',{group=g1.id,starred=true,author='Buddy',text='Tea [and] biscuits'})
raw('death',{group=g1.id,subject=c.id})
local pull=raw('pull',{group=g2.id,observedGroups={[g1.id]=true,[g2.id]=true,ignored=false}})
local oldRaw=c.records[c.order[1]]
-- Mutations while the shared index is still private must use current groups.
assert(Q.EnsureWarm(c)=='preparing')
local state=Q.Preparation(c);local amended=false
while not Q.IsWarm(c)do
 Q.ProcessPreparation(61)
 if state.scanned>500 and not amended then
  amended=true;oldRaw.group=g1.id;S.Changed(c,oldRaw)
  pull.observedGroups.extra=true;S.Changed(c,pull)
 end
end
local function sameRows(a,b)
 table.sort(a,S.Before);table.sort(b,S.Before);assert(#a==#b,'record count mismatch')
 for i,r in ipairs(a)do assert(r==b[i],'canonical identity mismatch')end
end
local function oracle(id,observed)
 local rows={};for _,r in pairs(c.records)do
  if r.group==id or observed and r.kind=='pull'and r.observedGroups and r.observedGroups[id]==true then rows[#rows+1]=r end
 end;return rows
end
local function verify()
 for _,id in ipairs({g1.id,g2.id,'extra','ignored','missing'})do
  sameRows(Q.Group(c,id),oracle(id,false));sameRows(Q.Group(c,id,true),oracle(id,true))
 end
end
verify();assert(#Q.Group(c,g2.id,true)==1,'direct and observed membership deduplicate')
local expected=oracle(g1.id,false)
-- Large unrelated history must not be visited by any warm page path.
local originalPairs=pairs;local guarded=false
pairs=function(t)if guarded and t==c.records then error('Warm Company page scanned the entire archive')end;return originalPairs(t)end
local instructions=0;guarded=true
debug.sethook(function()instructions=instructions+100 end,'',100)
local history=C.History(c,'buddy');local report=L.Report(c,g1);local transcript=X.Transcript(c,g1.id,'[and]')
debug.sethook();guarded=false
assert(instructions<30000,'unrelated history leaked into warm Company work')
sameRows(history.events,expected);assert(#history.quests==1 and #history.milestones==1 and #history.loot==2 and #history.quotes==1)
assert(history.recipientUnits==3 and history.unknownRecipientUnits==2 and #history.deaths==1)
assert(#report.pulls==1 and report.pulls[1]==pull and #transcript==1 and transcript[1]==quote)
assert(not history.quoteIDs[oldRaw.id])
-- In-place changes must remove copied old memberships, not just add new ones.
quest.group=g2.id;S.Changed(c,quest);pull.observedGroups[g1.id]=nil;pull.observedGroups.extra=false;S.Changed(c,pull)
verify();assert(#C.History(c,'buddy').quests==0 and #L.Report(c,g1).pulls==0)
pull.group=g1.id;pull.observedGroups[g2.id]=true;pull.kind='memory';S.Changed(c,pull)
verify();assert(#Q.Group(c,g2.id,true)==1,'former pull groups are removed; only moved quest remains')
pull.kind='pull';S.Changed(c,pull);verify();assert(#L.Report(c,g1).pulls==1)
quote.group=g2.id;quote.starred=false;S.Changed(c,quote)
assert(#C.History(c,'buddy').quotes==0 and #X.Transcript(c,g1.id,'[and]')==0)
loot.group=nil;S.Changed(c,loot);assert(C.History(c,'buddy').recipientUnits==0)
local other=S.Character('company-index-other',{})
assert(#Q.Group(other,g1.id,true)==0 and not C.History(other,'buddy'),'character indexes remain isolated')
-- Actual retention publication carries the group index atomically.
quote.ts=now-400*86400;S.Changed(c,quote);c.retention.chat=30
local preview=S.PreviewExpiry(c,now);assert(preview.ids[quote.id]or preview.count==1)
local published=false;local watching=true
E.On('RECORDS_REMOVED',function(owner)
 if watching and owner==c then published=true;assert(#X.Transcript(c,g2.id,'[and]')==0);assert(#Q.Group(c,g1.id,true)>0)end
end)
local job=W.Start(function(work)return S.ApplyExpiry(c,preview,work,function()guarded=true end)end)
while true do local result,reason=W.Step(job,71);if result then assert(result=='done',reason);break end end
watching=false;guarded=false;pairs=originalPairs
assert(published and not c.records[quote.id]);verify()
assert(c.records[quest.id]==quest and c.records[loot.id]==loot,'cleanup preserves unrelated canonical observations')
print('PASS Company index: 100,000 unrelated records, '..instructions..' warm instructions, canonical selection, shared pulls, private-build edits, corrected memberships/kinds, character isolation and atomic retention publication')
