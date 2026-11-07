local S,A,P,T,B,C,Q=E.Store,E.API,E.Progress,E.QuestAtlas,E.Book,E.Collectors,E.Query
local now=1800000000;TEST_NOW(now)
local c=S.Character('idle-workers-online',{});local offline=S.Character('idle-workers-offline',{})
E.current=c;C.session='idle-workers';B.frame:Hide()
Enum={SpellBookSpellBank={Player=0},SpellBookItemType={Spell=1,Flyout=4}}
local known,loaded=false,false
C_SpellBook={GetNumSpellBookSkillLines=function()return 0 end,
 FindSpellBookSlotForSpell=function()return 1,0 end,
 GetSpellBookItemInfo=function()return{itemType=1}end,
 IsSpellKnown=function()return known end}
C_Spell={GetSpellInfo=function(id)if loaded then return{name='Late spell name',spellID=id,iconID=123}end end,
 GetSpellSubtext=function()return loaded and'Rank 1'or nil end,RequestLoadSpellData=function()end}
GetCategoryList=function()return{900}end
GetCategoryNumAchievements=function()return 1 end
GetAchievementInfo=function()return 901,'Existing achievement',10,true,1,1,26,'Description',0,123,'',false,true end
P.Start(c)
local st=c.state.progress
assert(not next(st.pending)and not next(st.metadata))
P.Process(c,now,2)
assert(st.achievements[901]and not P.achievementScans[c],'Empty observation queues must still finish the achievement baseline')
local sequence=c.seq
for i=1,100 do P.Process(c,now,2)end
assert(c.seq==sequence,'Idle processing must not add historical accomplishments')
P.Learned(902,1,false)
assert(st.pending['spell:902'])
known=true;TEST_NOW(now+1);P.Process(c,now+1,2)
assert(st.pending['spell:902']and #Q.Kind(c,'spell')==0,'Future retries must keep their existing due time')
TEST_NOW(now+2);P.Process(c,now+2,2)
local r=assert(Q.Kind(c,'spell')[1])
assert(not next(st.pending)and st.metadata[r.id]and r.spellName==nil)
loaded=true;TEST_NOW(now+3);P.Process(c,now+3,2);assert(r.spellName==nil)
TEST_NOW(now+4);P.Process(c,now+4,2)
assert(r.spellName=='Late spell name'and not next(st.metadata),'Metadata-only retries must resume after an idle period')
P.Process(offline,now+10,2);assert(not offline.state.progress,'Offline owners must not gain live progress state')

-- Seed retained series while neither scrapbook is being read, then exercise
-- hidden current-owner and visible offline-owner backfill through Process.
local steps={65,132,135,141,142,155,166}
E.runtime={build=70532,interface=16001};E.current=offline
local function seed(owner)
 for i=1,300 do S.Add(owner,'chat',now+i,{text='Retained history'})end
 for i,id in ipairs(steps)do E.History.CompleteQuest(owner,id,now+400+i,{},'prior-session','Quest '..id)end
end
seed(c);E.current=c;seed(offline)
assert(#Q.Major(c)==0 and #Q.Major(offline)==0)
T.worker={c=c,session=C.session,queue={},head=1,queued={},requested={},elapsed=0}
for i=1,3 do T.Process(.25)end
assert(#Q.Major(c)==1 and #Q.Major(offline)==0,'A drained observation queue must still backfill the hidden current scrapbook')
B.character=offline.id;B.frame:Show()
for i=1,3 do T.Process(.25)end
assert(#Q.Major(offline)==1,'A drained observation queue must still backfill a selected offline scrapbook')
B.frame:Hide()
local reads={}
A.RecordingPlayerGUID=function()return c.id end
C_QuestLog={GetTitleForQuestID=function(id)reads[#reads+1]=id;return 'Observed quest '..id end,
 IsOnQuest=function()return false end,IsQuestFlaggedCompleted=function()return false end}
for i=1,100 do T.Process(.25)end
assert(#reads==0)
T.Queue(c,5001);T.Process(.1);assert(#reads==0)
T.Process(.15);assert(#reads==1 and reads[1]==5001,'Newly queued observations resume at the original cadence')
T.Queue(c,5002);T.Queue(c,5003,true);T.Process(.25)
assert(reads[2]==5003 and reads[3]==5002,'Priority observations retain order after an idle period')
A.RecordingPlayerGUID=function()return 'different-owner'end
T.Queue(c,5004);T.Process(.25)
assert(#reads==3 and T.worker.priority==5004)
A.RecordingPlayerGUID=function()return c.id end
T.Process(.25)
assert(reads[4]==5004 and not T.worker.queued[5004],'A guarded retry must run even when the ordinary queue has drained')
print('PASS idle workers: achievement baseline, metadata-only retries, hidden/offline series, resumed queue cadence and priority owner recovery')
