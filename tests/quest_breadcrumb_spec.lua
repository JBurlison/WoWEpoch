local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local B,V,K,T=E.Book,E.QuestView,E.QuestCatalog,E.QuestAtlas
local c=assert(E.current)
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests");B.questZone="all";B.questQuery="";B.questFilter="all"
local function show(id)V.Select(id);TEST_PREPARE_BOOK();assert(B.questAtlasID==id and B.Character()==c)end
local function action(prefix)
    for i=1,B.right.used.button or 0 do
        local f=B.right.pool.button[i]
        if f.text:GetText():sub(1,#prefix)==prefix then return f end
    end
end
local function result(id)
    local row=T.Row(c,id,K.Merge(c))
    return {label=row.label,state=row.state,eligibility=row.eligibility,completed=row.completed,active=row.active}
end
local inventory=E.BundledQuestBreadcrumbs
local function checkUnchanged(id)
    local before=result(id);E.BundledQuestBreadcrumbs=nil
    local without=result(id);E.BundledQuestBreadcrumbs=inventory
    assert(E.Same(before,without),"Breadcrumbs changed quest eligibility")
end
local before=c.seq
show(163)
local forward=assert(action("Leads to · Jitters' Growling Gut [5]"))
local stale=forward.scripts.OnClick
forward:Click();TEST_PREPARE_BOOK();assert(B.questAtlasID==5)
assert(action("Lead-in from · Raven Hill [163]")):Click();TEST_PREPARE_BOOK();assert(B.questAtlasID==163)
show(239)
assert(action("Leads to · Riverpaw Gnoll Bounty [11]"))
assert(action("Leads to · Wanted: ")):Click();TEST_PREPARE_BOOK();assert(B.questAtlasID==176)
assert(action("Lead-in from · Westbrook Garrison Needs Help! [239]"))
B.questZone=1454;show(235)
assert(action("Leads to · The Ashenvale Hunt (2/2) [6383]")):Click();TEST_PREPARE_BOOK()
assert(B.questAtlasID==6383 and B.questZone==1454,"Cross-zone reading discarded its originating zone")
assert(action("Lead-in from · The Ashenvale Hunt (1/2)")):Click();TEST_PREPARE_BOOK();assert(B.questAtlasID==235)
B.questZone="all"
show(464)
assert(action("Lead-in from · Report to Captain Stoutfist [473]"))
assert(action("Requires: Report to Captain Stoutfist"),"An independent prerequisite disappeared")
checkUnchanged(5);checkUnchanged(464)
assert(c.seq==before,"Reading breadcrumbs wrote quest history")
local other=E.Store.Character('breadcrumb-reader-other',{name='Offline reader'})
B.ChangeCharacter(other.id);B.SetChapter("Quests");B.questZone="all";V.Select(163);TEST_PREPARE_BOOK()
stale();assert(B.questAtlasID==163 and B.Character()==other,"A stale link operated on another owner")
assert(action("Leads to · Jitters' Growling Gut [5]")):Click();TEST_PREPARE_BOOK()
assert(B.questAtlasID==5 and B.Character()==other)
B.ChangeCharacter(c.id);B.SetChapter("Quests");B.questZone="all";show(163)
-- Actual QuestieDB spelling observed in the Forever simulator. A source-bound
-- link may use its own title while the merged destination retains the dispute.
local lib,addons=LibQuestieDB,C_AddOns
local installedTitle='WANTED: "Hogger"'
C_AddOns={GetAddOnMetadata=function(_,key)return key=='Version' and '1.0.9' or 'Forever'end}
LibQuestieDB={RequireContract=function()return true end,ModeIndicator={GetStatus=function()return {mode='source',expansion='Forever'}end},
    Support={Get=function()return {private={areaIdToUiMapId='return { [12] = 1429 }'}}end},
    Quest={GetAllIds=function()return {176}end,GetAll=function(id,fields)assert(id==176 and fields[1]=='name');return {n=#fields,[1]=installedTitle}end}}
for _,spelling in ipairs({'WANTED: "Hogger"','Entirely different provider title'})do
    installedTitle=spelling;assert(E.QuestieBridge.Start());E.QuestieBridge.Tick(.3)
    local merged=K.Merge(c).quests[176];assert(merged.conflicts.title and not merged.title)
    show(239);assert(action('Leads to · Wanted: "Hogger" [176]'),'Pinned breadcrumb title disappeared on provider disagreement'):Click()
    TEST_PREPARE_BOOK();assert(B.questAtlasID==176 and K.Merge(c).quests[176].conflicts.title)
    local fieldSeen=false
    for i=1,B.right.used.questDetailField or 0 do local f=B.right.pool.questDetailField[i]
        if f.label:GetText()=='Sources disagree' and f.value:GetText():find('title',1,true)then fieldSeen=true end
    end
    assert(fieldSeen,'Quest detail concealed its disputed title')
end
LibQuestieDB,C_AddOns=lib,addons;K.Remove('questiedb-installed');show(163)
local iface=E.runtime.interface;E.runtime.interface=iface-1
assert(not K.Breadcrumbs(c,163),"An incompatible client was shown bundled breadcrumbs")
E.runtime.interface=iface
local provider=inventory.provider
local click=assert(action("Leads to · Jitters' Growling Gut [5]")).scripts.OnClick
assert(K.Register({schema=1,client='forever',interface=E.target.interface,id=provider.id,name='Alternate',
    version='1',source='Source fixture',license='Fixture',compatibility='candidate',coverage='partial',coverageNote='Fixture',
    quests={{questID=163,title='Alternate Raven Hill'}}}))
assert(not K.Breadcrumbs(c,163));click();assert(B.questAtlasID==163)
B.Render();assert(not action("Leads to ·"))
print('PASS real breadcrumb source and reverse navigation, multiple destinations, independent prerequisite, unchanged status, offline character and replaced provider')

restoreSourceReview()
