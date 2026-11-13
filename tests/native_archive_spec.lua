local R,N=E.Archive,E.Notifications
local me=E.current
local alt=E.Store.Character('native-retention-test',{name='Keeper'})
local ui={target=alt,rows={},refreshed=0}
function ui:Character() return self.target end
function ui:Section() end
function ui:Refresh() self.refreshed=self.refreshed+1 end
local function row(ui,cat,key,default,get,set,choices)
    local r={default=default,get=get,set=set,choices=choices}
    function r:AddModifyPredicate(check) self.enabled=check end
    function r:SetParentInitializer(parent,check) self.parent,self.enabled=parent,check end
    ui.rows[cat]=ui.rows[cat] or {}
    assert(not ui.rows[cat][key]);ui.rows[cat][key]=r;return r
end
function ui:Choice(cat,key,label,default,get,set,choices) return row(self,cat,key,default,get,set,choices) end
ui.Check=ui.Choice
function ui:Slider(cat,key,label,default,get,set) return row(self,cat,key,default,get,set) end
function ui:Action(cat,label,button,fn) return row(self,cat,button,nil,nil,fn) end
E.ArchiveView.RegisterSettings(ui,'retention','account','character')
local policies=ui.rows.retention
for _,key in pairs(E.Store.categories) do assert(policies['retention_'..key]) end
for _,key in ipairs({'dailyNotes','recapNotes','otherNotes'}) do assert(policies['retention_'..key]) end
local chat=policies.retention_chat
assert(chat.get()==0);chat.set(30);assert(chat.get()==30 and me.retention.chat==nil)
local beforeDialogs,beforeShow,beforePanel=StaticPopupDialogs,StaticPopup_Show,SettingsPanel
local showing=true
SettingsPanel={IsShown=function()return showing end}
local data,definition
StaticPopupDialogs={}
StaticPopup_Show=function(key,title,help,context) data=context;definition=assert(StaticPopupDialogs[key]) end
local edit,ok={},{}
function edit:GetText()return self.text end
function edit:SetText(s)self.text=s end
function edit:SetNumeric(v) self.numeric=v end
function edit:SetFocus()end
function edit:HighlightText()end
function ok:SetEnabled(v)self.enabled=v end
function ok:IsEnabled()return self.enabled end
local popup={GetEditBox=function()return edit end,GetButton1=function()return ok end}
function edit:GetParent()return popup end
function ok:Click()definition.OnAccept(popup,data)end
chat.set(-1);definition.OnShow(popup,data);assert(edit.text=='30' and ok.enabled and edit.numeric)
edit.text='17';definition.OnHide(popup,data);assert(chat.get()==30,'Dismissing the popup keeps the saved value')
chat.set(-1);definition.OnShow(popup,data)
for _,text in ipairs({'','0','1.5','36501','-2','abc'}) do
    edit.text=text;definition.EditBoxOnTextChanged(edit);definition.EditBoxOnEnterPressed(edit)
    assert(not ok.enabled and chat.get()==30)
end
edit.text='36500';definition.EditBoxOnTextChanged(edit);assert(ok.enabled)
ui.target=me;ok:Click();ui.target=alt;assert(chat.get()==30)
showing=false;ok:Click();assert(chat.get()==30);showing=true
definition.EditBoxOnEnterPressed(edit);assert(chat.get()==36500);definition.OnHide(popup,data)
assert(not edit.numeric)
local found;for _,choice in ipairs(chat.choices())do if choice[1]==36500 then found=true end end;assert(found)
chat.set(0);assert(chat.get()==0)
policies.retentionAutomatic.set(true);assert(alt.state.retentionAutomatic)
local account,char=ui.rows.account,ui.rows.character
local master=account.notification_account_master
local override=char.notification_character_override
local chLevels=char.notification_character_levels
assert(chLevels.parent==override and not chLevels.enabled())
account.notification_account_levels.set(false);assert(not chLevels.get())
chLevels.set(true);assert(not chLevels.get(),'inherited controls cannot edit an inactive override')
override.set(true);assert(chLevels.enabled());chLevels.set(true)
assert(N.Enabled(alt,'levels') and not N.Enabled(me,'levels'))
master.set(false);assert(not N.Enabled(alt,'levels'));master.set(true)
char.notification_character_x.set(19);assert(char.notification_character_x.get()==19)
char.notification_character_y.set(25);assert(char.notification_character_y.get()==25)
char['Reset notification position'].set();assert(char.notification_character_x.get()==0 and char.notification_character_y.get()==6)
assert(not char['Preview notification'].enabled() and account['Preview notification'].enabled())
ui.target=me;assert(char['Preview notification'].enabled() and not chLevels.enabled())
StaticPopupDialogs,StaticPopup_Show,SettingsPanel=beforeDialogs,beforeShow,beforePanel
print('PASS native retention and notification settings: exact days, Forever, character switching, account defaults, override dependencies and positioning')
