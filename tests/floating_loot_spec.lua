local F, V, S, A = E.FloatingLoot, E.FloatingLootView, E.Store, E.API
local c = S.Character('floating-loot-test', {name='Fenna'})
local alt = S.Character('floating-alt', {name='Fern'})
local epoch = 1794000000
local function save(kind, ts, values)
    values.session = 'floating-session'; values.groupState = 'solo'
    return S.Add(c, kind, epoch + ts, values)
end
local function receipt(ts, kind, id, n, extra)
    local data = {itemID=id, title='Item '..id, recipient=c.id, quantity=n}
    for k, v in pairs(extra or {}) do data[k] = v end
    return save(kind, ts, data)
end
local function reward(ts, id, n)
    return save('quest_reward', ts, {itemID=id, quantity=n, questID=109, observerGroupState='solo',
        rewardType='item', sourceEvent='QUEST_LOOT_RECEIVED'})
end
local function check(report, key, id, n, inferred)
    for _, group in ipairs(report.groups) do
        if group.key == key then
            for _, item in ipairs(group.items) do
                if item.id == id then
                    assert(item.quantity == n, 'unexpected quantity for '..key)
                    assert((item.inferred == true) == (inferred == true), 'unexpected certainty for '..key)
                    return group
                end
            end
        end
    end
    error('missing '..key..'/'..id)
end
assert(not F.Preferences(c).enabled and F.Preferences(c).minutes == 1440)
assert(F.SetMinutes(c, '1') and not F.SetMinutes(c, '2.5') and not F.SetMinutes(c, 1441))
assert(F.Preferences(alt).minutes == 1440 and F.Preferences(c).minutes == 1)
receipt(940,'loot',18,12) -- outside the half-open rolling window at 1000
receipt(943,'loot',20,3,{npcID=31,npcName='Gnoll'})
receipt(948,'loot',20,4,{npcID=31,npcName='Gnoll'})
receipt(949,'loot',20,10,{recipient='someone else'})
receipt(950,'crafted',25,3,{profession='Tailoring'})
local gathered = receipt(951,'gathered',42,2,{profession='Mining',gathering={state='inferred'}})
receipt(961,'loot',11,2); reward(962,11,2); reward(963,10,3)
-- More than one notice can match. It cannot establish the quest source.
receipt(970,'loot',12,1); reward(970,12,1); reward(971,12,1)
-- Likewise one notice cannot be used to classify two independent receipts.
receipt(980,'loot',13,1); receipt(981,'loot',13,1); reward(980,13,1)
local window = save('loot_window', 990, {fishing=false, fromItem=false, mapID=1429, originEvidence=1})
local drop = save('drop', 990, {source='loot_window', window=window.id, itemID=9, slot=1, snapshots={}})
drop.snapshots[1] = {ts=epoch + 990,sequence=S.ReserveObservation(c),data={itemID=9,visibleQuantity=2,
    slotSources={{kind='Creature',guid='Creature-0-1-2-3-32-0001',npcID=32,name='Bandit',quantity=2}}}}
S.Changed(c,drop)
receipt(991,'loot',9,2,{observedLootWindow=window.id,source='unknown',mapID=1429})
local result = F.Build(c,epoch + 1000,1)
check(result,'mob/31',20,7); check(result,'crafted/Tailoring',25,3); check(result,'gathered/Mining',42,2,true)
check(result,'quest/109',11,2,true); check(result,'unknown',12,1)
assert(check(result,'unknown',13,2).quantity == 3)
check(result,'mob/32',9,2)
assert(#result.groups == 6 and result.expires == epoch + 1003)
check(F.Build(c,epoch + 1003,1),'mob/31',20,4)
assert(#F.Build(c,epoch + 1051,1).groups == 0 and #F.Build(alt,epoch + 1000,1).groups == 0)

local prev, now, ready = E.current, A.Now, E.RecorderReady
E.current, A.Now, E.RecorderReady = c, function()return epoch + 1000 end, function()return true end
assert(F.SetEnabled(c,true) and V.frame:IsShown())
local function pump()
    for i=1,150 do
        E.Query.ProcessPreparation(500)
        V.frame.scripts.OnUpdate(V.frame, .3)
        E.Keepsakes.Process(500)
    end
end
pump()
local frame = V.frame
assert(frame.headers[1].label:GetText() == 'Bandit' and frame.headers[1].total:GetText() == '×2')
assert(frame.tiles[1].itemID == 9 and frame.tiles[1].quantity:GetText() == '2')
assert(frame.headers[2].source == 'unknown' and frame.headers[2].total:GetText() == '×3')
assert(frame.tiles[4].itemID == 11 and frame.tiles[4].inference:IsShown())
assert(frame.next:IsShown()); frame.next:Click()
assert(frame.headers[3].source == 'mob/31' and frame.tiles[3].itemID == 20 and not frame.tiles[4]:IsShown())
frame.previous:Click()
-- Idle views do no history work. Corrections and time expiry refresh the
-- existing frame without a new login or reopening the scrapbook.
local oldBuild, builds = F.Build, 0
F.Build = function(...) builds = builds + 1; return oldBuild(...) end
pump(); assert(builds == 0)
frame.headers[1]:Click()
assert(F.Preferences(c).collapsed['mob/32'] and frame.headers[1].mark:GetText() == '+')
assert(frame.tiles[1].itemID == 13 and frame.headers[1].total:GetText() == '×2')
assert(not F.Preferences(alt).collapsed['mob/32'])
frame.headers[1]:Click()
assert(frame.tiles[1].itemID == 9 and not F.Preferences(c).collapsed['mob/32'])
pump(); assert(builds == 0)
gathered.kind, gathered.gathering, gathered.profession = 'loot', nil, nil
S.Changed(c,gathered)
pump(); assert(builds == 1)
check(F.Build(c,epoch + 1000,1),'unknown',42,2)
E.RecorderReady = function()return false end
V.frame.scripts.OnUpdate(V.frame,.3); assert(not frame.headers[1]:IsShown() and not frame.tiles[1]:IsShown())
E.RecorderReady = function()return true end
pump(); assert(frame.headers[1]:IsShown())
A.Now = function()return epoch + 1051 end
pump(); assert(frame.empty:IsShown() and not frame.headers[1]:IsShown())
F.Build = oldBuild
-- A large source continues under the same heading. Every stack appears once.
for id=101,131 do receipt(1045,'loot',id,2,{npcID=88,npcName='Gnoll'}) end
pump()
local seen = {}
for pg=1,2 do
    assert(frame.headers[1].source == 'mob/88' and frame.headers[1].total:GetText() == '×62')
    for _, tile in ipairs(frame.tiles) do
        if tile:IsShown() then
            assert(not seen[tile.itemID] and tile.quantity:GetText() == '2')
            seen[tile.itemID] = true
        end
    end
    if pg == 1 then assert(frame.next:IsEnabled()); frame.next:Click() end
end
for id=101,131 do assert(seen[id]) end
frame.headers[1]:Click()
assert(not frame.next:IsShown() and not frame.tiles[1]:IsShown())
E.current = alt; V.Sync(alt)
assert(not V.frame:IsShown() and not F.Preferences(alt).enabled)
E.current = c; V.Sync(c); pump()
assert(frame.headers[1].mark:GetText() == '+' and not frame.tiles[1]:IsShown())
frame.headers[1]:Click()
assert(frame.tiles[1]:IsShown() and frame.next:IsEnabled())
V.frame.close:Click()
assert(not F.Preferences(c).enabled and not V.frame:IsShown())
E.current, A.Now, E.RecorderReady = prev, now, ready

print('PASS floating loot: rolling personal sources, live updates, grouped tiles and character switching')
