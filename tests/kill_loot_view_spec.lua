local B,S,V,L,K=E.Book,E.Store,E.KillLootView,E.KillLoot,E.Keepsakes
local c=S.Character('kill-loot-ui',{name='Observer'});local ts=E.API.Now()-200
local raw=S.Add(c,'kill_observation',ts,{title='Party kill notification',session='one'})
local kill=S.Add(c,'kill',ts,{title='Hogger',npcName='Hogger',source='PARTY_KILL',session='one',mapID=1429,groupState='solo',npcID=448,victimGUID='Creature-0-1-2-3-448-001',notification=raw.id})
raw.canonical=kill.id;raw.victimGUID=kill.victimGUID
local window=S.Add(c,'loot_window',ts+10,{title='Loot window',session='one',mapID=1429,groupState='solo',fromItem=false,fishing=false,originEvidence=1})
local drops={}
for slot,item in ipairs({{2589,'Linen Cloth',3},{1931,'Huge Gnoll Claw',1}})do
 local d=S.Add(c,'drop',ts+11,{title=item[2],source='loot_window',session='one',window=window.id,slot=slot,itemID=item[1],itemLink='item:'..item[1],snapshots={}})
 local data={itemID=item[1],name=item[2],visibleQuantity=item[3]}
 d.snapshots={{ts=ts+11,sequence=S.ReserveObservation(c),data=data}};d.latest=data;drops[#drops+1]=d
end
local receipt=S.Add(c,'loot',ts+12,{title='Linen Cloth',itemID=2589,itemLink='item:2589',quantity=3,recipient=c.id,observedLootWindow=window.id,session='one'})
local function ready()
 L.Get(c);local n=0
 repeat K.Process(100);n=n+1;assert(n<1000,'linking job should finish')until L.Get(c)
 return L.Get(c)
end
local report=ready();assert(report.byKill[kill.id]and #report.byKill[kill.id].items==2)
B.ChangeCharacter(c.id);B.chapter='Quests';B.selected=kill.id;TEST_PREPARE_BOOK();ready()
local function render(r)B.selected=r.id;B.Clear(B.right);V.Record(B.right,c,r)end
local function text()
 local value='';for i=1,B.right.used.label or 0 do value=value..B.right.pool.label[i]:GetText()..'\n'end;return value
end
render(kill);assert(B.right.used.killLootRow==2,'one encounter has both item rows')
assert(B.right.pool.killLootRow[1].itemIcon:IsShown()and B.right.pool.killLootRow[1].open:IsShown())
assert(text():find(E.L['Approximate match · nearby kill and loot.'],1,true))
assert(not kill.refs,'derived loot never changes objective-credit or source facts')
for _,r in ipairs({raw,window,drops[1],receipt})do
 render(r);assert((B.right.used.killLootRow or 0)>0,'all kill/loot entry points share the links: '..r.kind)
end
render(kill);local openRow=B.right.pool.killLootRow[1].open.scripts.OnClick
local originalOpen=E.SearchView.Open;local opened
E.SearchView.Open=function(hit)opened=hit.record end;openRow();assert(opened==drops[1].id or opened==drops[2].id)
local other=S.Character('kill-loot-ui-other',{name='Other'});B.ChangeCharacter(other.id);opened=nil;openRow();assert(not opened,'stale callbacks cannot cross characters')
E.SearchView.Open=originalOpen;B.ChangeCharacter(c.id);B.selected=kill.id
-- Rebuilding an equivalent association must not disable a still-visible details control.
render(kill)
local details
for i=1,B.right.used.button or 0 do
 local action=B.right.pool.button[i]
 if action.text:GetText():find(E.L['Loot encounter details'],1,true)then details=action.scripts.OnClick end
end
assert(details,'details control exists')
local savedRender=B.Render;B.Render=function()end
S.Changed(c,window);ready()
details();assert(B.killLootDetails,'details opens after an equivalent background rebuild')
B.Render=savedRender
-- All shared detail renderers reach the same loot view, irrespective of entry chapter.
local originalRecord=V.Record;local called=0
V.Record=function(page,owner,r)if r==kill and owner==c then called=called+1 end;return originalRecord(page,owner,r)end
for _,chapter in ipairs({'Quests','Company','Calendar','Journey','Search'})do
 B.chapter=chapter;B.Clear(B.right);B.Record(B.right,kill);assert(called>0,chapter..' shares kill details')
end
V.Record=originalRecord
-- A late initial result must not rebuild an editor with focus.
S.Changed(c,window);B.Clear(B.right);V.Record(B.right,c,kill)
local edit=B.Acquire(B.right,'edit');edit:SetFocus()
local renders=0;local originalRender=B.Render;B.Render=function()renders=renders+1 end
ready();assert(renders==0,'ready event preserves typing');edit:ClearFocus();B.Render=originalRender
print('PASS kill loot view: grouped icon rows, reverse links, all chapter entry points, character isolation and focused-note stability')
