local F, V = E.FloatingLoot, E.FloatingLootView
local c = E.Store.Character('tracker-settings-owner', {name='Bole'})
local alt = E.Store.Character('tracker-settings-alt', {name='Fern'})
local category, rows, character = {}, {}, c
local ui = {Character=function() return character end}
function ui:Check(cat, key, label, default, get, set)
    assert(cat == category and type(label)=='string')
    rows[key] = {default=default,get=get,set=set}
end
function ui:Choice(cat, key, label, default, get, set, options)
    self:Check(cat,key,label,default,get,set); rows[key].options=options
end
function ui:Slider(cat, key, label, default, get, set, lo, hi, step, format)
    self:Check(cat,key,label,default,get,set)
    assert(lo == 1 and hi == 1440 and step == 1 and format(1440) == E.L['Last 24 hours'])
end
V.RegisterSettings(ui,category)
local enabled, presets, slider = rows.floatingLootEnabled, rows.floatingLootPeriod, rows.floatingLootMinutes
assert(enabled.default==false and enabled.get()==false)
assert(presets.default==1440 and slider.default==1440 and presets.get()==1440 and slider.get()==1440)
assert(presets.options()[5][2]==E.L['Last 24 hours'])
c.state.floatingLoot={minutes=30,collapsed={['mob/448']=true},x=.4,y=.55}
assert(slider.get()==30 and presets.get()==30, 'Preserve a saved 30-minute window')
assert(slider.set(17) and presets.get()==17 and #presets.options()==6)
assert(presets.options()[3][1]==17 and presets.options()[3][2]==F.PeriodLabel(17))
assert(presets.set(60) and slider.get()==60 and #presets.options()==5)
assert(not slider.set(0) and not slider.set(1440.5) and slider.get()==60)
assert(enabled.set(true) and enabled.get() and F.Preferences(c).collapsed['mob/448'] and F.Preferences(c).x==.4)
character=alt
assert(slider.get()==1440 and not enabled.get() and enabled.set(true))
assert(not V.frame or not V.frame:IsShown(),'Editing an offline character must not open its tracker')
assert(slider.set(123) and F.Preferences(c).minutes==60 and F.Preferences(alt).minutes==123)
print('PASS native loot settings: per-character checkbox, shared preset/custom control, 24-hour default and saved overrides')
