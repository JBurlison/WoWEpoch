local B,N,S,Q,D=E.Book,E.Book.Navigation,E.Store,E.Query,E.Diary
local prior={owner=B.character,chapter=B.chapter,tooltip=GameTooltip,warm=Q.IsWarm,pending=E.Gathering.Pending}
local c=S.Character('recap-badge-fixture',{name='Badge reader'})
local other=S.Character('recap-badge-empty',{name='No unread recaps'})
local first=S.Add(c,'recap',100,{title='First recap',read=false,periodKind='milestone'})
local second=S.Add(c,'recap',200,{title='Second recap',read=false,periodKind='milestone'})
local function update()Q.Kind(B.Character(),'recap');B.UpdateBadges();return B.tabs.Recaps end
B.ChangeCharacter(c.id);B.SetChapter('Chronicle');local tab=update()
assert(tab.text:GetText()=='Recaps'and tab.recapBadgeCount==2 and tab.recapBadge.text:GetText()=='2'and tab.recapBadge:IsShown())
assert(tab.recapBadgeHint=='2 unread recaps','count is explained independently of its color')
local orderedKind = Q.Kind
Q.Kind = function() error('The unread badge should not request a sorted history') end
B.UpdateBadges()
assert(tab.recapBadgeCount == 2)
Q.Kind = orderedKind
assert(tab.text:GetWidth()+tab.recapBadge:GetWidth()+48<=tab:GetWidth(),'badge reserves separate label space')
local shown,hidden,text=0,0,nil
GameTooltip={SetOwner=function()end,SetText=function(_,value)text=value end,Show=function()shown=shown+1 end,Hide=function()hidden=hidden+1 end}
tab.scripts.OnEnter(tab);assert(shown==1 and text=='2 unread recaps');tab.scripts.OnLeave(tab);assert(hidden==1)
D.MarkRead(c,first);tab=update();assert(tab.recapBadgeCount==1 and tab.recapBadgeHint=='1 unread recap')
tab.scripts.OnEnter(tab);Q.IsWarm=function()return false end;B.UpdateBadges()
assert(not tab.recapBadge:IsShown()and not tab.recapBadgeCount and B.badgesWaiting==c and hidden==2,'pending indexes hide stale count and tooltip')
Q.IsWarm=prior.warm;tab=update();assert(tab.recapBadgeCount==1)
E.Gathering.Pending=function()return true end;B.UpdateBadges();assert(not tab.recapBadge:IsShown()and B.badgesWaiting==c)
E.Gathering.Pending=prior.pending;tab=update()
D.MarkRead(c,second);tab=update();assert(not tab.recapBadge:IsShown()and tab.recapBadgeCount==nil and not tab.scripts.OnEnter,'zero is omitted')
first.read=false;second.read=false;S.Touch(c);tab=update();assert(tab.recapBadgeCount==2)
local index;for i,f in ipairs(B.nav.pool.button)do if f==tab then index=i;break end end
assert(index);B.nav.used.button=index-1;local reused=N.Button(B.nav,'A recycled filter',function()end,false)
assert(reused==tab and not reused.recapBadge:IsShown()and not reused.recapBadgeCount and not reused.scripts.OnEnter and not reused.scripts.OnLeave,'chapter badge cannot leak into a recycled submenu')
B.Render();tab=update();assert(tab.recapBadgeCount==2,'chapter redraw reconstructs current badge')
N.RecapBadge(tab,12345);assert(tab.recapBadge.text:GetText()=='12,345'and tab.recapBadgeHint=='12,345 unread recaps','large count is not abbreviated or lost')
assert(tab.text:GetWidth()+tab.recapBadge:GetWidth()+48<=tab:GetWidth())
B.ChangeCharacter(other.id);tab=update();assert(not tab.recapBadgeCount and(not tab.recapBadge or not tab.recapBadge:IsShown()),'owner switch never keeps old count')
B.ChangeCharacter(c.id);tab=update();assert(tab.recapBadgeCount==2)
GameTooltip=nil;tab.scripts.OnEnter(tab);GameTooltip=prior.tooltip
B.ChangeCharacter(prior.owner);B.SetChapter(prior.chapter)
print('PASS recap badge: colored separate count, singular/plural explanation, zero and pending hide, read updates, larger counts, tooltip cleanup, recycled submenu and character isolation')
