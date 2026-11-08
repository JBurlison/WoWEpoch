-- Exercise the real event dispatcher, automatic writer and notification UI.
-- Closing presentation caches must never stop recording or background writing.
local B,S,A,J,D,N=E.Book,E.Store,E.API,E.JournalJobs,E.Diary,E.Notifications
local bind,restoreRecorder=TEST_WALLET_SESSION()
local oldCharacter,oldLevel,oldCombat=B.character,UnitLevel,UnitAffectingCombat
local oldLootFormat=LOOT_ITEM_SELF_MULTIPLE
LOOT_ITEM_SELF_MULTIPLE='You receive loot: %sx%d.'
local now=A.Now()+30
TEST_NOW(now)
local c=S.Character('closed-journal-recording',{name='Closed-book adventurer',level=20})
c.state.firstObserved=now;c.state.level=20
bind(c,'closed-journal-recording:session')
local level=20;UnitLevel=function()return level end;UnitAffectingCombat=function()return false end
local function event(name,...)E.frame:GetScript('OnEvent')(E.frame,name,...)end
event('PLAYER_ENTERING_WORLD')
N.Configure(c,'account','master',true);N.Configure(c,'account','levels',true);N.Configure(c,'account','milestone',true)
N.Start(c);J.Login(c,now)
B.Combat(false);B.character=c.id;B.chapter='Chronicle';B.Open();B.Close(true)
assert(not B.frame:IsShown()and B.viewReleased and E.RecorderReady())

-- A sufficiently long personal loot trail makes the milestone recap suspend
-- over several genuine 500-operation Bootstrap update slices.
TEST_NOW(now+1)
for i=1,600 do
    event('CHAT_MSG_LOOT','You receive loot: |cffaaaaaa|Hitem:2840:0|h[Copper Bar]|hx2.',
        nil,nil,nil,nil,nil,nil,nil,nil,nil,710000+i)
end
local receipts=E.Query.Kind(c,'loot')
assert(#receipts==600 and receipts[1].recipient==c.id,'closed book still records native loot events')
TEST_NOW(now+2);level=21;event('PLAYER_LEVEL_UP',level)
local milestone
for _,r in ipairs(E.Query.Major(c))do if r.milestoneType=='level'and r.after==21 then milestone=r end end
assert(milestone and milestone.major and milestone.before==20 and milestone.subject==c.id,
    'native level event records an owned major milestone while closed')
local key='milestone:'..milestone.id
assert(J.pending[c]and J.pending[c][key],'milestone schedules its automatic recap while closed')
assert(c.state.notifications.seen[key]=='queued','milestone notification is queued independently of the book')

local weak=setmetatable({},{__mode='v'})
local witnessed,levelToast,recapToast,slices=false,false,false,0
local function observeNotification()
    local active=N.Current()
    if active and active.owner==c then
        assert(E.NotificationView.toast and E.NotificationView.toast:IsShown(),'real toast renderer presents queued notifications')
        for _,entry in ipairs(active.entries)do
            if entry.id==milestone.id and entry.category=='levels'then levelToast=true end
            if entry.key=='recap:'..key and entry.category=='milestone'then recapToast=true end
        end
    end
end
TEST_NOW(now+10)
local recap
for i=1,5000 do
    slices=i
    TEST_NOW(now+10+math.floor(i/10))
    E.frame:GetScript('OnUpdate')(E.frame,.1)
    assert(not B.frame:IsShown(),'recording and notifications must not open the book')
    local writer=J.dailyWriters[c]
    if writer and writer.eventID==milestone.id then
        if not witnessed then
            witnessed=true;weak.state=writer;weak.snapshot=writer.view;weak.records=writer.view.records
            weak.worker=writer.worker;weak.thread=writer.worker.thread
        end
        B.Close(true);B.Close(true)
        assert(J.dailyWriters[c]==writer and not writer.cancelled,
            'repeated book closes must leave the active automatic milestone writer intact')
    end
    observeNotification()
    recap=c.records[(c.state.recaps or{})[key]]
    if recap and D.Completed(recap)and levelToast and recapToast and not J.dailyWriters[c]then break end
end
assert(witnessed and slices<5000,'real automatic milestone compilation makes bounded progress while closed: witnessed='..tostring(witnessed)
    ..' slices='..slices..' phase='..tostring(J.dailyWriters[c]and J.dailyWriters[c].phase)..' recap='..tostring(recap~=nil)
    ..' levelToast='..tostring(levelToast)..' recapToast='..tostring(recapToast)..' error='..tostring(A.status.journalWritingError))
assert(recap and D.Completed(recap)and recap.periodKind=='milestone'and recap.read==false)
assert(recap.facts.counts.levels==1 and recap.facts.counts.looted==1200 and type(recap.text)=='string'and #recap.text>0,
    'automatic recap includes the actual level transition and preceding personal receipts')
assert(levelToast and recapToast and c.state.notifications.seen[key]=='delivered'
    and c.state.notifications.seen['recap:'..key]=='delivered','both milestone and completed recap notifications are delivered while closed')
assert(not J.pending[c][key]and not J.dailyWriters[c]and not A.status.journalWritingError)
collectgarbage('collect');collectgarbage('collect')
for _,name in ipairs({'state','snapshot','records','worker','thread'})do
    assert(weak[name]==nil,'completed automatic writing retains temporary '..name)
end

local savedText,savedFacts,generation=recap.text,recap.facts,recap.generation
B.Open();B.chapter='Recaps';B.recapKind='milestone';B.recapFocus=recap.id;B.selected=nil;B.Render(true);TEST_PREPARE_BOOK()
for _=1,2000 do
    local preparation=E.CraftProjectionPreparation
    if E.RecapView.lastRecord==recap and not preparation.waiting and(not preparation.job or preparation.job.status=='ready')then break end
    E.frame:GetScript('OnUpdate')(E.frame,.01)
end
assert(E.RecapView.lastRecord==recap and B.recapFocus==recap.id and recap.read,
    'reopening reaches the completed saved milestone recap')
assert(recap.text==savedText and recap.facts==savedFacts and recap.generation==generation,
    'opening a completed recap does not compile it again')
local visible={}
for i=1,B.right.used.label or 0 do visible[#visible+1]=B.right.pool.label[i]:GetText()end
assert(table.concat(visible,'\n'):find(E.DiaryPresentation.Recap(recap),1,true),
    'completed writing is rendered on the reopened recap page')
B.Close(true);N.Close();N.Stop()
UnitLevel=oldLevel;UnitAffectingCombat=oldCombat;LOOT_ITEM_SELF_MULTIPLE=oldLootFormat;restoreRecorder();B.character=oldCharacter
print('PASS closed-book recording: native loot/level events, automatic milestone recap, real milestone/recap toasts, writer survival, collected compiler scratch and saved recap reopening; slices',slices)
