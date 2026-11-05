local S,B=E.Store,E.Book
local owner,shown=B.character,B.frame and B.frame:IsShown()
local c=S.Character("transcript-label-reader",{name="Reader"})
local day=assert(E.API.ParseDay("2026-11-01"))
local g=S.Add(c,"group",day,{title="Party transcript",memberships={}})
local channels={"CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_INSTANCE_CHAT","CHAT_MSG_INSTANCE_CHAT_LEADER","Legacy channel",""}
local labels={"Party","Party leader","Raid","Raid leader","Raid warning","Instance","Instance leader","Legacy channel","Group channel unknown"}
local messages={}
for i=1,14 do
    messages[i]=S.Add(c,"chat",day+i,{group=g.id,text="Line "..i,author="Fern",channel=channels[i] or channels[1],starred=i>=13})
end
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Company")
B.companyMode="sessions";B.selected=g.id;B.groupTab="chat";B.transcriptSearch=""
B.transcriptPage=1;B.transcriptHighlight=nil;B.Render(true);TEST_PREPARE_BOOK()
for i,label in ipairs(labels) do
    local row=B.right.pool.companyChat[i]
    assert(row.meta:GetText():sub(-#label)==label and not row.sourceMark:IsShown())
    assert(messages[i].channel==channels[i])
end
B.selected=messages[14].id;B.Render(true);TEST_PREPARE_BOOK()
TEST_UI_CLICK("Open this group's transcript");TEST_PREPARE_BOOK()
local neighbor,source=B.right.pool.companyChat[1],B.right.pool.companyChat[2]
assert(neighbor.keep.text:GetText()=="Kept" and source.keep.text:GetText()=="Kept")
assert(not neighbor.sourceMark:IsShown() and not neighbor.meta:GetText():find("Selected quote",1,true))
assert(source.sourceMark:IsShown() and source.meta:GetText():find("Selected quote",1,true)==1)
assert(source.text:GetText()=="Line 14" and messages[14].text=="Line 14")
TEST_UI_CLICK("Earlier messages");TEST_PREPARE_BOOK()
assert(not B.right.pool.companyChat[2].sourceMark:IsShown() and not B.right.pool.companyChat[2].meta:GetText():find("Selected quote",1,true))
if owner then B.ChangeCharacter(owner)end
if not shown then B.Close() end
print("PASS original quote marker, neighboring kept quote, native source click, pooled rows and seven readable chat channels")
