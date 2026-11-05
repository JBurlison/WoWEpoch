local _,E=...
local V,B,A={},E.Book,E.API;E.MilestoneSnapshotView=V
local function plain(v)
    local ok,secret=pcall(A.Secret,v);if not ok or secret then return nil end
    if type(canaccessvalue)=='function'then local good,allowed=pcall(canaccessvalue,v);if not good or not allowed then return nil end end
    return v
end
local function number(v)
    v=plain(v);if type(v)=='number'and v==v and v~=math.huge and v~=-math.huge then return v end
end
local function text(v,fallback)v=plain(v);return type(v)=='string'and v~=''and v or fallback or''end
local function formatted(v)
    v=number(v);if not v then return 'Not recorded' end
    if v%1==0 then return string.format('%.0f',v)end
    return (string.format('%.2f',v):gsub('0+$',''):gsub('%.$',''))
end
local function owned(c,r)
    return c and E.db and E.db.characters[c.id]==c and type(r)=='table'and c.records[r.id]==r and r.character==c.id and r.kind=='milestone'and r.subject==c.id
end
local function valid(c,r,s)
    return owned(c,r)and B.Character()==c and B.selected==r.id and r.characterSnapshot==s and type(s)=='table'and s.version==1 and s.character==c.id
end
local function hide(f)
    if V.tooltipOwner==f then V.tooltipOwner=nil;if GameTooltip and type(GameTooltip.Hide)=='function'then pcall(GameTooltip.Hide,GameTooltip)end end
end
local function reset(f)
    hide(f);f.icon:SetScript('OnEnter',nil);f.icon:SetScript('OnLeave',nil);f.icon:SetScript('OnHide',nil)
    f.icon.image:SetTexture(nil);f.icon.image:Hide();f.icon.unknown:Show()
end
local function font(parent,size)
    local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont('Fonts\\FRIZQT__.TTF',size,'');f:SetTextColor(.29,.19,.11);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f
end
local function loggedIn(c)
    if E.current~=c or type(UnitGUID)~='function'then return false end
    local ok,id=pcall(UnitGUID,'player');return ok and text(id)==c.id
end
local function stopModel(f)
    f.token=nil;f.layoutToken=nil
    f:SetScript('OnUpdate',nil)
    local m=f.model;if not m then return end
    for _,script in ipairs({'OnUpdate','OnModelLoaded','OnModelCleared','OnDressModel'})do pcall(m.SetScript,m,script,nil)end
    pcall(m.SetAlpha,m,0);pcall(m.Hide,m)
    if type(m.ClearModel)=='function'then pcall(m.ClearModel,m)end
end
B.widgetFactories.milestoneModel=function(parent)
    local f=CreateFrame('Frame',nil,parent)
    f.paper=E.BookTheme.Texture(f,'ledger-line-v1');f.paper:SetAllPoints()
    f.brand=E.BookTheme.Texture(f,'emblem-v1','ARTWORK');f.brand:SetSize(104,104);f.brand:SetPoint('CENTER',0,38)
    f.brandTitle=font(f,18);f.brandTitle:SetPoint('CENTER',0,-32);f.brandTitle:SetJustifyH('CENTER');f.brandTitle:SetText('MY EPOCH')
    f.status=font(f,12);f.status:SetPoint('BOTTOMLEFT',12,12);f.status:SetJustifyH('CENTER')
    f:SetScript('OnHide',function()stopModel(f)end)
    return f
end
local visibleSlots={[1]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[15]=true,[16]=true,[17]=true,[18]=true,[19]=true}
local function modelPreview(page,c,r,s,state,area)
    local f=B.Acquire(page,'milestoneModel');stopModel(f);f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',area.x,-area.y)
    f:SetSize(area.width,area.height);f.status:SetWidth(area.width-24);f.brandTitle:SetWidth(area.width-24);f.brand:Show();f.brandTitle:Show()
    local chapter=B.chapter
    local function unavailable(message)
        stopModel(f);message=message or'3D preview unavailable here. Saved equipment remains around this page.'
        state.previewError=message;f.status:SetText(message);f.brand:Show();f.brandTitle:Show()
    end
    if not loggedIn(c)then f.status:SetText('3D preview requires this character to be logged in.');return end
    if not state.preview then f.status:SetText('Saved gear / current appearance');return end
    if state.previewError then f.status:SetText(state.previewError);return end
    if not f.model then local ok,m=pcall(CreateFrame,'DressUpModel',nil,f);if ok then f.model=m end end
    local m=f.model
    if not m then unavailable();return end
    for _,key in ipairs({'SetAutoDress','SetUseTransmogChoices','SetUseTransmogSkin','SetUnit','Undress','TryOn','ClearModel','GetModelFileID'})do if type(m[key])~='function'then unavailable();return end end
    local items,seen={},{};local partial=false
    for _,row in ipairs(type(s.equipment)=='table'and s.equipment or{})do if type(row)=='table'then
        local slot=number(row.slot)
        if visibleSlots[slot]then
            if seen[slot]then unavailable('Saved equipment has conflicting slots; use the recorded item list.');return end;seen[slot]=true
            if row.status=='equipped'then
                local link=text(row.link);local id=number(row.itemID)
                if link==''and id and id>0 and id%1==0 then link='item:'..string.format('%.0f',id);partial=true end
                if link~=''then items[#items+1]={link=link,slot=slot}else partial=true end
            elseif row.status~='empty'then partial=true end
        end
    end end
    for slot in pairs(visibleSlots)do if not seen[slot]then partial=true end end
    table.sort(items,function(a,b)return a.slot<b.slot end)
    local token={};f.token=token;local busy=false;local bodyLoaded=false;local loadedWhileDressing=false;local dirty=true;local settle=false;local elapsed,retry=0,0
    local function current()return f.token==token and V.state==state and state.preview and state.tab=='Equipment'and B.chapter==chapter and valid(c,r,s)and loggedIn(c)end
    local function invalidate()
        if f.token~=token then return end
        if not current()then unavailable('Preview closed because the selected character or milestone changed.');return end
        if busy then return end
        m:SetAlpha(0);dirty=true;settle=false;retry=0;f.brand:Show();f.brandTitle:Show();f.status:SetText('Loading saved gear...')
    end
    m:SetAlpha(0);m:ClearAllPoints();m:SetPoint('TOPLEFT',8,-8);m:SetSize(area.width-16,area.height-76)
    local ok=pcall(function()
        m:SetScript('OnModelLoaded',function()if f.token~=token then return end;bodyLoaded=true;if busy then loadedWhileDressing=true else invalidate()end end);m:SetScript('OnDressModel',invalidate)
        m:SetScript('OnModelCleared',function()if f.token~=token then return end;bodyLoaded=false;invalidate()end)
        m:SetAutoDress(false);m:SetUseTransmogChoices(false);m:SetUseTransmogSkin(false);m:ClearModel();m:Show()
        if m:SetUnit('player',false,true)~=true then error('Player model unavailable')end
        m:Undress()
    end)
    if not ok then unavailable();return end
    f.status:SetText('Loading saved gear...')
    m:SetScript('OnUpdate',function(_,delta)
        if f.token~=token then return end
        if not current()then unavailable('Preview closed because the selected character or milestone changed.');return end
        if not dirty and not settle then return end
        elapsed=elapsed+(number(delta)or 0);retry=retry-(number(delta)or 0)
        if elapsed>15 then unavailable('Saved gear preview did not finish loading. Close and reopen the preview to retry.');return end
        if settle then settle=false;elapsed=0;f.brand:Hide();f.brandTitle:Hide();m:SetAlpha(1);f.status:SetText(partial and'Saved gear / current appearance / partial gear'or'Saved gear / current appearance');return end
        if retry>0 or not bodyLoaded then return end;retry=.25
        local ready,id=pcall(m.GetModelFileID,m);if not ready then unavailable();return end
        if not number(id)or id<=0 then return end
        busy=true;loadedWhileDressing=false;local pending=false;local dressed=pcall(function()
            m:SetAlpha(0);m:SetAutoDress(false);m:SetUseTransmogChoices(false);m:SetUseTransmogSkin(false);m:Undress()
            for _,item in ipairs(items)do
                local hand=item.slot==16 and'MAINHANDSLOT'or item.slot==17 and'SECONDARYHANDSLOT'or nil
                local result=number(m:TryOn(item.link,hand))
                -- Pinned ItemTryOnReason: 0=Success, 3=DataPending. Unknown outcomes stay hidden.
                if result==3 then pending=true elseif result~=0 then error('Saved item cannot be previewed')end
            end
        end);busy=false
        if not dressed then unavailable('One or more saved items could not be previewed. The equipment list remains available.');return end
        if not pending and not loadedWhileDressing then dirty=false;settle=true end
    end)
end
local function previewControls(page,c,r,s,state,area)
    modelPreview(page,c,r,s,state,area)
    if not loggedIn(c)then return end
    local chapter=B.chapter;local y=page.y
    local button=B.Action(page,state.preview and'Hide gear preview'or'Show gear preview',function()
        if not valid(c,r,s)or V.state~=state or state.tab~='Equipment'or B.chapter~=chapter or not loggedIn(c)then return end
        if B.Navigation and B.Navigation.KeepDrafts then B.Navigation.KeepDrafts()end
        state.preview=not state.preview;state.previewError=nil;B.Render()
    end)
    button:ClearAllPoints();button:SetPoint('TOPLEFT',page.content,'TOPLEFT',area.x+(area.width-button:GetWidth())/2,-area.y-area.height-8);page.y=y
end
local slotNames={'Head','Neck','Shoulders','Shirt','Chest','Waist','Legs','Feet','Wrists','Hands','Finger 1','Finger 2','Trinket 1','Trinket 2','Back','Main hand','Off hand','Ranged','Tabard'}
local leftSlots={1,2,3,15,5,4,19,9};local rightSlots={10,6,7,8,11,12,13,14}
B.widgetFactories.milestoneSheet=function(parent)
    local f=CreateFrame('Frame',nil,parent);E.BookTheme.DialogPaper(f);return f
end
B.widgetFactories.milestoneEquipment=function(parent)
    local f=CreateFrame('Button',nil,parent)
    f.paper=E.BookTheme.Texture(f,'ledger-line-v1');f.paper:SetAllPoints()
    f.icon=CreateFrame('Button',nil,f);f.icon:SetSize(34,34);f.icon:SetPoint('TOPLEFT',3,-3);f.icon:EnableMouse(true)
    f.icon.border=f.icon:CreateTexture(nil,'BACKGROUND');f.icon.border:SetAllPoints();f.icon.border:SetColorTexture(.42,.29,.14,.65)
    f.icon.image=f.icon:CreateTexture(nil,'ARTWORK');f.icon.image:SetPoint('TOPLEFT',2,-2);f.icon.image:SetPoint('BOTTOMRIGHT',-2,2)
    f.icon.unknown=font(f.icon,20);f.icon.unknown:SetPoint('CENTER');f.icon.unknown:SetText('?')
    f.text=font(f,10);f.text:SetPoint('TOPLEFT',42,-6);f.text:SetMaxLines(1)
    f.meta=font(f,9);f.meta:SetPoint('TOPLEFT',42,-22);f.meta:SetMaxLines(1)
    f:SetScript('OnHide',function()reset(f);f:SetScript('OnClick',nil);f.icon:SetScript('OnClick',nil)end);return f
end
local equipmentStats
local function equipment(page,c,r,s,state)
    local start,total=page.y,B.Width(page);local w=math.floor(total*.66);local sheet=B.Acquire(page,'milestoneSheet');sheet:SetSize(w,400)
    local rows,duplicates={},{}
    for _,row in ipairs(type(s.equipment)=='table'and s.equipment or{})do if type(row)=='table'then local slot=number(row.slot)
        if slot and slot%1==0 and slotNames[slot]then if rows[slot]then duplicates[slot]=true else rows[slot]=row end end
    end end
    state.equipmentSlot=state.equipmentSlot or 16
    local function slot(slot,x,y,width)
        local row=not duplicates[slot]and rows[slot]or nil
        local status=row and text(row.status)or'unavailable';local f=B.Acquire(page,'milestoneEquipment');reset(f)
        f.slot=slot;f.row=row;f:SetSize(width,38);f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',x,-y)
        f.text:SetWidth(width-46);f.meta:SetWidth(width-46);f.text:SetText(slotNames[slot]);f.meta:SetText(status=='equipped'and'Equipped'or status=='empty'and'Empty slot'or'Unavailable')
        f.icon.unknown:SetText(status=='empty'and'-'or'?')
        f.icon.border:SetColorTexture(state.equipmentSlot==slot and .68 or .42,state.equipmentSlot==slot and .44 or .29,.14,.8)
        local chapter=B.chapter
        local function selectSlot()
            if not f:IsShown()or not valid(c,r,s)or V.state~=state or state.tab~='Equipment'or B.chapter~=chapter then return end
            if B.Navigation and B.Navigation.KeepDrafts then B.Navigation.KeepDrafts()end
            state.equipmentSlot=slot;B.Render()
        end
        f:SetScript('OnClick',selectSlot);f.icon:SetScript('OnClick',selectSlot)
        if not row then return end
        local texture=plain(row.icon)
        if status=='equipped'and(type(texture)=='string'or(number(texture)and texture>0))then local ok=pcall(f.icon.image.SetTexture,f.icon.image,texture);if ok then f.icon.image:Show();f.icon.unknown:Hide()end end
        local link=text(row.link);local id=number(row.itemID);if id and(id<=0 or id%1~=0)then id=nil end
        if status=='equipped'and(link~=''or id)then
            f.icon:SetScript('OnEnter',function()
                if not f:IsShown()or not valid(c,r,s)or V.state~=state or state.tab~='Equipment'or B.chapter~=chapter or f.row~=row then return end
                local tip=GameTooltip;if not tip or type(tip.SetOwner)~='function'or type(tip.SetHyperlink)~='function'or type(tip.Show)~='function'then return end
                if V.tooltipOwner then hide(V.tooltipOwner)end;V.tooltipOwner=f
                local ok=pcall(function()
                    tip:SetOwner(f.icon,'ANCHOR_RIGHT');tip:SetHyperlink(link~=''and link or'item:'..string.format('%.0f',id))
                    if type(tip.AddLine)=='function'then
                        if number(row.durability)and number(row.maxDurability)then tip:AddLine('Saved durability: '..formatted(row.durability)..' / '..formatted(row.maxDurability),.95,.85,.62)end
                        if link==''then tip:AddLine('Base item; exact link not recorded',.95,.85,.62)end
                    end
                    tip:Show()
                end)
                if not ok then hide(f)end
            end)
            f.icon:SetScript('OnLeave',function()hide(f)end);f.icon:SetScript('OnHide',function()hide(f)end)
        end
    end
    for i,id in ipairs(leftSlots)do slot(id,20,start+14+(i-1)*40,100)end
    for i,id in ipairs(rightSlots)do slot(id,12+w-108,start+14+(i-1)*40,100)end
    for i,id in ipairs({16,17,18})do slot(id,12+(w-316)/2+(i-1)*108,start+348,100)end
    previewControls(page,c,r,s,state,{x=124,y=start+22,width=w-224,height=270})
    equipmentStats(page,c,r,s,state,{x=24+w,y=start,width=total-w-12,height=400})
    page.y=start+412
end
local groupDefinitions={{'attributes','Attributes'},{'defense','Defense'},{'offense','Offense'},{'resources','Resources & movement'},{'other','Other recorded stats'}}
local function visibleStat(row)
    return type(row)=='table'and not(text(row.readStatus)=='restricted'and number(row.value)==nil)
end
function V.StatGroups(s)
    local groups,map={},{}
    for _,v in ipairs(groupDefinitions)do local g={key=v[1],title=v[2],rows={}};groups[#groups+1]=g;map[g.key]=g end
    for index,row in ipairs(type(s.stats)=='table'and s.stats or{})do if visibleStat(row)then
        local key=text(row.key):lower();local label=text(row.label):lower();local group
        if key:find('^attribute')then group='attributes'
        elseif key:find('^resistance')or key:find('^defense')or key=='armor'or key=='armorbase'or key=='armorbonus'or key=='dodge'or key=='parry'or key=='block'or key=='shieldblock'or(key:find('^rating')and(label:find('defense')or label:find('dodge')or label:find('parry')or label:find('block')or label:find('resilience')))then group='defense'
        elseif key:find('health')or key:find('power')and not key:find('attackpower')or key:find('^movement')or key=='manaregen'or key=='castingregen'then group='resources'
        elseif key:find('attack')or key:find('damage')or key:find('crit')or key:find('hit')or key:find('speed')or key:find('haste')or key:find('expertise')or key:find('penetration')or key=='healing'or key:find('^rating')then group='offense'
        else group='other'end
        map[group].rows[#map[group].rows+1]={row=row,index=index}
    end end
    return groups
end
B.widgetFactories.milestoneStats=function(parent)
    local f=CreateFrame('Frame',nil,parent);f.paper=E.BookTheme.Texture(f,'ledger-line-v1');f.paper:SetAllPoints()
    f.text=font(f,17);f.text:SetPoint('TOPLEFT',12,-12);f.lines={};return f
end
local statReadLabels={restricted='Restricted read',unavailable='API unavailable',failed='Read failed',missing='Not supplied'}
local function statLine(f,index,row,width,y,size)
    local line=f.lines[index];if not line then line={label=font(f,12),value=font(f,12)};f.lines[index]=line;line.value:SetJustifyH('RIGHT')end
    line.label:SetFont('Fonts\\FRIZQT__.TTF',size or 12,'');line.value:SetFont('Fonts\\FRIZQT__.TTF',size or 12,'')
    local unit=text(row.unit);local value=number(row.value)
    local display=value~=nil and formatted(value)..(unit~=''and' '..unit or'')or statReadLabels[text(row.readStatus)]or'Not recorded'
    line.label:SetText(E.Text(text(row.label,text(row.key,'Stat'))));line.value:SetText(display)
    line.label:SetWidth(width*.58);line.value:SetWidth(width*.36);line.label:ClearAllPoints();line.value:ClearAllPoints();line.label:SetPoint('TOPLEFT',12,-y);line.value:SetPoint('TOPRIGHT',-12,-y)
    line.label:Show();line.value:Show();return math.max(20,line.label:GetStringHeight(),line.value:GetStringHeight())+5
end
local function clearStats(f)
    for _,heading in ipairs(f.headings or{})do heading:Hide()end
    for _,line in ipairs(f.lines)do line.label:Hide();line.value:Hide()end
end
equipmentStats=function(page,c,r,s,state,area)
    local f=B.Acquire(page,'milestoneStats');f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',area.x,-area.y);f:SetSize(area.width,area.height);f.text:SetWidth(area.width-24);f.text:SetText('Saved stats')
    f.headings=f.headings or{};clearStats(f)
    local map={};for _,g in ipairs(V.StatGroups(s))do map[g.key]=g end
    local y,n,h=39,0,0
    for _,key in ipairs({'resources','attributes','offense','defense','other'})do local g=map[key]
        if #g.rows>0 and y<312 then
            h=h+1;local heading=f.headings[h]or font(f,12);f.headings[h]=heading;heading:ClearAllPoints();heading:SetPoint('TOPLEFT',12,-y);heading:SetWidth(area.width-24);heading:SetText(g.title);heading:SetTextColor(.52,.28,.14);heading:Show();y=y+22
            local shown=0;local limit=key=='attributes'and 5 or key=='resources'and 2 or 1
            for _,entry in ipairs(g.rows)do local k=text(entry.row.key):lower()
                if shown<limit and y<333 and not k:find('base')and not k:find('positive')and not k:find('negative')and not k:find('bonus')and not k:find('modifier')then
                    n=n+1;local height=statLine(f,n,entry.row,area.width-24,y,11)
                    if y+height>355 then f.lines[n].label:Hide();f.lines[n].value:Hide();break end
                    shown=shown+1;y=y+height
                end
            end
        end
    end
    if n==0 then local empty=f.headings[1]or font(f,12);f.headings[1]=empty;empty:ClearAllPoints();empty:SetPoint('TOPLEFT',12,-42);empty:SetWidth(area.width-24);empty:SetText('Stats not recorded');empty:Show()end
    local old=page.y;local chapter=B.chapter
    local button=B.Action(page,'All stat groups',function()
        if not valid(c,r,s)or V.state~=state or B.chapter~=chapter then return end
        if B.Navigation and B.Navigation.KeepDrafts then B.Navigation.KeepDrafts()end
        state.tab='Stats';state.statGroup=nil;B.Render()
    end)
    button:SetWidth(math.min(button:GetWidth(),area.width-24));button.text:SetWidth(button:GetWidth()-16);button:ClearAllPoints();button:SetPoint('TOPLEFT',page.content,'TOPLEFT',area.x+12,-area.y-area.height+42);page.y=old
end
local function stats(page,c,r,s,state,brief)
    local groups=V.StatGroups(s);local present={};for _,g in ipairs(groups)do if #g.rows>0 then present[#present+1]=g end end
    if #present==0 then if not brief then B.Text(page,'Stats were not recorded.',14)end;return end
    local chapter=B.chapter
    local function change(group)
        if not valid(c,r,s)or V.state~=state or B.chapter~=chapter then return end
        if B.Navigation and B.Navigation.KeepDrafts then B.Navigation.KeepDrafts()end
        state.tab='Stats';state.statGroup=group;B.Render()
    end
    local selected
    if not brief and state.statGroup then for _,g in ipairs(present)do if g.key==state.statGroup then selected=g end end end
    if selected then
        B.Action(page,'Back to stat groups',function()change(nil)end)
        local f=B.Acquire(page,'milestoneStats');f:SetWidth(B.Width(page));f.text:SetWidth(B.Width(page)-24);f.text:SetText(selected.title..' / all '..#selected.rows..' recorded fields')
        clearStats(f)
        local y=42;for i,entry in ipairs(selected.rows)do y=y+statLine(f,i,entry.row,B.Width(page)-24,y)end;f:SetHeight(y+12);page.y=page.y+f:GetHeight()+10;return
    end
    B.Text(page,brief and'Saved character stats'or'Recorded character sheet',19)
    local w=(B.Width(page)-12)/2;local start=page.y;local rowHeight=0;local count=brief and math.min(2,#present)or#present
    for i=1,count do local g=present[i];local col=(i-1)%2
        if col==0 and i>1 then start=start+rowHeight+12;rowHeight=0 end
        local f=B.Acquire(page,'milestoneStats');f:ClearAllPoints();f:SetPoint('TOPLEFT',page.content,'TOPLEFT',12+col*(w+12),-start);f:SetWidth(w);f.text:SetWidth(w-24);f.text:SetText(g.title)
        clearStats(f)
        local y=42;local shown={};local selectedRows={}
        -- Main values lead; modifiers/base values remain available in group details.
        for _,entry in ipairs(g.rows)do local key=text(entry.row.key):lower();if not key:find('base')and not key:find('positive')and not key:find('negative')and not key:find('bonus')and not key:find('modifier')then selectedRows[#selectedRows+1]=entry;shown[entry.index]=true end end
        for _,entry in ipairs(g.rows)do if not shown[entry.index]then selectedRows[#selectedRows+1]=entry end end
        for n=1,math.min(5,#selectedRows)do y=y+statLine(f,n,selectedRows[n].row,w-24,y)end
        f:SetHeight(y+48);local oldY=page.y;page.y=start+y;local button=B.Action(page,'All '..#g.rows..' '..g.title:lower()..' fields',function()change(g.key)end)
        button:SetWidth(math.min(button:GetWidth(),w-24));button.text:SetWidth(button:GetWidth()-16);button:ClearAllPoints();button:SetPoint('TOPLEFT',page.content,'TOPLEFT',24+col*(w+12),-start-y);page.y=oldY
        rowHeight=math.max(rowHeight,f:GetHeight())
    end
    page.y=start+rowHeight+12
    if brief then B.Action(page,'All stat groups',function()change(nil)end)end
end
B.widgetFactories.milestoneSkill=function(parent)
    local f=CreateFrame('Frame',nil,parent)
    f.text=font(f,14);f.text:SetPoint('TOPLEFT',0,0)
    f.track=f:CreateTexture(nil,'BACKGROUND');f.track:SetColorTexture(.13,.12,.10,1)
    f.track:SetPoint('TOPLEFT',0,-24);f.track:SetPoint('TOPRIGHT',0,-24);f.track:SetHeight(24)
    f.fill=f:CreateTexture(nil,'ARTWORK');f.fill:SetColorTexture(.20,.43,.59,1);f.fill:SetPoint('TOPLEFT',2,-26);f.fill:SetHeight(20)
    f.value=font(f,13);f.value:SetPoint('TOP',0,-29);f.value:SetTextColor(1,.94,.78);f.value:SetJustifyH('CENTER')
    f.minimum=font(f,11);f.minimum:SetPoint('TOPLEFT',0,-53)
    f.maximum=font(f,11);f.maximum:SetPoint('TOPRIGHT',0,-53);f.maximum:SetJustifyH('RIGHT')
    f.bonus=font(f,11);f.bonus:SetPoint('TOPLEFT',0,-72)
    return f
end
local function rankBar(page,row,title,maxLabel)
    local f=B.Acquire(page,'milestoneSkill');local width=B.Width(page);f:SetWidth(width);f.text:SetWidth(width)
    f.text:SetText(E.Text(title))
    local rank,cap=number(row.rank),number(row.maxRank);local known=rank and cap and rank>=0 and cap>0
    f.value:SetText(formatted(rank)..' / '..formatted(cap));f.value:SetWidth(width-12)
    f.minimum:SetText('0');f.maximum:SetText(maxLabel..' '..formatted(cap));f.maximum:SetWidth(width*.5)
    if known and rank>0 then f.fill:SetWidth((width-4)*math.min(1,rank/cap));f.fill:Show()else f.fill:Hide()end
    if known and rank>=cap then f.fill:SetColorTexture(.27,.48,.25,1)else f.fill:SetColorTexture(.20,.43,.59,1)end
    local extras={};local modifier=number(row.modifier);local temporary=number(row.tempPoints)
    if modifier and modifier~=0 then extras[#extras+1]='Modifier '..(modifier>0 and'+'or'')..formatted(modifier)end
    if modifier==nil then extras[#extras+1]='Modifier not recorded'end
    if temporary and temporary~=0 then extras[#extras+1]='Temporary points '..(temporary>0 and'+'or'')..formatted(temporary)
    elseif temporary==nil then extras[#extras+1]='Temporary points not recorded'end
    f.bonus:SetWidth(width);f.bonus:SetText(table.concat(extras,' / '));if #extras>0 then f.bonus:Show()else f.bonus:Hide()end
    local height=#extras>0 and 78+math.max(12,f.bonus:GetStringHeight())or 68
    f:SetHeight(height);page.y=page.y+height+12
end
function V.WeaponReading(page,c,r)
    if not c or E.db.characters[c.id]~=c or B.Character()~=c or r.character~=c.id or c.records[r.id]~=r or not A.weaponSkills[r.skillID] then return end
    if r.kind~='weapon_observation' and not (r.kind=='milestone' and r.subject==c.id and r.milestoneType=='skill') then return end
    local reading=r.weaponReading
    if type(reading)~='table' or type(reading.version)~='string' or type(reading.build)~='string' or type(reading.reader)~='string' then return end
    B.Text(page,'Recorded weapon skill',21)
    rankBar(page,reading,text(r.skillName,'Weapon skill '..r.skillID),'Observed max')
    local class=text(reading.className,'Class unknown')
    if number(reading.classID) then class=class..' (Class ID '..formatted(reading.classID)..')' end
    B.Text(page,'Character level '..formatted(reading.level)..'  /  '..class,14)
    B.Text(page,'Forever '..reading.version..' (build '..reading.build..')  /  C_SkillInfo.'..reading.reader,13)
end
local function skills(page,s)
    local rows=type(s.skills)=='table'and s.skills or{}
    if #rows==0 then B.Text(page,'Skills were not recorded.',14);return end
    for _,group in ipairs({{'profession','Professions'},{'weapon','Weapon skills'},{'other','Other skills'}})do
        local section
        for _,row in ipairs(rows)do if type(row)=='table'and (row.category==group[1]or(group[1]=='other'and row.category~='profession'and row.category~='weapon'))then
            if not section then section=B.Section(page,group[2])end
            rankBar(page,row,text(row.name,'Skill'),'Max')
        end end
        if section then B.EndSection(page,section)end
    end
end
function V.Render(page,r)
    local c=B.Character();B.Text(page,'Character at this milestone',21)
    if not owned(c,r)then B.Text(page,'No character snapshot is available for this milestone.',14);V.state=nil;return end
    local s=r.characterSnapshot
    if type(s)~='table'or s.version~=1 or s.character~=c.id then B.Text(page,'A character snapshot was not recorded for this milestone.',14);V.state=nil;return end
    if not V.state or V.state.owner~=c or V.state.record~=r or V.state.snapshot~=s then V.state={owner=c,record=r,snapshot=s,tab='Equipment'}end
    local state=V.state
    local stamp=number(s.capturedAt);local date='Capture time not recorded'
    if stamp then local ok,value=pcall(A.Date,stamp);if ok and type(value)=='string'then date=value end end
    B.Text(page,date..(number(s.level)and' / Level '..formatted(s.level)or''),12)
    local chapter=B.chapter
    B.Tabs(page,{'Equipment','Stats','Skills'},state.tab,function(selected)
            if not valid(c,r,s)or V.state~=state or B.chapter~=chapter then return end
            if B.Navigation and B.Navigation.KeepDrafts then B.Navigation.KeepDrafts()end
            state.tab=selected;B.Render()
    end)
    local key=state.tab:lower();local coverage=type(s.coverage)=='table'and text(s.coverage[key])or''
    if state.tab=='Stats'then
        local hidden,total,recorded=0,0,0
        for _,row in ipairs(type(s.stats)=='table'and s.stats or{})do if type(row)=='table'then
            if visibleStat(row)then total=total+1;if number(row.value)~=nil then recorded=recorded+1 end
            else hidden=hidden+1 end
        end end
        if hidden>0 then coverage=recorded..' of '..total..' values recorded at capture. Missing values show the read result.'end
    end
    if coverage~=''and state.tab~='Equipment'then B.Text(page,coverage,12)end
    if state.tab=='Equipment'then equipment(page,c,r,s,state)
    elseif state.tab=='Stats'then stats(page,c,r,s,state,false)
    else skills(page,s)end
end
