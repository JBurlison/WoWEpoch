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
    E.Wishes.Recover(c);E.Chapters.Ensure(c)
    MyEpoch_RicherReview=function(page)
        E.Book.Open();E.Book.ChangeCharacter(c.id)
        if page=='calendar'then
            local day=E.API.DayStart(c.records[c.state.reviewSecond].ts)
            if not c.state.calendarReview then
                c.state.calendarReview=true
                for i=1,180 do S.Add(c,'play',day+i*20,{ended=day+i*20+10,status='active',title='Observed active time'})end
                S.Add(c,'play',day,{ended=day+12600,status='active',title='Observed active time'})
                E.Diary.SaveDaily(c,day,E.API.ShiftDay(day,1),E.API.Now())
            end
            E.Book.SetChapter('Calendar');E.CalendarView.SelectDay(day);E.Book.Render(true)
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
