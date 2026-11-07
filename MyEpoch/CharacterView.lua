local _,E=...
local V,B,C,T={page=1,query=''},E.Book,E.Characters,E.BookTheme;E.CharacterView=V
local function text(parent,size,width)
    local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont(E.Font(),size,'');f:SetTextColor(.26,.15,.08)
    f:SetWidth(width);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f
end
local function button(parent,label,width,height,fn)
    local f=CreateFrame('Button',nil,parent);f:SetSize(width,height);T.Button(f);f.text=text(f,14,width-20)
    f.text:SetPoint('CENTER');f.text:SetJustifyH('CENTER');f.text:SetText(label);f:SetScript('OnClick',fn);return f
end
function V.Hide()if V.frame then V.frame:Hide();V.input:ClearFocus()end end
function V.Render()
    local rows=C.Rows(V.query);local pages=math.max(1,math.ceil(#rows/6));V.page=math.max(1,math.min(V.page,pages));V.rows=rows
    V.count:SetText(#rows==0 and E.L['No matching characters'] or E.Format('Characters: {count} / Page {page} of {pages}',{count=#rows,page=V.page,pages=pages}))
    for i,f in ipairs(V.cards)do
        local c=rows[(V.page-1)*6+i];f.characterID=c and c.id or nil
        if c then
            local selected=B.Character()==c;f:Show();f.tint:SetAlpha(selected and .14 or .04)
            f.name:SetText(E.Text(c.identity.name or c.id)..(selected and'  /  '..E.L['Reading now']or''))
            f.meta:SetText(E.Text(C.Description(c)))
            local ts,id=C.Latest(c);local source=id and c.records[id]
            local when=ts and(source and source.datePrecision=='day'and E.API.RecordDate(source)or E.API.Date(ts))
            f.activity:SetText(when and E.Format('Last recorded activity: {date} / Local time',{date=when})or E.L['No dated activity recorded'])
            f:SetScript('OnClick',function()V.Hide();B.ChangeCharacter(c.id)end)
        else f:Hide();f:SetScript('OnClick',nil)end
    end
    if V.page>1 then V.previous:Show()else V.previous:Hide()end
    if V.page<pages then V.next:Show()else V.next:Hide()end
    if E.ControllerAdapters then E.ControllerAdapters.RefreshCharacter()end
end
function V.Build()
    if V.frame then return end
    local overlay=CreateFrame('Frame','MyEpochCharacterPicker',B.frame);V.frame=overlay;overlay:SetAllPoints();overlay:SetFrameStrata('FULLSCREEN_DIALOG');overlay:EnableMouse(true)
    local outside=CreateFrame('Button',nil,overlay);outside:SetAllPoints();outside:SetScript('OnClick',V.Hide)
    local shade=outside:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints();shade:SetColorTexture(0,0,0,.25)
    local panel=CreateFrame('Frame',nil,overlay);V.panel=panel;panel:SetSize(680,750);panel:SetPoint('TOPRIGHT',B.frame,'TOPRIGHT',-56,-72);panel:EnableMouse(true)
    T.Photo(panel)
    local heading=text(panel,25,530);heading:SetText(E.L['Choose a character']);heading:SetPoint('TOPLEFT',30,-30)
    local close=button(panel,E.L['Close'],82,28,V.Hide);V.close=close;close:SetPoint('TOPRIGHT',-26,-26)
    local hint=text(panel,12,600);hint:SetText(E.L['Search names, realms or classes. Each journal stays separate.']);hint:SetPoint('TOPLEFT',30,-68)
    local input=CreateFrame('EditBox',nil,panel);V.input=input;input:SetSize(620,34);input:SetPoint('TOPLEFT',30,-92);input:SetAutoFocus(false);input:SetFont(E.Font(),15,'');input:SetTextColor(.26,.15,.08);input:SetTextInsets(10,10,6,6)
    local face=T.Texture(input,'button-v1');face:SetAllPoints()
    input:SetScript('OnEscapePressed',V.Hide);input:SetScript('OnEnterPressed',function(self)self:ClearFocus()end)
    input:SetScript('OnTextChanged',function(self,user)if user then V.query=self:GetText();V.page=1;V.Render()end end)
    V.count=text(panel,12,620);V.count:SetPoint('TOPLEFT',30,-140)
    V.cards={}
    for i=1,6 do
        local f=CreateFrame('Button',nil,panel);V.cards[i]=f;f:SetSize(620,80);f:SetPoint('TOPLEFT',30,-166-(i-1)*82)
        f.tint=f:CreateTexture(nil,'BACKGROUND');f.tint:SetAllPoints();f.tint:SetColorTexture(.49,.25,.10)
        f.name=text(f,17,596);f.name:SetHeight(25);f.name:SetMaxLines(1);f.name:SetPoint('TOPLEFT',12,-8)
        f.meta=text(f,12,596);f.meta:SetHeight(20);f.meta:SetMaxLines(1);f.meta:SetPoint('TOPLEFT',12,-34)
        f.activity=text(f,11,596);f.activity:SetPoint('TOPLEFT',12,-58)
        f:SetHighlightTexture('Interface\\Buttons\\WHITE8X8');f:GetHighlightTexture():SetAlpha(.12)
    end
    V.previous=button(panel,E.L['Previous'],150,30,function()V.page=V.page-1;V.Render()end);V.previous:SetPoint('BOTTOMLEFT',30,54)
    V.next=button(panel,E.L['Next'],150,30,function()V.page=V.page+1;V.Render()end);V.next:SetPoint('BOTTOMRIGHT',-30,54)
    local footer=text(panel,11,620);footer:SetText(E.L['Only characters recorded by this addon appear here.']);footer:SetPoint('BOTTOMLEFT',30,25)
    if UISpecialFrames then table.insert(UISpecialFrames,'MyEpochCharacterPicker')end
    overlay:SetScript('OnShow',function()if E.ControllerAdapters then E.ControllerAdapters.RefreshCharacter()end end)
    overlay:SetScript('OnHide',function()input:ClearFocus();if E.ControllerAdapters then E.ControllerAdapters.Hide('characters')end end)
    overlay:Hide()
end
function V.Toggle()
    V.Build();if V.frame:IsShown()then V.Hide();return end
    V.input:SetText(V.query);V.Render();V.frame:Show()
end
