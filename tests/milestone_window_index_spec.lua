local Q,S,D,A=E.Query,E.Store,E.Diary,E.API
local now=A.ParseDay('2026-11-01')+3600;TEST_NOW(now)
local c=S.Character('milestone-family-index',{name='Historian'})
c.state.firstObserved=now-200000
local function raw(owner,kind,ts,data)
 owner.seq=owner.seq+1
 local r={id=owner.id..':'..owner.seq,kind=kind,category=S.categories[kind],ts=ts,sequence=owner.seq,title='Progress'}
 for k,v in pairs(data or{})do r[k]=v end
 owner.records[r.id]=r;owner.order[#owner.order+1]=r.id;return r
end
local function family(r)return(r.milestoneType or '')..':'..tostring(r.skillID or '')end
local function ordered(a,b)
 if a.ts~=b.ts then return a.ts<b.ts end
 if S.Sequence(a)~=S.Sequence(b)then return S.Sequence(a)<S.Sequence(b)end
 if (a.sequence or 0)~=(b.sequence or 0)then return(a.sequence or 0)<(b.sequence or 0)end
 return a.id<b.id
end
-- Independent canonical-history oracle, including the pre-existing rule that
-- the first canonical record wins when linked observations share a boundary.
local function oracle(owner,event)
 local rows={}
 for _,r in pairs(owner.records)do
  if r.kind=='milestone'and r.subject==owner.id and r.major==true then rows[#rows+1]=r end
 end
 table.sort(rows,ordered)
 local previous
 for _,r in ipairs(rows)do
  if S.Before(r,event)and family(r)==family(event)and(not previous or S.Before(previous,r))then previous=r end
 end
 return previous
end
local function check(owner,event)
 local expected=oracle(owner,event)
 assert(Q.PreviousMajor(owner,event)==expected)
 local from,through,partial,previous=D.MilestoneWindow(owner,event)
 assert(previous==expected and through==event.ts and partial==(expected==nil))
 assert(from==(expected and expected.ts or owner.state.firstObserved or event.ts))
end
for i=1,60000 do raw(c,'milestone',now-i,{subject=c.id,milestoneType='skill',skillID=i%14,major=false})end
local events={}
for i=1,320 do
 local r=raw(c,'milestone',now-i*17%5000,{subject=i%7==0 and 'foreign'or c.id,
  milestoneType=i%3==0 and 'profession'or i%3==1 and 'skill'or 'level',
  skillID=i%3~=2 and i%14 or nil,major=true})
 if r.subject==c.id then events[#events+1]=r end
end
for _,r in ipairs(events)do check(c,r)end
local target=raw(c,'milestone',now+10,{subject=c.id,milestoneType='level',major=true})
E.Emit('RECORD_ADDED',c,target)
local a=S.Add(c,'milestone',now+2,{subject=c.id,milestoneType='level',major=true,observationSequence=999999})
local b=S.Add(c,'milestone',now+2,{subject=c.id,milestoneType='level',major=true,observationSequence=999999})
check(c,target);assert(Q.PreviousMajor(c,target)==a,'first canonical linked observation wins')
local samePoint={id=c.id..':probe',ts=a.ts,observationSequence=999999,milestoneType='level',subject=c.id,kind='milestone'}
check(c,samePoint);assert(Q.PreviousMajor(c,samePoint)~=a and Q.PreviousMajor(c,samePoint)~=b)
for _,change in ipairs({
 function()a.major=false end,
 function()a.major=true;a.subject='foreign' end,
 function()a.subject=c.id;a.milestoneType='skill';a.skillID=43 end,
 function()a.milestoneType='level';a.skillID=nil;a.ts=now+11 end,
 function()a.ts=now+1;a.observationSequence=2 end,
 function()a.kind='chat';a.category='chat';a.text='Corrected source kind' end,
 function()a.kind='milestone';a.category='milestones';a.major=true end
})do change();S.Changed(c,a);check(c,target);check(c,events[1])end
-- A minor change must not discard a cached major-family sort.
Q.PreviousMajor(c,target)
local sort=table.sort;local sorts=0
table.sort=function(...)sorts=sorts+1;return sort(...)end
local minor=S.Add(c,'milestone',now,{subject=c.id,milestoneType='level',major=false})
Q.PreviousMajor(c,target);minor.after=20;S.Changed(c,minor);Q.PreviousMajor(c,target)
table.sort=sort;assert(sorts==0,'routine progress does not re-sort major boundaries')
local other=S.Character('milestone-family-other',{name='Another historian'})
other.state.firstObserved=now-5000
local foreign=S.Add(other,'milestone',now,{subject=other.id,milestoneType='level',major=true})
local endPoint={id=other.id..':probe',ts=now+10,sequence=100,milestoneType='level',subject=other.id,kind='milestone'}
check(other,endPoint);assert(Q.PreviousMajor(other,endPoint)==foreign)
-- Real retention publication, including the prepared-query handoff, removes
-- expired boundaries without deleting the surviving event or personal notes.
local expiry=S.Character('milestone-family-expiry',{name='Keeper'})
expiry.state.firstObserved=now-400*86400;expiry.retention.milestones=30
local old=S.Add(expiry,'milestone',now-100*86400,{subject=expiry.id,milestoneType='level',major=true})
local recent=S.Add(expiry,'milestone',now-20,{subject=expiry.id,milestoneType='level',major=true})
S.Note(expiry,'recap:kept','My own words',now)
check(expiry,recent);assert(Q.PreviousMajor(expiry,recent)==old)
local preview=S.PreviewExpiry(expiry,now);assert(preview.ids[old.id])
assert(S.ApplyExpiry(expiry,preview));check(expiry,recent)
assert(Q.PreviousMajor(expiry,recent)==nil and expiry.notes['recap:kept'].text=='My own words')
-- Untyped removal notifications still rebuild conservatively.
c.records[b.id]=nil;E.Emit('RECORDS_REMOVED',c,{[b.id]=true});check(c,target)
-- Measure the warm boundary lookup separately from cold index construction,
-- family sorting and the independent full-history oracle.
for _,r in ipairs(events)do Q.PreviousMajor(c,r)end
local major=Q.Major;Q.Major=function()error('Milestone windows must not request the full major history')end
local instructions=0;debug.sethook(function()instructions=instructions+1000 end,'',1000)
for i=1,1000 do D.MilestoneWindow(c,events[(i-1)%#events+1])end
debug.sethook();Q.Major=major
assert(instructions<1000000,'warm predecessor lookup remains independent of unrelated milestones')
assert(c.records[minor.id]==minor and #Q.Kind(c,'milestone')==60323,'original history is retained')
print('PASS milestone family index: canonical oracle, shared observations, corrections, retention, character isolation; 1000 warm lookups',instructions,'Lua instructions')
