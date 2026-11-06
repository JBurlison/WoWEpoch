local C,K,S,A=E.Chapters,E.Keepsakes,E.Store,E.API
local c=S.Character('chapter-retention-race',{name='Keeper'})
local other=S.Character('chapter-retention-foreign',{})
local now=assert(A.ParseDay('2026-11-06'));local old=A.ShiftDay(now,-10);TEST_NOW(now)
c.retention.chat=1;c.retention.groups=1;c.retention.chapters=1
local witness=S.Add(c,'group',old,{title='Those who were there'})
local original=S.Add(c,'chat',old,{title='A kept word',text='Well played!',refs={witness.id}})
local discard=S.Add(c,'chat',old,{title='An unselected word',text='Other conversation'})
local chapter=assert(C.Create(c,{title='Keep this page',mode='picked',included={original.id,original.id}},old))
chapter.starred=true;S.Changed(c,chapter)
assert(K.Pending(c,'chapter:'..chapter.id)and #chapter.members==0,'No membership projection has run yet')
assert(#chapter.refs==1 and chapter.refs[1]==original.id,'Explicit links must be canonical before background preparation')
local keep=S.Protected(c);assert(keep[original.id]and keep[witness.id],'A pending chapter protects chosen sources and their dependencies')
local preview=S.PreviewExpiry(c,now)
assert(not preview.ids[original.id]and not preview.ids[witness.id]and preview.ids[discard.id])
S.ApplyExpiry(c,preview)
assert(c.records[original.id]and c.records[witness.id]and not c.records[discard.id],'Cleanup before first publication preserves the selected story')
local edited=S.Add(c,'chat',old,{title='Chosen while editing',text='Another happy thought'})
assert(C.Edit(c,chapter.id,{title='Keep this page',mode='picked',included={edited.id}}))
keep=S.Protected(c)
assert(keep[edited.id]and keep[original.id],'Pending edits protect new choices without dropping the prior projection')
preview=S.PreviewExpiry(c,now);assert(not preview.ids[edited.id]);S.ApplyExpiry(c,preview)
local included=S.Add(c,'chat',old,{title='One more story',text='The last laugh'})
assert(C.Include(c,chapter.id,included.id));assert(K.Pending(c,'chapter:'..chapter.id))
keep=S.Protected(c);assert(keep[included.id],'Include protects the chosen source before notifying listeners')
local foreign=S.Add(other,'chat',old,{title='Another character',text='Not this book'})
local previousRefs=E.Copy(chapter.refs)
assert(not C.Include(c,chapter.id,foreign.id)and E.Same(previousRefs,chapter.refs),'Foreign links cannot enter the protection graph')
preview=S.PreviewExpiry(c,now);assert(not preview.ids[included.id]);S.ApplyExpiry(c,preview)
for i=1,10000 do if not K.Pending(c)then break end;K.Process(100)end
assert(not K.Pending(c),'Membership must eventually publish')
local members={};for _,id in ipairs(chapter.members)do members[id]=true end
assert(members[edited.id]and members[included.id]and not members[original.id])
preview=S.PreviewExpiry(c,now)
assert(preview.ids[original.id]and preview.ids[witness.id],'Old links are released only after replacement membership is committed')
assert(not preview.ids[edited.id]and not preview.ids[included.id])
S.ApplyExpiry(c,preview)
assert(c.records[chapter.id]and c.records[edited.id]and c.records[included.id]and not c.records[original.id])
-- An automatic range has no materialized membership immediately after creation.
-- Retention derives those references cooperatively instead of waiting for UI jobs.
local range=S.Character('chapter-range-retention',{name='Date keeper'})
range.retention.chat=1;range.retention.chapters=1;range.retention.diaries=1;range.retention.time=1
local function rangeSource(title,stamp,map)
    return S.Add(range,'chat',stamp,{title=title,text=title,mapID=map})
end
local match=rangeSource('A matching conversation',old+20,1429)
local unrelated=rangeSource('A different place',old+30,1431)
local summary=S.Add(range,'play',old,{status='active',ended=old+120,session='range'})
local diary=S.Add(range,'diary',old,{title='That day',text='A pleasant walk'})
for i=1,200 do rangeSource('Unrelated '..i,old+i,1431)end
local automatic=assert(C.Create(range,{title='A remembered date',mode='range',fromDay=A.Day(old),throughDay=A.Day(old),
    kinds={chat=true},mapIDs={[1429]=true}},old))
automatic.starred=true;S.Changed(range,automatic)
assert(#automatic.members==0 and #automatic.refs==0 and K.Pending(range))
local unchanged=E.Copy(automatic);local revision=range.revision;local operations=0;local references={}
C.Retention(range,automatic,function(id)references[id]=true end,{work=function()operations=operations+1 end})
assert(references[match.id]and references[summary.id]and references[diary.id]and not references[unrelated.id])
assert(operations>200 and E.Same(automatic,unchanged)and range.revision==revision,'Retention derivation cooperates without publishing membership')
local job=assert(E.RetentionWork.Start(function(work)return S.PreviewExpiry(range,now,work)end))
assert(E.RetentionWork.Step(job,10)==nil and job.operations==10,'Range dependency scans obey cleanup work budgets')
local status
for i=1,10000 do status,preview=E.RetentionWork.Step(job,100);if status then break end end
assert(status=='done'and not preview.ids[match.id]and not preview.ids[summary.id]and not preview.ids[diary.id]and preview.ids[unrelated.id])
S.ApplyExpiry(range,preview)
assert(range.records[match.id]and range.records[summary.id]and range.records[diary.id]and not range.records[unrelated.id])
local function finishRange()
    for i=1,10000 do if not K.Pending(range)then return end;K.Process(100)end;error('Range chapter jobs did not settle')
end
finishRange();assert(#automatic.members==1)
local nextDay=A.ShiftDay(old,1)
local nextMatch=rangeSource('The following date',nextDay+20,1429)
local nextUnrelated=rangeSource('Still a different place',nextDay+30,1431)
assert(C.Edit(range,automatic.id,{title='A different date',mode='range',fromDay=A.Day(nextDay),throughDay=A.Day(nextDay),
    kinds={chat=true},mapIDs={[1429]=true}}))
preview=S.PreviewExpiry(range,now)
assert(not preview.ids[nextMatch.id]and not preview.ids[match.id]and preview.ids[nextUnrelated.id],
    'Pending range edits protect newly matched sources and retain prior refs until commit')
S.ApplyExpiry(range,preview);finishRange()
preview=S.PreviewExpiry(range,now);assert(preview.ids[match.id]and not preview.ids[nextMatch.id])
assert(C.Seal(range,automatic.id))
local arrivedDuringSeal=rangeSource('After the seal was requested',nextDay+40,1429)
preview=S.PreviewExpiry(range,now)
assert(preview.ids[arrivedDuringSeal.id]and not preview.ids[nextMatch.id],'Pending seal respects its recorded sequence boundary')
S.ApplyExpiry(range,preview);finishRange();assert(automatic.sealed)
local laterMatch=rangeSource('After the seal was set',nextDay+50,1429)
preview=S.PreviewExpiry(range,now)
assert(preview.ids[laterMatch.id]and not preview.ids[nextMatch.id],'Sealed chapters do not protect later matching arrivals')
local added={}
C.Retention(other,automatic,function(id)added[id]=true end,{})
C.Retention(range,E.Copy(automatic),function(id)added[id]=true end,{})
assert(not next(added),'Foreign and noncanonical chapter objects cannot add protection')
range.records[foreign.id]=foreign;range.order[#range.order+1]=foreign.id
automatic.selection.included[foreign.id]=true
C.Retention(range,automatic,function(id)added[id]=true end,{})
assert(not added[foreign.id],'Even malformed foreign selections are ignored')
range.records[foreign.id]=nil;table.remove(range.order);automatic.selection.included[foreign.id]=nil
assert(other.records[foreign.id]==foreign)
print('PASS pending explicit/range chapter retention, read-only bounded dependencies, sealed boundaries and source ownership')
