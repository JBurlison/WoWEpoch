local _,E=...
local V,B,K,L={},E.Book,E.Keepsakes,E.KillLoot;E.KillLootView=V
local supported={kill=true,kill_observation=true,loot_window=true,drop=true,loot=true}
local waiting
local function title(r)return E.Display.RecordTitle(r)or E.Display.Kind(r.kind)end
local function valid(c,r)return B.Character()==c and K.Record(c,r)end
local function open(c,r)
    if valid(c,r)then E.SearchView.Open({character=c.id,record=r.id})end
end
local function basis(value)
    return E.L[value=='exact'and'Matched to the defeated creature.'or value=='mixed'and'Exact and approximate matches'or'Approximate match · nearby kill and loot.']
end
B.widgetFactories.killLootRow=function(parent)
    local f=B.widgetFactories.questRow(parent)
    f.itemIcon=E.LedgerStyle.CreateIcon(f,34,12,-12)
    f.open=B.widgetFactories.calendarControl(f);f.open:SetPoint('TOPRIGHT',-10,-13);f.open:SetSize(76,28)
    f.open.text:SetFont(E.Font(),12,'');f.open.text:SetWidth(64)
    f.status:Hide();f.accent:Hide();f.tint:SetAlpha(0)
    f:SetScript('OnHide',function(self)E.LedgerStyle.SetIcon(self.itemIcon,nil);self.itemIcon:Hide()end)
    return f
end
local function row(page,name,meta,itemID,link,callback)
    local f=B.Acquire(page,'killLootRow');local w=B.Width(page);local x=itemID and 58 or 12
    f:SetWidth(w);E.LedgerStyle.SetIcon(f.itemIcon,itemID,link);f.itemIcon:SetShown(itemID~=nil)
    f.text:ClearAllPoints();f.text:SetPoint('TOPLEFT',x,-12);f.text:SetWidth(math.max(40,w-x-100));f.text:SetFont(E.Font(),16,'');f.text:SetText(E.Text(name))
    f.meta:ClearAllPoints();f.meta:SetPoint('TOPLEFT',x,-f.text:GetStringHeight()-18);f.meta:SetWidth(math.max(40,w-x-24));f.meta:SetFont(E.Font(),12,'');f.meta:SetText(E.Text(meta or''))
    f.open.text:SetText(E.L['Open']..' >');f.open:SetShown(callback~=nil);f.open:SetScript('OnClick',callback);f:SetScript('OnClick',callback)
    f:SetHeight(math.max(64,f.text:GetStringHeight()+f.meta:GetStringHeight()+30));page.y=page.y+f:GetHeight()
    return f
end
local function paging(page,key,rows,render)
    local count=math.max(1,math.ceil(#rows/8));B[key]=math.max(1,math.min(B[key]or 1,count))
    for i=(B[key]-1)*8+1,math.min(#rows,B[key]*8)do render(rows[i])end
    if count>1 then
        B.Text(page,E.Format('Page {page} of {pages}',{page=B[key],pages=count}),12)
        B.Tabs(page,{'Previous page','Next page'},nil,function(which)
            B[key]=math.max(1,math.min(count,B[key]+(which=='Previous page'and-1 or 1)));B.Render()
        end)
    end
end
local function itemSource(c,item)
    for _,id in ipairs(item.refs or{})do local r=c.records[id]
        if K.Record(c,r)and r.itemID==item.itemID and(r.kind=='drop'or r.kind=='loot')then return r end
    end
end
local function encounter(page,c,r,entry,report)
    local pass,chapter=page.used,B.chapter
    local function current()
        return valid(c,r)and B.selected==r.id and B.chapter==chapter and page.used==pass
    end
    B.Text(page,basis(entry.basis),13)
    paging(page,'killLootItems',entry.items,function(item)
        local source=itemSource(c,item)
        local quantity=item.quantity and('x'..E.Number(item.quantity))or E.L['Quantity not recorded']
        local name=E.LedgerStyle.Name(item.itemID,item.name or(source and title(source)))
        row(page,name,quantity..' · '..E.L['Loot observed'],item.itemID,source and source.itemLink,function()
            if current()and source then open(c,source)end
        end)
    end)
    if #entry.items==0 then B.Text(page,E.L['No loot encounter has been linked yet.'],14)end
    local expanded=B.killLootDetails
    B.Action(page,E.L['Loot encounter details']..(expanded and' −'or' +'),function()
        if current()then B.killLootDetails=not expanded;B.Render()end
    end)
    if expanded then
        B.Text(page,E.L['One encounter, all its items. Reopening the same corpse does not add another drop.'],12)
        B.Text(page,E.L['Observed drops do not identify who received them.'],12)
        paging(page,'killLootWindows',entry.windows,function(association)
            local window=association.window
            row(page,E.Format('Loot window · {date}',{date=E.API.RecordDate(window)}),basis(association.basis),nil,nil,function()if current()then open(c,window)end end)
            if association.basis=='inferred'then
                B.Action(page,E.L['Dismiss approximate match'],function()
                    if not current()then return end
                    local latest=L.Get(c);local linked=latest and latest.byKill[entry.kill.id]
                    for _,match in ipairs(linked and linked.windows or{})do
                        if match.window==window and match.basis=='inferred'and L.Dismiss(c,entry.kill,window)then break end
                    end
                    B.Render()
                end)
            end
        end)
        if #entry.receipts>0 then
            B.Text(page,E.L['Recorded receipts'],18)
            paging(page,'killLootReceipts',entry.receipts,function(receipt)
                row(page,title(receipt),E.API.RecordDate(receipt)..(receipt.quantity and' · x'..E.Number(receipt.quantity)or''),receipt.itemID,receipt.itemLink,function()if current()then open(c,receipt)end end)
            end)
        end
    end
end
function V.Record(page,c,r)
    if not supported[r.kind]or not valid(c,r)then return end
    if B.killLootRecord~=r.id then
        B.killLootRecord=r.id;B.killLootItems=1;B.killLootWindows=1;B.killLootReceipts=1;B.killLootLinks=1;B.killLootDetails=false
    end
    local kill=L.ResolveKill(c,r);local report=L.Get(c)
    local entries=report and report.byRecord[r.id]or{}
    if not kill and report and #entries==0 then return end
    local section=B.Section(page,E.L[kill and'Loot from this defeat'or'Related defeat'])
    if not report then
        B.Text(page,E.L['Looking for loot from this defeat…'],13)
        waiting={owner=c,record=r,pass=page.used,chapter=B.chapter,page=page}
    elseif kill then
        local entry=report.byKill[kill.id]
        if entry then encounter(page,c,r,entry,report)else B.Text(page,E.L['No loot encounter has been linked yet.'],14)end
        if L.HasDismissed(c,kill)then B.Action(page,E.L['Restore dismissed loot matches'],function()
            if valid(c,r)and L.Restore(c,kill)then B.Render()end
        end)end
    else
        paging(page,'killLootLinks',entries,function(entry)
            row(page,title(entry.kill),E.API.RecordDate(entry.kill)..' · '..basis(entry.basis),nil,nil,function()
                if valid(c,r)then open(c,entry.kill)end
            end)
        end)
    end
    B.EndSection(page,section)
end
E.On('KILL_LOOT_READY',function(c)
    local w=waiting
    if not w or w.owner~=c then return end
    waiting=nil
    if not B.frame or not B.frame:IsShown()or not valid(c,w.record)or B.selected~=w.record.id
        or B.chapter~=w.chapter or w.page.used~=w.pass then return end
    -- Finish initial loading once; never steal focus from personal writing.
    for _,page in ipairs({B.left,B.right})do
        for i=1,page.used.edit or 0 do if page.pool.edit[i]:HasFocus()then return end end
    end
    B.Render()
end)
