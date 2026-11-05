local S,B,M=E.Store,E.Book,E.Memories
local day=assert(E.API.ParseDay("2026-11-01"))
local owner,shown=B.character,B.frame:IsShown()
local c=S.Character("quote-list-reader",{name="Reader"})
local friend="test-friend"
local g=S.Add(c,"group",day,{title="Group",memberships={}})
for id,name in pairs({[c.id]="Reader",[friend]="Fern"}) do
    g.memberships[id]={name=name,intervals={{from=day,through=day+300}}}
end
S.Changed(c,g)
local quote=S.Add(c,"chat",day+20,{text="Checking a kept message",title="Fern",author="Fern",authorGUID=friend,group=g.id,starred=true})
local mem=M.Create(c,day+10)
local function listed(wanted)
    assert((#M.Saved(c,"Checking a kept message")==1)==wanted)
    assert((M.Category(c,quote)~=nil)==wanted)
    assert((#E.Company.History(c,friend).quotes==1)==wanted)
    local found=false
    for _,r in ipairs(E.CalendarView.Report(c,day).records)do if r==quote then found=true end end
    assert(found==wanted)
end
listed(true)
quote.character="different-reader";S.Changed(c,quote);listed(false)
assert(not M.Create(c,day+30,quote.id) and not M.Link(c,mem.id,quote.id) and not E.Company.Quote(c,quote.id))
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Memories");B.memoryMode="saved";B.memoryQuery="Checking a kept message";B.memoryOverview=true;B.selected=nil
B.Render(true);TEST_PREPARE_BOOK();assert((B.left.used.memoryCard or 0)==0)
quote.character=c.id;S.Changed(c,quote);listed(true)
B.Render(true);TEST_PREPARE_BOOK();assert(B.left.used.memoryCard==1 and B.left.pool.memoryCard[1].recordID==quote.id)
assert(M.Link(c,mem.id,quote.id))
if owner then B.ChangeCharacter(owner)end
if not shown then B.Close(true)end
print("PASS saved quote isolation in Memories previews and links, Calendar day rows, companion history and original source recovery")
