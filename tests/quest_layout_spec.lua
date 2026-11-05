local B,V,S,A,K=E.Book,E.QuestView,E.Store,E.API,E.QuestCatalog
local c=E.db.characters["myepoch-ui-fixture-027"]
local savedRuntime=E.runtime; E.runtime={build=70532,interface=16001}; K.cached=nil
-- Complete the fixture's two observed attempts so their kills belong to completed stories.
for _,attempt in ipairs(E.QuestAtlas.History(c)[990004].attempts)do
 attempt.status="completed"
 S.Add(c,"quest",attempt.ended or attempt.ts+40,{questID=990004,title=attempt.title,status="completed",attempt=attempt.id,mapID=52,zone="Westfall"})
end
c.state.activeQuests[990004]=nil
B.ChangeCharacter(c.id); B.questZone="recorded"; B.questFilter="all"; B.SetChapter("Quests")
local function eq(a,b,msg)assert(a==b,(msg or "").." expected "..tostring(b)..", got "..tostring(a))end
local function click(page,text)
 for _,kind in ipairs({"questControl","questRow","button"})do for i=1,page.used[kind] or 0 do local f=page.pool[kind][i]
  if f.text:GetText()==text then f:Click();return end
 end end
 return TEST_UI_CLICK(text,prefix)
end
eq(#V.lastReport.rows,3); eq(B.left.used.questStat or 0,0); eq(B.left.used.questRow,3)
B.left.scroll:SetVerticalScroll(45); V.Select(990004)
eq(B.left.scroll:GetVerticalScroll(),45,"opening details keeps the quest list's scroll position")
eq(B.right.scroll:GetVerticalScroll(),0)
eq(#V.lastKills.records,2,"two objectives credited by one kill must not double-count it")
eq(#V.lastKills.groups,2)
click(B.right,"While active"); eq(#V.lastKills.records,5); eq(#V.lastKills.groups,4)
local history=E.QuestAtlas.History(c)[990004]
local duplicate=E.Copy(history.attempts[2]); duplicate.id="duplicate-window"
local overlapping={history.attempts[1],history.attempts[2],duplicate}
eq(#V.KillReport(c,overlapping,"active").records,5,"overlapping attempts count shared kills once")
local bandanas=E.QuestAtlas.History(c)[990002]
eq(#V.KillReport(c,bandanas.attempts,"active").records,3,"another quest shares three kills")
eq(#V.KillReport(c,history.attempts,"active").records,5,"the observation gap stays excluded")
local q=history.attempts[2]; eq(#V.KillReport(c,{q},"active").records,3,"an individual attempt stays separate")
local boundary=S.Add(c,"kill",q.intervals[1].through,{title="Boundary",npcID=1,zone="Westfall"})
eq(#V.KillReport(c,{q},"active").records,4,"observed upper bound is inclusive while active")
local endTime=q.ended; q.ended=boundary.ts; eq(#V.KillReport(c,{q},"active").records,3,"ended attempt upper bound is exclusive"); q.ended=endTime
c.records[boundary.id]=nil; for i,id in ipairs(c.order)do if id==boundary.id then table.remove(c.order,i);break end end; S.Touch(c)
click(B.right,"Confirmed objective credit"); local creditKill=V.lastKills.records[1]; c.records[creditKill.id]=nil
local missing=V.KillReport(c,history.attempts,"credit"); eq(#missing.records,1); eq(missing.missing,1)
c.records[creditKill.id]=creditKill; S.Touch(c)
B.Render(); click(B.right,"+ Inspect linked kill records (2)")
local note=c.notes["quest:990004"].text
click(B.right,creditKill.title); eq(B.selected,creditKill.id)
click(B.right,"Back to quest overview"); eq(B.questAtlasID,990004); eq(c.notes["quest:990004"].text,note)
assert(not V.lastReport.all[990005] and not V.lastReport.all[990006])
click(B.left,"Find a completed quest"); assert(B.questTools)
local input=B.nav.pool.edit[1]; input:SetText("no such quest"); input.scripts.OnEnterPressed(input)
eq(#V.lastReport.rows,0); eq(B.left.used.questStat or 0,0); eq(B.questAtlasID,nil)
input=B.nav.pool.edit[1]; input:SetText(""); input.scripts.OnEnterPressed(input)
-- Many creatures stay bounded; rows with long names expand without overlap.
for i=1,30 do S.Add(c,"kill",q.ts+1,{title=string.rep("Long creature name ",12)..i,npcID=800000+i,zone=string.rep("Long location ",15)})end
V.Select(990004); click(B.right,"While active")
eq(B.right.used.questCreature,9,"one header plus eight creature rows")
local wrapped=false; for i=2,B.right.used.questCreature do if B.right.pool.questCreature[i]:GetHeight()>46 then wrapped=true end end
assert(wrapped,"long creature names and locations expand their rows")
local allocated=#B.right.pool.questCreature
for i=1,8 do B.questKillPage=i; B.Render()end
eq(#B.right.pool.questCreature,allocated)
local other=S.Character("quest-layout-isolation",{name="Another character"})
B.ChangeCharacter(other.id); B.SetChapter("Quests"); assert(not B.questTools and not B.questKillSources)
eq(#V.KillReport(other,history.attempts,"active").records,0)
B.ChangeCharacter(c.id); assert(B.questTools)
eq(B.frame:GetWidth(),1760); eq(B.frame:GetHeight(),940)
K.Remove("myepoch-layout-027"); E.runtime=savedRuntime; K.cached=nil
print("PASS Quest layout: nonzero scope totals, filters/search, source return, notes, distinct shared kills, credited objectives, interval gaps/endpoints, expired links, bounded rows, long labels and character isolation")
