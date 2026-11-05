local B,V,S,H,A=E.Book,E.QuestView,E.Store,E.History,E.API
local c=S.Character("quest-undated-reader",{name="Quest observer"});local t=A.Now()-500
local function attempt(id,name,intervals)return S.Add(c,"quest_attempt",t,{questID=id,title=name,intervals=intervals,status="completed",accepted=t})end
local a=attempt(990004,"Recorded Westfall attempt",{{from=t,through=t+5}})
local b=attempt(990002,"Overlapping attempt",{})
local k1=H.Kill(c,t+2,{npcID=601,name="First",title="Known-date kill"},"k1")
local k2=H.Kill(c,t+3,{npcID=602,title="Unclocked kill"},"k2")
local k3=H.Kill(c,t+4,{npcID=603,title="Sequence window end"},"k3")
local k4=H.Kill(c,t+10,{npcID=604,title="Outside both"},"k4")
k2.ts=nil;S.Changed(c,k2)
H.Credit(c,t+4,k2.id,a.id,1,1,"authored explicit fixture","a1")
H.Credit(c,t+4,k2.id,a.id,2,3,"authored explicit fixture","a2")
b.intervals={{fromSequence=k1.sequence,throughSequence=k3.sequence}};b.endedSequence=k3.sequence;S.Changed(c,b)
S.Add(c,"quest",t+20,{questID=990004,title=a.title,status="completed",attempt=a.id})
S.Add(c,"quest",t+21,{questID=990002,title=b.title,status="completed",attempt=b.id})
E.runtime={build=70532,interface=16001};E.QuestCatalog.cached=nil
for i=1,10000 do if B.HistoryReadiness(c)=="ready"then break end;E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()end
B.Open();B.ChangeCharacter(c.id);B.questZone="all";B.questFilter="all";B.SetChapter("Quests");V.Select(990004)
local function click(label)
 for _,kind in ipairs({"questControl","questRow","button"})do for i=1,B.right.used[kind] or 0 do local f=B.right.pool[kind][i];if f.text:GetText()==label then f:Click();return end end end
 error("missing "..label)
end
local function check(rows,...)
 local want={};for i=1,select("#",...)do want[select(i,...)]=true end
 for _,r in ipairs(rows)do assert(want[r],"unexpected "..r.id);want[r]=nil end
 assert(not next(want),"expected record missing")
end
click("Confirmed objective credit");check(V.lastKills.records,k2)
click("+ Inspect linked kill records (1)")
local sourceVisible=false
for i=1,B.right.used.questRow or 0 do local w=B.right.pool.questRow[i];if w.text:GetText()==k2.title then sourceVisible=true end end
assert(sourceVisible);click("While active");check(V.lastKills.records,k1,k3)
V.Select(990002);click("While active");check(V.lastKills.records,k1,k2)
click("Confirmed objective credit");check(V.lastKills.records)
check(V.KillReport(c,{a,b},"active").records,k1,k2,k3)
check(H.QuestKills(c,a.id,"active"),k1,k3);check(H.QuestKills(c,b.id,"active"),k1,k2)
assert(not S.InQuestInterval(k2,S.QuestInterval(a,a.intervals[1])) and S.InQuestInterval(k2,S.QuestInterval(b,b.intervals[1])))
print("PASS actual quest cards, explicit duplicate objective links, dated activity, sequence-only membership, exclusive end, overlap and canonical source details")


local report=V.KillReport(c,{a,b},"active");local byGroup={}
for _,bucket in ipairs(report.groups)do assert(bucket.count==#bucket.records);for _,r in ipairs(bucket.records)do assert(c.records[r.id]==r and not byGroup[r]);byGroup[r]=true end end
assert(byGroup[k1] and byGroup[k2] and byGroup[k3])
local hits=E.Query.Kind(c,"credit");local n=#hits;local hit=hits[n]
hits[n-1].character="forged";hit.character="forged";S.Changed(c,hit)
check(V.KillReport(c,{a},"credit").records);check((H.QuestKills(c,a.id,"credit")))
hit.character=c.id;S.Changed(c,hit)
local original=k2.character;k2.character="foreign";S.Changed(c,k2)
check(V.KillReport(c,{a},"credit").records);check(V.KillReport(c,{b},"active").records,k1)
assert(not pcall(H.Credit,c,t,k2.id,a.id,1,1,"invalid foreign source","should-refuse"))
k2.character=original;S.Changed(c,k2);check(V.KillReport(c,{a},"credit").records,k2)
local stale=E.Copy(a);check(V.KillReport(c,{stale},"credit").records)
local previousID=a.id;local fake=E.Copy(a);fake.id="bad-key";c.records[previousID]=fake
check(V.KillReport(c,{a,fake},"credit").records);assert(not pcall(H.Credit,c,t,k2.id,previousID,1,1,"invalid attempt alias","must-refuse"))
c.records[previousID]=a
a.intervals={{from=t},{through=t+5},{from=t,through="x"},{from="x",through=t},{from=t,through=t+5,throughSequence=0/0},false}
a.ended="missing";S.Changed(c,a)
check(V.KillReport(c,{a},"active").records);check(V.KillReport(c,{a},"credit").records,k2);check((H.QuestKills(c,a.id,"active")))
a.starred=true;S.Changed(c,a);local protected=S.Protected(c);assert(protected[k2.id] and not protected[k4.id])
local malformed=S.Add(c,'kill',t+20,{title="No sequence",npcID=605,observationSequence="not numeric"});malformed.ts=nil;S.Changed(c,malformed)
local unknown=S.QuestInterval(b,b.intervals[1]);assert(not S.InQuestInterval(malformed,unknown))
assert(not S.InQuestInterval(k1,nil) and not S.InQuestInterval(k2,{axis="timestamp"}))
assert(S.QuestSequence({id=c.id..":old",character=c.id})==nil and S.QuestSequence({id=c.id..":37",character=c.id})==37)
assert(S.QuestSequence({id="other:37",character=c.id})==nil)
-- A new local observation cannot fill in an old missing clock endpoint.
local fresh=H.BeginQuest(c,12345,"Returned quest",t+30,true);local old=fresh.intervals[1];old.through=nil
H.QuestObserved(c,fresh,t+31);assert(old.closed and old.through==nil and #fresh.intervals==2 and fresh.intervals[2].from==t+31)
fresh.intervals[2].through=nil;H.EndQuest(c,12345,t+32,"abandoned");assert(fresh.intervals[2].through==nil and fresh.ended==t+32)
print("PASS canonical source groups, foreign kill/credit/attempt refusal, malformed bounds, direct retention and honest continuation")


B.selected=a.id;B.Render(true)
local found=false
for i=1,B.right.used.questDetailField or 0 do local w=B.right.pool.questDetailField[i];if w.label:GetText()=="End observed" and w.value:GetText()=="Event date unknown" then found=true end end
assert(found,"Malformed occurrence end date should display as unknown in actual detail")

