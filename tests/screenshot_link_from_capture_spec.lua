local B,S,M,C,A=E.Book,E.Store,E.Memories,E.Capture,E.API
local oldCurrent,oldSession,oldClock,oldScreenshot=E.current,E.Collectors.session,A.Now(),Screenshot
local oldReader,wasOpen=B.character,B.frame and B.frame:IsShown()
local c=S.Character("reverse-shot-owner",{name="Photographer"})
local t=A.ParseDay("2026-11-03")+500;TEST_NOW(t);E.current=c;E.Collectors.session="photo"
local mem=M.Create(c,t-360);mem.title="Our picnic";S.Changed(c,mem)
local mile=S.Add(c,"milestone",t-180,{major=true,subject=c.id,title="Reached twenty",milestoneType="level",level=20})
local function button(label)
 for _,page in ipairs({B.right,B.left,B.nav})do for _,kind in ipairs({"button","memoryControl"})do for i=1,page.used[kind] or 0 do
  local f=page.pool[kind][i];if f.text and f.text:GetText()==label then return f end
 end end end
end
local function click(s)assert(button(s),s):Click()end
local function show(r)B.chapter="Memories";B.selected=r.id;B.memoryFocus=r.id;B.memoryEditing=false;B.Render(true);TEST_PREPARE_BOOK()end
local spare=CreateFrame("Frame",nil,UIParent);spare:Show()
Screenshot=function()assert(spare:IsShown() and not B.frame:IsShown(),"capture hides only scrapbook")end
B.Open();B.ChangeCharacter(c.id);show(mem);B.captureButton:Click()
local shot=assert(C.pending).record
assert(not B.frame:IsShown() and spare:IsShown());C.Tick(.05);C.Tick(.05);C.Tick(.6);C.Tick(.6)
assert(B.frame:IsShown() and spare:IsShown() and shot.status=="unconfirmed" and B.selected==mem.id)
show(shot);click("Edit this memory");click("Link a recorded moment")
local mlabel=A.RecordDate(mem).." - "..mem.title
local qlabel=A.RecordDate(mile).." - "..mile.title
-- Select the prior capture's target from its own actual editor.
click(mlabel)
assert(B.selected==mem.id and not B.memoryEditing and M.Screenshots(c,mem)[1]==shot and button("Open screenshot: "..shot.title))
assert(not (shot.userRefs and shot.userRefs[mem.id]))
local function picker()
 show(shot);click("Edit this memory");if button("Link a recorded moment")then click("Link a recorded moment")end
end
picker();assert(not button(mlabel),"existing attachment is not reoffered")
click(qlabel);assert(B.selected==mile.id and M.Screenshots(c,mile)[1]==shot and button("Open screenshot: "..shot.title))
mem.starred=true;S.Changed(c,mem);assert(S.Protected(c)[shot.id],"written memory retains its prior capture")
click("Unlink screenshot: "..shot.title)
assert(#M.Screenshots(c,mile)==0 and M.Screenshots(c,mem)[1]==shot and c.records[shot.id]==shot)
-- A capture's reading page can attach directly or revisit a previous attachment.
show(shot);click("Attach to a scrapbook page")
assert(not B.memoryEditing and button(qlabel) and not button(mlabel))
local oldChoose=button(qlabel).scripts.OnClick
click("Already attached");oldChoose()
assert(B.selected==shot.id and button(mlabel) and not button(qlabel) and #M.Screenshots(c,mile)==0)
click(mlabel);assert(B.selected==mem.id and M.Screenshots(c,mem)[1]==shot)
show(shot);click("Attach to a scrapbook page")
local search=B.right.pool.edit[B.right.used.edit]
search:SetText("reached");search.scripts.OnEnterPressed(search)
click(qlabel);assert(B.selected==mile.id and M.Screenshots(c,mile)[1]==shot)
click("Unlink screenshot: "..shot.title)
-- Existing context links retain the same direction and are never rewritten
-- during passive reads. An old reverse source remains available as context.
local past=S.Add(c,"group",t-500,{title="Friends on the road",memberships={}})
picker();click(A.RecordDate(past).." - "..past.title);assert(B.selected==shot.id and shot.userRefs[past.id])
assert(M.Link(c,shot.id,mile.id));assert(shot.userRefs[mile.id])
picker();assert(button(qlabel));click(qlabel)
assert(M.Screenshots(c,mile)[1]==shot and shot.userRefs[past.id] and shot.userRefs[mile.id])
show(shot);assert(button("Open: "..past.title) and button("Open: "..mile.title))
-- A stale picker cannot attach after the owner has changed.
local diff=M.Create(c,t);diff.title="Elsewhere";S.Changed(c,diff)
picker();local stale=assert(button(A.RecordDate(diff).." - "..diff.title)).scripts.OnClick
local alt=S.Character("reverse-shot-alt",{name="Other"});B.ChangeCharacter(alt.id);stale()
assert(#M.Screenshots(c,diff)==0)
print("PASS actual capture hides only scrapbook, attach from earlier screenshot to memory and milestone, navigate/verify, unlink independently, keep old context and guard stale owner callbacks")
spare:Hide();E.current=oldCurrent;E.Collectors.session=oldSession;TEST_NOW(oldClock);Screenshot=oldScreenshot
if oldReader then B.ChangeCharacter(oldReader)end
if not wasOpen then B.Close(true)end
