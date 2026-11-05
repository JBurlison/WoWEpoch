local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local K=E.QuestCatalog
local id,otherID=991001,991002
local min,max,rewards={87,3000},{21,-6000},{{87,25},{21,-125}}
local rewardReads,reads=0,{}
local values={[87]=3000,[21]=-6001}
local mode,after="ordinary"
local function data(fid)
    reads[fid]=(reads[fid]or 0)+1
    if after then after()end
    if mode=="nil" then return end
    if mode=="error" then error("unavailable")end
    return {factionID=mode=="wrongID" and fid+1 or fid,name=fid==87 and "Bloodsail" or "Booty Bay",
        isAccountWide=mode=="account",isHeader=mode=="header",isHeaderWithRep=false,
        currentStanding=values[fid],reaction=8}
end
C_Reputation={GetFactionDataByID=data}
local lib={RequireContract=function(n)return n==3 end,
    ModeIndicator={GetStatus=function()return {mode="source",expansion="Forever"}end},
    Support={Get=function()return {private={areaIdToUiMapId="return {[40]=1436}"}}end},
    Quest={GetAllIds=function()return {id,otherID}end,
        GetAll=function(qid,fields)return {n=#fields,[1]="Source-backed case "..qid,[2]=40}end,
        requiredMinRep=function()return min end,requiredMaxRep=function()return max end,
        reputationReward=function()rewardReads=rewardReads+1;return rewards end}}
assert(J.ReputationRules(c,id)==nil and not J.ReputationRewards(c,id))
LibQuestieDB=lib
local function publish()assert(J.Start());while J.worker do J.Tick(.1)end;assert(K.providers['questiedb-installed'])end
publish();assert(rewardReads==0 and next(reads)==nil)
local function label()return T.Row(c,id).eligibility end
assert(label()=="unknown","meeting two thresholds is still partial coverage")
values[21]=-6000;assert(label()=="ineligible","maximum is exclusive")
values[21]=-6001;values[87]=2999;assert(label()=="ineligible","minimum is inclusive")
values[87]=3000
reads={};local report=T.Rows(c,1436,"all","",true);assert(report.all[id] and report.all[otherID])
assert(reads[21]==1 and reads[87]==1 and rewardReads==0,"one standing read per faction per report")
for _,bad in ipairs({"account","header","wrongID","nil","error"})do
    mode=bad;values[87]=-500;assert(label()=="unknown",bad)
end
mode="ordinary"
local rawGUID=UnitGUID;UnitGUID=function(unit)return unit=="player" and "different-player" or rawGUID(unit)end
assert(label()=="unknown" and not J.ReputationRewards(c,id));UnitGUID=rawGUID
local wasSession=E.Collectors.session
after=function()E.Collectors.session="changed-during-read"end
assert(label()=="unknown");after=nil;E.Collectors.session=wasSession
FACTION="Horde";assert(label()=="unknown" and not J.ReputationRewards(c,id));FACTION="Alliance"
local offline=E.Store.Character("offline-rep",{name="Offline",faction="Alliance"})
assert(T.Row(offline,id).eligibility=="unknown" and not J.ReputationRewards(offline,id))
local original=E.Copy(c.records);assert(J.ReputationRewards(c,id) and E.Same(original,c.records))
min,max={87,0},{21,0};values[87],values[21]=0,-1;publish();assert(label()=="unknown")
values[21]=0;assert(label()=="ineligible")
B.Open();B.SetChapter("Quests");E.QuestView.Select(id)
local function fields(label)
    local lines={}
    for i=1,B.right.used.questDetailField or 0 do local w=B.right.pool.questDetailField[i]
        if w.label:GetText()==label then lines[#lines+1]=w.value:GetText()end
    end
    return table.concat(lines," / ")
end
for i=1,120 do if fields("Catalog reward")~="" then break end;E.frame.scripts.OnUpdate(E.frame,.2);B.Render()end
assert(fields("Catalog requirement"):find("below 0 points",1,true) and fields("Catalog requirement"):find("at least 0 points",1,true))
assert(fields("Catalog reward"):find("-125 reputation",1,true) and fields("Catalog reward"):find("+25 reputation",1,true))
assert(fields("Eligibility")=="Requirements not met" and not T.History(c)[id],fields("Eligibility"))
values[21]=-1
fire("UPDATE_FACTION")
for i=1,12 do E.QuestView.ProcessCatalogRefresh(.2)end
B.Render() -- Explicit source inspection; eligibility does not repaint completed stories.
assert(B.questAtlasID==id and fields("Eligibility")=="Some requirements are unknown",fields("Eligibility"))
assert(fields("Catalog requirement"):find("Current -1",1,true))
local rewardRead=lib.Quest.reputationReward
lib.Quest.reputationReward=function()E.Collectors.session="changed-during-reward";return rewards end
assert(J.ReputationRewards(c,id)==nil);E.Collectors.session=wasSession;lib.Quest.reputationReward=rewardRead
rewards={{87,math.huge}};assert(not J.ReputationRewards(c,id));rewards={{87,0}};assert(J.ReputationRewards(c,id)[1].points==0)
local secret={};local wasSecret=issecretvalue;issecretvalue=function(v)return rawequal(v,secret)or wasSecret and wasSecret(v)end
values[87]=secret;values[21]=-1;assert(label()=="unknown");issecretvalue=wasSecret
-- A different agreeing or disagreeing runtime provider does not gain
-- authority to present its own bound as QuestieDB's, or override a conflict.
values[87]=-1;values[21]=-1
local alternate=E.Copy(K.providers["questiedb-installed"]);alternate.id="alternate-reputation"
alternate.quests[1].eligibility.minReputation={factionID=87,points=-100}
assert(K.Register(alternate))
local mergedEntry=K.Merge(c).quests[id]
assert(mergedEntry.conflicts.eligibility.minReputation and not mergedEntry.eligibility.minReputation and label()=="unknown")
assert(J.ReputationRules(c,id).minReputation.points==0);K.Remove(alternate.id)
min,max={87,3000},{87,3000};values[87]=3000;publish();assert(label()=="unknown","contradictory half-open interval")
min={87,"0"};max={21,0,1};publish();local merged=K.Merge(c).quests[id].eligibility;assert(not merged.minReputation and not merged.maxReputation)
LibQuestieDB=nil;assert(not J.Start() and not J.ReputationRules(c,id) and not J.ReputationRewards(c,id) and not K.providers['questiedb-installed'])

restoreSourceReview()
