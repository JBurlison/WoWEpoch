local H,S,A,B,V=E.History,E.Store,E.API,E.Book,E.CompanyView
local oldGUID,oldName,oldCount,oldRaid,oldLeader,oldSecret=UnitGUID,UnitFullName,GetNumGroupMembers,IsInRaid,UnitIsGroupLeader,issecretvalue
UnitGUID=function(u)return u=='player'and'leader-owner'or'leader-friend'end
UnitFullName=function(u)return u=='player'and'Aldren'or'Mira','Test realm'end
GetNumGroupMembers=function()return 2 end;IsInRaid=function()return false end
UnitIsGroupLeader=function(u)return u=='party1'end
local roster=A.Roster();assert(roster[1].isLeader==false and roster[2].isLeader==true)
local secret={};issecretvalue=function(v)return v==secret end
UnitIsGroupLeader=function(u)return u=='party1'and secret or false end
assert(A.Roster()[2].isLeader==nil,'unavailable leadership is never false')
local calls={};UnitGUID=function(u)calls[u]=(calls[u]or 0)+1;return u..(calls[u]==1 and'-before'or'-after')end
UnitIsGroupLeader=function()return true end
assert(A.Roster()==nil,'a reused unit token cannot attach a name, realm or leader flag to an older identity')
UnitGUID,UnitFullName,GetNumGroupMembers,IsInRaid,UnitIsGroupLeader,issecretvalue=oldGUID,oldName,oldCount,oldRaid,oldLeader,oldSecret
local c=S.Character('leader-owner',{name='Aldren'});local t=2000020000
local function members(a,b)return{{id=c.id,name='Aldren',realm='Test realm',isLeader=a},{id='leader-friend',name='Mira',realm='Test realm',isLeader=b}}end
local g=H.Group(c,t,members(true,false),'login-1','party-1')
assert(#g.leadership==1 and g.leadership[1].leaderID==c.id)
H.Group(c,t+5,members(true,false),'login-1','party-1');assert(#g.leadership==1 and g.leadership[1].through==t+5)
H.Group(c,t+10,members(false,true),'login-1','party-1')
assert(#g.leadership==2 and g.leadership[2].changeObserved and g.leadership[2].previousLeaderID==c.id and g.leadership[1].closed)
assert(g.leadership[1].through==t+5,'do not extend an old leader to the later handoff observation')
H.Group(c,t+15,members(nil,true),'login-1','party-1');assert(g.leadership[3].state=='unknown'and not g.leadership[3].leaderID)
assert(#g.leadership[3].candidates==1,'retain the reported candidate without claiming a confirmed leader')
H.Group(c,t+20,members(true,true),'login-1','party-1');assert(#g.leadership[4].candidates==2 and not g.leadership[4].leaderID)
H.Group(c,t+25,members(false,false),'login-1','party-1');assert(g.leadership[5].reason:find('No leader',1,true))
H.Group(c,t+30,members(false,true),'login-1','party-1');assert(not g.leadership[6].changeObserved)
H.PauseGroup(c,t+31,'Restricted roster');assert(g.leadership[6].closed)
H.Group(c,t+35,members(false,true),'login-1','party-1');assert(#g.leadership==7 and not g.leadership[7].changeObserved)
H.Group(c,t+40,members(false,true),'login-2','party-1');assert(c.state.group==g.id and #g.leadership==8 and g.leadership[7].closed)
H.Group(c,t+45,{},'login-2','party-1');assert(g.leadership[8].closed and g.ended==t+45)
local other=H.Group(c,t+50,members(true,false),'login-2','party-2');assert(other.id~=g.id and #other.leadership==1)
H.Group(c,t+100,members(true,false),'login-2','party-2');assert(#other.leadership==2 and not other.leadership[2].changeObserved)
H.Group(c,t+90,members(false,true),'login-2','party-2');assert(#other.leadership==3 and not other.leadership[3].changeObserved,'clock reversal cannot imply a timed handoff')
local duplicate=members(true,false);duplicate[2].id=c.id
H.Group(c,t+95,duplicate,'login-2','party-2');assert(other.leadership[4].reason:find('Duplicate',1,true))
-- A pre-existing group receives only newly observed leadership; no historical backfill.
local old=S.Add(c,'group',t-1000,{title='Legacy session',memberships={},observedThrough=t-1000})
assert(old.leadership==nil)
g.starred=true;S.Changed(c,g);assert(S.Protected(c)[g.id])
local function click(page,label)
 for _,kind in ipairs({'companyControl','companyRow','button'})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==label then f:Click();return end end end
 return TEST_UI_CLICK(label)
end
local function content(page)local out={};for i=1,page.used.label or 0 do out[#out+1]=page.pool.label[i]:GetText()end;return table.concat(out,'\n')end
B.ChangeCharacter(c.id);B.SetChapter('Company');B.selected=g.id;B.groupTab='coverage';B.Render();TEST_PREPARE_BOOK()
assert(content(B.right):find('Leadership page 1 of 2',1,true)and content(B.right):find('Leader unavailable',1,true))
click(B.right,'More leadership observations');assert(B.groupLeaderPage==2)
local allocated=#B.right.pool.label
B.ChangeCharacter(S.Character('leader-other',{name='Other'}).id);B.ChangeCharacter(c.id)
assert(B.groupLeaderPage==2,'restore leadership pagination for each character')
click(B.right,'Earlier leadership observations')
click(B.right,'Leader change observed: Mira - Test realm');assert(B.companionID=='leader-friend')
B.selected=old.id;B.companyMode='sessions';B.Render();assert(content(B.right):find('Leadership was not recorded',1,true))
-- Long observation histories paginate without creating one widget per interval.
for i=1,2000 do g.leadership[#g.leadership+1]={from=t+i,through=t+i,leaderID=c.id,name='Aldren',realm='Test realm',state='observed',candidates={}}end
S.Changed(c,g);B.selected=g.id;B.groupTab='coverage';B.Render()
for page=1,20 do B.groupLeaderPage=page;B.Render();assert(#B.right.pool.label<=allocated+4)end
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(unpack(size));B.Fit();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)end
UIParent:SetSize(1920,1080);B.Fit()
print('PASS leadership: guarded roster flags/identity, changes, ambiguity, gaps, reload/leave, clock reversal, legacy data, protection, companion links and bounded character-specific pagination')
