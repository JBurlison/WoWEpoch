local _,E=...
local V,B,I,K={},E.Book,E.ItemStories,E.Keepsakes;E.ItemStoryView=V
local states=setmetatable({},{__mode='k'})
function V.ReleaseView()V.lastStory=nil end
local function state(c)local s=states[c];if not s then s={page=1,eventPage=1,query=''};states[c]=s end;return s end
local function current(c,s)return K.Owned(c)and B.Character()==c and states[c]==s and B.chapter=='Loot'and B.lootMode=='stories'end
local function redraw(c,s)if current(c,s)then B.Render()end end
function V.Open(c,itemID)
    if not K.Owned(c)or B.Character()~=c or itemID~=nil and not K.ID(itemID)then return false end
    local s=state(c);s.itemID=itemID or s.itemID;s.eventPage=1
    B.lootMode='stories';B.chapter='Loot';B.selected=nil;B.Render(true);return true
end
function V.State(c)return state(c)end
E.On('ITEM_STORIES_READY',function(c)local s=states[c];if s then redraw(c,s)end end)
local function open(c,s,entry,id)
    local r=c.records[id or entry.record]
    if current(c,s)and K.Record(c,r)then B.lootMode='receipts';E.SearchView.Open({character=c.id,record=r.id,kind=r.kind})end
end
local function sourceTitle(entry)
    local title=E.L[entry.storyKind]
    if entry.inferred then title=title..' / '..E.L['Inferred']end
    return title
end
local function pager(page,c,s,key,count,size)
    local function inactive(button,enabled)
        button:EnableMouse(enabled);button:SetAlpha(enabled and 1 or .45)
        button:SetScript('OnHide',function(self)self:EnableMouse(true);self:SetAlpha(1);self:SetScript('OnHide',nil)end)
    end
    local pageNo=s[key];local y=page.y;local left=B.Action(page,E.L['Previous page'],function()if current(c,s)and pageNo>1 then s[key]=pageNo-1;redraw(c,s)end end)
    inactive(left,pageNo>1)
    page.y=y;local right=B.Action(page,E.L['Next page'],function()if current(c,s)and pageNo*size<count then s[key]=pageNo+1;redraw(c,s)end end)
    right:ClearAllPoints();right:SetPoint('TOPRIGHT',page.content,'TOPRIGHT',-12,-y);inactive(right,pageNo*size<count)
    page.y=y+math.max(left:GetHeight(),right:GetHeight())+12
end
function V.Render(left,right,c)
    c=c or B.Character();if not K.Owned(c)then return end
    B.selected=nil;local s=state(c);local model=I.Get(c)
    B.Text(left,E.L['LOOT · AN ITEM’S STORY'],11);B.Text(left,E.L['Little treasures, long stories'],29)
    B.Text(left,E.L['Find an item and follow the moments you recorded with it.'],14)
    B.Text(left,E.L['Find an item by name or ID'],12)
    B.Input(left,s.query,function(value)if current(c,s)then s.query=value;s.page=1;redraw(c,s)end end)
    if not model then B.viewPreparing=true;B.Text(left,E.L['Gathering the threads of your item stories…'],14);return end
    local rows={};local query=s.query:lower()
    for _,item in ipairs(model.rows)do
        if query==''or tostring(item.itemID)==query or(item.name or''):lower():find(query,1,true)then rows[#rows+1]=item end
    end
    s.page=math.max(1,math.min(s.page,math.max(1,math.ceil(#rows/8))))
    if not s.itemID or not model.items[s.itemID]then s.itemID=rows[1]and rows[1].itemID end
    for i=(s.page-1)*8+1,math.min(s.page*8,#rows)do local item=rows[i]
        local f=E.LedgerStyle.Item(left,item.itemID,item.name,nil,E.Format('{count} recorded moments',{count=#item.events}))
        local button=B.Action(left,E.L[item.itemID==s.itemID and'Reading this story'or'Open item story'],function()
            if current(c,s)then s.itemID=item.itemID;s.eventPage=1;redraw(c,s)end
        end)
        E.BookTheme.ButtonStyle(button,item.itemID==s.itemID and'filter'or nil)
    end
    if #rows==0 then B.Text(left,E.L['No matching items in this scrapbook.'],14)elseif #rows>8 then pager(left,c,s,'page',#rows,8)end
    local item=s.itemID and model.items[s.itemID]
    if not item then B.Text(right,E.L['Choose an item to open its story.'],22);return end
    B.Text(right,E.L['AN ITEM’S STORY'],11)
    E.LedgerStyle.Item(right,item.itemID,item.name,nil,E.L['One item type, many remembered moments'])
    B.Text(right,E.L['These are recorded appearances and exchanges, not the journey of one particular copy.'],12)
    local filtered=E.SourceFilters.Controls(right,item.events,'item-story:'..item.itemID,nil,{changed=function()s.eventPage=1 end})
    s.eventPage=math.max(1,math.min(s.eventPage,math.max(1,math.ceil(#filtered/8))))
    for i=(s.eventPage-1)*8+1,math.min(s.eventPage*8,#filtered)do local entry=filtered[i];local r=c.records[entry.record]
        if K.Record(c,r)then
            local panel=B.Section(right,sourceTitle(entry))
            local detail=E.API.RecordDate(r);local zone=E.Display.Zone(r)
            if zone then detail=detail..' / '..zone end
            if entry.quantity and entry.quantity>0 then detail=detail..' / x'..E.Number(entry.quantity)end
            B.Text(right,detail,12)
            if entry.slot then
                local slots={'Head','Neck','Shoulders','Shirt','Chest','Waist','Legs','Feet','Wrists','Hands','Finger 1','Finger 2','Trinket 1','Trinket 2','Cloak','Main hand','Off hand','Ranged','Tabard'}
                B.Text(right,E.L[slots[entry.slot]or'Equipment'],12)
            end
            if entry.link then E.LedgerStyle.Item(right,item.itemID,item.name,nil,E.L['Recorded item variant'],entry.link)end
            if entry.replacementItemID then E.LedgerStyle.Item(right,entry.replacementItemID,nil,nil,E.L['Worn in the later snapshot'])end
            if entry.previous then B.Action(right,E.L['Open earlier milestone'],function()open(c,s,entry,entry.previous)end)end
            B.Action(right,E.L['Open source record'],function()open(c,s,entry,entry.evidence or entry.record)end)
            B.EndSection(right,panel)
        end
    end
    if #filtered>8 then pager(right,c,s,'eventPage',#filtered,8)end
    if #filtered==0 then B.Text(right,E.L['No matching moments for this item.'],14)end
    B.Note(right,I.NoteKey(item.itemID),function()return current(c,s)and s.itemID==item.itemID end)
    V.lastStory=item;return item
end
