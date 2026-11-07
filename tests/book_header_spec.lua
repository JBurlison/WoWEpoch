local B=E.Book
B.Open();TEST_PREPARE_BOOK()
local character=B.Character();local chapter=B.chapter
assert(B.heading:GetText()=="",'the header must not repeat character/chapter')
assert(B.heading.point[1]=='TOPLEFT'and B.heading.point[2]==680 and B.heading.point[3]==-106)
assert(B.characterButton.text:GetText()==E.Text(character.identity.name or character.id),'the selected name must not contain the old next-character arrow')
assert(B.characterButton.text.point[1]=='CENTER'and B.characterButton.text.point[2]==-16 and B.characterButton.text.point[3]==0)
assert(B.characterButton.text:GetWidth()==218 and B.characterButton.text.maxLines==1)
assert(not B.characterButton.face:IsShown()and B.characterButton.dropdownBorder and B.characterButton.dropdownFill and #B.characterButton.arrow==3,'the character dropdown must have its own inset background and down marker')
local previousRight=0
for _,row in ipairs({{B.illustrations,680},{B.memoryButton,808},{B.captureButton,986}})do
 local f,x=row[1],row[2];assert(f.parent==B.frame and f.point[1]=='TOPLEFT'and f.point[2]==x and f.point[3]==-73)
 assert(x>previousRight and x+f:GetWidth()<1434,'header controls overlap each other or the character picker');previousRight=x+f:GetWidth()
end
local focusButton=B.controllerButton
assert(focusButton.parent==B.frame and focusButton.point[1]=='TOPLEFT'and focusButton.point[2]==1180 and focusButton.point[3]==-69)
assert(focusButton:GetWidth()==38 and focusButton:GetHeight()==38 and not focusButton.text and focusButton.icon and #focusButton.fallback==8,
 'controller focus must use a compact glyph with an atlas-independent fallback')
assert(focusButton.point[2]>previousRight and focusButton.point[2]+focusButton:GetWidth()<1434)
for _,page in ipairs({B.left,B.right})do
 assert(page.panel.point[3]==-152 and page.panel:GetHeight()==756,'the removed strip must become page content')
 assert(page.scroll:GetHeight()==732 and page.panel.paper and page.panel.paper.texCoords[3]==211/940)
end
E.Controller.UpdateLegend()
local legend=E.Controller.legend;local legendTop=-legend.point[5]
assert(legend.parent==B.frame and legend.point[1]=='TOPLEFT'and legend.point[2]==B.frame and legend.point[3]=='TOPLEFT',
 'controller prompts must belong to the book header')
assert(legendTop>=40 and legendTop+legend:GetHeight()<=-B.characterButton.point[3]-4,
 'header prompts must clear the title and end above header actions and character metadata')
assert(legendTop+legend:GetHeight()<=-B.left.panel.point[3]-4,
 'header prompts must finish above the parchment pages')
assert(legend.point[4]>=B.left.panel.point[2] and legend.point[4]+legend:GetWidth()<=B.right.panel.point[2]+B.right.panel:GetWidth(),
 'header prompts must fit between the page edges without entering the sidebar')
assert(B.Width(B.left)==684 and B.Width(B.right)==684 and B.Width(B.nav)==196)
assert(B.nav.panel:GetWidth()==232 and B.nav.panel:GetHeight()==778)
assert(B.nav.panel.point[2]+B.nav.panel:GetWidth()==236 and B.left.panel.point[2]==262 and B.right.panel.point[2]==994,
 'reclaiming the left margin must preserve the rail edge and both page positions')
assert(not B.folioPages and not B.folioCharacter and not B.folioQuote,'the removed folio must not consume page room')
for _,name in ipairs(B.Navigation.chapters)do assert(B.tabs[name].parent==B.nav.content and B.tabs[name].isChapter)end
assert(B.frame.movable and B.frame.clamped and B.dragBar.dragButtons[1]=='LeftButton')
B.inCombat=false;B.dragBar.scripts.OnDragStart();assert(B.frame.moving)
B.dragBar.scripts.OnDragStop();assert(not B.frame.moving)
B.inCombat=true;B.dragBar.scripts.OnDragStart();assert(not B.frame.moving)
B.inCombat=false;B.dragBar.scripts.OnDragStart();B.frame.scripts.OnHide();assert(not B.frame.moving)
local calls={};local art,memory,capture,picker,focus=E.ArtDialog.OpenForPage,E.MemoryView.Create,MyEpoch_Capture,E.CharacterView.Toggle,E.Controller.ToggleFocus
E.ArtDialog.OpenForPage=function()calls.art=true end;E.MemoryView.Create=function()calls.memory=true end
MyEpoch_Capture=function()calls.capture=true end;E.CharacterView.Toggle=function()calls.picker=true end;E.Controller.ToggleFocus=function()calls.focus=true end
B.illustrations:Click();B.memoryButton:Click();B.captureButton:Click();B.characterButton:Click();B.controllerButton:Click()
E.ArtDialog.OpenForPage=art;E.MemoryView.Create=memory;MyEpoch_Capture=capture;E.CharacterView.Toggle=picker;E.Controller.ToggleFocus=focus
assert(calls.art and calls.memory and calls.capture and calls.picker and calls.focus and B.chapter==chapter,'header controls must retain their actions')
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do
 UIParent:SetSize(size[1],size[2]);B.Fit()
 assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
 assert(B.frame:GetWidth()*B.frame:GetScale()<=size[1]*.95+0.001 and B.frame:GetHeight()*B.frame:GetScale()<=size[2]*.93+0.001)
end
UIParent:SetSize(1920,1080);B.Fit()
print('PASS book header: no duplicate strip, expanded pages, separate centered dropdown, header actions and1080p/1440p/4K fit')
