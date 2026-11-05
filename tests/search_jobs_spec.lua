local X,S,B,V=E.Search,E.Store,E.Book,E.SearchView
local function eq(a,b,label)assert(a==b,(label or 'Search job')..': '..tostring(a)..' ~= '..tostring(b))end
local c=S.Character('search-jobs-045',{name='Search jobs'})
-- A retained history large enough to force scanning and ordering across updates.
for i=1,100000 do
 local id=c.id..':'..i
 c.records[id]={id=id,character=c.id,kind='chat',title='Camp conversation',text='Campfire story '..i,author='Mira',ts=i%701,sequence=i,refs={}}
 c.order[i]=id
end
c.seq=100000
local warm=0
while not X.IsReady(c)do X.WarmStep(c,500);warm=warm+1;assert(warm<205)end
local started=os.clock()
local result,pending=X.Request(c,'Campfire','chat',1,8);assert(not result and pending.job.position==200)
local job=pending.job;local steps=0;local biggest=0
while not job.ready do
 local tick=os.clock();local work=X.Step(c,500);biggest=math.max(biggest,os.clock()-tick)
 assert(work<=500,'Scanning and heap extraction both consume the operation budget')
 steps=steps+1;assert(steps<410)
end
result=X.Request(c,'Campfire','chat',1,8);eq(result.total,100000);eq(#result.hits,8);assert(not result.changed)
local expected=X.Find(c,'Campfire','chat',1,8)
for page=1,result.pages do
 local actual=X.Request(c,'Campfire','chat',page,8)
 local reference=X.Find(c,'Campfire','chat',page,8)
 for i,hit in ipairs(actual.hits)do eq(hit.id,reference.hits[i].id,'Heap order agrees with timestamps, observation sequence and IDs')end
end
eq(X.Step(c,500),0,'Finished jobs do no further work')

-- Continuous new chat must not restart a running search forever.
X.Refresh(c);result,pending=X.Request(c,'story','chat',1,8);job=pending.job
local new=S.Add(c,'chat',800,{title='Late arrival',text='story after the search started'})
local first=c.records[c.order[1]];first.text='Edited after scan';S.Changed(c,first)
S.Note(c,'record:'..first.id,'Fresh annotation',801)
while not job.ready do X.Step(c,500)end
result=X.Request(c,'story','chat',1,8);eq(result.total,100000,'Captured documents remain stable after later edits')
assert(result.changed,'Results expose later edits/additions instead of claiming a fresh snapshot')
X.Refresh(c);result,pending=X.Request(c,'Fresh annotation','notes',1,8)
while not result do X.Step(c,500);result=X.Request(c,'Fresh annotation','notes',1,8)end
eq(result.total,1);eq(result.hits[1].record,first.id)

-- A new applied query replaces unfinished work; characters never share results.
X.Refresh(c);local _,old=X.Request(c,'story','chat')
local _,replacement=X.Request(c,'never present','chat');assert(old.job~=replacement.job)
local oldPosition=old.job.position;X.Step(c,300);eq(old.job.position,oldPosition)
local other=S.Character('search-jobs-other-045',{name='Other search'})
S.Add(other,'memory',100,{title='Private elsewhere'});X.WarmStep(other,500)
eq(X.Request(other,'story','all').total,0)

-- Progress updates preserve the same edit box and its unsent draft.
B.ChangeCharacter(c.id);B.search='never present';B.searchFilter='chat';B.SetChapter('Search')
assert(V.pending and not V.lastResult)
local edit=B.left.pool.edit[1];edit:SetText('Still typing');edit.scripts.OnTextChanged(edit,true)
local before=B.right.used.label;X.Process(500)
eq(B.left.pool.edit[1],edit);eq(edit:GetText(),'Still typing');eq(B.right.used.label,before)
local loops=0
while not V.lastResult do X.Process(10000);loops=loops+1;assert(loops<30)end
eq(B.search,'never present');eq(B.left.pool.edit[1]:GetText(),'Still typing')
eq(V.lastResult.total,0)
S.Add(c,'chat',900,{title='Another later message',text='never present now appears'})
assert(V.lastResult.changed);assert(V.freshness.label:GetText():find('History changed',1,true))
X.Refresh(c);B.Render()
while not V.lastResult do X.Process(10000)end
eq(V.lastResult.total,1)

-- Invalidated indexes discard stale jobs; deleted records cannot survive a fresh query.
local deleted=V.lastResult.hits[1].record;c.records[deleted]=nil;E.Emit('RECORDS_REMOVED',c,{[deleted]=true})
assert(not X.IsReady(c));B.Render()
while not V.lastResult do X.Process(10000)end
eq(V.lastResult.total,0)
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do
 UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();eq(B.frame:GetWidth(),1760);eq(B.frame:GetHeight(),940)
end
UIParent:SetSize(1920,1080);B.Fit()
local tied=S.Character('search-jobs-ties',{name='Tied dates'})
for i,key in ipairs({'a','b','c','d'})do
 local id=tied.id..':'..key;tied.order[i]=id
 tied.records[id]={id=id,character=tied.id,kind='memory',title='100% [literal]',sequence=9,ts=i<=2 and 10 or nil,refs={}}
end
X.WarmStep(tied,500)
local tieResult=X.Request(tied,'100% [literal]','all',1,4)
for i,key in ipairs({'a','b','c','d'})do eq(tieResult.hits[i].id,tied.id..':'..key,'Unknown dates sort after known dates; IDs break exact ties')end
eq(X.Request(tied,'100% [literal]','all',2,2).hits[1].id,tied.id..':c')
print(string.format('PASS search jobs: 100,000 records, bounded scan/order, matching sort, live edits, replacement, isolation, input drafts, expiry and geometry; largest 500-operation host slice %.2f ms',biggest*1000))
