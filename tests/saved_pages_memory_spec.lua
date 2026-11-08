local B,P,V,S,M,N,A=E.Book,E.SavedPages,E.MemoryView,E.Store,E.Memories,E.ControllerNavigation,E.API
local c=S.Character('saved-pages-memory-fixture',{name='Album reader'})
local now=A.Now()-4000;c.state.firstObserved=now
for i=1,2400 do
    c.seq=c.seq+1;local id=c.id..':'..c.seq;local memory=i%4==0
    c.records[id]={id=id,character=c.id,kind=memory and'memory'or'chat',category=memory and'memories'or'chat',
        sequence=c.seq,ts=now+i,title='Album page '..i,text='A remembered afternoon.',tags={},refs={}}
    c.order[#c.order+1]=id
end
local function upvalue(fn,key)
    for i=1,100 do local name,value=debug.getupvalue(fn,i)
        if not name then break end
        if name==key then return value end
    end
end
local function drain()
    for _=1,20000 do
        P.Tick()
        if V.lastSaved and not B.viewPreparing then return end
    end
    error('Saved memory page did not finish')
end
B.Open();B.ChangeCharacter(c.id);B.memoryMode='saved';B.memoryOverview=true;B.SetChapter('Memories');TEST_PREPARE_BOOK()
assert(B.viewPreparing and not V.lastSaved)
drain();assert(#V.lastSaved==600)
local state=assert(upvalue(P.Page,'active'));assert(state.positions[c.order[1]])
local worker=assert(upvalue(P.Tick,'frame'));assert(not worker:IsShown())
local row=B.left.pool.memoryCard[5];local oldClick=row:GetScript('OnClick')
local focus=assert(N.Find(row));assert(N.Focus(focus));local identity=focus.id
B.left.scroll:SetVerticalScroll(137);assert(B.left.scroll:GetVerticalScrollRange()>137)
local input=B.nav.pool.edit[1];local draft='Unsubmitted album filter';input:SetText(draft)
local weak=setmetatable({state=state,positions=state.positions,rows=V.lastSaved},{__mode='v'});state=nil
B.Close(true)
assert(not upvalue(P.Page,'active')and not upvalue(P.Tick,'scheduled')and not worker:IsShown())
assert(not V.lastSaved and not V.lastReport)
collectgarbage('collect');collectgarbage('collect')
assert(not weak.state and not weak.positions and not weak.rows,'Closing must release all-history positions and saved-page results')

-- Canonical additions and corrections remain recorded without maintaining the
-- retired view or redrawing it. Old row callbacks cannot reopen stale results.
local render=B.Render;local renders=0;B.Render=function(...)renders=renders+1;return render(...)end
local latest=assert(M.Create(c,A.Now()));latest.title='Recorded while closed';S.Changed(c,latest)
S.Note(c,'record:'..latest.id,'Keep this exact note.',A.Now())
for _=1,6000 do P.Tick()end
oldClick();assert(renders==0 and not upvalue(P.Page,'active')and not B.selected)
B.Render=render
B.Open();assert(B.viewPreparing and B.closedScroll and B.pendingInputDrafts)
B.left.scroll:SetVerticalScroll(0)
drain()
assert(#V.lastSaved==601 and V.lastSaved[#V.lastSaved]==latest and c.notes['record:'..latest.id].text=='Keep this exact note.')
assert(B.left.scroll:GetVerticalScroll()==137 and input:GetText()==draft and N.Current().id==identity,
    'Cold saved pages must restore scroll, unsubmitted query and semantic selection')

-- Abandoning an unfinished scan releases its coroutine and native worker.
B.Close(true);B.Open();assert(B.viewPreparing and worker:IsShown())
local pending=upvalue(P.Page,'active');weak.pending=pending;weak.scan=pending.seed or pending.build or pending.fold;pending=nil
B.Close(true);collectgarbage('collect');collectgarbage('collect')
assert(not weak.pending and not weak.scan and not worker:IsShown())

-- Temporary hides must retain a pending scan for Show-only restoration.
B.Open();assert(B.viewPreparing and worker:IsShown())
local retained=upvalue(P.Page,'active')
B.captureHiding=true;B.frame:Hide();B.captureHiding=false
for _=1,20 do P.Tick()end
assert(upvalue(P.Page,'active')==retained and upvalue(P.Tick,'scheduled')and worker:IsShown())
B.frame:Show();drain();assert(#V.lastSaved==601)
local ready=upvalue(P.Page,'active')
E.db.settings.combatClose=true;B.Combat(true);P.Tick();assert(upvalue(P.Page,'active')==ready)
B.Combat(false);assert(P.SamePage(c,B.memoryQuery,B.memoryPage))
B.Close(true)
print('PASS saved-page close memory: index collection, no hidden maintenance, recording continuity, cold restoration and temporary-hide resume')
