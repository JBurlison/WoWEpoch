local B,V,S,H,A=E.Book,E.QuestView,E.Store,E.History,E.API
local c=S.Character('quest-locale-reader',{name='Quest reader'})
local q=H.BeginQuest(c,9918123,'Original captured quest',A.Now()-120,true)
q.objectives={{text='Original objective text',numFulfilled=1,numRequired=3}}
local r=H.CompleteQuest(c,9918123,A.Now()-60,{xp=10},nil,'Original captured quest')
local before=E.Copy(r)
local titleAPI=C_QuestLog.GetTitleForQuestID
C_QuestLog.GetTitleForQuestID=function(id)if id==9918123 then return 'Client-language quest name' end end
B.ChangeCharacter(c.id);B.questZone='all';B.questQuery=nil;B.questAtlasID=nil;B.selected=nil
B.SetChapter('Quests');TEST_PREPARE_BOOK()
assert(B.left.pool.questRow[1].text:GetText()=='Client-language quest name')
local titleFound,headingFound=false,false
for i=1,B.right.used.label or 0 do local value=B.right.pool.label[i]:GetText()
    titleFound=titleFound or value=='Client-language quest name'
    headingFound=headingFound or value==E.L['A COMPLETED STORY']
end
assert(titleFound and headingFound,'quest title and section must use current presentation language')
B.Clear(B.right);V.Objectives(B.right,q)
assert(B.right.pool.questObjective[1].title:GetText()=='Original objective text','captured objective text stays unchanged')
assert(B.right.pool.questObjective[1].count:GetText()=='1 / 3')
assert(E.Same(before,r),'localized display must not rewrite saved quest records')
C_QuestLog.GetTitleForQuestID=function()return nil end
assert(E.Display.Quest(r.questID,r.title)=='Original captured quest','missing client names fall back to the capture')
C_QuestLog.GetTitleForQuestID=titleAPI
print('PASS quest localization: current client names, original fallback, translated sections and untouched captures')

local diagnostics={
    'Catalog requirements are unavailable','Catalog providers disagree about requirements',
    'Eligibility coverage is incomplete','Some prerequisite relationships have unknown rules',
    'Saved faction readings disagree.','Saved class readings disagree.','Saved race readings disagree.',
    'The saved class reading cannot be verified.',"This character's race has not been recorded.",
    "This character's recorded class does not meet the quest requirement.",
    "Requires Horde. This character's recorded faction is Alliance.",
    'Profession 171: Profession observation is unknown',
    'Profession 171: Required profession is not currently learned',
    'Profession 171: Profession observation is offline; refresh on that character',
    'Profession 171: Profession observation is stale; refresh the quest atlas',
    'Profession 171: Profession observation is incomplete or unavailable',
    'Profession 171: Profession rank is unknown',
    'Minimum rank for profession 171 is unknown','Profession 171 requires rank 75 (observed 20)',
    'The catalog reputation bounds disagree.','Faction 72 reputation does not meet the listed requirement.',
    'Stormwind reputation does not meet the listed requirement.',
    'Required quest 76 is not completed','Completion of prerequisite 76 is unknown',
    'Alternative prerequisites have unknown completion','None of the alternative prerequisites is completed',
    'Catalog requires 2 of 4 listed quests. 1 completed, 2 unknown.',
    'Mutually exclusive quest 76 was completed','Exclusive branch 76 has unknown completion',
    'Reload the UI to load QuestieDB contacts for this character.',
}
for _,rule in ipairs(E.QuestCatalog.stateRules)do
    diagnostics[#diagnostics+1]=rule.label..' 76 (quest state unknown).'
    diagnostics[#diagnostics+1]=rule.label..' 76 (requirement unmet).'
end
for _,reason in ipairs(diagnostics)do
    local display=V.Reason(reason)
    assert(type(display)=='string' and not display:find('{',1,true),'reason placeholders must be filled')
    if E.locale~='enUS'then assert(display~=reason,'untranslated quest diagnostic: '..reason)end
end
assert(V.Reason('Original provider prose')=='Original provider prose','unknown provider prose stays intact')
assert(V.Reason('Stormwind reputation does not meet the listed requirement.'):find('Stormwind',1,true),'captured faction name stays intact')
print('PASS bounded quest diagnostic display translations and provider prose preservation')
