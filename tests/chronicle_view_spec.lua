local B,S=E.Book,E.Store
local c=E.db.characters["myepoch-ui-fixture-024"]
B.ChangeCharacter(c.id); B.SetChapter("Chronicle")
assert(B.left.used.timeline==6)
local newest=B.left.pool.timeline[1]
assert(newest.text:GetText()=="The Defias Brotherhood completed")
newest:Click(); assert(B.selected==c.id..":6")
assert(B.right.pool.artImage[1]:GetWidth()==B.Width(B.right))
local before=#c.order
for i=1,15 do S.Add(c,"milestone",time()+i,{title=string.rep("A long milestone title ",14),subject=c.id,major=true,milestoneType="level"})end
S.Add(c,"milestone",time()+30,{title="Another character's milestone",subject="someone-else",major=true})
S.Add(c,"milestone",time()+31,{title="Minor progress",subject=c.id,major=false})
B.Render(true); assert(B.left.used.timeline==12)
assert(B.left.pool.timeline[1]:GetHeight()>118,"long titles must expand their row")
for i=1,B.left.used.timeline do assert(B.left.pool.timeline[i].text:GetText()~="Another character's milestone"); assert(B.left.pool.timeline[i].text:GetText()~="Minor progress")end
local allocated=#B.left.pool.timeline
for i=1,20 do B.page=i%2+1; B.Render(true)end
assert(#B.left.pool.timeline==allocated,"timeline paging must reuse frames")
assert(#c.order==before+17,"rendering must not create history")
B.SetChapter("Calendar"); assert(not newest:IsShown()); B.SetChapter("Chronicle")
assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
print("PASS Chronicle layout: own major milestones, newest first, clickable detail, long-title wrapping, bounded page reuse and unchanged history")
