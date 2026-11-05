local _,E=...
local V,A,S,C={},E.API,E.Store,E.Collectors; E.GatherActions=V
local function integer(v)return type(v)=='number'and v>0 and v<math.huge and v%1==0 end
local function text(v)return type(v)=='string'and v~=''and v or nil end
function V.Start(c)V.live={c=c,session=C.session,recent={},last=A.Now()}end
local function live()
    local c=E.current;if not c or not text(C.session)then return end
    if not V.live or V.live.c~=c or V.live.session~=C.session then V.Start(c)end
    local l=V.live;local now=A.Now()
    if now<l.last then
        l.recent={};l.clockGap=true
        local w=c.records[c.state.activeLootWindow];if w then w.gatherActionGap=true;S.Changed(c,w)end
    end
    l.last=now;local kept={};for _,id in ipairs(l.recent)do local r=c.records[id];if r and now>=r.ts and now-r.ts<=2 then kept[#kept+1]=id end end
    l.recent=kept;return l
end
local function attach(c,w,r)
    w.gatherActions=w.gatherActions or {};r.windows=r.windows or {}
    if r.windows[w.id]then return end
    w.gatherActions[#w.gatherActions+1]=r.id;r.windows[w.id]=true
    w.refs=w.refs or {};w.refs[#w.refs+1]=r.id
    S.Changed(c,r);S.Changed(c,w)
end
local function gap(l)
    l.recent={}
    local w=l.c.records[l.c.state.activeLootWindow]
    if w and not w.closedAt then w.gatherActionGap=true;S.Changed(l.c,w)end
end
function V.Succeeded(unit,castGUID,spellID)
    local l=live();if not l then return end
    unit=A.Plain(unit);castGUID=A.Plain(castGUID);spellID=A.Plain(spellID)
    if unit==nil then gap(l);return end
    if unit~='player'then return end
    if not text(castGUID)or not integer(spellID)then gap(l);return end
    local key=l.session..':'..castGUID;local old=l.c.records[l.c.dedup['gather_action:'..key]]
    if old then
        if old.spellID~=spellID then old.conflict=true;S.Changed(l.c,old);gap(l)end
        return old
    end
    local info=A.Call('gatherRecipe',C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo,spellID)
    if type(info)~='table'or info.recipeID~=spellID or info.isGatheringRecipe~=true or info.isSalvageRecipe~=false or info.isEnchantingRecipe~=false then gap(l);return end
    local profession=A.Call('gatherProfession',C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID,spellID)
    local data=C.Context({title='Gathering action: '..(text(info.name)or spellID),recipeID=spellID,spellID=spellID,recipeName=text(info.name),
        castGUID=castGUID,subject=l.c.id,session=l.session,source='UNIT_SPELLCAST_SUCCEEDED',classificationEvidence=1,
        isGatheringRecipe=true,isSalvageRecipe=false,isEnchantingRecipe=false,
        coverage='Successful gathering-recipe cast observed; item receipt and node identity unconfirmed.',windows={}})
    if type(profession)=='table'then data.profession=text(profession.professionName);data.professionID=integer(profession.professionID)and profession.professionID or nil end
    local r=S.Add(l.c,'gather_action',A.Now(),data,key)
    if #l.recent>=32 then gap(l);l.clockGap=true;return r end
    l.recent[#l.recent+1]=r.id
    local w=l.c.records[l.c.state.activeLootWindow]
    if w and not w.closedAt and w.session==l.session and r.ts>=w.ts and r.ts-w.ts<=2 then attach(l.c,w,r)end
    A.status.gatherActions='Client-classified gathering casts recorded; receipt links remain inferred.'
    return r
end
E.On('RECORD_ADDED',function(c,w)
    if w.kind~='loot_window'or c~=E.current then return end
    local l=live();if not l or w.session~=l.session then return end
    w.gatherActionCapture=1;w.gatherActions={}
    if l.clockGap then w.gatherActionGap=true;l.clockGap=nil end
    for _,id in ipairs(l.recent)do local r=c.records[id];if r and w.ts>=r.ts and w.ts-r.ts<=2 then attach(c,w,r)end end
end)
local prior=C.handlers.UNIT_SPELLCAST_SUCCEEDED
C.handlers.UNIT_SPELLCAST_SUCCEEDED=function(...)if prior then prior(...)end;return V.Succeeded(...)end
for _,event in ipairs({'UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED'})do
    local before=C.handlers[event]
    C.handlers[event]=function(unit,...)
        if before then before(unit,...)end
        unit=A.Plain(unit);if unit==nil or unit=='player'then local l=live();if l then
            local castGUID=A.Plain((...));local r=unit=='player'and text(castGUID)and l.c.records[l.c.dedup['gather_action:'..l.session..':'..castGUID]]
            if r then r.conflict=true;r.failureObserved=true;S.Changed(l.c,r)end
            gap(l)
        end end
    end
end
