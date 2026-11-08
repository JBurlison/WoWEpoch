local B,V,S,A,N=E.Book,E.MobDropView,E.Store,E.API,E.ControllerNavigation
local c=S.Character('mob-drop-memory-fixture',{name='Drop observer'})
local now=A.Now()-120;c.state.firstObserved=now
local serial=0
local function kill()
    serial=serial+1
    return S.Add(c,'kill',now+serial,{source='PARTY_KILL',npcID=524,npcName='Rockhide Boar',
        victimGUID='Creature-0-1-2-3-524-000'..serial,session='closed-drop-test'})
end
local function drop(k,item)
    local w=S.Add(c,'loot_window',now+serial,{session='closed-drop-test',fromItem=false,fishing=false})
    local r=S.Add(c,'drop',now+serial,{source='loot_window',session=w.session,window=w.id,slot=1,itemID=item,title='Remembered item '..item,snapshots={}})
    r.snapshots[1]={ts=now+serial,sequence=S.ReserveObservation(c),data={itemID=item,name=r.title,visibleQuantity=1,
        slotSources={{guid=k.victimGUID,npcID=524,name='Rockhide Boar',kind='Creature',quantity=1}}}}
    return r
end
for _=1,12 do local k=kill();drop(k,100+serial)end
local function drain()
    for _=1,10000 do
        V.Tick()
        if V.job and V.job.model and not B.viewPreparing then return end
    end
    error('Drop-rate view did not finish: '..tostring(V.lastError))
end
B.Open();B.ChangeCharacter(c.id);B.lootMode='mob_rates';B.mobDropNPC=524;B.SetChapter('Loot');TEST_PREPARE_BOOK()
assert(B.viewPreparing and V.job and V.job.work,'A cold report must preserve pending scroll/focus restoration')
drain();assert(V.lastReport.killCount==12 and #V.lastReport.items==12)
assert(not V.job.work,'A completed report must release its coroutine')
local field=B.right.pool.edit[1];local focus=assert(N.Find(field));assert(N.Focus(focus));local identity=focus.id
B.right.scroll:SetVerticalScroll(137);assert(B.right.scroll:GetVerticalScrollRange()>137)
local draft='Unsubmitted item filter';field:SetText(draft)
local weak=setmetatable({job=V.job,model=V.job.model,report=V.lastReport},{__mode='v'})
B.Close(true)
assert(not V.job and not V.lastReport and not V.lastError,'A real close releases the mob-rate view')
collectgarbage('collect');collectgarbage('collect')
assert(not weak.job and not weak.model and not weak.report,'Closed report graphs must become collectible')

-- Recording continues while closed, without recreating any hidden presentation.
local oldRender=B.Render;local renders=0
B.Render=function(...)renders=renders+1;return oldRender(...)end
local later=kill();local laterDrop=drop(later,101)
local expected=#c.order
for _=1,6000 do V.Tick()end
assert(renders==0 and not V.job and c.records[later.id]==later and c.records[laterDrop.id]==laterDrop and #c.order==expected)
B.Render=oldRender
B.Open();assert(B.viewPreparing and B.closedScroll,'Cold report must not consume the saved position')
local pending=setmetatable({V.job,V.job.work},{__mode='v'})
B.Close(true);collectgarbage('collect');collectgarbage('collect')
assert(not pending[1]and not pending[2],'Closing during preparation releases the unfinished scan too')
B.Open();assert(B.viewPreparing and B.closedScroll)
B.right.scroll:SetVerticalScroll(0)
drain()
assert(V.lastReport.killCount==13 and V.lastReport.byItem[101].killsWithItem==2,
    'Reopening must include kills and observed drops recorded while closed')
assert(B.right.scroll:GetVerticalScroll()==137 and field:GetText()==draft and N.Current().id==identity,
    'Ready report restores the scroll, unsubmitted filter and semantic focus')

-- Temporary capture/combat hides can retain a report. Ignore invalidation
-- while hidden, then rebuild when it becomes visible again.
local retained=V.job
B.captureHiding=true;B.frame:Hide();B.captureHiding=false
local hiddenKill=kill();renders=0
B.Render=function(...)renders=renders+1;return oldRender(...)end
for _=1,100 do V.Tick()end
assert(renders==0 and V.job==retained and c.records[hiddenKill.id]==hiddenKill)
B.Render=oldRender;B.frame:Show();drain()
assert(V.job~=retained and V.lastReport.killCount==14)

-- Failed view preparation keeps its explanatory error, not a dead worker or
-- a permanent preparing state that would prevent navigation restoration.
local list=E.MobDrops.List;E.MobDrops.List=function()error('Synthetic report failure')end
B.mobDropItemQuery='failure';B.Render();V.Tick()
assert(V.job.error and not V.job.work and not B.viewPreparing and V.lastError)
E.MobDrops.List=list;B.Close(true)
assert(not V.lastError and not V.job)
B.Open();drain();assert(V.lastReport.killCount==14)
B.Close(true)
print('PASS mob-drop memory: closed work released, no hidden redraw, recording continuity, cold restoration and failed worker cleanup')
