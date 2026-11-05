local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local B,K,S,T=E.Book,E.QuestCatalog,E.Store,E.QuestAtlas
local prev=B.character
local owner=S.Character("quest-level-offline",{name="Test reader",level=60})
assert(owner~=E.current)
local oldRuntime=E.runtime
E.runtime={interface=16001,build=70707}
local questID=9287001
local quest={questID=questID,title="A level check",mapIDs={1436},requiresAll={},requiresAny={},excludes={}}
local function register(low,high)
    quest.eligibility={complete=true,minLevel=low,maxLevel=high}
    assert(K.Register({schema=1,client="forever",interface=16001,id="quest-level-requirements",name="Test",
        source="UI fixture",version="1",license="Test",minBuild=70707,maxBuild=70707,coverage="partial",quests={quest}}))
end
register(14,60)
B.ChangeCharacter(owner.id);B.SetChapter("Quests");B.questZone="all";B.questQuery=tostring(questID)
B.questFilter="all";B.questAtlasID=questID;B.selected=nil
local function field()
    B.Render(true)
    for i=1,B.right.used.questDetailField or 0 do
        local f=B.right.pool.questDetailField[i]
        if f.label:GetText()=="Required level" then return f.value:GetText()end
    end
end
local function check(state,expected)
    assert(T.Row(owner,questID).eligibility==state)
    assert(field()==expected,expected)
end
check("eligible","14 to 60  /  Recorded level 60")
owner.identity.level=nil;owner.state.questAtlas={facts={},profile={level=14}}
check("eligible","14 to 60  /  Recorded level 14")
owner.state.questAtlas.profile.level="bad";owner.state.level=13
check("ineligible","14 to 60  /  Recorded level 13")
owner.identity.level=60;check("unknown","14 to 60  /  Saved levels disagree")
owner.identity.level=nil;owner.state.level=-1;check("unknown","14 to 60  /  Character level unrecorded")
owner.state.questLevelObservation={level=61,session="prior-login"};owner.identity.level=13
local before=E.Copy(owner)
local oldLevel,reads=UnitLevel,0
UnitLevel=function()reads=reads+1;return 1 end
check("ineligible","14 to 60  /  Recorded level 61")
assert(reads==0 and E.Same(before,owner),"offline level reads must not sample the current player or change the journal")
UnitLevel=oldLevel
register(nil,60);check("ineligible","60 or lower  /  Recorded level 61")
register(61,61);check("eligible","61  /  Recorded level 61")
register(14,nil);check("eligible","14 or higher  /  Recorded level 61")
local real=T.Row(owner,79192);assert(real.eligibility=="unknown","meeting the minimum does not establish full availability")
K.Remove("quest-level-requirements");E.runtime=oldRuntime
if prev then B.ChangeCharacter(prev)end
print("PASS quest level details: saved owner evidence, conflicts, invalid data, min/max boundaries, offline isolation and partial coverage")

restoreSourceReview()
