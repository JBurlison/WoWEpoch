local _,E=...
local X,A,S,C={},E.API,E.Store,E.Collectors;E.ExperienceSources=X
-- Session-local evidence only. The observed XP delta remains the sole source
-- of totals; messages and rewards describe it, never add a second XP receipt.
local function state()
    if not E.current then X.live=nil;return end
    if not X.live or X.live.owner~=E.current or X.live.session~=C.session then
        X.live={owner=E.current,session=C.session,gains={},causes={}}
    end
    if X.live.blockedUntil and A.Now()<=X.live.blockedUntil then return end
    return X.live
end
local function positive(n)return type(n)=='number'and n>0 and n<9007199254740991 and n%1==0 end
local function plain(v)local ok,value,hidden=pcall(A.Plain,v);if ok and not hidden then return value end end
local function append(list,value)
    list[#list+1]=value
    if #list>128 then
        -- An overflow must not make ambiguous evidence look unique.
        X.live.gains={};X.live.causes={};X.live.blockedUntil=A.Now()+8
    end
end
function X.Observe(c,r)
    if c~=E.current then return end
    local st=state();if not st then return end
    if r.kind=='xp'and r.subject==c.id and r.session==st.session and positive(r.amount)then
        append(st.gains,r)
    elseif r.kind=='quest'and r.status=='completed'and r.rewards and positive(r.rewards.xp)then
        append(st.causes,{kind='quest',amount=r.rewards.xp,ts=r.ts,name=r.title,questID=r.questID,recordID=r.id})
    end
end
function X.Message(message,exploration)
    local st=state();message=plain(message)
    if not st or type(message)~='string'then return end
    local keys=exploration and {'ERR_ZONE_EXPLORED_XP'}or{
        'COMBATLOG_XPGAIN_FIRSTPERSON','COMBATLOG_XPGAIN_FIRSTPERSON_GROUP','COMBATLOG_XPGAIN_FIRSTPERSON_RAID',
        'COMBATLOG_XPGAIN_EXHAUSTION1','COMBATLOG_XPGAIN_EXHAUSTION2','COMBATLOG_XPGAIN_EXHAUSTION4','COMBATLOG_XPGAIN_EXHAUSTION5',
        'COMBATLOG_XPGAIN_EXHAUSTION1_GROUP','COMBATLOG_XPGAIN_EXHAUSTION2_GROUP','COMBATLOG_XPGAIN_EXHAUSTION4_GROUP','COMBATLOG_XPGAIN_EXHAUSTION5_GROUP'}
    for _,key in ipairs(keys)do
        local args=A.MatchFormat(plain(_G[key]),message)
        local amount=args and tonumber(args[2])
        if args and type(args[1])=='string'and args[1]~=''and positive(amount)then
            append(st.causes,{kind=exploration and 'exploration'or'kill',name=args[1],amount=amount,ts=A.Now(),message=message,format=key})
            return
        end
    end
end
function X.Process()
    local st=state();if not st then return end
    local now=A.Now()
    for _,gain in ipairs(st.gains)do
        if not gain.xpCause and not gain.xpCauseDismissed and st.owner.records[gain.id]==gain and now-gain.ts>=3 and now-gain.ts<=8 then
            local match,count=nil,0
            for _,cause in ipairs(st.causes)do
                if cause.amount==gain.amount and math.abs(cause.ts-gain.ts)<=2 then match=cause;count=count+1 end
            end
            if count==1 and not match.used and (not match.recordID or st.owner.records[match.recordID])then
                local candidates=0
                for _,other in ipairs(st.gains)do
                    if other.amount==match.amount and math.abs(other.ts-match.ts)<=2 then candidates=candidates+1 end
                end
                if candidates==1 then
                    match.used=true;gain.xpCause=E.Copy(match);gain.xpCause.used=nil;gain.xpCause.attribution='inferred'
                    if match.recordID then gain.refs=gain.refs or{};gain.refs[#gain.refs+1]=match.recordID end
                    S.Changed(st.owner,gain)
                end
            end
        end
    end
    for _,list in ipairs({st.gains,st.causes})do
        for i=#list,1,-1 do if now-list[i].ts>8 or now<list[i].ts then table.remove(list,i)end end
    end
end
function X.Dismiss(c,r)
    local cause=r.xpCause;if not cause then return end
    if cause.recordID then for i=#(r.refs or{}),1,-1 do if r.refs[i]==cause.recordID then table.remove(r.refs,i)end end end
    r.xpCause=nil;r.xpCauseDismissed=true;S.Changed(c,r)
end
local function hook(event,fn)
    local prior=C.handlers[event];C.handlers[event]=function(...)if prior then prior(...)end;fn(...)end
end
hook('CHAT_MSG_COMBAT_XP_GAIN',function(message)X.Message(message,false)end)
hook('CHAT_MSG_SYSTEM',function(message)X.Message(message,true)end)
hook('PLAYER_LEAVING_WORLD',function()X.live=nil end)
hook('PLAYER_ENTERING_WORLD',function()X.live=nil end)
local heartbeat=C.Heartbeat
C.Heartbeat=function(...)heartbeat(...);X.Process()end
E.On('RECORD_ADDED',X.Observe)
