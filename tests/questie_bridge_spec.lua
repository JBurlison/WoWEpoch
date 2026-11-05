local J,K,A,C,S=E.QuestieBridge,E.QuestCatalog,E.API,E.Collectors,E.Store
local saved={lib=LibQuestieDB,addons=C_AddOns,current=E.current,runtime=E.runtime,session=C.session,providers=K.providers,worker=E.QuestAtlas.worker}
local c=S.Character('questie-reader',{name='Catalog reader'});local other=S.Character('questie-other',{name='Other reader'})
E.current=c;C.session='questie-test';E.runtime={interface=16001,build='70532'};K.providers={};K.revision=K.revision+1
local mode='source';local flavor='Forever';local version='1.0.9';local calls=0;local bad
-- Actual pinned QuestieDB 1.0.9 quest 3639 pair, independently decoded in the source-evidence runner.
local sourcedRequiredSkill=TEST_SOURCED_REQUIRED_SKILL or {202,200};local requiredSkill=sourcedRequiredSkill
local ids={};for i=1,60 do ids[i]=i end
local maps='return { [40] = 1436, -- Westfall\n [44] = 1433 }'
C_AddOns={GetAddOnMetadata=function(addon,key)assert(addon=='QuestieDB');if key=='Version'then return version elseif key=='X-Flavor'then return flavor end end}
LibQuestieDB={RequireContract=function(n)assert(n==3);return true end,
    ModeIndicator={GetStatus=function()return{mode=mode,expansion=mode=='source'and flavor or nil}end},
    Support={Get=function(key)assert(key=='ZoneDB');return{private={areaIdToUiMapId=maps,areaIdToUiMapIdOverride='return { [1581] = 291 }'}}end},
    Enum={raceMaskById={[1]=1,[2]=2,[95]=4294967296,[96]=8589934592},classKeys={WARRIOR=1,PALADIN=2,SHAMAN=64,DRUID=1024,ALL_CLASSES=1503}},
    Quest={GetAllIds=function()return ids end,GetAll=function(id,keys)
        calls=calls+1;assert(#keys==15 and keys[1]=='name'and keys[9]=='requiredRaces'and keys[10]=='requiredSkill'and keys[11]=='requiredClasses')
        assert(table.concat(keys,',',12,15)=='parentQuest,availableUntilCompleted,availableStartingWith,disabledByQuest')
        if id==bad then error('provider read failed')end
        return{n=#keys,[1]='Catalog quest '..id,[2]=id==3 and 1581 or id==4 and -22 or 40,[3]=id==2 and {-1}or{1},
            [5]={9},[6]=10,[7]=60,[8]=id==1 and 1 or 0,[9]=4294967297,[10]=id==1 and requiredSkill or nil,
            [11]=({67,1024,1025+2048,0})[id],[12]=id==1 and 253 or nil,[13]=id==2 and 949 or nil,
            [14]=id==3 and 92514 or nil,[15]=id==4 and 420 or nil}
    end}}
assert(J.MapTable(maps)[40]==1436)
for _,raw in ipairs({'return {[40]=1436}; error("run")','return {[40]=1436,[40]=1433}','return {[0]=0}','return { [40] = f() }','return { [40] = 1436 }; _G.HACKED=true'})do assert(not J.MapTable(raw))end
assert(not _G.HACKED)
assert(J.Start());assert(not K.providers['questiedb-installed']);J.Tick(.05);assert(calls==0);J.Tick(.05);assert(calls==25)
J.Tick(.1);assert(calls==50 and not K.providers['questiedb-installed']);J.Tick(.1);assert(calls==60 and not J.worker)
local p=assert(K.providers['questiedb-installed']);assert(#p.quests==60 and p.runtimeBinding.character==c.id and not p.minBuild)
local merged=K.Merge(c);local one=merged.quests[1]
assert(one.title=='Catalog quest 1'and one.mapIDs[1]==1436 and one.repeatable==true)
assert(one.eligibility.complete==false and one.eligibility.minLevel==10 and one.eligibility.maxLevel==60)
assert(one.eligibility.profession.skillID==202 and one.eligibility.profession.minRank==200)
-- Actual baked masks from quests 5126 (67) and 26 (1024). A partially
-- recognizable mask must never narrow the eligible set to its known bits.
assert(table.concat(one.eligibility.classIDs,',')=='1,2,7')
assert(merged.quests[2].eligibility.classIDs[1]==11)
assert(one.eligibility.parentQuest==253 and merged.quests[2].eligibility.availableUntilCompleted==949)
assert(merged.quests[3].eligibility.availableStartingWith==92514 and merged.quests[4].eligibility.disabledByQuest==420)
assert(merged.quests[3].eligibility.classIDs==nil and #merged.quests[4].eligibility.classIDs==0 and merged.quests[5].eligibility.classIDs==nil)
local function classReason()
    local _,reasons=E.QuestAtlas.Eligibility(c,merged.quests[2])
    return table.concat(reasons,' '):find("recorded class does not meet",1,true)
end
c.identity.classID=1;assert(classReason())
c.identity.classID=11;assert(not classReason());c.identity.classID=nil
assert(merged.quests[2].eligibility.profession==nil,'missing provider rule is not unrestricted coverage')
for _,invalid in ipairs({{202},{0,200},{202,-1},{202,200,300},{skillID=202,minRank=200}})do
    requiredSkill=invalid;assert(J.Start());J.Tick(.1);assert(not J.worker and K.providers['questiedb-installed']==p,'malformed requiredSkill rejects whole replacement')
end
requiredSkill=sourcedRequiredSkill
assert(one.eligibility.raceIDs[1]==1 and one.eligibility.raceIDs[2]==95,'wide race masks must not be truncated')
assert(not merged.quests[2].requiresAll,'negative/active prerequisites cannot become completion requirements')
assert(not merged.quests[3].mapIDs,'legacy instance overrides must not masquerade as native maps')
assert(not merged.quests[4].mapIDs,'negative quest sorts are not area IDs')
assert(not merged.quests[2].repeatable,'absence of one repeatable flag must not assert nonrepeatability')
assert(next(K.Merge(other).quests)==nil,'character-dependent provider corrections cannot leak across scrapbooks')
assert(E.QuestAtlas.Rows(other,'all').total==0)
E.runtime.build='70707';assert(not K.Compatible(p,c));E.runtime.build='70532'
local B=E.Book;B.ChangeCharacter(c.id);B.chapter='Quests';B.questTools=true;B.questZone='all';B.Render()
local edit=B.nav.pool.edit[1];edit:SetText('Unsaved catalog search')
bad=30;assert(J.Start());J.Tick(.1)
assert(J.status:find('25 / 60',1,true)and edit:GetText()=='Unsaved catalog search','progress must update without rerendering away a draft')
J.Tick(.1);assert(not J.worker and K.providers['questiedb-installed']==p,'failed refresh must preserve the previous snapshot')
bad=nil;assert(J.Start());J.Tick(.1);E.current=other;J.Tick(.1);assert(not J.worker and K.providers['questiedb-installed']==p);E.current=c
mode='baked';assert(J.Start());for i=1,3 do J.Tick(.1)end;assert(K.providers['questiedb-installed'].name=='QuestieDB / baked')
flavor='Classic';assert(not J.Start()and not K.providers['questiedb-installed']);flavor='Forever'
ids={1,1};assert(not J.Start(),'duplicate ID lists rejected');ids={1,2}
LibQuestieDB.RequireContract=function()return false,'wrong range'end;assert(not J.Start())
LibQuestieDB=nil;assert(not J.Start()and J.status:find('not installed',1,true))
K.providers=saved.providers;K.revision=K.revision+1;E.QuestAtlas.worker=saved.worker
LibQuestieDB=saved.lib;C_AddOns=saved.addons;E.current=saved.current;E.runtime=saved.runtime;C.session=saved.session;J.worker=nil
print('PASS QuestieDB bridge: bounded import, atomic refresh, wide race masks, source/baked flavor checks, character isolation and nonexecuting map parser')
