local B,L,V,S,C=E.Book,E.CompanyLayout,E.CompanyView,E.Store,E.Company
local c=E.db.characters["myepoch-ui-fixture-028"]; local g=c.records[c.id..":1"]
local function click(page,text)
 for _,kind in ipairs({"companyControl","companyRow","button"})do for i=1,page.used[kind] or 0 do local f=page.pool[kind][i]; if f.text:GetText()==text then f:Click(); return end end end
 return TEST_UI_CLICK(text,prefix)
end
B.ChangeCharacter(c.id); B.SetChapter("Company")
assert(B.selected==g.id and B.companySessionFocus==g.id)
assert(B.right.used.companyStat==3 and #L.lastSession.quests==2 and #L.lastSession.loot==1)
click(B.right,"Chat"); assert(B.right.used.companyChat==12 and #L.lastMessages==15)
local before=c.seq; local f=B.right.pool.companyChat[1]; local record=L.lastMessages[1]; local text=record.text; local refs=E.Copy(record.refs)
f.keep:Click(); assert(record.starred and c.seq==before and record.text==text and E.Same(refs,record.refs))
assert(S.Protected(c)[g.id]); assert(#C.History(c,"Player-Test-Merrin").quotes==2)
B.right.pool.companyChat[1].keep:Click(); assert(not record.starred and #C.History(c,"Player-Test-Merrin").quotes==1)
click(B.right,"Later messages"); assert(B.transcriptPage==2 and B.right.used.companyChat==3)
click(B.right,"Earlier messages"); B.right.pool.companyChat[1]:Click(); assert(B.selected==record.id)
click(B.right,"Back to group session"); assert(B.selected==g.id and B.groupTab=="chat")
local input=B.right.pool.edit[1]; input:SetText("SNACKS"); input.scripts.OnEnterPressed(input); assert(#L.lastMessages==2)
input=B.right.pool.edit[1]; input:SetText(""); input.scripts.OnEnterPressed(input)
click(B.right,"Quests"); click(B.right,"The People's Militia"); assert(B.selected~=g.id); click(B.right,"Back to group session")
click(B.right,"Pulls"); assert(#L.lastSession.pulls==0)
local content=""; for i=1,B.right.used.label or 0 do content=content..B.right.pool.label[i]:GetText()end
assert(content:find("Membership at observation time",1,true) and not content:find("0 damage",1,true))
g.refs={c.id..":2"}; S.Changed(c,g); B.Render(); click(B.right,"Open: The road to Sentinel Hill"); assert(B.selected==c.id..":2")
B.selected=g.id; B.Render()
click(B.left,"Companions"); click(B.left,"Merrin - Sample realm")
assert(V.lastHistory.person.id=="Player-Test-Merrin" and #V.lastHistory.quests==1 and #V.lastHistory.milestones==1)
assert(B.right.used.companyStat==4)
local oldWhisper=E.Social.Whisper; local requested
E.Social.Whisper=function(p)requested=p.id; return "Composer only" end
click(B.right,"Whisper - open composer"); assert(requested=="Player-Test-Merrin"); E.Social.Whisper=oldWhisper
click(B.right,"Your quest completions (1)"); click(B.right,"The People's Militia"); click(B.right,"Back to companion")
assert(B.companySection=="quests" and c.notes["companion:Player-Test-Merrin"].text=="Always remembers to bring the snacks.")
-- Long messages reuse a fixed page of frames, and notes are never mistaken for transcript search.
for i=1,30 do S.Add(c,"chat",g.ts+400+i,{group=g.id,refs={g.id},author="A long recorded speaker name",channel="PARTY",text=string.rep("A very long memory ",40),title="Long message"})end
click(B.left,"Group sessions"); click(B.right,"Chat"); local allocated=#B.right.pool.companyChat
for i=1,5 do B.transcriptPage=i; B.Render(); assert((B.right.used.companyChat or 0)<=12 and #B.right.pool.companyChat==allocated)end
local other=S.Character("company-layout-empty",{name="Other reader"})
B.ChangeCharacter(other.id); B.SetChapter("Company"); assert(not B.companySessionFocus and (B.right.used.companyStat or 0)==0)
B.ChangeCharacter(c.id); assert(B.companySessionFocus==g.id and B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
print("PASS Company layout: session tabs, bounded transcripts, canonical keepsakes/protection, literal search, source return, membership gaps, own milestones, guarded composer routing, notes, empty metrics and character isolation")
