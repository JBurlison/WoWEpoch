local X,S,B,V=E.Search,E.Store,E.Book,E.SearchView
local c=S.Character('search-release-view',{name='Search reader'})
for i=1,1600 do S.Add(c,'memory',1793810000+i,{title='Saved page '..i,text='A remembered road '..i})end
B.ChangeCharacter(c.id);B.SetChapter('Search');B.search='remembered';B.searchDraft=nil;B.Render()
while not V.lastResult do X.Process(500)end
assert(V.lastResult.total==1600 and X.IsReady(c))
local first=V.lastResult.hits[1].id
local records,notes,sequence=c.records,c.notes,c.seq
B.searchDraft='Unsubmitted words'
B.Close(true)
assert(not X.IsReady(c)and not V.lastResult and not V.pending and not V.freshness,
 'Closing releases search documents and UI result references')
for i=1,5 do X.Process(500)end
assert(not X.IsReady(c),'Closed search is not rebuilt by background processing')
assert(B.search=='remembered'and B.searchDraft=='Unsubmitted words')
B.Open();while not V.lastResult do X.Process(500)end
assert(V.lastResult.total==1600 and V.lastResult.hits[1].id==first,
 'Reopening rebuilds the applied result without submitting the draft')
assert(B.left.pool.edit[1]:GetText()=='Unsubmitted words')
assert(c.records==records and c.notes==notes and c.seq==sequence,'Cache release never changes saved history')
-- A screenshot's temporary hide preserves work for its immediate restoration.
local ready=V.lastResult
B.captureHiding=true;B.frame:Hide();B.captureHiding=nil
assert(X.IsReady(c)and V.lastResult==ready,'Temporary screenshot hides retain the current search')
B.frame:Show();B.Render()
-- Abandoning an unfinished UI request cancels its worker and ignores late ready.
B.search='a different query';B.searchDraft=nil;X.Refresh(c,true);B.Render()
local abandoned=assert(V.pending and V.pending.job)
B.Close(true);local at=abandoned.position
X.Process(500);E.Emit('SEARCH_READY',c,abandoned)
assert(not X.IsReady(c)and abandoned.position==at and not V.lastResult)
-- Explicit non-UI consumers keep their in-flight work when the book closes.
local api=S.Character('search-release-api',{name='API reader'})
for i=1,1000 do S.Add(api,'memory',1793820000+i,{text='Outside the book '..i})end
local result=X.Request(api,'outside','all',1,8)
assert(not result)
X.ReleaseView()
local ticks=0
repeat X.Process(500);result=X.Request(api,'outside','all',1,8);ticks=ticks+1;assert(ticks<30)until result
assert(result.total==1000,'Closing the book must not cancel explicit asynchronous requests')
X.ReleaseView();assert(not X.IsReady(api),'Completed API cache can be discarded without altering its returned hits')
assert(#result.hits==8 and result.hits[1].record)
-- Transcript arrays are rebuildable, including when reused by a synchronous caller.
local group=S.Add(c,'group',1793830000,{title='A conversation'})
S.Add(c,'chat',1793830001,{group=group.id,text='Retained words',author='Writer'})
local rows=X.ReadTranscript(c,group.id,'');assert(#rows==1)
X.ReleaseView()
local rebuilt=X.ReadTranscript(c,group.id,'')
assert(rebuilt~=rows and #rebuilt==1 and rebuilt[1]==rows[1])
print('PASS search cache release: closed memory/work release, restored query/draft/results, screenshot retention, API ownership and transcript rebuilding')
