local _,E=...
local V,B,X,K={},E.Book,E.SnapshotComparison,E.Keepsakes;E.ComparisonView=V
local states=setmetatable({},{__mode='k'})
local revisions=setmetatable({},{__mode='k'})
local filters={{'all','Major milestones'},{'level','Character levels'},{'achievement','Achievements'},
    {'discovery','Discoveries'},{'completion','First completions'},{'profession','Professions'},{'skill','Weapon skills'}}
local function category(r)
    local key=r.milestoneType
    return(key=='quest_chain'or key=='encounter')and'completion'or key
end
local function revision(c)return revisions[c]or 0 end
local function invalidate(c,r)
    local s=states[c]
    if not r or r.kind=='milestone'or s and s.choiceIDs and s.choiceIDs[r.id]then revisions[c]=revision(c)+1 end
end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function state(c)
    local s=states[c];if not s then s={tab='Equipment',pages={before=1,after=1},filters={before='all',after='all'},paperDolls={}};states[c]=s end;return s
end
function V.State(c)return state(c)end
local function current(c,s)return K.Owned(c)and B.Character()==c and states[c]==s and B.chapter=='Chronicle'and B.chronicleMode=='compare'end
local function redraw(c,s)if current(c,s)then B.Render()end end
local function prepare(c,s)
    if s.revision==revision(c) or K.Pending(c,'comparison-choices')then return end
    K.Queue(c,'comparison-choices',function(work)
        local rows=X.Choices(c,work);local groups={all=rows}
        for _,filter in ipairs(filters)do if filter[1]~='all'then groups[filter[1]]={}end end
        for _,r in ipairs(rows)do work();local group=groups[category(r)];if group and group~=rows then group[#group+1]=r end end
        return{rows=rows,groups=groups}
    end,function(result)
        local rows=result.rows;s.choiceGroups=result.groups
        s.choices=rows;s.revision=revision(c);s.choiceIDs={};for _,r in ipairs(rows)do s.choiceIDs[r.id]=true end
        if not X.Eligible(c,c.records[s.after])then s.after=rows[#rows]and rows[#rows].id end
        if not X.Eligible(c,c.records[s.before])then
            local previous
            for _,r in ipairs(rows)do if r.id==s.after then break end;previous=r end
            s.before=previous and previous.id or rows[1]and rows[1].id
            s.fresh=nil;s.currentUnavailable=s.useCurrent or nil
        end
        redraw(c,s)
    end,function()return revision(c)end)
end
function V.Open(c,selectedID)
    if not K.Owned(c)or B.Character()~=c then return false end
    local s=state(c)
    if selectedID and X.Eligible(c,c.records[selectedID])then s.after=selectedID;s.before=nil;s.revision=nil;s.fresh=nil;s.useCurrent=false end
    B.chronicleMode='compare';B.chapter='Chronicle';B.selected=nil;prepare(c,s);B.Render(true);return true
end
local function number(n)
    if not K.Number(n)then return E.L['Not recorded']end
    if n%1==0 then return E.Number(n)end
    return(string.format('%.2f',n):gsub('0+$',''):gsub('%.$',''))
end
local function delta(n,unit)
    if n==nil then return E.L['Change unknown']end
    local text=(n>0 and'+'or'')..number(n)
    return text..(unit=='pp'and' '..E.L['percentage points']or unit and unit~=''and' '..E.L[unit]or'')
end
local function title(r)return r and E.Display.RecordTitle(r)or E.L['Choose a milestone']end
local function fresh(c,s)
    s.fresh=X.Current(c,s.before);s.useCurrent=true;s.currentUnavailable=s.fresh==nil;s.freshRevision=c.revision
end
function V.CloseMenu()
    V.menuContext=nil
    if V.menu then V.menu:Hide()end
end
local function menuValid(context)
    return context and V.menuContext==context and current(context.c,context.s)and context.revision==revision(context.c)
end
local function menuButton(parent,label,fn)
    local f=CreateFrame('Button',nil,parent);f:SetHeight(32);E.BookTheme.Button(f)
    f.text=f:CreateFontString(nil,'OVERLAY');f.text:SetFont(E.Font(),13,'');f.text:SetPoint('LEFT',10,0)
    f.text:SetJustifyH('LEFT');f.text:SetMaxLines(1);f.text:SetText(label or'');E.BookTheme.ButtonStyle(f)
    f:SetScript('OnClick',fn);return f
end
function V.UpdateMenu()
    local ctx=V.menuContext;if not menuValid(ctx)then V.CloseMenu();return end
    local c,s,side=ctx.c,ctx.s,ctx.side;local selected=s.filters[side]or'all'
    local rows=s.choiceGroups and s.choiceGroups[selected]or{};local count=#rows
    local visible=math.min(8,count);ctx.offset=math.max(0,math.min(ctx.offset,math.max(0,count-8)))
    local live=side=='after'and E.current==c
    local filterHeight=102
    V.menuPanel:SetHeight(24+filterHeight+math.max(1,visible)*34+(live and 36 or 0)+36)
    local filterWidth=(ctx.width-32)/3
    for i,filter in ipairs(filters)do local f=V.menuFilters[i];local key=filter[1]
        f:SetWidth(filterWidth);f.text:SetWidth(filterWidth-16);f.text:SetText(E.L[filter[2]])
        f:ClearAllPoints();f:SetPoint('TOPLEFT',12+((i-1)%3)*(filterWidth+4),-12-math.floor((i-1)/3)*32)
        E.BookTheme.ButtonStyle(f,selected==key and'filter'or nil)
        f:SetScript('OnClick',function()
            if not menuValid(ctx)then V.CloseMenu();return end
            s.filters[side]=key;ctx.offset=0;V.UpdateMenu()
        end)
    end
    for i,f in ipairs(V.menuButtons)do
        local r=i<=visible and rows[count-ctx.offset-i+1]
        if r then
            f:Show();f:SetWidth(ctx.width-24);f.text:SetWidth(ctx.width-44)
            f:ClearAllPoints();f:SetPoint('TOPLEFT',12,-12-filterHeight-(i-1)*34)
            f.text:SetText(E.API.RecordDate(r)..' / '..title(r))
            E.BookTheme.ButtonStyle(f,s[side]==r.id and not(side=='after'and s.useCurrent)and'filter'or nil)
            f:SetScript('OnClick',function()
                if not menuValid(ctx)or not X.Eligible(c,r)then V.CloseMenu();return end
                s[side]=r.id
                if side=='after'then s.useCurrent=false;s.fresh=nil elseif s.useCurrent then fresh(c,s)end
                V.CloseMenu();redraw(c,s)
            end)
        else f:Hide();f:SetScript('OnClick',nil)end
    end
    if live then V.menuLive:Show()else V.menuLive:Hide()end
    V.menuLive:SetWidth(ctx.width-24);V.menuLive.text:SetWidth(ctx.width-44)
    V.menuLive:ClearAllPoints();V.menuLive:SetPoint('TOPLEFT',12,-12-filterHeight-math.max(1,visible)*34)
    V.menuLive:SetScript('OnClick',function()
        if not menuValid(ctx)or E.current~=c then V.CloseMenu();return end
        fresh(c,s);V.CloseMenu();redraw(c,s)
    end)
    V.menuCount:SetText(count==0 and E.Format('{count} matching records',{count=0})or E.Format('{first}–{last} of {count}',{first=ctx.offset+1,last=math.min(count,ctx.offset+8),count=count}))
    V.menuUp:EnableMouse(ctx.offset>0);V.menuUp:SetAlpha(ctx.offset>0 and 1 or .4)
    V.menuDown:EnableMouse(ctx.offset+8<count);V.menuDown:SetAlpha(ctx.offset+8<count and 1 or .4)
end
local function buildMenu()
    if V.menu then return end
    local menu=CreateFrame('Frame','MyEpochMilestoneDropdown',B.frame);V.menu=menu
    menu:SetAllPoints();menu:SetFrameStrata('FULLSCREEN_DIALOG');menu:SetFrameLevel(B.frame:GetFrameLevel()+100)
    local dismiss=CreateFrame('Button',nil,menu);V.menuDismiss=dismiss;dismiss:SetAllPoints();dismiss:SetScript('OnClick',V.CloseMenu)
    local panel=CreateFrame('Frame',nil,menu);V.menuPanel=panel;panel:SetFrameLevel(menu:GetFrameLevel()+2)
    panel:EnableMouse(true);panel:EnableMouseWheel(true);E.BookTheme.DialogPaper(panel)
    V.menuFilters={};for i=1,#filters do V.menuFilters[i]=menuButton(panel);V.menuFilters[i]:SetHeight(28)end
    V.menuButtons={}
    for i=1,8 do local f=menuButton(panel);V.menuButtons[i]=f;f:SetPoint('TOPLEFT',12,-12-(i-1)*34)end
    V.menuLive=menuButton(panel,E.L['Compare with current character'])
    V.menuCount=panel:CreateFontString(nil,'OVERLAY');V.menuCount:SetFont(E.Font(),12,'');V.menuCount:SetTextColor(.26,.15,.08)
    V.menuCount:SetPoint('BOTTOMLEFT',14,12);V.menuCount:SetJustifyH('LEFT')
    local function scroll(amount)if V.menuContext then V.menuContext.offset=V.menuContext.offset+amount;V.UpdateMenu()end end
    V.menuUp=menuButton(panel,E.L['Up'],function()scroll(-8)end);V.menuUp:SetWidth(66);V.menuUp:SetPoint('BOTTOMRIGHT',-82,6)
    V.menuDown=menuButton(panel,E.L['Down'],function()scroll(8)end);V.menuDown:SetWidth(66);V.menuDown:SetPoint('BOTTOMRIGHT',-12,6)
    panel:SetScript('OnMouseWheel',function(_,d)scroll(-d*3)end)
    menu:SetScript('OnHide',function()V.menuContext=nil end)
    menu:SetScript('OnUpdate',function()if V.menuContext and not menuValid(V.menuContext)then V.CloseMenu()end end);menu:Hide()
    UISpecialFrames=UISpecialFrames or{};UISpecialFrames[#UISpecialFrames+1]='MyEpochMilestoneDropdown'
end
local function openMenu(anchor,page,c,s,side)
    if not current(c,s)then return end
    if V.menuContext and V.menuContext.side==side then V.CloseMenu();return end
    buildMenu();V.menuContext={c=c,s=s,side=side,offset=0,revision=revision(c),width=B.Width(page)}
    V.menuPanel:ClearAllPoints();V.menuPanel:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-4);V.menuPanel:SetWidth(B.Width(page))
    V.menu:Show();V.UpdateMenu()
end
local function selector(page,c,s,side)
    local r=c.records[s[side]];local label=side=='after'and s.useCurrent and E.L['Current character — fresh reading']or title(r)
    local f
    f=B.Action(page,label..'  v',function()openMenu(f,page,c,s,side)end)
    if side=='after'and s.useCurrent then B.Action(page,E.L['Refresh current reading'],function()if current(c,s)then fresh(c,s);redraw(c,s)end end)end
end
local function font(p,size)
    local f=p:CreateFontString(nil,'OVERLAY');f:SetFont(E.Font(),size,'');f:SetTextColor(.29,.19,.11);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f
end
local function equipment(page,c,s,comparison,side)
    local snapshot=comparison[side];local pane=s.paperDolls[side]
    if not pane or pane.snapshot~=snapshot then pane={snapshot=snapshot,tab='Equipment',preview=true};s.paperDolls[side]=pane end
    local record=c.records[s[side]];local live=side=='after'and s.useCurrent
    local changed={};for _,row in ipairs(comparison.equipment)do if row.known and row.changed then changed[row.slot]=true end end
    E.MilestoneSnapshotView.PaperDoll(page,c,snapshot,pane,{fullWidth=true,changedSlots=changed,valid=function()
        if not current(c,s)or s.tab~='Equipment'or s.paperDolls[side]~=pane then return false end
        if live then return s.useCurrent and s.fresh and s.fresh.after==snapshot and E.current==c end
        return not(side=='after'and s.useCurrent)and c.records[s[side]]==record and X.Eligible(c,record)==snapshot
    end})
    if next(changed)then local label=B.Text(page,E.L['Changed'],12);label:SetTextColor(.17,.35,.13)end
end
B.widgetFactories.compareStat=function(p)
    local f=CreateFrame('Frame',nil,p);f.label=font(f,14);f.label:SetPoint('TOPLEFT',0,-8)
    f.value=font(f,17);f.value:SetJustifyH('RIGHT');f.value:SetPoint('TOPRIGHT',-126,-8)
    f.change=font(f,12);f.change:SetJustifyH('RIGHT');f.change:SetPoint('TOPRIGHT',0,-10)
    f.rule=f:CreateTexture(nil,'BACKGROUND');f.rule:SetPoint('BOTTOMLEFT');f.rule:SetPoint('BOTTOMRIGHT');f.rule:SetHeight(1);f.rule:SetColorTexture(.52,.36,.17,.25)
    return f
end
local function stats(left,right,comparison)
    local pages={{left,'before'},{right,'after'}}
    for _,row in ipairs(comparison.stats)do
        local frames,height={},44
        for i,pair in ipairs(pages)do
            local page,side=pair[1],pair[2]
            local entry=row[side];local other=row.before or row.after;local f=B.Acquire(page,'compareStat');f:SetWidth(B.Width(page));frames[i]=f
            local title=E.MilestoneSnapshotView.StatLabel(other or{key=row.key})
            if(row.key=='power'or row.key=='maxPower')and not row.compatible then
                local snap=comparison[side];title=title..' / '..E.L[snap.powerToken or'Unknown power type']
            end
            f.label:SetWidth(math.max(40,B.Width(page)-240));f.value:SetWidth(100);f.change:SetWidth(115)
            f.label:SetText(E.Text(title));f.value:SetText(number(entry and entry.value)..(entry and K.Number(entry.value)and entry.unit and' '..E.L[entry.unit]or''))
            f.change:SetText(side=='after'and delta(row.delta,row.unit)or'');f.change:SetTextColor(row.delta and row.delta<0 and .55 or .22,row.delta and row.delta<0 and .22 or .40,.18)
            height=math.max(height,f.label:GetStringHeight()+20,f.value:GetStringHeight()+20,f.change:GetStringHeight()+20)
        end
        -- Match each pair, not just the final page height: missing readings,
        -- translated labels and change text can wrap on only one side.
        for i,pair in ipairs(pages)do frames[i]:SetHeight(height);pair[1].y=pair[1].y+height end
    end
end
local function skills(page,comparison,side)
    for _,row in ipairs(comparison.skills)do
        local entry=row[side]or{};local other=row.before or row.after;local width=B.Width(page);local f=B.Acquire(page,'milestoneSkill');f:SetWidth(width);f.text:SetWidth(width)
        f.text:SetText(E.Text(E.Display.Skill(row.id,other and other.name)..(side=='after'and' / '..delta(row.delta)or'')))
        local rank,cap=K.Number(entry.rank,0),K.Number(entry.maxRank,1)
        f.value:SetWidth(width-12);f.value:SetText(number(rank)..' / '..number(cap));f.minimum:SetText('0');f.maximum:SetWidth(width*.5);f.maximum:SetText(E.L['Max']..' '..number(cap));f.bonus:Hide()
        if rank and cap and rank>0 then f.fill:SetWidth(math.max(.1,(width-4)*math.min(1,rank/cap)));f.fill:SetColorTexture(.27,.48,.25,1);f.fill:Show()else f.fill:Hide()end
        f:SetHeight(68);page.y=page.y+80
    end
    if #comparison.skills==0 then B.Text(page,E.L['Skills were not recorded.'],14)end
end
function V.SyncScroll(scroll,offset)
    local c=B.Character();local s=c and states[c]
    if V.syncing or V.rendering or not s or not current(c,s)or B.selected or V.scrollOwner~=c then return end
    local other=scroll==B.left.scroll and B.right or scroll==B.right.scroll and B.left
    if not other then return end
    offset=K.Number(offset,0);if not offset then return end
    local target=math.min(offset,other.scroll:GetVerticalScrollRange())
    if other.scroll:GetVerticalScroll()==target then return end
    V.syncing=true;other.scroll:SetVerticalScroll(target);E.BookTheme.Scroll(other);V.syncing=nil
end
function V.Render(left,right,c)
    V.CloseMenu()
    c=c or B.Character();if not K.Owned(c)then return end
    B.selected=nil;local s=state(c);prepare(c,s);V.rendering=true;V.scrollOwner=c
    if s.useCurrent and E.current~=c then s.fresh=nil;s.currentUnavailable=true end
    local comparison=X.Eligible(c,c.records[s.before])and(s.useCurrent and s.fresh or X.Eligible(c,c.records[s.after])and X.Saved(c,s.before,s.after))or nil
    for _,pair in ipairs({{left,'before'},{right,'after'}})do
        local page,side=pair[1],pair[2]
        B.Text(page,E.L[side=='before'and'THEN & NOW · BEFORE'or'AFTER'],11)
        B.Text(page,E.L[side=='before'and'Look how far you have come'or s.useCurrent and'Here you are today'or'A little further along'],29)
        selector(page,c,s,side)
        local reading=side=='after'and s.useCurrent and s.fresh and s.fresh.after or c.records[s[side]]
        if reading then B.Text(page,E.API.RecordDate(reading.ts and reading or{ts=reading.capturedAt}),12)end
        B.Tabs(page,{'Equipment','Stats','Skills'},s.tab,function(tab)if current(c,s)then s.tab=tab;redraw(c,s)end end)
    end
    -- Both snapshots begin at the same vertical position, including when the
    -- current-reading refresh control or a translated title adds another line.
    left.y=math.max(left.y,right.y);right.y=left.y
    if s.tab=='Stats'and s.choices and comparison and not(s.useCurrent and s.currentUnavailable)then stats(left,right,comparison)end
    for _,pair in ipairs({{left,'before'},{right,'after'}})do
        local page,side=pair[1],pair[2]
        if not s.choices then B.Text(page,E.L['Preparing saved snapshots…'],14)
        elseif s.useCurrent and s.currentUnavailable then B.Text(page,E.L['A current reading is unavailable. Choose a saved milestone or try again while logged in as this character.'],14)
        elseif not comparison then B.Text(page,E.L['Choose two recorded snapshots to compare. Missing readings stay unknown.'],14)
        else
            if s.tab=='Equipment'then equipment(page,c,s,comparison,side)elseif s.tab~='Stats'then skills(page,comparison,side)end
            local r=not(side=='after'and s.useCurrent)and c.records[s[side]]
            if r then B.Action(page,E.L[side=='before'and'Open earlier milestone'or'Open later milestone'],function()
                if current(c,s)and X.Snapshot(c,r)then B.chronicleMode=nil;E.SearchView.Open({character=c.id,record=r.id,kind=r.kind})end
            end)end
        end
    end
    -- Equal scroll extents keep the two paper dolls aligned all the way down.
    left.y=math.max(left.y,right.y);right.y=left.y
    V.rendering=nil;V.lastComparison=comparison;return comparison
end
