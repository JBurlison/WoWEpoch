local B,D,C,S=E.Book,E.ArtDialog,E.Capture,E.Store
local c=E.current
local m=assert(E.Memories.Create(c,E.API.Now()))
B.Open();B.SetChapter("Memories");B.selected=m.id;B.memoryEditing=true;B.memoryEditID=m.id;B.Render(true)
for i=1,500 do if (B.right.used.edit or 0)>0 then break end;E.frame.scripts.OnUpdate(E.frame,.05);B.Render()end
local outside=B.right.pool.edit[1]
outside:SetText("Unsaved text on the scrapbook page")
if SCENARIO=="location"then
    B.SetChapter("Chronicle");B.selected=nil;B.Render(true);D.OpenLocation("zone:westfall")
else D.OpenRecord(m)end
assert(D.IsOpen());local ctx=D.context;local tile=D.left.pool.artTile[2];assert(tile)
local choice=tile.artID;tile:Click()
local apply=assert(D.apply.scripts.OnClick);local input=D.left.pool.edit and D.left.pool.edit[1]
local filterText="Unsubmitted dialog search"
if input and input:IsShown()then input:SetText(filterText)end
D.left.scroll:SetVerticalScroll(9);D.right.scroll:SetVerticalScroll(11)
if SCENARIO=="filter" then D.OpenFilterDropdown();D.filterInput:SetText("cooking");D.filterInput.scripts.OnTextChanged(D.filterInput,true);assert(D.filterContext==ctx)end
local calls,commits=0,0
E.On("RECORD_CHANGED",function(owner,r)if owner==c and r==m then commits=commits+1 end end)
Screenshot=function()calls=calls+1;assert(not B.frame:IsShown() and not D.IsOpen(),"Capture must hide both book and picker")end
if SCENARIO=="unavailable"then
    Screenshot=nil;local shot=assert(MyEpoch_Capture());assert(shot.status=="unavailable" and not C.pending)
    assert(D.IsOpen() and D.context==ctx and m.artID==nil);D.cancel:Click();return
end
local shot=assert(MyEpoch_Capture());assert(C.pending and not B.frame:IsShown() and not D.IsOpen());apply()
if SCENARIO=="filter"then
    -- Native parent hiding can notify hidden children. The focused filter and context must survive that callback.
    D.filterOverlay.scripts.OnHide(D.filterOverlay);D.frame.scripts.OnHide(D.frame)
    assert(D.filterContext==ctx)
end
assert(commits==0 and m.artID==nil,"An unavailable Apply callback cannot commit a hidden draft")
local function tick()for i=1,6 do E.frame.scripts.OnUpdate(E.frame,.4)end end
if SCENARIO=="manual-open"then
    B.Open();assert(D.IsOpen() and D.context==ctx and shot.status=="cancelled" and not C.pending)
    tick();assert(calls==0 and D.IsOpen());D.cancel:Click();return
elseif SCENARIO=="manual-close"then
    B.Close(true);tick();assert(not B.frame:IsShown() and not D.context and not D.IsOpen() and calls==1)
    B.Open();assert(not D.IsOpen() and m.artID==nil);return
elseif SCENARIO=="record-replaced"then
    local repl=E.Copy(m);c.records[m.id]=repl;S.Changed(c,repl);tick()
    assert(B.frame:IsShown() and not D.context and not D.IsOpen() and repl.artID==nil and m.artID==nil)
    apply();assert(repl.artID==nil and m.artID==nil);return
elseif SCENARIO=="recorder-handoff"then
    local prior=UnitGUID;UnitGUID=function(unit)if unit=="player"then return "new-screenshot-recorder" end;return prior(unit)end
    for i=1,8 do E.frame.scripts.OnUpdate(E.frame,.5)end
    assert(E.current~=c and not C.pending and not D.context and not D.IsOpen() and calls==0 and m.artID==nil)
    B.Open();assert(not D.IsOpen());return
elseif SCENARIO=="owner-changed"then
    local nextOwner=S.Character("new-capture-owner",{name="Another adventurer"})
    B.ChangeCharacter(nextOwner.id);tick();assert(not D.IsOpen() and not D.context and B.Character()==nextOwner)
    apply();assert(m.artID==nil and calls==1);return
elseif SCENARIO=="combat" or SCENARIO=="combat-manual-close"then
    E.db.settings.combatClose=true;B.Combat(true);tick()
    assert(calls==1 and not D.IsOpen() and not B.frame:IsShown() and B.reopen)
    if SCENARIO=="combat-manual-close"then B.Close(true)end
    B.Combat(false)
    if SCENARIO=="combat-manual-close"then assert(not D.context and not B.frame:IsShown());return end
else tick()end
assert(calls==1 and not C.pending and shot.status=="unconfirmed" and D.IsOpen() and B.frame:IsShown() and D.context==ctx)
assert(commits==0 and m.artID==nil and D.left.scroll:GetVerticalScroll()==9 and D.right.scroll:GetVerticalScroll()==11)
if input and input:IsShown() then assert(input:GetText()==filterText)end
if SCENARIO=="filter"then assert(D.filterOverlay:IsShown() and D.filterContext==ctx and D.filterQuery=="cooking");D.CloseFilterDropdown()end
if SCENARIO=="cancel"then D.cancel:Click();apply();assert(not D.IsOpen()and commits==0 and m.artID==nil and outside:GetText()=="Unsaved text on the scrapbook page")
elseif SCENARIO=="location"then
    D.apply:Click();assert(not D.IsOpen() and E.Artwork.Resolve(c,"zone:westfall").id==choice)
else
    D.apply:Click();apply()
    assert(not D.IsOpen() and commits==1 and m.artID==choice and m.artMode=="fixed")
    assert(outside:GetText()=="Unsaved text on the scrapbook page" and m.title~="Unsaved text on the scrapbook page")
end
