local X,S,A,C,V=E.ExperienceSources,E.Store,E.API,E.Collectors,E.RecapView
local owner,session,clock=E.current,C.session,A.Now
local c=S.Character('xp-sources',{name='Explorer'});E.current=c;C.session='xp-session';X.live=nil
local now=100;A.Now=function()return now end
local formats={'COMBATLOG_XPGAIN_FIRSTPERSON','ERR_ZONE_EXPLORED_XP'};local saved={}
for _,key in ipairs(formats)do saved[key]=_G[key]end
COMBATLOG_XPGAIN_FIRSTPERSON='%s dies, you gain %d experience.'
ERR_ZONE_EXPLORED_XP='Discovered %s: %d experience gained'
local function xp(n)return S.Add(c,'xp',now,{subject=c.id,session=C.session,amount=n,title='XP gained: '..n})end
local function settle()now=now+3;X.Process()end
local gain=xp(40);X.Message('Wolf dies, you gain 40 experience.');settle()
assert(gain.xpCause.kind=='kill'and gain.xpCause.name=='Wolf'and gain.amount==40)
assert(E.Display.RecordTitle(gain):find('Kill: Wolf',1,true))
-- Reordered localized parameters; evidence may arrive before the XP delta.
now=120;ERR_ZONE_EXPLORED_XP='%2$d EP für die Entdeckung von %1$s'
X.Message('65 EP für die Entdeckung von Tal',true);local explored=xp(65);settle()
assert(explored.xpCause.kind=='exploration'and explored.xpCause.name=='Tal')
now=140;local quest=S.Add(c,'quest',now,{status='completed',questID=123456,rewards={xp=100},title='A small favor'})
local questGain=xp(100);settle();assert(questGain.xpCause.recordID==quest.id and questGain.refs[1]==quest.id)
X.Dismiss(c,questGain);X.Process();assert(not questGain.xpCause and #questGain.refs==0 and questGain.amount==100)
now=160;local ambiguous=xp(50)
X.Message('Wolf dies, you gain 50 experience.');X.Message('Boar dies, you gain 50 experience.');settle()
assert(not ambiguous.xpCause,'Competing sources remain unknown')
now=180;local first=xp(30);local second=xp(30);X.Message('Wolf dies, you gain 30 experience.');settle()
assert(not first.xpCause and not second.xpCause,'One report cannot describe multiple receipts')
now=200;local mismatch=xp(90);X.Message('Wolf dies, you gain 45 experience.');settle();assert(not mismatch.xpCause)
now=220;X.Message('Wolf dies, you gain 20 experience.');now=230;local stale=xp(20);settle();assert(not stale.xpCause)
now=240;X.Message('Wolf dies, you gain 80 experience.');C.session='new-session';local fresh=xp(80);settle();assert(not fresh.xpCause)
assert(#E.Query.Kind(c,'xp')==9,'Attribution must not create additional XP receipts')
local travel=S.Add(c,'travel',now,{subject=c.id,amount=7,title='Distance traveled'})
local recap={refs={travel.id,gain.id,quest.id,explored.id}}
local sources=V.Sources(c,recap)
assert(#sources==3 and c.records[travel.id]==travel,'Hide travel without deleting Journey history')
local shown,kinds,counts=V.FilterSources(sources,{quest=true});assert(#shown==2 and counts.xp==2 and #kinds==2)
assert(#V.FilterSources(sources,{quest=true,xp=true})==0)
assert(#V.FilterSources(sources,{})==3)
-- Exercise the production prepared source list and multi-select controls.
local B=E.Book
local milestone=S.Add(c,'milestone',now,{subject=c.id,major=true,milestoneType='level',before=2,after=3,title='Level 3'})
local savedRecap=S.Add(c,'recap',now,{periodKind='milestone',key='milestone:'..milestone.id,from=90,through=now,refs=recap.refs,facts={},text='A little adventure.'})
B.ChangeCharacter(c.id);B.recapKind='milestone';B.recapFocus=savedRecap.id;B.recapSourcesOpen=true;B.recapFiltersOpen=true;B.recapSourceExcluded={}
B.SetChapter('Recaps');TEST_PREPARE_BOOK()
local projection=assert(E.CraftProjectionPreparation.Recap(c,savedRecap));assert(#projection.sources==3)
assert(TEST_UI_FIND('Follow the source records (3)') or TEST_UI_FIND('- Follow the source records (3)'))
local toggle=assert(TEST_UI_FIND('Quest (1)'));toggle.scripts.OnClick();TEST_PREPARE_BOOK()
assert(B.recapSourceExcluded.quest and #V.FilterSources(projection.sources,B.recapSourceExcluded)==2)
local xpToggle=assert(TEST_UI_FIND('Experience gained (2)'));xpToggle.scripts.OnClick();TEST_PREPARE_BOOK()
assert(B.recapSourceExcluded.xp and B.recapSourceExcluded.quest)
local reset=assert(TEST_UI_FIND('All events'));reset.scripts.OnClick();TEST_PREPARE_BOOK();assert(not next(B.recapSourceExcluded))
for _,key in ipairs(formats)do _G[key]=saved[key]end
E.current=owner;C.session=session;A.Now=clock;X.live=nil
print('PASS XP sources: localized reports, quest refs, event order, ambiguous/expired/session guards, reversal, unchanged totals, filtered recap sources')
