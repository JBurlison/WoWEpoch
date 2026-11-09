local _,E=...
local V,A,S,C={},E.API,E.Store,E.Collectors;E.RecapVitals=V
local function plain(v)local ok,value,hidden=pcall(A.Plain,v);if ok and not hidden then return value end end
local function number(v)return type(v)=='number'and v==v and v>=0 and v<=9007199254740991 end
local function player(unit)return not A.OtherUnit(unit)and plain(unit)=='player'end
local function record(kind,amount,source)
    local c=E.current;if not c then return end
    local label=kind=='damage'and'Damage taken'or'Health gained'
    local now=A.Now();local prior=c.records[c.order[#c.order]]
    -- Only adjacent observations in the same second can merge. Any intervening
    -- milestone keeps its exact observation-order boundary intact.
    if prior and prior.kind==kind and prior.ts==now and prior.session==C.session and prior.amount+amount<=9007199254740991 then
        prior.amount=prior.amount+amount;prior.title=label..': '..E.Number(prior.amount);S.Changed(c,prior);return prior
    end
    return S.Add(c,kind,now,{title=label..': '..E.Number(amount),subject=c.id,amount=amount,session=C.session,
        source=source,coverage='Readable observations only; unobserved activity remains unknown.'})
end
function V.Damage(unit,event,flags,amount)
    if not E.current or not player(unit)or plain(event)~='WOUND'then return end
    amount=plain(amount)
    if not number(amount)then A.status.recapDamage='Damage amounts unavailable or restricted; omitted, not counted as zero.';return end
    A.status.recapDamage='Readable player UNIT_COMBAT wound amounts only; complete damage coverage is unverified.'
    return record('damage',amount,'UNIT_COMBAT WOUND')
end
function V.Reset()V.sample=nil end
function V.Health(unit)
    if not E.current or not player(unit)then return end
    local health=A.Call('recapHealthValue',UnitHealth,'player',false)
    local maximum=A.Call('recapHealthMaximum',UnitHealthMax,'player')
    local dead=A.Call('recapHealthAlive',UnitIsDeadOrGhost,'player')
    if not number(health)or not number(maximum)or health>maximum or dead~=false or health==0 then
        V.Reset();A.status.recapHealth='Health observation unavailable, restricted or dead; next readable value starts a new baseline.';return
    end
    local previous=V.sample
    V.sample={owner=E.current,session=C.session,health=health,maximum=maximum,ts=A.Now()}
    A.status.recapHealth='Observed positive health changes, including regeneration; resurrection and maximum-health changes reset the baseline.'
    if previous and previous.owner==E.current and previous.session==C.session and previous.maximum==maximum and previous.ts<=A.Now()and health>previous.health then
        return record('health',health-previous.health,'UNIT_HEALTH positive change')
    end
end
local function hook(event,fn)
    local prior=C.handlers[event]
    C.handlers[event]=function(...)if prior then prior(...)end;fn(...)end
end
hook('UNIT_COMBAT',V.Damage)
hook('UNIT_HEALTH',V.Health)
hook('UNIT_MAXHEALTH',function(unit)if player(unit)then V.Reset()end end)
for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_LOGOUT'})do hook(event,V.Reset)end
