local P,S,M,B=E.SavedPages,E.Store,E.Memories,E.Book
local ts=1701000000;local c=S.Character("saved-frontier-owner",{})
local read=M.Create(c,ts);read.title="Selected page";S.Changed(c,read)
for i=1,380 do local r=S.Add(c,"screenshot",ts,{title="source "..i});r.observationSequence=7 end
local chat=S.Add(c,"chat",ts+1,{text="Private kept transcript",starred=true,observationSequence=7})
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Memories");B.memoryMode="saved";B.memoryQuery=nil;B.memoryOverview=true
B.selected=read.id;B.memoryFocus=read.id;B.memoryEditing=true;B.memoryEditID=read.id;B.Render(true);TEST_PREPARE_BOOK()
B.memoryEditing=true;B.memoryEditID=read.id;B.Render()
local input=B.right.pool.edit[1];input:SetText("Private unsubmitted title")
-- The status labels completed cuts while new eligible additions keep arriving.
local shown=0
for i=1,150 do
 S.Add(c,"screenshot",ts+2+i,{title="Live capture "..i});P.Tick()
 if (B.left.used.memoryCard or 0)>0 then shown=shown+1 end
end
assert(shown>0,"Tied prior rows starved displays during sustained recording")
local function settle()
 for i=1,1500 do
  P.Tick()
  local rows,_,_,pending=P.Page(c,B.memoryQuery,B.memoryPage or 1)
  if rows and not pending then B.Render();return rows end
 end
 error("Stale saved list")
end
local rows=settle();local expected=M.Saved(c,"")
assert(#rows==#expected)
for i,r in ipairs(expected)do assert(rows[i]==r,"Unstable tied row order after live additions")end
assert(B.right.pool.edit[1]:GetText()=="Private unsubmitted title" and read.title=="Selected page")
B.memoryQuery="Private kept transcript";B.memoryPage=1;B.memoryOverview=true;B.selected=nil;B.memoryEditing=false;B.Render()
settle()
local old=B.left.pool.memoryCard[1].scripts.OnClick
-- UI revalidates the eight visible sources even before a correction notice.
chat.character="not-this-owner";B.Render();assert((B.left.used.memoryCard or 0)==0)
chat.character=c.id;S.Changed(c,chat);settle()
chat.character="another-owner";S.Changed(c,chat);old();assert(B.selected~=chat.id)
settle();assert((B.left.used.memoryCard or 0)==0)
chat.character=c.id;S.Changed(c,chat);settle();assert(B.left.pool.memoryCard[1].recordID==chat.id)
local before=c.records;chat.starred=false;S.Changed(c,chat)
c.retention.chat=1;local preview=S.PreviewExpiry(c,ts+7*86400)
assert(preview.ids[chat.id]);S.ApplyExpiry(c,preview);assert(c.records~=before and not c.records[chat.id])
B.Render();settle();assert((B.left.used.memoryCard or 0)==0)
local alt=S.Character("saved-other-frontier",{});B.ChangeCharacter(alt.id);old();assert(B.Character()==alt and B.selected~=chat.id)
print("PASS coherent tied cuts during sustained capture arrivals, eventual native order, unsaved draft, withdrawn/reinstated quote, actual expiry and stale-owner clicks")


