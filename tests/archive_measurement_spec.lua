local R,S,A,B=E.Archive,E.Store,E.API,E.Book
local c=S.Character('archive-bounded-078',{name='Large archive'})
local stamp=A.Now()
-- Synthetic persisted history, independent of collector and event scheduling cost.
for i=1,100000 do
 local id=c.id..':'..i
 c.records[id]={id=id,kind='chat',category='chat',ts=stamp,sequence=i,text='A remembered conversation.'}
 c.order[i]=id
end
c.seq=100000
local all={};for n=0,255 do all[#all+1]=string.char(n)end
local bytes=table.concat(all)
c.notes['day:2026-11-01']={text=string.rep(bytes,8192)..'\000123"\\\n\r',updated=stamp}
c.state[string.rep('key"\\',3000)]='A long metadata key'
local function size(v)
 local kind=type(v)
 if kind=='string'then return #string.format('%q',v)end
 if kind=='number'then return #tostring(v)end
 if kind=='boolean'then return v and 4 or 5 end
 if kind=='nil'then return 3 end
 local n=2;for k,value in pairs(v)do n=n+4+size(k)+size(value)end;return n
end
local expected=size(c)
local rawNext,rawPairs,rawFormat=next,pairs,string.format
local visits,formats,maxInput=0,0,0
local function observedNext(t,k)
 if t==c.records then visits=visits+1 end
 return rawNext(t,k)
end
next=observedNext
pairs=function(t)if t==c.records then return observedNext,t,nil end;return rawPairs(t)end
string.format=function(pattern,...)
 if pattern=='%q'then local value=...;maxInput=math.max(maxInput,#value);formats=formats+1;assert(#value<=256,'a large string was formatted in one slice')end
 return rawFormat(pattern,...)
end
local result,steps,peak= nil,0,0
local ok,err=pcall(function()
 R.Start(c);assert(visits==0,'starting must not enumerate the history')
 repeat
  local before=visits;local started=os.clock();result=R.Step(64)
  peak=math.max(peak,os.clock()-started);steps=steps+1
  assert(visits-before<=64,'entering a table exhausted the incremental budget')
  assert(steps<150000,'bounded measurement terminates')
 until result
end)
next,pairs,string.format=rawNext,rawPairs,rawFormat
assert(ok,err)
assert(result.complete and not result.changed and result.bytes==expected,'chunked quoting must equal the complete Lua 5.1 representation')
assert(result.records==100000 and result.notes==1 and result.unavailable==0)
assert(#c.order==100000 and #c.notes['day:2026-11-01'].text>2000000,'measurement preserves original text and history')
assert(formats>8192 and maxInput==256)
-- Ordinary recording can finish with the existing explicit changed-during-scan label.
local small=S.Character('archive-changing-078',{name='Changing archive'})
S.Add(small,'chat',stamp,{text='Before'})
R.Start(small);R.Step(1);S.Add(small,'chat',stamp+1,{text='During'})
repeat result=R.Step(64)until result
assert(result.complete and result.changed)
local completed=R.results[small]
-- A failed cursor cannot replace a completed estimate or silently restart forever.
R.Start(small)
next=function(t,k)if t==small then error('invalid key to next')end;return rawNext(t,k)end
result=R.Step(1);next=rawNext
assert(result.interrupted and result.changed and not result.complete and not R.worker)
assert(R.results[small]==completed and R.interrupted[small]==result)
B.ChangeCharacter(small.id);B.SetChapter('Archive');B.archiveTab='storage';B.Render(true)
assert(not R.worker,'render must not automatically repeat an interrupted scan')
local found=false
for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find('Measurement stopped',1,true)then found=true end end
assert(found,'interrupted estimate needs a visible retry explanation')
R.Start(small);assert(not R.interrupted[small]);repeat result=R.Step(64)until result;assert(result.complete)
-- Removal invalidates both the old total and any in-flight scan, including note-only cleanup.
R.Start(small);E.Emit('RECORDS_REMOVED',small,{})
assert(not R.worker and not R.results[small] and R.interrupted[small])
B.Render(true);assert(not R.worker)
R.Start(small);repeat result=R.Step(64)until result
assert(result.complete and not R.interrupted[small])
B.SetChapter('Chronicle')
print(string.format('PASS bounded archive scan: 100,000 records, 2 MiB note, all byte values, %d slices, largest 64-operation host slice %.2f ms; interruption, retry and source preservation',steps,peak*1000))
