local _,E=...
local M,A={},E.API;E.CombatMeter=M
local function number(v)return type(v)=='number'and v==v and v>=0 and v<math.huge and v or nil end
local function id(v)return type(v)=='number'and v==v and math.abs(v)<=9007199254740991 and v%1==0 and v or nil end
local function text(v)return type(v)=='string'and v~=''and v or nil end
local function input(v)local ok,value,hidden=pcall(A.Plain,v);return value,not ok or hidden end
local function method(name)return C_DamageMeter and C_DamageMeter[name]end
local function accessReady()
    return type(issecretvalue)=='function'and type(canaccessvalue)=='function'and type(canaccesstable)=='function'
end
local function coverage(label)return A.status[label]=='restricted values omitted'and'partial'or'observed'end
local function rows(raw,convert)
    if type(raw)~='table'then return nil,'unavailable'end
    local keys,out,partial={},{},false
    for k in pairs(raw)do if id(k)and k>=1 then keys[#keys+1]=k else partial=true end end
    table.sort(keys)
    for i,k in ipairs(keys)do
        if k~=i then partial=true end
        local row=type(raw[k])=='table'and convert(raw[k])
        if row then row.sourceIndex=k;out[#out+1]=row;if row.coverage=='partial'then partial=true end else partial=true end
    end
    return out,partial and'partial'or'observed'
end
function M.Availability()
    local available,reason=A.Call('combatMeterAvailability',method('IsDamageMeterAvailable'))
    local state={available=type(available)=='boolean'and available or nil,reason=text(reason)}
    -- Preserve false; Lua's and/or idiom otherwise turns it into nil.
    if available==false then state.available=false end
    A.status.combatMeter=available==true and'Client reports a meter; accessible session observations can be recorded.'
        or available==false and('Meter unavailable'..(state.reason and(': '..state.reason)or'.'))
        or'Meter availability is unknown; missing data is not zero damage.'
    return state
end
function M.AvailableSessions()
    local state=M.Availability();if state.available~=true then return nil,state.reason or A.status.combatMeter end
    if not accessReady()then return nil,'Required value-access checks are unavailable.'end
    local raw=A.Call('combatMeterSessions',method('GetAvailableCombatSessions'))
    local result,quality=rows(raw,function(r)
        if not id(r.sessionID)then return end
        return {sessionID=r.sessionID,name=text(r.name),durationSeconds=number(r.durationSeconds)}
    end)
    if not result then return nil,'Session list unavailable; no empty history inferred.'end
    local seen={}
    for _,r in ipairs(result)do
        if seen[r.sessionID]then quality='partial';r.duplicateID=true;seen[r.sessionID].duplicateID=true else seen[r.sessionID]=r end
    end
    if coverage('combatMeterSessions')=='partial'then quality='partial'end
    return {sessions=result,coverage=quality,observedAt=A.Now()}
end
local function damageType(kind)
    if kind~='DamageDone'and kind~='EnemyDamageTaken'then return end
    local value=A.Plain(Enum and Enum.DamageMeterType and Enum.DamageMeterType[kind])
    return id(value)
end
local function ready(sessionID,kind)
    sessionID=input(sessionID);kind=input(kind)
    if not id(sessionID)then return nil,'Session ID unavailable or invalid.'end
    if not accessReady()then return nil,'Required value-access checks are unavailable.'end
    local value=damageType(kind);if value==nil then return nil,'Requested meter type is unavailable.'end
    if M.Availability().available~=true then return nil,A.status.combatMeter end
    return value,nil,sessionID
end
function M.Session(sessionID,kind)
    local value,reason,cleanID=ready(sessionID,kind);if value==nil then return nil,reason end
    sessionID=cleanID;kind=input(kind)
    local raw=A.Call('combatMeterSession',method('GetCombatSessionFromID'),sessionID,value)
    if type(raw)~='table'then return nil,'Session contents unavailable; no zero totals inferred.'end
    local sources,quality=rows(raw.combatSources,function(r)
        local row={sourceGUID=text(r.sourceGUID),sourceCreatureID=id(r.sourceCreatureID),name=text(r.name),
            classFilename=text(r.classFilename),totalAmount=number(r.totalAmount),reportedPerSecond=number(r.amountPerSecond),
            sourceDisplayType=id(r.sourceDisplayType),classification=text(r.classification)}
        if type(r.isLocalPlayer)=='boolean'then row.isLocalPlayer=r.isLocalPlayer end
        row.coverage=row.totalAmount~=nil and(row.sourceGUID or row.sourceCreatureID)and'observed'or'partial'
        return row
    end)
    if coverage('combatMeterSession')=='partial'or raw.totalAmount==nil then quality='partial'end
    local out={sessionID=sessionID,meterKind=kind,observedAt=A.Now(),totalAmount=number(raw.totalAmount),
        durationSeconds=number(raw.durationSeconds),sources=sources,coverage=quality}
    if not out.totalAmount then out.coverage='partial'end
    -- No wall-clock start/end, outcome, group, player GUID or pet ownership is inferred.
    return out
end
function M.Source(sessionID,kind,sourceGUID,sourceCreatureID)
    local hiddenGUID,hiddenCreature
    sourceGUID,hiddenGUID=input(sourceGUID);sourceCreatureID,hiddenCreature=input(sourceCreatureID)
    if hiddenGUID or hiddenCreature then return nil,'Source identity is restricted.'end
    if sourceGUID~=nil and not text(sourceGUID)or sourceCreatureID~=nil and not id(sourceCreatureID)then return nil,'Source identity is invalid.'end
    if sourceGUID==nil and sourceCreatureID==nil then return nil,'No source identity was reported.'end
    local value,reason,cleanID=ready(sessionID,kind);if value==nil then return nil,reason end
    sessionID=cleanID;kind=input(kind)
    local raw=A.Call('combatMeterSource',method('GetCombatSessionSourceFromID'),sessionID,value,sourceGUID,sourceCreatureID)
    if type(raw)~='table'then return nil,'Source details unavailable.'end
    local spells,quality=rows(raw.combatSpells,function(r)
        local details=type(r.combatSpellDetails)=='table'and r.combatSpellDetails or{}
        local row={spellID=id(r.spellID),totalAmount=number(r.totalAmount),reportedPerSecond=number(r.amountPerSecond),
            creatureName=text(r.creatureName),overkillAmount=number(r.overkillAmount),
            target={name=text(details.unitName),classFilename=text(details.unitClassFilename),classification=text(details.classification),amount=number(details.amount)}}
        for _,k in ipairs({'isPet','isMob'})do if type(details[k])=='boolean'then row.target[k]=details[k]end end
        for _,k in ipairs({'isAvoidable','isDeadly'})do if type(r[k])=='boolean'then row[k]=r[k]end end
        row.coverage=row.spellID and row.totalAmount~=nil and row.target.amount~=nil and'observed'or'partial'
        return row
    end)
    if coverage('combatMeterSource')=='partial'or not number(raw.totalAmount)then quality='partial'end
    return {sessionID=sessionID,meterKind=kind,sourceGUID=sourceGUID,sourceCreatureID=sourceCreatureID,
        observedAt=A.Now(),totalAmount=number(raw.totalAmount),spells=spells,coverage=quality}
end
function M.Rate(amount,duration)
    amount=input(amount);duration=input(duration)
    if number(amount)==nil or number(duration)==nil or duration<=0 then return end
    return number(amount/duration)
end
function M.Diagnose()
    local result,reason=M.AvailableSessions()
    A.status.combatMeterRead=result and(#result.sessions..' available meter sessions ('..result.coverage..'); this diagnostic does not create records.')or reason
    A.status.combatMeterSample='No damage-session ID has been announced during this addon session.'
    A.status.combatMeterDetails='Source detail operation not tested.'
    local kind=damageType('DamageDone');local sessionID=kind and M.announced[kind]
    if result and sessionID~=nil then
        local sample,why=M.Session(sessionID,'DamageDone')
        if sample then
            A.status.combatMeterSample='Announced session '..sessionID..': '..(sample.sources and #sample.sources..' source rows'or'source rows unavailable')..
                '; '..sample.coverage..'; total '..(sample.totalAmount~=nil and tostring(sample.totalAmount)or'unavailable')..
                '; duration '..(sample.durationSeconds~=nil and tostring(sample.durationSeconds)..' s'or'unavailable')..'. Snapshot, not a completed pull.'
            for _,source in ipairs(sample.sources or{})do if source.sourceGUID or source.sourceCreatureID then
                local detail,unavailable=M.Source(sessionID,'DamageDone',source.sourceGUID,source.sourceCreatureID)
                A.status.combatMeterDetails=detail and('One source queried: '..(detail.spells and #detail.spells..' spell rows'or'spell rows unavailable')..'; '..detail.coverage..'.')or unavailable
                break
            end end
        else A.status.combatMeterSample=why end
    end
    return A.status.combatMeterRead
end
-- Diagnostic counters are transient. The separate collector persists permitted observations.
M.announced={};M.events={}
function M.Observe(event,kind,sessionID)
    M.events[event]=(M.events[event]or 0)+1
    if event=='DAMAGE_METER_RESET'then M.announced={}
    elseif event=='DAMAGE_METER_COMBAT_SESSION_UPDATED'then
        kind=input(kind);sessionID=input(sessionID)
        if id(kind)and id(sessionID)then M.announced[kind]=sessionID end
    end
    if E.Pulls then E.Pulls.Observe(event,kind,sessionID)end
end
for _,event in ipairs({'DAMAGE_METER_COMBAT_SESSION_UPDATED','DAMAGE_METER_CURRENT_SESSION_UPDATED','DAMAGE_METER_RESET'})do
    local name=event;local prior=E.Collectors.handlers[name]
    E.Collectors.handlers[name]=function(...)if prior then prior(...)end;M.Observe(name,...)end
end
