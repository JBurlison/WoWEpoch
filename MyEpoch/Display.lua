local _,E=...
local D,A={},E.API;E.Display=D
-- Presentation only: never replace captured names, links, IDs or journal text.
local function id(value)return type(value)=='number'and value>0 and value%1==0 and value<2147483648 end
local function text(value)return type(value)=='string'and value~=''and value or nil end
function D.Item(itemID,fallback)
    local name
    if id(itemID)then
        name=A.Call('displayItemName',C_Item and C_Item.GetItemInfo,itemID)
    end
    return text(name) or fallback or E.Format('Item {id}',{id=itemID or '?'})
end
function D.Quest(questID,fallback)
    local name=id(questID)and A.QuestTitle(questID)
    return text(name)or fallback or E.Format('Quest {id}',{id=questID or '?'})
end
function D.Map(mapID,fallback)
    local info=id(mapID)and A.Call('displayMapName',C_Map and C_Map.GetMapInfo,mapID)
    if type(info)=='table'and info.mapID==mapID and text(info.name)then return info.name end
    return fallback or E.Format('Map {id}',{id=mapID or '?'})
end
function D.Zone(record)
    if type(record)~='table'then return end
    -- instanceMapID is a different ID space and must never be passed to C_Map.
    if not record.mapID then return record.zone end
    return D.Map(record.mapID,record.zone)
end
function D.Skill(skillID,fallback)
    local info=id(skillID)and A.Call('displaySkillName',C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID,skillID)
    return type(info)=='table'and info.skillID==skillID and text(info.name)or fallback or E.L.Skill
end
function D.Class(identity)
    identity=identity or{}
    local info=id(identity.classID)and A.Call('displayClassName',C_CreatureInfo and C_CreatureInfo.GetClassInfo,identity.classID)
    if type(info)=='table'and info.classID==identity.classID and text(info.className)then return info.className end
    return identity.className or identity.classFile or E.L['Class not recorded']
end
function D.SpellName(spellID,fallback)
    local info=id(spellID)and A.Call('displaySpellName',C_Spell and C_Spell.GetSpellInfo,spellID)
    return type(info)=='table'and info.spellID==spellID and text(info.name)or fallback
end
local kinds={quest='Quest',quest_attempt='Quest attempt',objective='Quest objective',loot='Loot',
    crafted='Crafted',gathered='Gathered',drop='Observed drop',group='Group session',chat='Group chat',
    gold='Wallet change',balance='Observed wallet balance',wallet_window='Wallet observation interval',
    milestone='Milestone',death='Death',spell='Learning',memory='Memory',screenshot='Captured moment',
    play='Play time',xp='Experience gained',encounter='Boss encounter',pull='Pull history',
    quest_reward='Quest reward event',encounter_loot='Encounter loot notice',recap='Recap',diary='Diary',
    travel='Journey',position='Position',zone='Location',gap='Recording gap',inventory='Inventory',
    cost_lot='Acquisition record',stock_move='Inventory outflow',stock_reset='Inventory baseline',
    bank='Bank observation',auction='Auction',trade='Trade',mail='Mail'}
function D.Kind(kind)return E.L[kinds[kind]or kind or 'Unknown']end
function D.MilestoneTitle(r)
    if E.locale=='enUS'then return r.title end
    local kind=r.milestoneType
    if kind=='level'and r.after then
        return E.Format('Character level {before} → {after}',{before=r.before or '?',after=r.after})
    elseif kind=='discovery'and(r.mapID or r.zone)then
        return E.Format('First recorded visit: {place}',{place=D.Zone(r)})
    elseif (kind=='skill'or kind=='profession')and r.after then
        return E.Format('{skill}: {before} → {after}',{skill=D.Skill(r.skillID,r.skillName),before=r.before or '?',after=r.after})
    elseif kind=='achievement'and r.achievementName then
        return E.Format('Achievement: {name}',{name=r.achievementName})
    end
    return r.title
end
function D.RecordTitle(r)
    if type(r)~='table'then return E.L.Unknown end
    local kind=r.kind
    if kind=='xp'and type(r.amount)=='number'then
        local title=E.L['XP gained']..': '..E.Number(r.amount)
        local cause=r.xpCause
        if cause then
            local label=({quest='Quest',kill='Kill',exploration='Exploration'})[cause.kind]
            local name=cause.kind=='quest'and D.Quest(cause.questID,cause.name)or cause.name
            if label and name then title=title..' / '..E.L[label]..': '..name..' ('..E.L['inferred']..')'end
        end
        return title
    end
    if kind=='memory'or kind=='screenshot'or kind=='chat'then return r.title or D.Kind(kind)end
    if E.locale~='enUS'and kind=='diary'and r.day and r.title=='Diary - '..r.day then
        return E.L['Daily diary']..' - '..r.day
    end
    if E.locale~='enUS'and kind=='recap'and r.periodKind and type(r.from)=='number'then
        local prefix=({daily='Daily',weekly='weekly',monthly='monthly',yearly='yearly'})[r.periodKind]
        if prefix and r.title==prefix..' recap - '..A.Day(r.from)then
            return E.L[({daily='Daily',weekly='Weekly',monthly='Monthly',yearly='Yearly'})[r.periodKind]]..' / '..E.L.Recap..' - '..A.Day(r.from)
        end
    end
    if (kind=='quest'or kind=='quest_attempt')and id(r.questID)then return D.Quest(r.questID,r.title)end
    if (kind=='loot'or kind=='crafted'or kind=='gathered'or kind=='drop')and id(r.itemID)then return D.Item(r.itemID,r.title)end
    if kind=='milestone'then return D.MilestoneTitle(r)or D.Kind(kind)end
    if kind=='spell'and E.locale~='enUS'then
        local name=D.SpellName(r.spellID,r.spellName)
        if name then return E.Format('Learning recorded: {name}',{name=name})end
    end
    if kind=='pull'and not r.meterName and r.meterSessionID and r.title=='Meter session '..r.meterSessionID then
        return E.Format('Meter session {id}',{id=r.meterSessionID})
    end
    if (kind=='trade'or kind=='trade_offer')and r.partner then
        local prefix=kind=='trade'and'Trade with 'or'Offer with '
        if r.title==prefix..r.partner then return E.Format(kind=='trade'and'Trade with {name}'or'Offer with {name}',{name=r.partner})end
    end
    -- Translate known addon-generated defaults only. Custom captured titles stay intact.
    local defaults={group='Adventures together',gold='Wallet change',balance='Observed wallet balance',
        wallet_window='Wallet observation interval',death='A death to remember'}
    if r.title and defaults[kind]==r.title then return E.L[r.title]end
    local systemTitles={
        inventory={['Inventory observation baseline']=true,['Inventory locations changed']=true,['Inventory counts changed']=true},
        inventory_gap={['Inventory observation gap']=true},
        cost_lot={['Inventory count increase; acquisition cost unknown']=true,['Inferred vendor purchase cost']=true},
        stock_move={['Inventory count decrease; destination and cause unknown']=true,['Inferred vendor sale']=true},
        merchant={['Merchant observations']=true},
        bank={['Account bank observation']=true,['Character bank observation']=true,['Account bank baseline']=true,['Character bank baseline']=true},
        bank_gap={['Account bank observation ended']=true,['Character bank observation ended']=true},
        mail_draft={['Outgoing attachment observations']=true},mail_scan={['Mailbox observation']=true},
        mail_collection={['Mailbox collection']=true},mail_request={['Send-mail request']=true,['Mailbox request']=true},
        mail_notice={['Mail operation succeeded']=true,['Mail operation failed']=true,['Mail sending succeeded']=true},
    }
    if systemTitles[kind]and systemTitles[kind][r.title]then return E.L[r.title]end
    return r.title or D.Kind(kind)
end
function D.Date(ts)
    if E.locale=='enUS'then return date('%d %b %Y %H:%M',ts)end
    local d=date('*t',ts)
    local months={'January','February','March','April','May','June','July','August','September','October','November','December'}
    local month=E.localeDateMonths and E.localeDateMonths[d.month]or E.L[months[d.month]]
    return E.Format('{day} {month} {year} at {time}',{day=d.day,month=month,year=d.year,time=date('%H:%M',ts)})
end
