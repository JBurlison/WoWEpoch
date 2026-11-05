local B,S,Q,X=E.Book,E.Store,E.Query,E.Search
local active,chapter,shown=B.character,B.chapter,B.frame and B.frame:IsShown()
local c=S.Character("cooperative-transcript-test",{name="Reader"})
local t=E.API.Now()
local g=S.Add(c,"group",t,{memberships={},title="A long evening"})
local target
for n=1,640 do
 local text=n==639 and "A patched copper lantern" or "Party line "..n
 local r=S.Add(c,"chat",t+n,{group=g.id,title="Fern",text=text,author="Fern"})
 if n==639 then target=r end
end
while B.HistoryReadiness(c)~="ready"do Q.ProcessPreparation(750);E.Gathering.Process();E.GoldChecks.Process()end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Company");B.selected=g.id;B.groupTab="chat";B.transcriptSearch="";B.Render()
assert(not E.CompanyLayout.lastMessages,"large group must not publish a partial list")
local function finish()
 for i=1,250 do E.frame.scripts.OnUpdate(E.frame,0);if E.CompanyLayout.lastMessages then return E.CompanyLayout.lastMessages end end
 error("Transcript failed to publish")
end
local late=S.Add(c,"chat",t-1,{group=g.id,text="The clock rolled back"})
local list=finish();assert(#list==641 and list[1]==late)
local edit=B.right.pool.edit[1];edit:SetText("lantern");edit.scripts.OnEnterPressed(edit);assert(not E.CompanyLayout.lastMessages)
local filtered=finish();assert(#filtered==1 and filtered[1]==target)
B.right.pool.companyChat[1]:Click();assert(B.selected==target.id)
X.Invalidate(c);TEST_UI_CLICK("Open this group's transcript");assert(B.selected==g.id and not E.CompanyLayout.lastMessages)
finish();assert(B.transcriptHighlight==target.id and B.transcriptPage>1)
-- Repeated membership corrections retain one live directory entry per message.
local h=S.Add(c,"group",t,{memberships={},title="Another session"})
for i=1,20 do target.group=h.id;S.Changed(c,target);target.group=g.id;S.Changed(c,target)end
assert(#Q.ChatDirectory(c,g.id)==641 and not Q.ChatDirectory(c,h.id))
-- A sustained clock rollback can publish a labeled complete prefix while new
-- receipts continue. The visible refresh includes all later accepted records.
X.Invalidate(c);B.transcriptSearch="";B.Render()
local total,shown=641
for i=1,400 do
    if i%3==0 then S.Add(c,"chat",t-1000+i,{group=g.id,text="Earlier clock "..i});total=total+1 end
    X.TranscriptTick(50)
    if E.CompanyLayout.lastMessages then shown=#E.CompanyLayout.lastMessages;break end
end
assert(shown and shown<total,"Expected the visible rollback snapshot")
TEST_UI_CLICK("Include newer messages")
assert(#finish()==total)
if active then B.ChangeCharacter(active)end
if chapter and B.chapter~=chapter then B.SetChapter(chapter)end
if not shown then B.Close(true)end
print("PASS cold source route yields and publishes complete corrected chronological rows, keyword results and exact quote position")
