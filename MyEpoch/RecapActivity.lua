local _,E=...
local M,A,S,C={},E.API,E.Store,E.Collectors;E.RecapActivity=M
local function plain(v)local ok,value,hidden=pcall(A.Plain,v);if ok and not hidden then return value end end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<=9007199254740991 end
local function nonnegative(v)return finite(v)and v>=0 end
local function live()
    local c=E.current;if not c then return end
    if not M.live or M.live.owner~=c or M.live.session~=C.session then M.live={owner=c,session=C.session}end
    return M.live
end
local function amount(kind,value,label,extra)
    local state=live();if not state or not nonnegative(value)or value==0 then return end
    local data=extra or{};data.subject=state.owner.id;data.amount=value;data.session=state.session
    data.title=label..': '..E.Number(value);data.coverage='Observed activity only; gaps remain unknown.'
    return S.Add(state.owner,kind,A.Now(),data)
end
function M.XP(unit,baseline)
    local state=live();if not state or plain(unit)~='player'then return end
    local xp=A.Call('recapXP',UnitXP,'player');local maximum=A.Call('recapXPMax',UnitXPMax,'player')
    local level=A.Call('recapXPLevel',UnitLevel,'player')
    if not nonnegative(xp)or not nonnegative(maximum)or not nonnegative(level)or xp>maximum then state.xp=nil;return end
    local prior=state.xp;local current={xp=xp,maximum=maximum,level=level,ts=A.Now()}
    if prior and not baseline then
        if level==prior.level and xp>=prior.xp and maximum==prior.maximum then
            state.xp=current;return amount('xp',xp-prior.xp,'XP gained')
        elseif level==prior.level+1 and prior.maximum>0 then
            state.xp=current;return amount('xp',prior.maximum-prior.xp+xp,'XP gained',{coverage='Observed single-level rollover.'})
        elseif level==prior.level and xp<prior.xp and A.Now()-prior.ts<=5 then
            -- XP may reset before the level update becomes readable. Keep the
            -- old endpoint briefly; never guess thresholds for skipped levels.
            return
        end
        A.status.recapXP='XP baseline reset after an ambiguous level/XP transition; missing XP is unknown.'
    end
    state.xp=current
end
function M.Distance()
    local state=live();if not state then return end
    local x,y,z,map=A.Call('recapPosition',UnitPosition,'player')
    local speed,run,flight,swim=A.Call('recapMovementSpeed',GetUnitSpeed,'player')
    local taxi=A.Call('recapTaxi',UnitOnTaxi,'player')
    if not finite(x)or not finite(y)or not finite(z)or not finite(map)or not nonnegative(speed)
        or not nonnegative(run)or not nonnegative(flight)or not nonnegative(swim)or taxi~=false then state.position=nil;return end
    local now=A.Now();local prior=state.position
    state.position={x=x,y=y,z=z,map=map,ts=now,speed=math.max(speed,run,flight,swim)}
    if not prior or prior.map~=map then return end
    local dt=now-prior.ts;if dt<=0 or dt>15 then return end
    local distance=math.sqrt((x-prior.x)^2+(y-prior.y)^2+(z-prior.z)^2)
    if distance>math.max(prior.speed,state.position.speed)*dt+5 then
        A.status.recapDistance='Position jump omitted; distance is a sampled estimate.';return
    end
    A.status.recapDistance='Straight-line movement between readable samples; taxis, long gaps, map changes and implausible jumps excluded.'
    return amount('travel',distance,'Distance traveled (estimated yards)')
end
local function ownName(value,c)
    if type(value)~='string'or c.identity.nameKnown==false then return false end
    local name=c.identity.name;local realm=c.identity.realm
    return name and(value==name or realm and value==name..'-'..realm)or false
end
local function finishDuel(state)
    local message=state.duelMessage;local finished=state.duelFinished
    if not message or not finished or finished.record or math.abs(message.ts-finished.ts)>5 then return end
    local c=state.owner;local won,lost=ownName(message.winner,c),ownName(message.loser,c)
    if won==lost then return end
    local outcome=won and'won'or'lost'
    finished.record=S.Add(c,'duel',finished.ts,{title='Duel '..outcome,subject=c.id,outcome=outcome,
        winner=message.winner,loser=message.loser,session=state.session,
        coverage='Personal duel-finished event matched a localized system result within five seconds.'})
    state.duelMessage=nil;return finished.record
end
function M.DuelFinished()
    local state=live();if not state then return end
    local now=A.Now()
    if not state.duelFinished or now-state.duelFinished.ts>5 then state.duelFinished={ts=now}end
    return finishDuel(state)
end
function M.SystemMessage(message)
    local state=live();message=plain(message);if not state or type(message)~='string'then return end
    for _,key in ipairs({'DUEL_WINNER_KNOCKOUT','DUEL_WINNER_RETREAT'})do
        local args=A.MatchFormat(plain(_G[key]),message)
        if args and args[1]and args[2]then
            state.duelMessage={winner=args[1],loser=args[2],ts=A.Now()};return finishDuel(state)
        end
    end
end
function M.BattlegroundActive()
    local state=live();if not state then return end
    local inside,kind=A.Call('recapBGInstance',IsInInstance)
    local active=A.Call('recapBGState',C_PvP and C_PvP.GetActiveMatchState)
    local engaged=plain(Enum and Enum.PvPMatchState and Enum.PvPMatchState.Engaged)
    if inside==true and kind=='pvp'and engaged~=nil and active==engaged then state.owner.state.recapBGCompleted=nil;S.Touch(state.owner)end
end
function M.BattlegroundComplete(winner)
    local state=live();if not state or state.owner.state.recapBGCompleted then return end
    winner=plain(winner);if winner~=0 and winner~=1 then return end
    local inside,kind=A.Call('recapBGInstance',IsInInstance)
    if inside~=true or kind~='pvp'or A.Call('recapBGSpectator',C_Commentator and C_Commentator.IsSpectating)~=false then return end
    local faction=A.Call('recapBGTeam',GetBattlefieldArenaFaction)
    if faction~=0 and faction~=1 then return end
    local c=state.owner;local outcome=winner==faction and'won'or'lost'
    -- Persist the completion latch across UI reloads. Only observed entry into
    -- an active match or a non-BG world clears it; no guessed match ID is used.
    c.state.recapBGCompleted=true;S.Touch(c)
    return S.Add(c,'battleground',A.Now(),{title='Battleground '..outcome,subject=c.id,outcome=outcome,
        winner=winner,playerTeam=faction,session=state.session,coverage='Personal completed battleground event; draws and unknown results excluded.'})
end
function M.World()
    local state=live();if not state then return end
    state.position=nil;state.xp=nil;state.duelMessage=nil;state.duelFinished=nil
    M.XP('player',true)
    local inside,kind=A.Call('recapBGInstance',IsInInstance)
    if inside==false or inside==true and kind~='pvp'then state.owner.state.recapBGCompleted=nil;S.Touch(state.owner)end
end
function M.Roll(c,r)
    if r.kind~='drop'or r.source~='roll_history'or not nonnegative(r.sourceStartTime)
        or not nonnegative(r.encounterID)or not nonnegative(r.lootListKey)or not nonnegative(r.encounterStartTime)then return end
    local data=r.latest or{};local winner=data.winner
    local confirmed=winner and winner.isWinner==true and (winner.isSelf==true or winner.playerGUID==c.id)
        and data.allPassed~=true and data.isTied~=true or false
    local key='roll:'..r.encounterID..':'..r.lootListKey..':'..r.sourceStartTime..':'..tostring(r.encounterStartTime or '?')
    local saved=c.records[c.dedup['roll_win:'..key]]
    if saved then
        if saved.confirmed~=confirmed then saved.confirmed=confirmed;S.Changed(c,saved)end
    elseif confirmed then
        return S.Add(c,'roll_win',A.Now(),{title='Item roll won: '..(r.title or'Unknown item'),subject=c.id,
            confirmed=true,itemID=r.itemID,refs={r.id},coverage='Winner first observed; receipt and original roll date unconfirmed.'},key)
    end
end
local function hook(event,fn)
    local prior=C.handlers[event];C.handlers[event]=function(...)if prior then prior(...)end;fn(...)end
end
hook('PLAYER_XP_UPDATE',M.XP)
hook('PLAYER_ENTERING_WORLD',M.World)
hook('PLAYER_LEAVING_WORLD',function()local state=live();if state then state.position=nil;state.xp=nil end end)
hook('DUEL_FINISHED',M.DuelFinished);hook('CHAT_MSG_SYSTEM',M.SystemMessage)
hook('PVP_MATCH_ACTIVE',M.BattlegroundActive);hook('PVP_MATCH_COMPLETE',M.BattlegroundComplete)
local heartbeat=C.Heartbeat
C.Heartbeat=function(...)heartbeat(...);M.XP('player');M.Distance()end
E.On('RECORD_ADDED',M.Roll);E.On('RECORD_CHANGED',M.Roll)
