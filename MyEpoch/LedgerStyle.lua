local _,E=...
local L,B,T,A={},E.Book,E.BookTheme,E.API;E.LedgerStyle=L
local tooltipOwner
local function hideItemTooltip(f)
    if tooltipOwner~=f then return end
    tooltipOwner=nil
    local tip=GameTooltip
    if tip and type(tip.Hide)=='function'and(not tip.IsOwned or tip:IsOwned(f))then pcall(tip.Hide,tip)end
end
local function showItemTooltip(f)
    local id=f.itemID
    if type(id)~='number'or id<=0 or id%1~=0 then return end
    local tip=GameTooltip
    if not tip or type(tip.SetOwner)~='function'or type(tip.SetHyperlink)~='function'or type(tip.Show)~='function'then return end
    if tooltipOwner then hideItemTooltip(tooltipOwner)end
    tooltipOwner=f
    local ok=pcall(function()
        tip:SetOwner(f,'ANCHOR_RIGHT')
        tip:SetHyperlink(f.itemPayload or 'item:'..string.format('%.0f',id))
        tip:Show()
    end)
    if not ok then hideItemTooltip(f)end
end
local function width(page)return B.Width and B.Width(page)or 760 end
local function font(parent,size,width)
    local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont(E.Font(),size,'');f:SetWidth(width)
    f:SetTextColor(.29,.19,.11);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f
end
local function icon(parent,size,x,y)
    local f=CreateFrame('Frame',nil,parent);f:SetSize(size,size);f:SetPoint('TOPLEFT',x,y)
    f.border=f:CreateTexture(nil,'BACKGROUND');f.border:SetAllPoints();f.border:SetColorTexture(.44,.32,.17,1)
    f.image=f:CreateTexture(nil,'ARTWORK');f.image:SetPoint('TOPLEFT',2,-2);f.image:SetPoint('BOTTOMRIGHT',-2,2)
    f.unknown=font(f,size*.5,size);f.unknown:SetPoint('CENTER');f.unknown:SetJustifyH('CENTER');f.unknown:SetText('?')
    -- Hover only: clicks still reach the receipt/group row underneath.
    f:EnableMouseMotion(true)
    f:SetScript('OnEnter',showItemTooltip)
    f:SetScript('OnLeave',hideItemTooltip)
    f:SetScript('OnHide',hideItemTooltip)
    f:SetMouseClickEnabled(false)
    return f
end
L.CreateIcon=icon
local function savedItemPayload(id,link)
    if A.Secret(link) or type(link)~='string' or #link>4096 then return end
    local payload=link:match('|H(item:[^|]+)|h') or link:match('^(item:[^|]+)$')
    if not payload or payload:find('%c') then return end
    local linkedID=payload:match('^item:(%d+):') or payload:match('^item:(%d+)$')
    if linkedID and tonumber(linkedID)==id then return payload end
end
function L.SetIcon(f,id,link)
    hideItemTooltip(f)
    f.itemID=id;f.itemPayload=savedItemPayload(id,link);f.image:SetTexture(nil);f.image:Hide();f.unknown:Show()
    if type(id)~='number'or id<=0 or id%1~=0 then return end
    local texture=A.Call('ledgerItemIcon',C_Item and C_Item.GetItemIconByID,id)
    if type(texture)=='number'and texture>0 and texture%1==0 then f.image:SetTexture(texture);f.image:Show();f.unknown:Hide()end
end
function L.Items(r)
    local list,seen={},{}
    local function add(id)if type(id)=='number'and id>0 and id%1==0 and not seen[id]then seen[id]=true;list[#list+1]=id end end
    add(r and r.itemID)
    for _,field in ipairs({'attempts','items','transfers'})do for _,row in ipairs(r and r[field]or{})do add(row.itemID)end end
    return list
end
function L.Name(id,fallback)
    return E.Display.Item(id,fallback or(id and E.Format('Item {id}',{id=id}) or E.L['Item not recorded']))
end
function L.RowIcons(f,ids,record)
    f.icons=f.icons or{};local count=math.min(#ids,3)
    for i=1,3 do
        if i<=count then
            f.icons[i]=f.icons[i]or icon(f,32,10+(i-1)*36,-12);L.SetIcon(f.icons[i],ids[i],record and (record.itemLink or record.auctionData and record.auctionData.itemLink));f.icons[i]:Show()
        elseif f.icons[i]then L.SetIcon(f.icons[i],nil);f.icons[i]:Hide()end
    end
    local x=count>0 and 22+count*36 or 10
    local available=math.max(80,f:GetWidth()-325-x)
    f.text:ClearAllPoints();f.text:SetPoint('TOPLEFT',x,-12);f.text:SetWidth(available);f.meta:SetWidth(available)
    local h=math.max(f.text:GetStringHeight(),f.amount:GetStringHeight(),f.balance:GetStringHeight(),count>0 and 32 or 0)
    f.meta:ClearAllPoints();f.meta:SetPoint('TOPLEFT',x,-h-19);f:SetHeight(h+f.meta:GetStringHeight()+32)
    f.iconOverflow=f.iconOverflow or font(f,9,65);f.iconOverflow:ClearAllPoints();f.iconOverflow:SetPoint('TOPLEFT',10,-49)
    if #ids>3 then f.iconOverflow:SetText(E.Format('+{count} more',{count=#ids-3}));f.iconOverflow:Show()else f.iconOverflow:Hide()end
end
B.widgetFactories.ledgerHeading=function(parent)
    local f=CreateFrame('Frame',nil,parent);f:SetWidth(760);f.paper=T.Texture(f,'invoice-v1');f.paper:SetAllPoints()
    f.kicker=font(f,11,540);f.kicker:SetPoint('TOPLEFT',26,-20);f.kicker:SetTextColor(.50,.27,.16)
    f.text=font(f,27,535);f.text:SetPoint('TOPLEFT',26,-46)
    f.date=font(f,12,540);f.seal=T.Texture(f,'invoice-seal-v1','ARTWORK');f.seal:SetSize(76,76);f.seal:SetPoint('TOPRIGHT',-41,-14)
    f.status=font(f,12,150);f.status:SetPoint('TOPRIGHT',-8,-91);f.status:SetJustifyH('CENTER');f.status:SetMaxLines(3)
    return f
end
function L.Heading(page,title,kicker,status,date)
    local f=B.Acquire(page,'ledgerHeading');local w=width(page);f:SetWidth(w)
    f.text:SetWidth(w-225);f.kicker:SetWidth(w-220);f.date:SetWidth(w-220)
    f.text:SetText(E.Text(title));f.kicker:SetText(E.Text(kicker));f.status:SetText(E.Text(E.L[status or'Recorded']))
    local h=math.max(54,f.text:GetStringHeight());f.date:ClearAllPoints();f.date:SetPoint('TOPLEFT',26,-h-58);f.date:SetText(E.Text(date or''))
    f:SetHeight(math.max(155,h+96));page.y=page.y+f:GetHeight()+14;return f
end
B.widgetFactories.ledgerItem=function(parent)
    local f=CreateFrame('Frame',nil,parent);f:SetWidth(760);f.paper=T.Texture(f,'ledger-line-v1');f.paper:SetAllPoints();f.icon=icon(f,46,13,-15)
    f.text=font(f,20,540);f.text:SetPoint('TOPLEFT',78,-13);f.meta=font(f,12,540)
    f.quantity=font(f,20,110);f.quantity:SetPoint('TOPRIGHT',-15,-20);f.quantity:SetJustifyH('RIGHT');return f
end
function L.Item(page,id,name,quantity,meta,link)
    local f=B.Acquire(page,'ledgerItem');f:SetWidth(width(page));f.text:SetWidth(width(page)-220);f.meta:SetWidth(width(page)-220)
    L.SetIcon(f.icon,id,link);f.icon:Show()
    if f.icon.itemPayload then name=link:match('|h%[([^|%]]+)%]|h') or name end
    f.text:SetText(E.Text(L.Name(id,name)))
    f.quantity:SetText(quantity and quantity>0 and('x'..quantity)or'');f.meta:SetText(E.Text(meta or(id and E.Format('Item {id}',{id=id}) or E.L['Item identity unavailable'])))
    local h=math.max(24,f.text:GetStringHeight());f.meta:ClearAllPoints();f.meta:SetPoint('TOPLEFT',78,-h-20)
    f:SetHeight(math.max(78,h+f.meta:GetStringHeight()+34));page.y=page.y+f:GetHeight()+10;return f
end
B.widgetFactories.ledgerAmount=function(parent)
    local f=CreateFrame('Frame',nil,parent);f:SetWidth(760);f.text=font(f,15,410);f.text:SetPoint('TOPLEFT',15,-12)
    f.unknown=font(f,13,300);f.unknown:SetPoint('TOPRIGHT',-16,-12);f.unknown:SetJustifyH('RIGHT');f.coins={}
    for i,name in ipairs({'gold','silver','copper'})do local part={};part.icon=T.Texture(f,'coin-'..name..'-v1','ARTWORK');part.icon:SetSize(18,18);part.icon:SetPoint('TOPLEFT',520+(i-1)*108,-10)
        part.text=font(f,17,85);part.text:SetPoint('TOPLEFT',430+(i-1)*108,-12);part.text:SetJustifyH('RIGHT');f.coins[i]=part end
    f.rule=f:CreateTexture(nil,'BACKGROUND');f.rule:SetColorTexture(.53,.37,.20,.28);f.rule:SetHeight(1);f.rule:SetPoint('BOTTOMLEFT',12,0);f.rule:SetPoint('BOTTOMRIGHT',-12,0)
    return f
end
function L.Amount(page,label,value,unknownText)
    if value==0 then return end
    local f=B.Acquire(page,'ledgerAmount');local w=width(page);f:SetWidth(w);f.text:SetWidth(w-350)
    for i,part in ipairs(f.coins)do
        part.text:ClearAllPoints();part.text:SetPoint('TOPLEFT',w-330+(i-1)*108,-12)
        part.icon:ClearAllPoints();part.icon:SetPoint('TOPLEFT',w-240+(i-1)*108,-10)
    end
    f.text:SetText(E.Text(label));f.unknown:Hide()
    for _,part in ipairs(f.coins)do part.icon:Hide();part.text:Hide()end
    if value==nil then f.unknown:SetText(unknownText or E.L['Not recorded']);f.unknown:Show()
    else
        local n=math.abs(value);if n%1~=0 then n=math.floor(n+.5)end;local sign=value<0 and'-'or''
        for i,v in ipairs({math.floor(n/10000),math.floor(n%10000/100),n%100})do if v>0 then
            local part=f.coins[i];part.text:SetText(sign..v);sign='';part.icon:Show();part.text:Show()
        end end
    end
    local height=math.max(42,f.text:GetStringHeight()+24)
    for _,part in ipairs(f.coins)do if part.text:IsShown()then height=math.max(height,part.text:GetStringHeight()+24)end end
    f:SetHeight(height);page.y=page.y+f:GetHeight();return f
end
function L.Section(page,text)B.Text(page,text,18):SetTextColor(.49,.24,.14)end
L.financial={gold=true,balance=true,merchant=true,item_sale=true,sale_return=true,cost_lot=true,stock_move=true,stock_reset=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true}
