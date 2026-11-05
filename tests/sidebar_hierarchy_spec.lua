local B,N,S=E.Book,E.Book.Navigation,E.Store
local old=B.character
local c=S.Character('sidebar-tree-fixture',{name='Tree fixture'})
c.state.lastLocation={mapID=52,zone='Westfall'}
B.ChangeCharacter(c.id);B.Open();B.SetChapter('Gold');TEST_PREPARE_BOOK()
local function find(label)
 for i=1,B.nav.used.button or 0 do local f=B.nav.pool.button[i];if f.text:GetText()==label then return f end end
end
local function x(f)return f.point[4]end
local function y(f)return -f.point[5]end
local function branch(label)
 local f=assert(find(label),label);assert(f.navExpandable,label..' should disclose children');return f
end
local function bounds()
 for kind,pool in pairs(B.nav.pool)do for i=1,B.nav.used[kind]or 0 do local f=pool[i]
  if f.point and f.point[2]==B.nav.content then assert(x(f)+f:GetWidth()<=B.Width(B.nav)+12.1,'Indented content exceeds sidebar: '..kind)end
 end end
end
B.goldSection='wallet';B.goldDates=false;B.goldMorePeriods=false;B.goldPreset='last30';B.Render()
local wallet=branch('Wallet / trading');local dates=branch('Custom dates')
assert(x(wallet)>x(B.tabs.Gold)and x(dates)>x(wallet),'Chapter > view > filters staircase')
assert(y(dates)<y(find('Inventory history')),'Wallet controls must precede its next sibling view')
dates:Click();local input=B.nav.pool.edit[1]
assert(x(input)>x(branch('Custom dates'))and y(input)>y(branch('Custom dates'))and y(input)<y(branch('More periods')),'Date inputs belong directly under their own branch')
input:SetText('2026-09-17');branch('Custom dates'):Click()
assert((B.nav.used.edit or 0)==0 and not branch('Custom dates').navExpanded)
branch('Custom dates'):Click();assert(B.nav.pool.edit[1]:GetText()=='2026-09-17','Closing a branch must retain its unapplied draft')
branch('Wallet / trading'):Click();assert(not find('Custom dates')and B.goldSection=='wallet','Collapsing a view does not switch the page')
branch('Wallet / trading'):Click();assert(B.nav.pool.edit[1]:GetText()=='2026-09-17','Collapsing parent retains descendants draft')
branch('More periods'):Click();local extra=assert(find('Yesterday'))
assert(x(extra)>x(branch('More periods'))and y(extra)>y(branch('More periods'))and y(extra)<y(find('Inventory history')),'Additional periods must follow their parent')
bounds()
B.SetChapter('Quests');TEST_PREPARE_BOOK();B.questTools=false;B.questZoneChooser=false;B.Render()
branch('Find / refresh'):Click();input=B.nav.pool.edit[1]
assert(x(input)>x(branch('Find / refresh'))and y(input)>y(branch('Find / refresh'))and y(input)<y(find('All known')),'Quest search is attached to Find / refresh, before state filters')
input:SetText('unsubmitted quest');branch('Find / refresh'):Click();assert((B.nav.used.edit or 0)==0)
branch('Find / refresh'):Click();assert(B.nav.pool.edit[1]:GetText()=='unsubmitted quest')
branch('All known'):Click();local active=assert(find('Active'))
assert(x(active)>x(branch('All known'))and y(active)>y(branch('All known')),'Choice rows indent below the selected-value heading')
bounds()
B.SetChapter('Company');B.companyMode='companions';B.Render();TEST_PREPARE_BOOK()
assert(y(B.nav.pool.edit[1])>y(branch('Companions'))and y(B.nav.pool.edit[1])<y(find('Pull history')),'Companion search appears inside Companions before Pull history')
bounds()
B.ChangeCharacter(old);TEST_PREPARE_BOOK();assert(next(N.collapsed)==nil,'Expansion state cannot leak to another scrapbook')
E.db.characters[c.id]=nil
print('PASS sidebar hierarchy: nested indentation, owning-view order, branch collapse/expand, hidden drafts, bounded widths, quest search/state, companion search and character isolation')
