-- Synthetic review history, included only by the private browser build.
local _,E=...
local function seed()
    local id='myepoch-richer-review-v3';local S=E.Store
    if not E.db then return end
    local c=S.Character(id,{name='Aldren · Review',class='Warrior',level=22,realm='Design fixture',faction='Alliance'})
    if not c.state.richerReview then
        c.state.richerReview=true
        local now=E.API.DayStart(E.API.Now())-86400+14*3600
        local a={version=1,character=id,capturedAt=now-86400,equipment={},stats={{key='strength',label='Strength',value=44},{key='health',label='Health',value=612},{key='crit',label='Critical strike',value=3.4,unit='%'}},skills={{id=43,name='Swords',rank=75,maxRank=100},{id=164,name='Blacksmithing',rank=65,maxRank=150}}}
        for i=1,19 do a.equipment[i]={slot=i,status='empty'}end
        a.equipment[16]={slot=16,status='equipped',itemID=25,link='item:25',name='Worn Shortsword',quality=1,icon=135274}
        local b=E.Copy(a);b.capturedAt=now;b.equipment[16]={slot=16,status='equipped',itemID=935,link='item:935',name='Night Watch Shortsword',quality=3,icon=135274}
        b.stats[1].value=51;b.stats[2].value=748;b.stats[3].value=4.1;b.skills[1].rank=100;b.skills[1].maxRank=125;b.skills[2].rank=75
        local first=S.Add(c,'milestone',now-86400,{subject=id,major=true,milestoneType='level',before=20,after=21,title='Character level 21',characterSnapshot=a,zone='Westfall',mapID=1436,artMode='fixed',artID='westfall-04'})
        local second=S.Add(c,'milestone',now,{subject=id,major=true,milestoneType='level',before=21,after=22,title='Character level 22',characterSnapshot=b,zone='Westfall',mapID=1436,artMode='fixed',artID='westfall-04'})
        local loot=S.Add(c,'loot',now-600,{itemID=935,itemLink='item:935',title='Night Watch Shortsword',quantity=1,recipient=id,zone='Westfall',mapID=1436,vendorUnitValue=174})
        local quest=S.Add(c,'quest',now-300,{questID=166,title='The Defias Brotherhood',status='completed',zone='Westfall',mapID=1436})
        S.Add(c,'play',now-3600,{ended=now,seconds=3600,status='active',session='review'})
        local chapter=E.Chapters.Create(c,{title='An afternoon along the coast',mode='picked',included={loot.id,quest.id,second.id}},now)
        chapter.artMode='fixed';chapter.artID='westfall-04';S.Note(c,'record:'..chapter.id,'The sea air, the old lighthouse, and one very stubborn crab.',now)
        local wish=E.Wishes.Create(c,{title='A blade worth remembering',goalType='acquire',target={itemID=935,quantity=1},includeHistory=true,notes='A little something to work toward with friends.'},now)
        wish.artMode='fixed';wish.artID='westfall-04'
        E.Wishes.Create(c,{title='Learn to cook a proper camp supper',goalType='freeform',notes='Invite someone who did the cooking last time.'},now)
        c.state.reviewFirst=first.id;c.state.reviewSecond=second.id;c.state.reviewChapter=chapter.id;c.state.reviewWish=wish.id
    end
    local reviewRecord=c.records[c.state.reviewRecord]
    if reviewRecord and reviewRecord.recordType=='crafted'and not reviewRecord.recordKey then
        reviewRecord.recordKey='baseline:crafted';S.Changed(c,reviewRecord)
    end
    E.Wishes.Recover(c);E.Chapters.Ensure(c)
    local reviewTimer
    MyEpoch_RicherReviewStatus=function(steps)
        for i=1,math.min(1000,tonumber(steps)or 0)do E.Keepsakes.Process(500)end
        local owner=E.Book.Character()
        print('Review recording ready',E.RecorderReady(),'pending',E.Keepsakes.Pending(owner,'comparison-choices'))
        print('Review owner',owner and owner.id,'live',E.current and E.current.id)
        E.Keepsakes.Process(500)
    end
    E.On('KEEPSAKE_JOB_FAILED',function(_,key,err)print('Review preparation failed',key,tostring(err))end)
    MyEpoch_RicherReview=function(page)
        E.Book.Open();E.Book.ChangeCharacter(c.id)
        if page=='compare-current'then
            local live=E.current;if not live then return end
            local target=live.records[live.state.reviewCompareFinal]
            if not target then
                local now=E.API.Now();local kinds={'level','discovery','profession','skill','achievement','quest_chain','level'}
                for i,kind in ipairs(kinds)do
                    local snap=E.Copy(c.records[c.state.reviewFirst].characterSnapshot)
                    snap.character=live.id;snap.capturedAt=now-(#kinds-i)*3600
                    snap.equipment[5]={slot=5,status='equipped',itemID=2576,link='item:2576',name='White Linen Shirt'}
                    if i==#kinds then snap.equipment[16]={slot=16,status='equipped',itemID=935,link='item:935',name='Night Watch Shortsword'}end
                    target=S.Add(live,'milestone',snap.capturedAt,{subject=live.id,major=true,milestoneType=kind,title='REVIEW: '..kind..' milestone',characterSnapshot=snap,before=20,after=21})
                end
                live.state.reviewCompareFinal=target.id
            end
            E.Book.ChangeCharacter(live.id);E.ComparisonView.Open(live,target.id)
        elseif page=='kill-loot'then
            local now=E.API.Now();local k=c.records[c.state.reviewLootKill]
            if not k then
                k=S.Add(c,'kill',now-20,{title='Hogger',npcName='Hogger',source='PARTY_KILL',session='loot-review',npcID=448,victimGUID='Creature-0-1-2-3-448-0001',mapID=1429,zone='Elwynn Forest',groupState='solo'})
                local w=S.Add(c,'loot_window',now-10,{title='A handful of treasures',source='loot_window',session='loot-review',fromItem=false,fishing=false,originEvidence=1,mapID=1429,groupState='solo'})
                for slot,item in ipairs({{2589,'Linen Cloth',3},{1931,'Huge Gnoll Claw',1},{117,'Tough Jerky',2}})do
                    local d=S.Add(c,'drop',now-9,{title=item[2],source='loot_window',session='loot-review',window=w.id,slot=slot,itemID=item[1],itemLink='item:'..item[1],mapID=1429,snapshots={}})
                    local data={itemID=item[1],name=item[2],visibleQuantity=item[3]}
                    d.snapshots={{ts=now-9,sequence=S.ReserveObservation(c),data=data}};d.latest=data
                    S.Add(c,'loot',now-8,{title=item[2],itemID=item[1],itemLink='item:'..item[1],quantity=item[3],recipient=c.id,observedLootWindow=w.id,session='loot-review'})
                end
                c.state.reviewLootKill=k.id
            end
            E.SearchView.Open({character=c.id,record=k.id})
        elseif page=='combat'then
            local now=E.API.Now();local p=c.records[c.state.reviewPull]
            if not p then
                local g=S.Add(c,'group',now-90,{title='A few friends near the river',memberships={}})
                local sources={{name='Aldren',totalAmount=420,classFilename='WARRIOR',sourceGUID='Player-Review',detail={observedAt=now,spells={{spellID=6603,totalAmount=300,target={name='Hogger',isMob=true,amount=300}},{spellID=78,totalAmount=120,target={name='Hogger',amount=120}}}}},{name='A helpful rogue',totalAmount=120,classFilename='ROGUE'},{name='A cheerful mage',totalAmount=66,classFilename='MAGE'}}
                local sample={totalAmount=606,durationSeconds=47,observedAt=now,sources=sources,coverage='partial'}
                p=S.Add(c,'pull',now-47,{title='Hogger',recordingSession='combat-review',snapshots={DamageDone={sample,E.Copy(sample)},EnemyDamageTaken={{totalAmount=606,durationSeconds=47,observedAt=now,sources={{sourceCreatureID=448,name='Hogger',totalAmount=606}}}}},contexts={{from=now-47,through=now,mapID=1429,zone='Elwynn Forest',group=g.id}},gaps={},observedGroups={[g.id]=true},refs={g.id}})
                S.Add(c,'kill',now-7,{title='Hogger',session='combat-review',source='PARTY_KILL',npcID=448,victimGUID='Creature-Review-Hogger',group=g.id,mapID=1429,zone='Elwynn Forest',position={mapID=1429,x=.265,y=.935,space='uiMap',unit='player'},refs={g.id}})
                c.state.reviewPull=p.id
            end
            E.Book.chapter='Company';E.Book.companyMode='pulls';E.Book.selected=p.id;E.Book.Render(true)
        elseif page=='calendar-live'then
            local now=E.API.Now();local day=E.API.DayStart(now)
            local r=S.Add(c,'play',now-45,{ended=now,status='active',title='Observed active time'})
            S.Add(c,'quest',now-20,{status='completed',title='A quiet page to write on'})
            E.Book.SetChapter('Calendar');E.CalendarView.SelectDay(day)
            if not reviewTimer then reviewTimer=CreateFrame('Frame')end
            local elapsed,count=0,0
            reviewTimer:SetScript('OnUpdate',function(self,delta)
                elapsed=elapsed+delta;if elapsed<1 then return end;elapsed=0;count=count+1
                r.ended=E.API.Now();S.Changed(c,r)
                if count>=120 then self:SetScript('OnUpdate',nil)end
            end)
        elseif page=='calendar'then
            local day=E.API.DayStart(c.records[c.state.reviewSecond].ts)
            if not c.state.calendarReview then
                c.state.calendarReview=true
                for i=1,180 do S.Add(c,'play',day+i*20,{ended=day+i*20+10,status='active',title='Observed active time'})end
                S.Add(c,'play',day,{ended=day+12600,status='active',title='Observed active time'})
                E.Diary.SaveDaily(c,day,E.API.ShiftDay(day,1),E.API.Now())
            end
            E.Book.SetChapter('Calendar');E.CalendarView.SelectDay(day);E.Book.Render(true)
        elseif page=='memory-edit'then
            local r=c.records[c.state.reviewMemory]
            if not r then r=E.Memories.Create(c,E.API.Now(),c.state.reviewSecond);c.state.reviewMemory=r.id
                E.Memories.Edit(c,r.id,'title','The crab had other plans');E.Memories.Edit(c,r.id,'text','We brought a picnic. The crab brought an appetite.')
            end
            r.artMode='fixed';r.artID='westfall-04'
            E.Book.chapter='Memories';E.Book.memoryMode='saved';E.Book.selected=r.id;E.Book.memoryFocus=r.id;E.Book.memoryEditID=r.id;E.Book.memoryEditing=true;E.Book.Render(true)
        elseif page=='record-rows'then
            local now=E.API.Now();local day=E.API.ShiftDay(E.API.DayStart(now),-1);local r=c.records[c.state.reviewRecord]
            if not r then
                local refs={}
                for i=1,4 do local item=S.Add(c,'crafted',day+3600+i*600,{recipient=c.id,itemID=2840,itemLink='item:2840',quantity=i,title='Copper Bar'});refs[#refs+1]=item.id end
                r=S.Add(c,'personal_record',day+86399,{recordType='crafted',recordKey='baseline:crafted',title='Most items crafted in a day',unit='count',value=10,from=day,through=E.API.ShiftDay(day,1),refs=refs,valid=true,baseline=true})
                local state=E.Keepsakes.State(c);state.personalRecords=state.personalRecords or{ids={},enabled={}};table.insert(state.personalRecords.ids,r.id);c.state.reviewRecord=r.id
            end
            E.Book.chapter='Chronicle';E.Book.chronicleMode='records';E.Book.personalRecord=r.id;E.Book.personalRecordTab='Personal bests';E.Book.selected=nil;E.Book.Render(true)
        elseif page=='daily-recap'then
            local now=E.API.Now();local day=E.API.ShiftDay(E.API.DayStart(now),-1);local r=c.records[c.state.reviewRecap]
            c.state.recapLoginThrough=E.API.DayStart(now)
            if not r then r=S.Add(c,'recap',E.API.ShiftDay(day,1),{title='Daily recap',key='daily:'..E.API.Day(day),periodKind='daily',from=day,through=E.API.ShiftDay(day,1),read=true,readGeneration=1,generation=1,refs={},facts={},text='A small adventure, safely kept.'});c.state.reviewRecap=r.id end
            E.Book.chapter='Recaps';E.Book.recapKind='daily';E.Book.recapFocus=r.id;E.Book.recapDate=day;E.Book.selected=r.id;E.Book.Render(true)
        elseif page=='toast'then
            E.Book.ChangeCharacter(E.current.id);E.Book.chapter='Archive';E.Book.archiveTab='notifications';E.Book.selected=nil;E.Book.Render(true);E.Notifications.Preview(E.current,'account')
        elseif page=='chapters'then E.ChapterView.Open(c,c.state.reviewChapter)
        elseif page=='wishes'then E.WishView.Open(c.state.reviewWish)
        elseif page=='items'then E.ItemStoryView.Open(c,935)
        elseif page=='records'then E.Book.chapter='Chronicle';E.Book.chronicleMode='records';E.Book.selected=nil;E.Book.Render(true)
        elseif page=='notifications'then E.Book.chapter='Archive';E.Book.archiveTab='notifications';E.Book.selected=nil;E.Book.Render(true)
        else E.ComparisonView.Open(c,c.state.reviewSecond)end
    end
end
local f=CreateFrame('Frame');f:SetScript('OnUpdate',function(self)if E.db and E.current then self:SetScript('OnUpdate',nil);seed()end end)
