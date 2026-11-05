local S,M,B,A,Q=E.Store,E.Memories,E.Book,E.API,E.Query
local n=SAVED_HISTORY_SIZE or 2500
local c=S.Character("saved-performance-owner",{name="Offline album"})
local other=S.Character("separate-saved-journal",{name="Other journal"})
local ts=1701000000
local first=M.Create(c,ts);first.title="Copper teapot archive single"
local last
for i=1,n do
 local id=c.id..":"..(c.seq+1);c.seq=c.seq+1
 local kind=({"chat","chat","screenshot","chat","quest","memory"})[(i-1)%6+1]
 local r={id=id,character=c.id,sequence=c.seq,ts=ts+i,kind=kind,category=kind=="chat" and "chat" or "memories",title="Shelf "..i,text="A short caption",refs={},tags={}}
 if kind=="memory"then r.tags={"Copper","spoon"};last=r end
 c.records[id]=r;c.order[#c.order+1]=id
end
local P=E.SavedPages
local clock=SAVED_CLOCK or os.clock
local function elapsed(fn)local start=clock();fn();return (clock()-start)*1000 end
local function pump()
 if not P then return 0,0 end
 local maxStep=0
 for i=1,40000 do
  if E.MemoryView.lastSaved then return i-1,maxStep end
  if i%11==0 then S.Add(c,"chat",ts+n+i,{text="Continued party conversation"})end
  if i%37==0 then S.Add(c,"screenshot",ts+n+i,{title="New live picture "..i})end
  maxStep=math.max(maxStep,elapsed(P.Tick))
 end
 error("No ready saved page during recording")
end
local function find(text)
 for _,page in ipairs({B.left,B.right,B.nav})do
  for _,kind in ipairs({"button","memoryCard","memoryControl"})do
   for i=1,page.used[kind]or 0 do local widget=page.pool[kind][i];if widget.text:GetText()==text then return widget end end
  end
 end
end
local function click(text)assert(find(text),text):Click()end
local function cards(expected)
 local p=B.left;local rows=E.MemoryView.lastSaved;local page=B.memoryPage or 1
 assert(#expected==#rows and rows[#rows]==expected[#expected])
 for i=1,math.min(8,#expected-(page-1)*8)do assert(p.pool.memoryCard[i].recordID==expected[#expected-(page-1)*8-i+1].id)end
end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Character");TEST_PREPARE_BOOK()
local syncCalls=0;local realSaved=M.Saved
M.Saved=function(...)syncCalls=syncCalls+1;return realSaved(...)end
B.memoryMode="saved";B.memoryOverview=true;B.selected=nil;B.memoryQuery=nil
local cold=elapsed(function()B.SetChapter("Memories")end)
local frames,maxStep=pump()
local expected=realSaved(c,"");cards(expected)
local warm={};for i=1,5 do warm[i]=elapsed(B.Render)end;table.sort(warm)
local pageMs=elapsed(function()click("Older entries")end);pump();assert(B.memoryPage==2);cards(expected)
click("Newer entries");pump();cards(expected)
local row=B.left.pool.memoryCard[1]
local selected=row.recordID;row:Click();assert(B.selected==selected)
B.memoryOverview=true;B.selected=nil;B.memoryFocus=nil
local returnMs=elapsed(B.Render);pump();cards(expected)
-- Enter a real sidebar filter. It may span the exact comma/space tag separator.
local input=B.nav.pool.edit[1];input:SetText("COPPER, SPOON")
local filterMs=elapsed(function()input.scripts.OnEnterPressed(input)end);local filterFrames=0
if P then
 for i=1,40000 do if E.MemoryView.lastSaved then filterFrames=i-1;break end;P.Tick()end
end
cards(realSaved(c,"COPPER, SPOON"))
-- Open an actual Search result, then use its Back action.
B.chapter="Search";B.search="Copper teapot archive single";B.searchFilter="memories";B.searchPage=1;B.selected=nil;B.searchOrigin=nil;B.Render(true)
for i=1,30000 do
 E.Search.Process(1500)
 if E.SearchView.lastResult and E.SearchView.lastResult.total==1 then break end
end
B.Render()
local hit=B.right.pool.searchRow[1];assert(hit and E.SearchView.lastResult.total==1)
local searchMs=elapsed(function()hit.scripts.OnClick(hit)end)
assert(B.Character()==c and B.chapter=="Memories" and B.selected==first.id)
pump();click("Back to search results");assert(B.chapter=="Search" and B.search=="Copper teapot archive single")
M.Saved=realSaved
if P then assert(syncCalls==0,"UI called legacy synchronous M.Saved")end
SAVED_PROFILE={records=n,qualified=#expected,coldMs=cold,frames=frames,maxFrameMs=maxStep,warmMedianMs=warm[3],olderMs=pageMs,returnMs=returnMs,filterMs=filterMs,filterFrames=filterFrames,searchToMemoryMs=searchMs,legacyUICalls=syncCalls}
print("PASS real saved Book, first/eighth cards, adjacent pages, select/return, registered live Adds and sidebar filter, Search result and original search Back")

