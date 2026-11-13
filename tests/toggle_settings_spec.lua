-- Exercise the real registration callbacks against the native list contract.
-- The mock deliberately has no canvas category or custom navigation backend.
local U,F,N=E.AddonSettings,E.FloatingLoot,E.Notifications
local c=E.Store.Character('settings-owner',{name='Aster'})
local alt=E.Store.Character('settings-alt',{name='Fern'})
E.current=c;E.RecorderReady=function() return true end
Settings={}
assert(not U.Register(),'Wait for Blizzard settings to finish loading')
local categories,registered,proxies={},0,{}
local function category(parent,name)
    local cat={parent=parent,name=name,id=#categories+1,GetID=function(s)return s.id end}
    local layout={AddInitializer=function(s,row) s[#s+1]=row end}
    cat.layout=layout;categories[#categories+1]=cat
    return cat,layout
end
Settings.RegisterVerticalLayoutCategory=function(name)return category(nil,name)end
Settings.RegisterVerticalLayoutSubcategory=category
Settings.RegisterAddOnCategory=function(root)assert(root==categories[1]);registered=registered+1 end
Settings.RegisterProxySetting=function(cat,id,kind,label,default,get,set)
    assert(type(default)==kind and not proxies[id] and type(label)=='string')
    local s={get=get,set=set,updates=0,category=cat,NotifyUpdate=function(self)self.updates=self.updates+1 end}
    proxies[id]=s;return s
end
local function initializer()
    return {AddModifyPredicate=function(s,f)s.predicate=f end,SetParentInitializer=function(s,p,f)s.parent=p;s.predicate=f end}
end
local function row(cat,setting,options)
    local r=initializer();r.setting=setting;r.options=options;cat.layout:AddInitializer(r);return r
end
Settings.CreateCheckbox=row;Settings.CreateDropdown=row;Settings.CreateSlider=row
Settings.CreateControlTextContainer=function()return {Add=function(s,v,t)s[#s+1]={v,t}end,GetData=function(s)return s end}end
MinimalSliderWithSteppersMixin={Label={Right=1}}
Settings.CreateSliderOptions=function()return {SetLabelFormatter=function()end}end
CreateSettingsButtonInitializer=initializer;CreateSettingsListSectionHeaderInitializer=initializer
local shown,opened,hooks=false,nil,{}
SettingsPanel={HookScript=function(_,k,v)hooks[k]=v end,IsShown=function()return shown end}
Settings.OpenToCategory=function(id)opened=id;shown=true;hooks.OnShow()end
assert(U.Register() and U.Register() and registered==1 and #categories==6)
local function s(key)return assert(proxies['MYEPOCH_'..key],key) end
local function set(key,value)s(key).set(value)end
local function get(key)return s(key).get()end
assert(U.Open('general',alt) and opened==U.categories.general:GetID() and U:Character()==alt)
assert(E.Controller.CompetingNative(),'The book must yield while Blizzard Settings is visible')
assert(get('floatingLootMinutes')==1440 and get('journal_general')==alt.id)
set('floatingLootMinutes',41)
assert(get('floatingLootPeriod')==41 and F.Preferences(c).minutes==1440 and s('floatingLootPeriod').updates>0)
set('journal_general',c.id);set('journal_general','')
assert(U:Character()==c and get('floatingLootPeriod')==1440,'Defaults must not redirect the journal')
set('journal_records',alt.id)
local key=E.PersonalRecords.categories[1].key
set('record_'..key,false);assert(not E.PersonalRecords.Enabled(alt,key) and E.PersonalRecords.Enabled(c,key))
set('retention_chat',17);set('retentionAutomatic',true)
assert(alt.retention.chat==17 and alt.state.retentionAutomatic and not c.retention.chat and not c.state.retentionAutomatic)
set('notification_character_sound',false)
assert(N.Preferences(alt).sound,'Inherited preferences must not be changed')
set('notification_character_override',true);set('notification_character_sound',false)
assert(not N.Preferences(alt).sound and N.Preferences(c).sound)
set('notification_account_master',false);assert(not N.Preferences(alt).master and not N.Preferences(c).master)
set('combatClose',true);assert(E.db.settings.combatClose)
set('controllerSwap',true);assert(E.Controller.Settings().swapConfirm)
shown=false;hooks.OnHide();assert(U:Character()==c,'Closing Settings releases the target journal')
U.Open('retention',alt);local third=E.Store.Character('settings-third',{name='Thistle'});E.current=third
assert(U:Character()==third and get('retention_chat')==0,'A real character handoff cannot keep an old target')
print('PASS native Settings registration, scoped proxies, exact duration, retention, overrides, controller handoff and character switches')
