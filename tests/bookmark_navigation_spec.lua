local B,N,A,S=E.Book,E.Book.Navigation,E.API,E.Store
local oldCharacter=B.character;local oldNow=A.Now();local oldChapter=B.chapter
local now=assert(A.ParseDay("2026-11-03"))+43200;TEST_NOW(now)
local c=S.Character("bookmark-navigation-fixture",{name="Bookmark fixture"})
local level=S.Add(c,"milestone",now-300,{title="Level twelve",major=true,subject=c.id,milestoneType="level"})
S.Add(c,"milestone",now-200,{title="Swords milestone",major=true,subject=c.id,milestoneType="skill"})
S.Add(c,"milestone",now-100,{title="A first discovery",major=true,subject=c.id,milestoneType="discovery"})
S.Add(c,"milestone",now-50,{title="Another character",major=true,subject="someone-else",milestoneType="level"})
local group=E.History.Group(c,now-400,{{id=c.id,name="Bookmark fixture"},{id="bookmark-friend",name="A companion with a longer recorded name"}},"bookmark-session","bookmark-party")
E.History.Acquisition(c,now-350,"loot",{itemID=2840,title="Copper bars with a deliberately long remembered name",quantity=4,recipient=c.id,rarity=1,zone="Westfall",mapID=52,group=group.id,vendorUnitValue=10},"bookmark-loot")
E.History.Acquisition(c,now-340,"crafted",{itemID=2840,title="Copper Bar",quantity=2,recipient=c.id,profession="Mining",professionID=186,zone="Westfall",mapID=52,vendorUnitValue=10},"bookmark-craft")
S.Add(c,"chat",now-320,{group=group.id,author="A companion",text="Good job, friends!",refs={group.id}})
E.History.Wallet(c,now-300,10000,"bookmark-session");E.History.Wallet(c,now-200,10500,"bookmark-session")
S.Add(c,"memory",now-100,{title="A page to remember",text="A saved note belongs to its original page.",tags={"friends"}})
B.ChangeCharacter(c.id);B.Open();TEST_PREPARE_BOOK()
local function find(label)
    for _,p in ipairs({B.nav,B.left,B.right})do for kind,pool in pairs(p.pool)do for i=1,p.used[kind]or 0 do local f=pool[i]
        if f.text and f.text.GetText and f.text:GetText()==label and f.scripts and f.scripts.OnClick then return f,p end
    end end end
end
local function click(label)
    local f=find(label);if f then f:Click();return end
    local menus={};for i=1,B.nav.used.button or 0 do local b=B.nav.pool.button[i];local text=b.text:GetText()
        if b.navExpandable and not b.navExpanded and(not b.navSubview or b.navActive)then menus[#menus+1]=text end
    end
    for _,labelMenu in ipairs(menus)do
        local menu=find(labelMenu);if menu then menu:Click();f=find(label);if f then f:Click();return end
            local opened=find(labelMenu);if opened and opened.navExpanded then opened:Click()end
        end
    end
    error("Missing bookmark control: "..label)
end
local function bounds()
    for _,p in ipairs({B.nav,B.left,B.right})do for kind,pool in pairs(p.pool)do for i=1,p.used[kind]or 0 do local f=pool[i];local q=f.point
        if q and q[1]=="TOPLEFT"and q[2]==p.content and q[3]=="TOPLEFT"then
            local left=q[4]or 0
            if kind=="detailSection"then
                assert(left>=0 and left+f:GetWidth()<=p.scroll:GetWidth(),"Section frame exceeds the scroll viewport in "..B.chapter)
            else
                assert(left+f:GetWidth()<=B.Width(p)+12.1,"Horizontal overflow in "..B.chapter.."/"..kind)
            end
        end
    end end end
end
for _,chapter in ipairs(N.chapters)do
    B.SetChapter(chapter);TEST_PREPARE_BOOK();assert(B.tabs[chapter]and B.tabs[chapter].isChapter)
    for _,name in ipairs(N.chapters)do assert(B.tabs[name]and B.tabs[name].text:GetText():sub(1,#name)==name,"All chapters remain reachable")end
    bounds()
end
B.nav.scroll:SetVerticalScroll(900);B.SetChapter("Chronicle")
assert(B.nav.scroll:GetVerticalScroll()<=B.tabs.Chronicle:GetHeight(),"Chapter navigation brings its bookmark back into view")
B.SetChapter("Chronicle");TEST_PREPARE_BOOK();click("Character levels");assert(B.selected==level.id and #N.Major(c)==1)
click("Skills & professions");assert(#N.Major(c)==1);click("Major milestones");assert(#N.Major(c)==3,"Never include another subject")
local menu=assert(find("All recorded years"));assert(menu.navExpandable);menu:Click();assert(N.open and find("All recorded years").navExpanded);assert(find("All recorded years")):Click();assert(N.open==nil,"Clicking an open filter heading collapses it")
B.SetChapter("Calendar");TEST_PREPARE_BOOK();B.day=assert(A.ParseDay("2024-02-29"));B.Render()
E.CalendarView.SelectMonth(2025,2);assert(A.Day(B.day)=="2025-02-28","Month/year controls clamp leap days")
E.CalendarView.SelectMonth(2025,13);assert(A.Day(B.day)=="2025-02-28"and B.calendarError,"Invalid month preserves selection")
local parse=A.ParseDay;A.ParseDay=function(value)if value:sub(1,4)=="9999"then error("Host time cannot represent date")end;return parse(value)end
local ok=pcall(E.CalendarView.SelectMonth,9999,12);A.ParseDay=parse
assert(ok and A.Day(B.day)=="2025-02-28"and B.calendarError,"Host date limitations do not escape selection")
E.CalendarView.SelectMonth(2026,11);assert(A.Day(B.day)=="2026-11-28")
click("Today");assert(A.Day(B.day)=="2026-11-03")
assert(B.left.used.edit==nil or B.left.used.edit==0,"Calendar selectors moved out of the page")
bounds()
B.SetChapter("Gold");TEST_PREPARE_BOOK();click("MTD");assert(B.goldPreset=="mtd"and E.FinanceView.lastRange.first=="2026-11-01")
click("Custom dates");assert(B.nav.used.edit==2 and(B.left.used.edit or 0)==0)
local edit=B.nav.pool.edit[1];edit:SetText("2026-10-17")
click("More periods");assert(B.nav.pool.edit[1]:GetText()=="2026-10-17","Opening sidebar options preserves an unsubmitted date")
local beforeScroll=math.min(180,B.nav.scroll:GetVerticalScrollRange());B.nav.scroll:SetVerticalScroll(beforeScroll);B.Render()
assert(B.nav.scroll:GetVerticalScroll()==math.min(beforeScroll,B.nav.scroll:GetVerticalScrollRange()),"Same-chapter rendering preserves sidebar scroll")
edit=B.nav.pool.edit[1];edit.scripts.OnEnterPressed(edit);assert(B.goldFrom=="2026-10-17"and B.goldPreset=="custom")
click("Pick Through date");bounds()
-- The same button slot can previously have been a chapter or sidebar action.
-- Repaint an actual day cell with those pooled decorations, then rebuild it.
local cell=assert(find("[3]"));cell.isChapter=true
cell.bookmark=cell.bookmark or E.BookTheme.Texture(cell,"bookmark-v2","ARTWORK");cell.bookmark:Show()
cell.chapterIcon=cell.chapterIcon or E.BookTheme.Texture(cell,"icon-gold-v2","OVERLAY");cell.chapterIcon:Show()
cell.navigationShade=cell.navigationShade or cell:CreateTexture(nil,"BACKGROUND");cell.navigationShade:Show()
cell.text:ClearAllPoints();cell.text:SetPoint("LEFT",36,0)
local setColor=cell.text.SetTextColor;cell.text.SetTextColor=function(self,r,g,b,a)self.observedColor={r,g,b,a};setColor(self,r,g,b,a)end
B.Render();assert(find("[3]")==cell)
assert(not cell.isChapter and cell.face:IsShown()and not cell.bookmark:IsShown()and not cell.chapterIcon:IsShown()and not cell.navigationShade:IsShown(),"Raw calendar cells reset chapter/subview backgrounds")
assert(cell.text.point[1]=="CENTER"and cell.text.observedColor[1]==.29,"Pale date cells retain centered dark ink")
cell.text.SetTextColor=setColor
click("[3]");assert(B.goldThrough=="2026-11-03"and not B.goldPicker)
for _,name in ipairs({"Inventory history","Stock / cost basis","Auctions","Trades","Mail"})do click(name);TEST_PREPARE_BOOK();bounds()end
B.SetChapter("Loot");TEST_PREPARE_BOOK();assert((B.left.used.edit or 0)==0 and B.nav.used.edit>0)
for _,label in ipairs({"Craft / gather log","Observed drops","Item receipts"})do click(label);TEST_PREPARE_BOOK();bounds()end
B.SetChapter("Company");click("Companions");assert(B.companyMode=="companions"and B.nav.used.edit==1);click("Pull history");assert(B.companyMode=="pulls"and B.nav.used.edit==1);bounds()
click("Group sessions");bounds();click("Chat");bounds();click("Highlights");bounds()
B.SetChapter("Memories");click("On This Day");assert(B.memoryMode=="rediscover"and B.nav.used.edit==1);bounds()
B.SetChapter("Search");assert(B.left.used.edit==1,"Main search field remains next to its story")
B.searchDraft="draft words";B.Render();click("Record type: Everything");assert(B.left.pool.edit[1]:GetText()=="draft words")
B.SetChapter("Archive");click("Archive size");assert(B.archiveTab=="storage");click("Recording status");assert(B.archiveTab=="capabilities");bounds()
N.open="Archive:1";TEST_NOW(oldNow);B.ChangeCharacter(oldCharacter);TEST_PREPARE_BOOK();assert(N.open==nil,"Changing scrapbook closes the previous owner's menu")
B.SetChapter(oldChapter);E.db.characters[c.id]=nil
print("PASS bookmark navigation: all11 chapters, sidebar callbacks, adaptive bounds, draft preservation, calendar month/year validation, character-only milestones")
