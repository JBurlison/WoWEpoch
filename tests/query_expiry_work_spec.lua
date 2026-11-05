local Q,S,W,A=E.Query,E.Store,E.RetentionWork,E.API
local now=A.ParseDay('2026-11-01')+3600;TEST_NOW(now)
local old=now-400*86400
local c=S.Character('query-expiry-large',{name='Index keeper'})
local function raw(owner,kind,ts,data)
 owner.seq=owner.seq+1
 local r={id=owner.id..':'..owner.seq,kind=kind,category=S.categories[kind],ts=ts,sequence=owner.seq}
 for key,value in pairs(data or{})do r[key]=value end
 owner.records[r.id]=r;owner.order[#owner.order+1]=r.id;return r
end
for i=1,15000 do raw(c,'chat',old+i,{text='An old chat message'})end
local survivor
for i=1,8000 do survivor=raw(c,'memory',now-i%120*86400,{title='A retained memory '..i})end
c.notes.keep={text='Keep my own words',updated=now};c.retention.chat=30
assert(#Q.Kind(c,'chat')==15000 and #Q.Kind(c,'memory')==8000)
local preview=S.PreviewExpiry(c,now);assert(preview.count==15000)
local prepare=Q.PrepareExpiry;local preparing=false;local sawPrivate=false
Q.PrepareExpiry=function(owner,records,work)
 if owner==c then preparing=true end
 local token=prepare(owner,records,work)
 if owner==c then preparing=false end
 return token
end
local originalPairs=pairs;local guarded=false;local insideQuery=false
pairs=function(t)
 if guarded and t==c.records then error('Cleanup must not force a cold full-history query rebuild')end
 return originalPairs(t)
end
local observed=0;local publicationToken;local watching=true
E.On('RECORDS_REMOVED',function(owner,ids,batch)
 if watching and owner==c then
  observed=observed+1;publicationToken=batch.queryIndex
  assert(type(publicationToken)=='table')
  assert(#Q.Kind(c,'chat')==0 and #Q.Kind(c,'memory')==8000)
  assert(#Q.RangeKinds(c,-math.huge,math.huge,{memory=true,chat=true})==8000)
  assert(c.records[survivor.id]==survivor and c.notes.keep.text=='Keep my own words')
  Q.TimeStats(c,old,now)
 end
end)
local oldRecords=c.records;local job=W.Start(function(work)
 return S.ApplyExpiry(c,preview,work,function()guarded=true end)
end)
local slices,maxInstructions=0,0
while true do
 local before=job.operations;local instructions=0
 debug.sethook(job.thread,function()instructions=instructions+1000 end,'',1000)
 local result,reason=W.Step(job,71)
 -- The observer deliberately queries/sorts the retained rows to prove it can
 -- use the published cache. It is verified separately from the preparation cap.
 if observed==0 then maxInstructions=math.max(maxInstructions,instructions)end
 assert(job.operations-before<=71)
 slices=slices+1;assert(slices<10000)
 if preparing and not sawPrivate then
  assert(c.records==oldRecords and #Q.Kind(c,'chat')==15000,'private replacement never leaks into live reads')
  sawPrivate=true
 end
 if result then assert(result=='done',reason);break end
end
watching=false;guarded=false;pairs=originalPairs;Q.PrepareExpiry=prepare
assert(sawPrivate and observed==1 and maxInstructions<25000)
assert(c.records~=oldRecords and #Q.Kind(c,'chat')==0 and #Q.Kind(c,'gap')==1)
-- Every retained dated record is present exactly once, with identity unchanged.
local expected={};for _,r in pairs(c.records)do expected[#expected+1]=r end
table.sort(expected,S.Before);local actual=Q.Range(c,-math.huge,math.huge)
assert(#actual==#expected);for i,r in ipairs(expected)do assert(actual[i]==r)end
local fresh=S.Add(c,'crafted',now,{recipient=c.id,itemID=1,quantity=2,title='Fresh work'})
assert(Q.RangeKinds(c,now,now+1,{crafted=true})[1]==fresh)
survivor.ts=now+1;survivor.kind='screenshot';survivor.category=S.categories.screenshot;S.Changed(c,survivor)
assert(Q.Range(c,now+1,now+2,'screenshot')[1]==survivor)
assert(#Q.Kind(c,'memory')==7999)
-- Notes-only cleanup reuses the existing cache rather than rebuilding unchanged
-- canonical records. Guard just the Query preparation/publication paths here.
c.retention={dailyNotes=30};c.notes['day:'..A.Day(old)]={text='An expired note',updated=old}
S.Touch(c);preview=S.PreviewExpiry(c,now);assert(preview.count==0 and preview.noteCount==1)
local noteRecords=c.records
pairs=function(t)if (guarded or insideQuery)and t==c.records then error('Notes-only cleanup rebuilt the query cache')end;return originalPairs(t)end
Q.PrepareExpiry=function(owner,records,work)
 insideQuery=true;local token=prepare(owner,records,work);insideQuery=false;return token
end
job=W.Start(function(work)return S.ApplyExpiry(c,preview,work,function()guarded=true end)end)
while true do local result,reason=W.Step(job,71);if result then assert(result=='done',reason);break end end
assert(c.records==noteRecords and #Q.Kind(c,'memory')==7999)
guarded=false;pairs=originalPairs;Q.PrepareExpiry=prepare
-- Untyped/external snapshot notifications cannot reuse a stale prepared cache.
local backdated=raw(c,'crafted',old,{recipient=c.id,itemID=2,quantity=1})
E.Emit('RECORDS_REMOVED',c,{},{kinds={note=true}})
local scans=0;pairs=function(t)if t==c.records then scans=scans+1 end;return originalPairs(t)end
local found=Q.Range(c,old,old+1,'crafted');pairs=originalPairs
assert(scans==1 and found[1]==backdated,'legacy notifications retain conservative invalidation')
-- An opaque token cannot be replayed after a later change or used by another
-- character. Neither case may install the wrong record maps.
local other=S.Character('query-expiry-other',{name='Another keeper'})
local own=S.Add(other,'memory',now,{title='Only mine'});Q.Kind(other,'memory')
local token=Q.PrepareExpiry(c,c.records)
S.Touch(other);E.Emit('RECORDS_REMOVED',other,{},{queryIndex=token})
local only=Q.Kind(other,'memory');assert(#only==1 and only[1]==own)
S.Touch(c);E.Emit('RECORDS_REMOVED',c,{},{queryIndex=token})
assert(#Q.Kind(c,'memory')==7999)
local stale=Q.PrepareExpiry(c,c.records)
S.Add(c,'crafted',now,{recipient=c.id,itemID=3,quantity=1})
S.Touch(c);E.Emit('RECORDS_REMOVED',c,{},{queryIndex=stale})
assert(#Q.Kind(c,'crafted')==3)
-- Cancellation/concurrent edits during index preparation leave the original
-- cache readable; Store's revision guard rejects the entire stale transaction.
local cancel=S.Character('query-expiry-cancel',{name='Cancel'})
local doomed=S.Add(cancel,'chat',old,{text='Keep until committed'})
for i=1,1500 do raw(cancel,'memory',now-i*86400,{title='Retain'})end
E.Emit('RECORDS_REMOVED',cancel,{});Q.Kind(cancel,'chat');cancel.retention.chat=30
local review=S.PreviewExpiry(cancel,now);local started=false
Q.PrepareExpiry=function(owner,records,work)
 if owner==cancel then started=true end
 return prepare(owner,records,work)
end
job=W.Start(function(work)return S.ApplyExpiry(cancel,review,work)end)
while not started do local result,reason=W.Step(job,31);assert(not result,reason)end
S.Note(cancel,'keep','A concurrent edit',now)
local result,reason
repeat result,reason=W.Step(job,31)until result
Q.PrepareExpiry=prepare
assert(result=='failed'and tostring(reason):find('History changed',1,true))
assert(cancel.records[doomed.id]and #Q.Kind(cancel,'chat')==1 and cancel.notes.keep.text=='A concurrent edit')
-- A commit hook that edits history must also be rejected after that hook.
review=S.PreviewExpiry(cancel,now)
local ok,err=pcall(S.ApplyExpiry,cancel,review,nil,function()S.Note(cancel,'hook','Preserve this newer edit',now)end)
assert(not ok and tostring(err):find('before cleanup publication',1,true))
assert(cancel.records[doomed.id]and cancel.notes.hook.text=='Preserve this newer edit'and #Q.Kind(cancel,'chat')==1)
for _,owner in ipairs({c,other,cancel})do
 E.db.characters[owner.id]=nil
 local J=E.JournalJobs;J.pending[owner]=nil;J.seeds[owner]=nil;J.boundaries[owner]=nil;J.corrections[owner]=nil;J.spans[owner]=nil
end
print('PASS retained query index: 15,000 deletions / 8,000 retained records; '..slices..' bounded cleanup slices, max '..maxInstructions..' pre-publication instructions per 71 checkpoints; no cold rebuild in observers, live changes, notes-only reuse, cancellation, stale/replayed tokens and isolation')
