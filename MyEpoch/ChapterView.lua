local _,E=...
local V,B,K,U={},E.Book,E.Keepsakes,E.KeepsakeView;E.ChapterView=V
local states=setmetatable({},{__mode='k'})
local function state(c)
    if not states[c]then states[c]={page=1,query='',pickPage=1}end;return states[c]
end
function V.ReleaseView()
    for c,s in pairs(states)do
        K.Cancel(c,'chapter-picker');K.Cancel(c,'chapter-list')
        s.picker=nil;s.pickToken=nil;s.chapters=nil;s.chapterRevision=nil
    end
    -- Keep unsaved chapter definitions, query/page choices and edit ownership.
end
local function guard(c,r,fn)return U.Guard(c,r,fn)end
local function draft(r)
    local rule=r and r.selection or{}
    return {title=r and r.title or '',mode=rule.mode or 'range',fromDay=rule.fromDay or E.API.Day(E.API.Now()),
        throughDay=rule.throughDay or E.API.Day(E.API.Now()),kinds=E.Copy(rule.kinds or{}),mapIDs=E.Copy(rule.mapIDs or{}),
        groupIDs=E.Copy(rule.groupIDs or{}),included=E.SortedKeys(rule.included or{}),excluded=E.SortedKeys(rule.excluded or{})}
end
local function draftGuard(c,s,d,fn)
    return guard(c,nil,function(...)if s.draft==d then return fn(...)end end)
end
local function input(page,c,s,d,value,change)
    local update=draftGuard(c,s,d,change)
    local edit=B.Input(page,value,update);edit:SetScript('OnTextChanged',function(self,user)if user then update(self:GetText())end end);return edit
end
local function listContains(list,id)for _,key in ipairs(list)do if key==id then return true end end end
local function toggle(list,id)
    for i,key in ipairs(list)do if key==id then table.remove(list,i);return end end;list[#list+1]=id
end
local function refresh()B.Render()end
local function preparePicker(c,s)
    local catalog=U.Catalog(c);if not catalog then return end
    local token=tostring(catalog.generation or catalog.revision)..'\n'..s.query
    if s.pickToken~=token and not K.Pending(c,'chapter-picker')then
        local query=s.query:lower()
        K.Queue(c,'chapter-picker',function(work)
            local result={rows={},types={},groups={},maps=catalog.maps}
            for _,r in ipairs(catalog.rows)do work()
                if E.Chapters.Source(c,r)then
                    result.types[r.kind]=E.Display.Kind(r.kind)
                    if query==''or tostring(E.Display.RecordTitle(r)or''):lower():find(query,1,true)then result.rows[#result.rows+1]=r end
                end
            end
            for _,r in ipairs(catalog.groups)do work();result.groups[r.id]=E.Display.RecordTitle(r)end
            return result
        end,function(result)s.picker=result;s.pickToken=token;U.dirty=c end,function()return U.Generation(c)end)
    end
    return s.pickToken==token and s.picker
end
local function chooser(page,c,s,d,picker)
    B.Text(page,E.L['Find entries to add or leave out'],15)
    B.Input(page,s.query,draftGuard(c,s,d,function(value)s.query=value;s.pickPage=1;refresh()end))
    local rows=picker and picker.rows
    if not rows then B.viewPreparing=true;B.Text(page,E.L['Finding your entries…'],14);return end
    local pages=math.max(1,math.ceil(#rows/8));s.pickPage=math.min(pages,s.pickPage)
    for i=(s.pickPage-1)*8+1,math.min(#rows,s.pickPage*8)do local r=rows[i]
        if E.Chapters.Source(c,r)then
        local mark=listContains(d.included,r.id)and 'Include'or listContains(d.excluded,r.id)and 'Exclude'or 'Automatic'
        B.Text(page,E.Display.RecordTitle(r)..' / '..E.API.RecordDate(r),14)
        B.Tabs(page,{'Include','Exclude','Automatic'},mark,guard(c,r,draftGuard(c,s,d,function(action)
            if listContains(d.included,r.id)then toggle(d.included,r.id)end
            if listContains(d.excluded,r.id)then toggle(d.excluded,r.id)end
            if action=='Include'then d.included[#d.included+1]=r.id elseif action=='Exclude'then d.excluded[#d.excluded+1]=r.id end
            refresh()
        end)))
        end
    end
    B.Text(page,E.Format('Page {page} of {pages}',{page=s.pickPage,pages=pages}),12)
    B.Tabs(page,{'Previous page','Next page'},nil,draftGuard(c,s,d,function(choice)s.pickPage=math.max(1,math.min(pages,s.pickPage+(choice=='Previous page'and -1 or 1)));refresh()end))
end
local function editor(left,right,c,s)
    local d=s.draft;local current=s.editRecord
    local picker=preparePicker(c,s)
    U.Heading(left,'ADVENTURE CHAPTERS',current and 'Shape this chapter'or 'Start a chapter')
    B.Text(left,E.L['Title'],13);input(left,c,s,d,d.title,function(value)d.title=value end)
    B.Tabs(left,{'Date range','Hand-picked'},d.mode=='range'and'Date range'or'Hand-picked',draftGuard(c,s,d,function(choice)d.mode=choice=='Date range'and'range'or'picked';refresh()end))
    if d.mode=='range'then
        B.Text(left,E.L['From (local date)'],13);input(left,c,s,d,d.fromDay,function(value)d.fromDay=value end)
        B.Text(left,E.L['Through (local date)'],13);input(left,c,s,d,d.throughDay,function(value)d.throughDay=value end)
        B.Text(left,E.L['Leave a filter empty to include every match.'],12)
        local types,groups,maps=picker and picker.types or{},picker and picker.groups or{},picker and picker.maps or{}
        U.Select(left,'Event types',types,d.kinds,draftGuard(c,s,d,function(id)d.kinds[id]=not d.kinds[id]or nil;refresh()end),true)
        U.Select(left,'Locations',maps,d.mapIDs,draftGuard(c,s,d,function(id)d.mapIDs[id]=not d.mapIDs[id]or nil;refresh()end),true)
        U.Select(left,'Groups',groups,d.groupIDs,draftGuard(c,s,d,function(id)d.groupIDs[id]=not d.groupIDs[id]or nil;refresh()end),true)
        for _,entry in ipairs({{d.kinds,types},{d.mapIDs,maps},{d.groupIDs,groups}})do
            local selected={};for _,id in ipairs(E.SortedKeys(entry[1]))do selected[#selected+1]=entry[2][id]or tostring(id)end
            if #selected>0 then B.Text(left,table.concat(selected,', '),12)end
        end
    end
    B.Tabs(left,{'Save chapter','Cancel'},nil,draftGuard(c,s,d,function(action)
        if action=='Cancel'then s.draft=nil;s.error=nil;refresh();return end
        local r,err
        if current and not K.Record(c,current,'chapter')then s.error='This chapter is no longer available.';refresh();return end
        if current then r,err=E.Chapters.Edit(c,current.id,d)else r,err=E.Chapters.Create(c,d,E.API.Now())end
        if r then s.focus=current and current.id or r.id;s.draft=nil;s.error=nil else s.error=err end;refresh()
    end))
    if s.error then B.Text(left,E.L[s.error],14)end
    U.Heading(right,'YOUR SELECTION','Add a few personal touches')
    B.Text(right,E.L['Individual choices take priority over the chapter filters.'],14)
    chooser(right,c,s,d,picker)
end
function V.Open(c,id)
    if B.Character()~=c then return end
    B.chapter='Memories';B.memoryMode='chapters';B.selected=nil;local s=state(c);s.focus=id;s.draft=nil;B.Render(true)
end
function V.Render(left,right,c)
    B.selected=nil;local s=state(c);E.Chapters.Ensure(c)
    if s.draft then editor(left,right,c,s);return end
    U.Heading(left,'CHAPTER VIII · YOUR OWN STORIES','Adventure chapters')
    B.Text(left,E.L['Gather a few pages into a story of your own.'],15)
    B.Action(left,E.L['Start a chapter'],guard(c,nil,function()s.draft=draft();s.editID=nil;s.editRecord=nil;s.query='';s.pickPage=1;refresh()end))
    local chapters={}
    -- Only the model's small chapter registry is used here once available.
    local rows=E.Chapters.List and E.Chapters.List(c)
    if rows then chapters=rows else
        if not s.chapterRevision or s.chapterRevision~=c.revision then
            if not K.Pending(c,'chapter-list')then K.Queue(c,'chapter-list',function(work)
                local found={};for _,id in ipairs(c.order)do work();local r=c.records[id];if K.Record(c,r,'chapter')then found[#found+1]=r end end
                return found
            end,function(found)s.chapters=found;s.chapterRevision=c.revision;U.dirty=c end)end
        end
        if not s.chapters then B.viewPreparing=true end
        chapters=s.chapters or{}
    end
    local pages=math.max(1,math.ceil(#chapters/8));s.page=math.min(s.page,pages)
    for i=(s.page-1)*8+1,math.min(#chapters,s.page*8)do local r=chapters[i]
        B.Action(left,r.title or E.L['Untitled chapter'],guard(c,r,function()s.focus=r.id;refresh()end))
        B.Text(left,E.L[r.sealRequested and 'Sealing chapter…'or r.sealed and 'Sealed chapter'or'Open chapter'],12)
    end
    if #chapters>8 then B.Tabs(left,{'Previous page','Next page'},nil,guard(c,nil,function(choice)s.page=math.max(1,math.min(pages,s.page+(choice=='Previous page'and -1 or 1)));refresh()end))end
    local r=s.focus and c.records[s.focus]or chapters[#chapters]
    if K.Record(c,r,'chapter')then s.focus=r.id;V.Record(right,c,r)
    else U.Heading(right,'A NEW CHAPTER','Every adventure has a thread');B.Text(right,E.L['Choose entries by hand or let an open chapter gather matching days.'],16)end
end
function V.Record(page,c,r)
    if not K.Record(c,r,'chapter')then return end
    local s=state(c);local report=E.Chapters.Projection(c,r.id)
    B.Ribbon(page,E.L[r.sealed and'SEALED CHAPTER'or'OPEN CHAPTER']);B.Text(page,r.title or E.L['Untitled chapter'],29)
    E.ArtView.Record(page,c,r)
    local actions={'Edit selection'}
    if not r.sealRequested then actions[#actions+1]=r.sealed and'Reopen chapter'or'Seal chapter'else B.Text(page,E.L['Sealing chapter…'],14)end
    B.Tabs(page,actions,nil,guard(c,r,function(action)
        if action=='Edit selection'then s.focus=r.id;s.editID=r.id;s.editRecord=r;s.draft=draft(r);s.pickPage=1;B.chapter='Memories';B.memoryMode='chapters';B.selected=nil
        elseif r.sealed then E.Chapters.Reopen(c,r.id)else E.Chapters.Seal(c,r.id)end;refresh()
    end))
    if report then
        if report.activeSeconds and report.activeSeconds>0 then B.Text(page,E.Format('Active time on these dates: {time}',{time=E.LocaleDuration(report.activeSeconds)}),18)end
        if report.missingCount and report.missingCount>0 then B.Text(page,E.Format('{count} linked entries are no longer available.',{count=report.missingCount}),12)end
        if #(report.diaries or{})>0 then
            local section=B.Section(page,E.L['Days in this chapter']);U.Sources(page,c,report.diaries,'chapter-diaries:'..r.id,'chapterDiaryPage');B.EndSection(page,section)
        end
    end
    U.Keep(page,c,r);B.Note(page,'record:'..r.id,function()return K.Record(c,r,'chapter')end)
    B.Text(page,E.L['The chapter’s events'],20)
    if report then U.Sources(page,c,report.rows or{},'chapter-events:'..r.id,'chapterEventPage')else B.viewPreparing=true;B.Text(page,E.L['Gathering this chapter’s pages…'],14)end
end
E.On('CHAPTER_READY',function(c,r)
    if B.Character()==c and(B.selected==r.id or B.chapter=='Memories'and B.memoryMode=='chapters'and not state(c).draft)then U.dirty=c end
end)
