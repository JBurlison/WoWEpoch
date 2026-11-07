local _,E=...
local V,B,K,S,A={},E.Book,E.Keepsakes,E.Store,E.API;E.WishView=V
local states=setmetatable({},{__mode='k'})
local kinds={{'freeform','A wish of my own'},{'level','Character level'},{'skill','Profession or weapon skill'},
    {'acquire','Acquire an item'},{'craft','Craft an item'},{'gather','Gather an item'},{'quests','Complete quests'},{'locations','Visit locations'}}
local kindLabels={};for _,pair in ipairs(kinds)do kindLabels[pair[1]]=pair[2]end
local views={Active='active',Completed='completed',Archived='archived'}
function V.State(c)
    if not K.Owned(c)then return end
    if not states[c]then states[c]={owner=c,view='active',page=1,selectedShares={},includeNotes=true,targetPage=1,sourcePage=1}end
    return states[c]
end
local function valid(c,state)return K.Owned(c)and B.Character()==c and V.State(c)==state end
local function action(c,state,fn)return function(...)if valid(c,state)then return fn(...)end end end
local function draftAction(c,state,draft,fn)
    return action(c,state,function(...)if state.draft==draft then return fn(...)end end)
end
local function heading(page,kicker,title)
    B.Text(page,E.L[kicker],11):SetTextColor(.54,.40,.23);B.Text(page,title,29)
end
local function redraw()B.Render()end
local function field(page,label,value,changed,multiline)
    B.Text(page,E.L[label],13)
    local f=B.Input(page,value or '',changed)
    if multiline then f:SetMultiLine(true);f:SetHeight(120);f:SetScript('OnEnterPressed',nil);page.y=page.y+82 end
    f:SetScript('OnTextChanged',function(self,user)if user then changed(self:GetText(),true)end end)
    return f
end
local function message(page,state)
    if state.message then B.Text(page,E.L[state.message],14)end
end
local function pageControls(page,state,key,count,size)
    local pages=math.max(1,math.ceil(count/size));state[key]=math.max(1,math.min(state[key]or 1,pages))
    if pages>1 then
        B.Text(page,E.Format('Page {page} of {pages}',{page=state[key],pages=pages}),12)
        local y=page.y;local previous=B.Action(page,E.L['Previous page'],action(state.owner,state,function()state[key]=math.max(1,state[key]-1);redraw()end))
        local bottom=page.y;page.y=y
        local nextPage=B.Action(page,E.L['Next page'],action(state.owner,state,function()state[key]=math.min(pages,state[key]+1);redraw()end))
        nextPage:ClearAllPoints();nextPage:SetPoint('TOPRIGHT',page.content,'TOPLEFT',12+B.Width(page),-y)
        previous:SetAlpha(state[key]>1 and 1 or .4);nextPage:SetAlpha(state[key]<pages and 1 or .4)
        page.y=math.max(bottom,page.y)
    end
    return (state[key]-1)*size+1,math.min(count,state[key]*size)
end
local function targetName(kind,id,fallback)
    if kind=='skill'then return E.Display.Skill(id,fallback)..' ['..id..']'end
    if kind=='quests'then return E.Display.Quest(id,fallback)..' ['..id..']'end
    if kind=='locations'then return E.Display.Map(id,fallback)..' ['..id..']'end
    return E.Display.Item(id,fallback)..' ['..id..']'
end
local function draftTarget(state,id)
    local d=state.draft;if not d or not K.ID(id)then state.message='Choose a valid target ID.';return end
    if d.goalType=='quests'or d.goalType=='locations'then
        d.target.ids=d.target.ids or{};for _,old in ipairs(d.target.ids)do if old==id then return end end
        d.target.ids[#d.target.ids+1]=id
    elseif d.goalType=='skill'then d.target.skillID=id
    else d.target.itemID=id end
    state.message=nil
end
local function candidates(c,state)
    local d=state.draft;local kind=d.goalType;local query=(state.targetQuery or ''):lower()
    local function generation()return E.KeepsakeView.Generation(c)end
    local key=kind..'\0'..query;local revision=generation()
    if state.catalog and state.catalog.key==key and state.catalog.revision==revision then return state.catalog.rows end
    if state.catalogPending==key then return end
    state.catalogPending=key
    K.Queue(c,'wish-target-picker',function(work)
        local seen,rows={},{}
        local function add(id,name)
            work();if K.ID(id)and not seen[id]then
                seen[id]=true;local label=targetName(kind,id,name)
                if query==''or label:lower():find(query,1,true)then rows[#rows+1]={id=id,label=label}end
            end
        end
        for _,recordID in ipairs(c.order)do
            work();local r=c.records[recordID]
            if K.Record(c,r)then
                if kind=='skill'then
                    if r.skillID then add(r.skillID,r.skillName)end
                    for _,skill in ipairs(r.characterSnapshot and r.characterSnapshot.skills or{})do add(skill.id,skill.name)end
                elseif kind=='quests'then add(r.questID,r.title)
                elseif kind=='locations'then add(r.mapID,r.zone)
                else
                    add(r.itemID,r.title)
                    for _,slot in ipairs(r.characterSnapshot and r.characterSnapshot.equipment or{})do add(slot.itemID,slot.name)end
                end
            end
        end
        E.RetentionWork.Sort(rows,function(a,b)return a.label<b.label end,work)
        return {key=key,revision=generation(),rows=rows}
    end,function(result)
        if V.State(c)~=state then return end
        state.catalogPending=nil;state.catalog=result
        if valid(c,state)and B.chapter=='Memories'and B.memoryMode=='wishes'and state.draft then E.KeepsakeView.dirty=c end
    end,generation)
end
local function picker(page,c,state)
    local d=state.draft;local kind=d.goalType;local group=B.Section(page,E.L['Choose the target'])
    local function guarded(fn)return draftAction(c,state,d,fn)end
    local ids=d.target.ids or{kind=='skill'and d.target.skillID or d.target.itemID}
    for i,id in ipairs(ids)do
        B.Action(page,targetName(kind,id)..'  ×',guarded(function()
            if d.target.ids then table.remove(d.target.ids,i)elseif kind=='skill'then d.target.skillID=nil else d.target.itemID=nil end;redraw()
        end))
    end
    field(page,'Find a recorded target',state.targetDraft or state.targetQuery or '',guarded(function(value,typing)
        state.targetDraft=value;if not typing then state.targetQuery=value;state.targetPage=1;state.catalog=nil;redraw()end
    end))
    local rows=candidates(c,state)
    if rows then
        local first,last=pageControls(page,state,'targetPage',#rows,6)
        for i=first,last do local row=rows[i];B.Action(page,row.label,guarded(function()draftTarget(state,row.id);redraw()end))end
        if #rows==0 then B.Text(page,E.L['No recorded targets match. You can enter an ID below.'],13)end
    else B.Text(page,E.L['Opening the target catalogue…'],13)end
    field(page,'Or enter an item, quest, skill or map ID',state.targetID or '',guarded(function(value,typing)
        state.targetID=value;if not typing then draftTarget(state,tonumber(value));state.targetID='';redraw()end
    end))
    B.EndSection(page,group)
end
function V.New(c)
    local state=V.State(c);if not state then return end
    state.draft={title='',goalType='freeform',target={},includeHistory=false,notes=''}
    state.selected=nil;state.shareMode=nil;state.targetPage=1;state.targetQuery='';state.targetDraft='';state.catalog=nil;state.message=nil
    B.selected=nil;redraw()
end
local function create(page,c,state)
    local d=state.draft;heading(page,'A LITTLE DREAM, A LITTLE DIRECTION',E.L['A new wish'])
    local function guarded(fn)return draftAction(c,state,d,fn)end
    field(page,'Give your wish a name',d.title,guarded(function(value)d.title=value end))
    local types={};for _,pair in ipairs(kinds)do types[#types+1]=pair[2]end
    B.Tabs(page,types,kindLabels[d.goalType],guarded(function(label)
        for _,pair in ipairs(kinds)do if pair[2]==label then d.goalType=pair[1];break end end
        d.target={};state.catalog=nil;state.targetPage=1;redraw()
    end))
    if d.goalType=='level'then field(page,'Target level',d.target.level and tostring(d.target.level)or'',guarded(function(value)d.target.level=tonumber(value)end))
    elseif d.goalType~='freeform'then
        picker(page,c,state)
        if d.goalType=='skill'then field(page,'Target skill rank',d.target.rank and tostring(d.target.rank)or'',guarded(function(value)d.target.rank=tonumber(value)end))
        elseif d.goalType~='quests'and d.goalType~='locations'then field(page,'Quantity to collect',d.target.quantity and tostring(d.target.quantity)or'',guarded(function(value)d.target.quantity=tonumber(value)end))end
    end
    if d.goalType~='freeform'then
        B.Tabs(page,{'From now','Include recorded history'},d.includeHistory and 'Include recorded history'or'From now',guarded(function(label)d.includeHistory=label=='Include recorded history';redraw()end))
    end
    field(page,'A few words for the journey',d.notes,guarded(function(value)d.notes=value end),true)
    message(page,state)
    B.Action(page,E.L['Keep this wish'],guarded(function()
        local goal,err=E.Wishes.Create(c,d,A.Now());state.message=err
        if goal then state.draft=nil;state.selected=goal.id;state.view='active';state.page=1 end;redraw()
    end))
    B.Action(page,E.L['Cancel'],guarded(function()state.draft=nil;state.message=nil;redraw()end))
end
local targetSummary
local function share(page,c,state)
    heading(page,'WISHES TRAVEL WELL',E.L[state.shareMode=='import'and "Bring in a friend's wishes"or'Share a wish list'])
    if state.shareMode=='export'then
        B.Text(page,E.L['Choose wishes on the left, then copy the text below for a friend.'],14)
        B.Tabs(page,{'Include notes','Leave notes out'},state.includeNotes and'Include notes'or'Leave notes out',action(c,state,function(label)state.includeNotes=label=='Include notes';state.shareText=nil;redraw()end))
        B.Action(page,E.L['Prepare sharing text'],action(c,state,function()
            local ids={};for _,goal in ipairs(E.Wishes.List(c,'all'))do if state.selectedShares[goal.id]then ids[#ids+1]=goal.id end end
            state.shareText,state.message=E.WishSharing.Export(c,ids,state.includeNotes);redraw()
        end))
        if state.shareText then
            B.Text(page,E.L['Select this text and copy it.'],13)
            local edit=field(page,'Shared wishes',state.shareText,function()end,true)
            edit.controllerLiteral=true
            edit:SetHeight(200);page.y=page.y+80
        end
    else
        B.Text(page,E.L['A friend supplies the inspiration. Your progress and memories start here.'],14)
        field(page,'Paste your friend’s sharing text',state.importText or'',action(c,state,function(value)state.importText=value;state.preview=nil end),true).controllerLiteral=true
        B.Action(page,E.L['Review these wishes'],action(c,state,function()state.preview,state.message=E.WishSharing.Preview(state.importText or'');redraw()end))
        if state.preview then
            local preview=state.preview;local definitions=preview.goals
            B.Text(page,E.Format('{count} wishes ready to bring in',{count=#definitions}),19)
            local first,last=pageControls(page,state,'previewPage',#definitions,6)
            for i=first,last do local definition=definitions[i]
                B.Text(page,definition.title or E.L['Wish'],16)
                B.Text(page,E.L[kindLabels[definition.goalType]or'Wish']..' / '..targetSummary(definition),13)
                if definition.notes and definition.notes~=''then B.Text(page,definition.notes,13)end
            end
            B.Action(page,E.L['Bring these wishes into my book'],action(c,state,function()
                if state.shareMode~='import'or state.preview~=preview then return end
                local added,err=E.WishSharing.Import(c,preview,A.Now());state.message=err
                if added then state.shareMode=nil;state.preview=nil;state.importText=nil;state.view='active';state.selected=added[1]and added[1].id;state.message='Your new wishes are ready.'end
                redraw()
            end))
        end
    end
    message(page,state)
    B.Action(page,E.L['Back to my wishes'],action(c,state,function()state.shareMode=nil;state.message=nil;redraw()end))
end
targetSummary=function(r)
    local t=r.target or{};local kind=r.goalType
    if kind=='level'then return E.Format('Reach level {level}',{level=t.level or'?'})end
    if kind=='skill'then return targetName(kind,t.skillID or 0)..' / '..tostring(t.rank or'?')end
    if kind=='quests'or kind=='locations'then
        local names={};for _,id in ipairs(t.ids or{})do names[#names+1]=targetName(kind,id)end;return table.concat(names,'\n')
    end
    if kind=='acquire'or kind=='craft'or kind=='gather'then return targetName(kind,t.itemID or 0)..' × '..tostring(t.quantity or'?')end
    return E.L['A wish of my own']
end
local function sources(page,c,r,state)
    local function generation()return E.KeepsakeView.Generation(c)end
    local cached=state.sources
    if not cached or cached.id~=r.id or cached.revision~=generation()then
        if not K.Pending(c,'wish-visible-sources')then
            K.Queue(c,'wish-visible-sources',function(work)
                local rows={};for _,id in ipairs(r.refs or{})do work();local source=c.records[id]
                    if K.VisibleSource(c,source)and source.kind~='memory'then rows[#rows+1]=source end
                end
                return {id=r.id,revision=generation(),rows=rows}
            end,function(result)
                if V.State(c)~=state then return end
                state.sources=result
                if valid(c,state)and(B.selected==r.id or B.chapter=='Memories'and B.memoryMode=='wishes'and state.selected==r.id and not state.draft and not state.shareMode)then E.KeepsakeView.dirty=c end
            end,generation)
        end
        if not cached or cached.id~=r.id then
            if #(r.refs or{})>0 then B.Text(page,E.L['Opening the supporting pages…'],13)end
            return
        end
    end
    local rows=cached.rows
    if #rows==0 then return end
    B.Text(page,E.L['The steps along the way'],20)
    rows=E.SourceFilters.Controls(page,rows,'wish:'..r.id)
    local first,last=pageControls(page,state,'sourcePage',#rows,8)
    for i=first,last do local source=rows[i];B.Action(page,E.Display.RecordTitle(source),action(c,state,function()E.SearchView.Open({character=c.id,record=source.id})end))end
end
function V.Record(page,c,r)
    if not K.Record(c,r,'goal')then return end
    local state=V.State(c)
    heading(page,'A WISH FOR THE ROAD',r.title or E.L['Wish'])
    local status=r.archived and'archived'or r.status or'active';B.Text(page,E.L[({active='In progress',completed='Completed',archived='Archived'})[status]or status],13)
    local group=B.Section(page,E.L[kindLabels[r.goalType]or'Wish'])
    if r.goalType~='freeform'then B.Text(page,targetSummary(r),18)end
    local progress=r.goalType~='freeform'and r.progress or nil
    if type(progress)=='table'then
        local current=progress.current or progress.value or progress.count
        local target=progress.target or progress.required
        if progress.known==false then B.Text(page,E.L['Progress has not been observed yet.'],16)
        elseif current~=nil then B.Text(page,E.Format('Recorded progress: {current} / {target}',{current=current,target=target or'?' }),16)end
        if #(progress.inferredRefs or{})>0 then B.Text(page,E.L['Includes accepted inferred evidence'],13)end
    elseif type(progress)=='number'then B.Text(page,E.Format('Recorded progress: {current}',{current=progress}),16)end
    if r.manualCompleted then B.Text(page,E.L['Completed by you'],14)end
    if r.evidenceRevised then B.Text(page,E.L['The recorded evidence changed. Your memory and notes are kept.'],14)end
    B.EndSection(page,group)
    if E.ArtView then E.ArtView.Record(page,c,r)end
    B.Action(page,E.L['Choose wish illustration'],action(c,state,function()if K.Record(c,r,'goal')then E.ArtDialog.OpenRecord(r)end end))
    local function change(mode)
        local ok,err=E.Wishes.SetStatus(c,r,mode);state.message=err;if ok then state.view=r.archived and'archived'or r.status or'active'end;redraw()
    end
    if status=='completed'then B.Action(page,E.L['Reopen this wish'],action(c,state,function()change('reopen')end))
    elseif status~='archived'then B.Action(page,E.L['Mark this wish complete'],action(c,state,function()change('complete')end))end
    if status=='archived'then B.Action(page,E.L['Return to active wishes'],action(c,state,function()change('restore')end))
    else B.Action(page,E.L['Archive this wish'],action(c,state,function()change('archive')end))end
    if r.completionMemory and K.Record(c,c.records[r.completionMemory],'memory')then
        B.Action(page,E.L['Open the completion memory'],action(c,state,function()E.SearchView.Open({character=c.id,record=r.completionMemory})end))
    end
    B.Action(page,r.starred and E.L['Unstar this memory']or E.L['Star and protect this memory'],action(c,state,function()if K.Record(c,r,'goal')then r.starred=not r.starred;S.Changed(c,r);redraw()end end))
    B.Note(page,'record:'..r.id,function()return K.Record(c,r,'goal')end)
    sources(page,c,r,state);message(page,state)
end
function V.Open(goalID)
    local c=B.Character();local state=V.State(c);if not state then return end
    B.chapter='Memories';B.memoryMode='wishes';B.selected=nil;state.draft=nil;state.shareMode=nil
    if goalID and K.Record(c,c.records[goalID],'goal')then state.selected=goalID;state.view=c.records[goalID].archived and'archived'or c.records[goalID].status or'active'end
    B.Render(true)
end
function V.Render(left,right,c)
    c=c or B.Character();local state=V.State(c);if not state then return end
    E.Wishes.Recover(c);B.selected=nil
    state.dirty=false;state.pending=E.Wishes.Pending(c)
    heading(left,'LITTLE WISHES, LONG ROADS',E.L['Wish list'])
    B.Text(left,E.L['A few dreams to carry in your pack.'],16)
    B.Tabs(left,{'Active','Completed','Archived'},state.view=='completed'and'Completed'or state.view=='archived'and'Archived'or'Active',action(c,state,function(label)state.view=views[label];state.page=1;state.selected=nil;redraw()end))
    B.Action(left,E.L['Write a new wish'],action(c,state,function()V.New(c)end))
    local rows=E.Wishes.List(c,state.view)
    local first,last=pageControls(left,state,'page',#rows,8)
    if #rows==0 then B.Text(left,E.L[state.pending and'Opening your wishes…'or'No wishes on this page yet.'],17)end
    for i=first,last do local r=rows[i]
        local title=state.shareMode=='export'and(state.selectedShares[r.id]and'[x] 'or'[ ] ')..(r.title or E.L['Wish'])or r.title or E.L['Wish']
        local button=B.Action(left,title,action(c,state,function()
            if state.shareMode=='export'then state.selectedShares[r.id]=not state.selectedShares[r.id]or nil;state.shareText=nil
            else state.selected=r.id;state.draft=nil;state.shareMode=nil;state.sourcePage=1;state.message=nil end;redraw()
        end))
        button:SetWidth(B.Width(left));button.text:SetWidth(B.Width(left)-28)
        E.BookTheme.ButtonStyle(button,state.selected==r.id and'filter'or nil)
        B.Text(left,E.L[kindLabels[r.goalType]or'Wish'],12)
    end
    local group=B.Section(left,E.L['Pass a little inspiration along'])
    B.Action(left,E.L['Share a wish list'],action(c,state,function()state.shareMode='export';state.draft=nil;state.shareText=nil;state.message=nil;redraw()end))
    B.Action(left,E.L["Bring in a friend's wishes"],action(c,state,function()state.shareMode='import';state.draft=nil;state.preview=nil;state.message=nil;redraw()end))
    B.EndSection(left,group)
    if state.draft then create(right,c,state)
    elseif state.shareMode then share(right,c,state)
    else
        local selected=c.records[state.selected]
        if not K.Record(c,selected,'goal')then selected=rows[1];state.selected=selected and selected.id end
        if selected then V.Record(right,c,selected)
        else heading(right,'ROOM FOR A NEW DREAM',E.L['What would you like to do next?']);B.Text(right,E.L['Write a wish, choose a target, or bring in a little inspiration from a friend.'],17)end
    end
end
E.On('RECORD_CHANGED',function(c,r)if r.kind=='goal'and states[c]then states[c].dirty=true end end)
E.On('WISHES_UPDATED',function(c)
    local state=states[c]
    if not state or not(state.pending or state.dirty)or not valid(c,state)or not B.frame or not B.frame:IsShown()
        or B.chapter~='Memories'or B.memoryMode~='wishes'or state.draft or state.shareMode then return end
    -- Live progress should not move the caret out from under someone's notes.
    for _,page in ipairs({B.left,B.right})do for i=1,page.used.edit or 0 do local f=page.pool.edit[i]
        if f.HasFocus and f:HasFocus()then return end
    end end
    redraw()
end)
