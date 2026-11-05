local P,Q,S,M,B,EApi=E.ScreenshotPages,E.Query,E.Store,E.Memories,E.Book,E.API
local c=S.Character("picker-boundaries",{})
local memory=M.Create(c,1701000000)
local shots={};for i=1,160 do shots[i]=S.Add(c,"screenshot",1701000000+i,{title="Saved "..i})end
-- The cold path neither builds the general query index nor drops a saved orphan.
local function isolated(owner,target,open)
 local s=P.View(owner,target,open)
 for i=1,5000 do
  if P.Page(s,"linked",1) and (not open or P.Page(s,"available",1))then return s end
  s=P.View(owner,target,open)
 end
 error("Unfinished independent picker")
end
local oldWarm=Q.WarmScreenshotIDs
Q.WarmScreenshotIDs=function()return nil end
local oldKind=Q.Kind;Q.Kind=function()error("Cold picker used synchronous query")end
local orphan={id="saved-only",character=c.id,kind="screenshot",title="Retained orphan"}
c.records[orphan.id]=orphan
local s=isolated(c,memory,true);local row,total=P.Page(s,"available",1);assert(total==161 and row[1]==orphan)
assert(not Q.IsWarm(c))
Q.WarmScreenshotIDs=oldWarm;Q.Kind=oldKind
-- A separate target forces delayed link preparation. Draft text entered before
-- that worker's final redraw must remain local to this record.
local target=M.Create(c,1701000300)
for i=1,120 do target.refs[i]=shots[i].id end
local function button(label)for n=1,B.right.used.button or 0 do local f=B.right.pool.button[n];if f.text:GetText()==label then return f end end end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Memories");B.selected=target.id; B.memoryEditID=target.id;B.memoryEditing=true;B.Render(true);TEST_PREPARE_BOOK();B.memoryEditing=true;B.memoryEditID=target.id;B.Render()
local edit=B.right.pool.edit[1];assert(edit and edit:GetText()==target.title);edit:SetText("Unsaved picker draft")
for i=1,20 do P.Tick()end
assert(B.right.pool.edit[1]:GetText()=="Unsaved picker draft" and target.title~="Unsaved picker draft")
assert(button("Link existing screenshots")):Click();for i=1,20 do P.Tick()end
local first=assert(button("Open screenshot: Saved 1")).scripts.OnClick
shots[1].kind="chat";S.Changed(c,shots[1]);first();assert(B.selected==target.id);P.Tick();assert(not button("Open screenshot: Saved 1"))
shots[1].kind="screenshot";S.Changed(c,shots[1]);B.Render()
local saved=assert(button("Open screenshot: Saved 1")).scripts.OnClick
local copy=E.Copy(shots[1]);c.records[copy.id]=copy;S.Changed(c,copy);saved();assert(B.selected==target.id)
local other=S.Character("picker-boundary-alt",{});B.ChangeCharacter(other.id);saved();assert(B.Character()==other and B.selected~=copy.id)
print("PASS independent cold directory, unordered retained source, delayed redraw draft, stale reclassified/replaced source callbacks and offline owner change")

