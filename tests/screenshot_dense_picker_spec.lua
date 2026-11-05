local S,Q,M,B,A=E.Store,E.Query,E.Memories,E.Book,E.API
local P=E.ScreenshotPages
local c=S.Character("dense-shot-owner",{name="Album owner"})
local at=A.ParseDay("2026-11-02")+1200
local memory=M.Create(c,at);memory.title="Large screenshot album"
local count=SHOT_COUNT or 2600
local shots={}
for i=1,count*3 do
 local id=c.id..":"..(c.seq+1);c.seq=c.seq+1
 local r={id=id,sequence=c.seq,character=c.id,ts=at+(i%23),kind="chat",category="chat",text="Unrelated line"}
 if i%3==0 then
  r.kind="screenshot";r.category="memories";r.title="Choice "..i;r.observationSequence=i%19
  if i%33==0 then r.ts=nil end
  shots[#shots+1]=r
  if i%6==0 then memory.refs[#memory.refs+1]=id end
 end
 c.records[id]=r;c.order[#c.order+1]=id
end
local linkedCount=#memory.refs
local function button(label)
 for n=1,B.right.used.button or 0 do local f=B.right.pool.button[n];if f.text:GetText()==label then return f end end
end
local function click(label)assert(button(label),label):Click()end
local function find(prefix)
 local rows={};for n=1,B.right.used.button or 0 do local text=B.right.pool.button[n].text:GetText();if text:sub(1,#prefix)==prefix then rows[#rows+1]=text end end;return rows
end
local function expected()
 local linked={};for _,id in ipairs(memory.refs)do linked[id]=true end
 local out={};for _,r in ipairs(Q.Kind(c,"screenshot"))do if r.character==c.id and not linked[r.id]then out[#out+1]=r end end
 return out
end
local function checkPage(out,page)
 local rows=find("Link screenshot: ")
 for i,s in ipairs(rows)do local r=out[#out-(page-1)*6-i+1];assert(r and s=="Link screenshot: "..A.RecordDate(r).." - "..r.title,s)end
 assert(#rows==math.min(6,#out-(page-1)*6))
end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Memories");B.selected=memory.id;B.memoryFocus=memory.id;B.memoryEditing=false;B.Render(true);TEST_PREPARE_BOOK()
local original=Q.Kind;local queries=0;Q.Kind=function(owner,kind,...)if kind=="screenshot"then queries=queries+1 end;return original(owner,kind,...)end
local function waitFor(state)
 if not P then return end
 for n=1,20000 do
  if #find(state)>0 then return n end
  P.Tick()
  if n%3==0 then S.Add(c,"chat",at,{text="Live recording"})end
 end
 error("Picker preparation did not complete "..state.." selected "..tostring(B.selected).." chapter "..B.chapter.." mine "..tostring(E.MemoryView.screenshotState and E.MemoryView.screenshotState.target==memory).." shown "..tostring(B.frame:IsShown()).." controls "..table.concat(find(""),"|"))
end
waitFor("Open screenshot: ")
local start=os.clock();click("Link existing screenshots");local openMs=(os.clock()-start)*1000
local frames=waitFor("Link screenshot: ") or 0
local warmStart=os.clock();for i=1,3 do B.Render()end;local warmMs=(os.clock()-warmStart)*1000/3
if P then assert(queries==0,"Picker enumerated and sorted the screenshot bucket")end
Q.Kind=original
local out=expected();checkPage(out,1);click("Older screenshot choices");checkPage(out,2);click("Newer screenshot choices");checkPage(out,1)
local shot=out[#out];local first=find("Link screenshot: ")[1];click(first);waitFor("Link screenshot: ");assert(#memory.refs==linkedCount+1)
out=expected();checkPage(out,1)
-- Correction of an already linked record does not rewrite the user's source references.
shot.title="New caption";shot.ts=at+4000;S.Changed(c,shot);B.Render();assert(#memory.refs==linkedCount+1)
local fresh=S.Add(c,"screenshot",at,{title="Newly acquired"});local other=out[4]
other.observationSequence=9999;other.ts=nil;S.Changed(c,other);B.Render();checkPage(expected(),1)
local change=out[7];change.kind="chat";S.Changed(c,change);B.Render();checkPage(expected(),1)
change.kind="screenshot";S.Changed(c,change);B.Render();checkPage(expected(),1)
local oldRecords=c.records;local newRecords={};for id,row in pairs(oldRecords)do if row~=other then newRecords[id]=row end end
c.records=newRecords;E.Emit("RECORDS_REMOVED",c,{[other.id]=true},{});B.Render();TEST_PREPARE_BOOK();waitFor("Link screenshot: ");checkPage(expected(),1)
local beforeReturn=os.clock();B.selected=nil;B.memoryFocus=nil;B.memoryOverview=true;B.Render(true);local returnMs=(os.clock()-beforeReturn)*1000
SHOT_RESULT={openMs=openMs,warmMs=warmMs,returnMs=returnMs,frames=frames,queries=queries,shots=count,linked=linkedCount}
print("PASS dense real Book screenshot order, every tie, page navigation, attach, correction, reclassification, arrivals and retention; linked="..linkedCount)


