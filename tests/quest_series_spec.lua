local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local S,Q,H,B,K=E.Store,E.Query,E.History,E.Book,E.QuestCatalog
local T=E.QuestAtlas
local priorCharacter,priorRuntime=E.current,E.runtime
E.runtime={build=70532,interface=16001}
local steps={65,132,135,141,142,155,166}
local function character(id)
    local c=S.Character("series-test-"..id,{name=id})
    E.current=c
    return c
end
local function turn(c,id,ts)
    return H.CompleteQuest(c,id,ts,{},"series-test","Quest "..id,{zone="Westfall",mapID=1436})
end
local c=character("reader")
local ids={}
for i,id in ipairs(steps) do
    ids[i]=turn(c,id,1800000000-i).id
    if i<#steps then assert(#Q.Major(c)==0) end
end
local milestone=assert(Q.Major(c)[1])
assert(milestone.title=="The Defias Brotherhood completed" and milestone.subject==c.id)
assert(milestone.milestoneType=="quest_chain" and E.Same(milestone.refs,ids) and E.Same(milestone.seriesSteps,steps))
assert(milestone.ts==c.records[ids[7]].ts and milestone.mapID==1436)
turn(c,166,1800000100)
assert(#Q.Major(c)==1 and not pcall(E.Diary.MilestoneWindow,c,milestone))
B.ChangeCharacter(c.id);B.SetChapter("Chronicle");B.selected=milestone.id;B.Render()
local navigated=false
for i=1,B.right.used.button do
    local button=B.right.pool.button[i]
    if button.text:GetText()=="Open the series in Quests" then button:Click();navigated=true;break end
end
assert(navigated and B.chapter=="Quests" and B.questAtlasID==166)
assert(B.questZone=="series:166" and #E.QuestView.lastReport.rows==7)
for i,row in ipairs(E.QuestView.lastReport.rows) do assert(row.questID==steps[i]) end
local labels={}
for i=1,B.right.used.label do labels[#labels+1]=B.right.pool.label[i]:GetText() end
assert(table.concat(labels," "):find("7 of 7 steps known complete",1,true))
local reader=S.Character("series-test-bookmark",{name="Bookmark"})
reader.state.historicalCompleted={[65]=true,[135]=true}
reader.state.questAtlas={facts={[141]={completed=false}}}
B.ChangeCharacter(reader.id);E.QuestView.BrowseSeries(166)
local function bookmarkField()
    for i=1,B.right.used.questDetailField or 0 do
        local f=B.right.pool.questDetailField[i]
        if f.label:GetText()=="First step without known completion" then return f.value:GetText() end
    end
end
local function jump(number)
    for i=1,B.right.used.button or 0 do
        local b=B.right.pool.button[i]
        if b.text:GetText()=="Open step "..number then return b end
    end
end
assert(bookmarkField():find("2.",1,true)==1 and bookmarkField():find("Completion unverified",1,true))
B.questRelationsPage=3;B.questKillSources=true
assert(jump(2)):Click()
assert(B.Character()==reader and B.questAtlasID==132 and B.questZone=="series:166" and B.questRelationsPage==1 and not B.questKillSources)
assert(not jump(2),"The selected earliest step does not link to itself")
reader.state.historicalCompleted[132]=true
B.Render()
assert(bookmarkField():find("4.",1,true)==1 and bookmarkField():find("incomplete",1,true))
for _,id in ipairs(steps) do reader.state.historicalCompleted[id]=true end
B.Render();assert(not bookmarkField(),"A completed series has no unfinished-step bookmark")
-- In Foul Magics the level requirement rises from 30 to 35 between
-- steps. A saved level-31 character can have completed the first step
-- while the next one's eligibility and completion evidence differ.
local low=S.Character("series-test-arathi",{name="Arathi reader",faction="Horde",level=31})
assert(low~=E.current)
H.CompleteQuest(low,671,1800000150,{},"previous-login","Foul Magics (1/2)")
low.state.questAtlas={facts={[673]={onQuest=false,flagObservedAt=1800000160,observationSequence=low.seq,session="previous-login"}}}
B.ChangeCharacter(low.id);E.QuestView.BrowseSeries(671)
local unknownText=assert(bookmarkField())
assert(unknownText:find("Completion unverified",1,true) and unknownText:find("Requirements not met",1,true))
low.state.questAtlas.facts[673].completed=false
S.Touch(low,"questAtlas");B.Render()
local incompleteText=assert(bookmarkField())
assert(incompleteText:find("Recorded as incomplete",1,true) and incompleteText:find("Requirements not met",1,true))
local other=character("flags")
other.state.historicalCompleted={}
for _,id in ipairs(steps) do other.state.historicalCompleted[id]=true end
turn(other,166,1800000200)
assert(#Q.Major(other)==0,"Undated flags cannot fabricate a series milestone")
local scrambled=character("out-of-order")
for _,id in ipairs({132,65,135,141,142,155,166}) do turn(scrambled,id,1800000300) end
assert(#Q.Major(scrambled)==0)
local missing=character("expired")
local removed
for i=1,6 do local r=turn(missing,steps[i],1800000400);if i==3 then removed=r.id end end
missing.records[removed]=nil;E.Emit("RECORDS_REMOVED",missing)
turn(missing,166,1800000401)
assert(#Q.Major(missing)==0,"Previously recorded but expired evidence cannot establish the order")
local conflict=character("conflicting")
for i=1,6 do turn(conflict,steps[i],1800000500) end
assert(K.Register({schema=1,id="conflicting-series",name="Conflicting series fixture",version="1",client="forever",
    interface=16001,minBuild=70532,maxBuild=70532,coverage="partial",source="host fixture",license="test",
    quests={{questID=135,requiresAll={999}}}}))
turn(conflict,166,1800000501)
assert(#Q.Major(conflict)==0)
assert(K.Remove("conflicting-series"))
local old=S.Character("series-test-before-update",{name="Old journal"})
for i=1,280 do S.Add(old,"chat",1800000600,{text="Previously retained chat"}) end
for i,id in ipairs(steps) do turn(old,id,1800000700+i) end
turn(old,166,1800000800)
B.frame:Show();B.ChangeCharacter(old.id)
assert(E.current~=old,"Backfill uses only the selected scrapbook's saved records")
T.ProcessSeries(old);T.ProcessSeries(old)
assert(#Q.Major(old)==0,"Older history is replayed in bounded slices")
T.ProcessSeries(old)
local recovered=assert(Q.Major(old)[1])
assert(recovered.ts==1800000707 and #recovered.refs==7,"Use the earliest qualifying finale's original time")
old.records[recovered.id]=nil;old.dedup[recovered.dedup]=nil;E.Emit("RECORDS_REMOVED",old)
for _=1,3 do T.ProcessSeries(old) end
assert(#Q.Major(old)==0 and old.state.questSeriesFirst[166]==recovered.id,"Retention must not recreate an expired first")
E.runtime=priorRuntime;E.current=priorCharacter;K.cached=nil
if priorCharacter then B.ChangeCharacter(priorCharacter.id) end
print("PASS recorded quest series: ordered Defias turn-ins, Chronicle link and progress, clock reversal, repeat suppression, expired and conflicting evidence, flags, character isolation and recap exclusion")

restoreSourceReview()
