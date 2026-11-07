local _,E=...
local P,A,S={},E.API,E.Store; E.Progress=P
P.achievementScans=setmetatable({},{__mode="k"})
local restrictedGaps=setmetatable({},{__mode="k"})
local function id(value) return not A.Secret(value) and type(value)=="number" and value>0 and value<math.huge and value==math.floor(value) end
local function state(c)
    c.state.progress=c.state.progress or {spells={},pending={},metadata={}}
    c.state.progress.achievements=c.state.progress.achievements or {}
    return c.state.progress
end
local function playerBank() return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player end
local function known(spellID)
    local bank=playerBank(); if bank==nil then A.status.learning="Player spell-bank enum unavailable"; return end
    return A.Call("spellKnown",C_SpellBook and C_SpellBook.IsSpellKnown,spellID,bank)
end
local function spellOwnership(spellID)
    local bank=playerBank(); local types=Enum and Enum.SpellBookItemType
    if bank==nil or not types then return nil,"Spellbook identity unavailable" end
    local slot,foundBank=A.Call("spellSlot",C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell,spellID,true,true,false,false)
    if foundBank~=nil and foundBank~=bank then return false,"Non-player spell bank" end
    if not slot or foundBank==nil then return nil,"Player spellbook slot unavailable" end
    local item=A.Call("spellBookItem",C_SpellBook and C_SpellBook.GetSpellBookItemInfo,slot,bank)
    if not item or item.itemType==nil then return nil,"Spellbook item unavailable" end
    if item.itemType~=types.Spell and item.itemType~=types.Flyout then return false,"Not a learned player spell" end
    if known(spellID)~=true then return nil,"Player knowledge not confirmed" end
    return true
end
local function spellText(spellID)
    local info=A.Call("spellInfo",C_Spell and C_Spell.GetSpellInfo,spellID)
    local subtext=A.Call("spellSubtext",C_Spell and C_Spell.GetSpellSubtext,spellID)
    -- Do not replace the event's spell with a different override's identity.
    if not info or info.spellID~=spellID then return end
    return type(info.name)=="string" and info.name~="" and info.name or nil,subtext,info.originalIconID or info.iconID
end
local function achievementInfo(achievementID)
    local valid=A.Call("achievementValid",C_AchievementInfo and C_AchievementInfo.IsValidAchievement,achievementID)
    if valid==false then return false,"Invalid achievement" end
    local guild=A.Call("achievementGuild",C_AchievementInfo and C_AchievementInfo.IsGuildAchievement,achievementID)
    if guild==true then return false,"Guild achievement" end
    if valid~=true or guild~=false then return nil,"Achievement scope unavailable" end
    local result={A.Call("achievementInfo",GetAchievementInfo,achievementID)}
    if result[1]~=achievementID or result[4]~=true or result[13]~=true then return nil,"Completion by this character is not confirmed" end
    return true,{name=result[2],description=result[8],icon=result[10],source="GetAchievementInfo: completed and wasEarnedByMe"}
end
function P.Refresh(c)
    if c~=E.current then return end
    for spellID,entry in pairs(state(c).spells) do
        local present=known(spellID)
        if present==false and entry.present==true then entry.epoch=(entry.epoch or 0)+1 end
        if present~=nil then entry.present=present end
    end
end
function P.Start(c)
    if c~=E.current then return end
    local st=state(c); P.Refresh(c)
    local categories=A.Call("achievementCategories",GetCategoryList)
    if type(categories)=="table" then
        local available={}; local complete=A.status.achievementCategories~="restricted values omitted"
        for _,category in pairs(categories) do if id(category) then available[#available+1]=category else complete=false end end
        table.sort(available); P.achievementScans[c]={categories=available,category=1,index=1,complete=complete}
    else A.status.achievements="Historical achievement baseline unavailable; notifications require personal-completion verification" end
    local api=C_SpellBook; local bank=playerBank(); local types=Enum and Enum.SpellBookItemType
    if not api or bank==nil or not types then A.status.learning="Spellbook baseline unavailable; event verification remains required"; return end
    local count=A.Call("spellLines",api.GetNumSpellBookSkillLines); local complete=type(count)=="number"
    for line=1,count or 0 do
        local skill=A.Call("spellLine",api.GetSpellBookSkillLineInfo,line)
        if not skill or type(skill.itemIndexOffset)~="number" or type(skill.numSpellBookItems)~="number" then complete=false
        else
            for slot=skill.itemIndexOffset+1,skill.itemIndexOffset+skill.numSpellBookItems do
                local item=A.Call("spellBookItem",api.GetSpellBookItemInfo,slot,bank)
                if not item then complete=false
                elseif item.itemType==types.Spell then
                    for _,spellID in pairs({item.actionID,item.spellID}) do
                        if id(spellID) and not st.spells[spellID] and not st.pending["spell:"..spellID] and known(spellID)==true then
                            st.spells[spellID]={present=true,epoch=0,baselineAt=A.Now()}
                        end
                    end
                end
            end
        end
    end
    A.status.learning=complete and "Visible player-spell baseline observed; no historical learning dates inferred" or "Partial spellbook baseline; hidden/flyout history may be unknown"
end
function P.ScanAchievements(c,limit)
    local scan=P.achievementScans[c]; if not scan then return end
    local st=state(c)
    for _=1,limit or 20 do
        local category=scan.categories[scan.category]
        if category==nil then
            P.achievementScans[c]=nil
            A.status.achievements=scan.complete and "Available personal completion flags observed without invented dates; unlisted history remains unknown" or "Partial achievement baseline; unavailable history remains unknown"
            return
        end
        if scan.count==nil then
            scan.count=A.Call("achievementCategoryCount",GetCategoryNumAchievements,category)
            if type(scan.count)~="number" or scan.count<0 then scan.count=0; scan.complete=false end
        end
        if scan.index>scan.count then scan.category=scan.category+1; scan.index=1; scan.count=nil
        else
            local values={A.Call("achievementBaseline",GetAchievementInfo,category,scan.index)}; scan.index=scan.index+1
            if not id(values[1]) or values[4]==nil or values[13]==nil then scan.complete=false
            elseif values[4]==true and values[13]==true and not st.pending["achievement:"..values[1]] then
                st.achievements[values[1]]=st.achievements[values[1]] or {baselineAt=A.Now()}
            end
        end
    end
end
local function enrich(c,r)
    if r.kind=="spell" then
        local name,rank,icon=spellText(r.spellID)
        if name then
            local changed=false
            if not r.spellName then r.spellName=name; r.nameObservedAt=A.Now(); r.icon=icon; changed=true end
            if not r.rankText and type(rank)=="string" and rank~="" and A.Now()>=r.ts and A.Now()-r.ts<=30 then
                r.rankText=rank; r.rankObservedAt=A.Now(); changed=true
            end
            if changed then r.title="Learning recorded: "..r.spellName..(r.rankText and " ("..r.rankText..")" or ""); S.Changed(c,r) end
            return r.rankText~=nil
        end
    elseif r.milestoneType=="achievement" then
        local personal,info=achievementInfo(r.achievementID)
        if personal and type(info.name)=="string" and info.name~="" then
            r.title="Achievement: "..info.name; r.achievementName=info.name; r.description=info.description; r.icon=info.icon
            S.Changed(c,r); return true
        end
    end
    return false
end
local function resolve(c,p)
    local st=state(c); local verified,details
    if p.kind=="spell" then verified,details=spellOwnership(p.sourceID) else verified,details=achievementInfo(p.sourceID) end
    if verified==nil then p.reason=details; return false end
    if verified==false then A.status[p.kind.."Observation"]="Excluded notification: "..details; return true end
    A.status[p.kind.."Observation"]="Personal notification verified against current character data"
    if p.kind=="spell" then
        local entry=st.spells[p.sourceID]; local prior=entry and c.records[entry.lastRecord]
        if prior and prior.learningEpoch==(entry.epoch or 0) then
            prior.notifications=prior.notifications or {{ts=prior.ts,group=prior.group,zone=prior.zone}}
            prior.refs=prior.refs or {}; local linked={}; for _,ref in ipairs(prior.refs) do linked[ref]=true end
            for _,notification in ipairs(p.notifications) do
                prior.notifications[#prior.notifications+1]=E.Copy(notification)
                if notification.group and not linked[notification.group] then prior.refs[#prior.refs+1]=notification.group; linked[notification.group]=true end
            end
            prior.notificationCount=(prior.notificationCount or 1)+p.count; prior.lastNotificationAt=p.lastAt or p.ts
            S.Changed(c,prior); return true
        end
    end
    local data=E.Copy(p.context); local r
    data.subject=c.id; data.observedEvent=p.event; data.observationSequence=p.notifications[1].sequence; data.verificationAt=A.Now(); data.notificationCount=p.count; data.notifications=p.notifications
    local linked={}; data.refs=data.refs or {}; for _,ref in ipairs(data.refs) do linked[ref]=true end
    for _,notification in ipairs(p.notifications) do if notification.group and not linked[notification.group] then data.refs[#data.refs+1]=notification.group; linked[notification.group]=true end end
    if p.kind=="spell" then
        local entry=st.spells[p.sourceID] or {epoch=0}; st.spells[p.sourceID]=entry
        local key="learning:"..p.sourceID..":"..(entry.epoch or 0)
        data.title="Learning recorded: spell "..p.sourceID; data.spellID=p.sourceID; data.skillLineIndex=p.skillLineIndex
        data.source="LEARNED_SPELL_IN_SKILL_LINE and verified player spellbook"; data.permanence="unknown"
        data.isGuildPerk=p.isGuildPerk
        data.previouslyObserved=entry.baselineAt~=nil or entry.lastRecord~=nil; data.learningEpoch=entry.epoch or 0
        r=S.Add(c,"spell",p.ts,data,key)
        entry.present=true; entry.lastRecord=r.id
    else
        data.title="Achievement "..p.sourceID; data.achievementID=p.sourceID; data.milestoneType="achievement"; data.major=true
        data.characterSnapshot=p.characterSnapshot
        data.source=details.source; data.alreadyEarnedFlag=p.alreadyEarned
        data.coverage="Personal completion confirmed during an earned-event notification; earlier completion time is not reconstructed"
        r=S.Add(c,"milestone",p.ts,data,"achievement:"..p.sourceID)
        st.achievements[p.sourceID]={record=r.id}
    end
    if not enrich(c,r) then
        st.metadata[r.id]={due=A.Now()+2,tries=0}
        if r.kind=="spell" then A.Call("spellDataRequest",C_Spell and C_Spell.RequestLoadSpellData,r.spellID) end
    end
    return true
end
local function observe(kind,sourceID,extra)
    local c=E.current; if not c then return end
    if not id(sourceID) then
        A.status[kind.."Observation"]="Restricted or invalid notification omitted"
        local gaps=restrictedGaps[c] or {}; restrictedGaps[c]=gaps
        if not gaps[kind] then
            gaps[kind]=true
            S.Add(c,"gap",A.Now(),E.Collectors.Context({title=kind.." notification unavailable",coverage="Source identity was restricted or invalid; no accomplishment was attributed"}))
        end
        return
    end
    if restrictedGaps[c] then restrictedGaps[c][kind]=nil end
    local st=state(c); local key=kind..":"..sourceID; local pending=st.pending[key]
    if kind=="achievement" and (st.achievements[sourceID] or c.dedup["milestone:achievement:"..sourceID]) then return end
    local context=E.Collectors.Context()
    local notification={ts=A.Now(),group=context.group,zone=context.zone,subzone=context.subzone,mapID=context.mapID,mapArtID=context.mapArtID,
        instanceType=context.instanceType,instanceMapID=context.instanceMapID,instanceLocationUncertain=context.instanceLocationUncertain,
        position=E.Copy(context.position),session=E.Collectors.session,sequence=S.ReserveObservation(c)}
    if pending then pending.count=pending.count+1; pending.lastAt=A.Now(); pending.notifications[#pending.notifications+1]=notification; S.Touch(c); return end
    local p={kind=kind,sourceID=sourceID,ts=A.Now(),due=A.Now()+2,count=1,context=context,notifications={notification},event=kind=="spell" and "LEARNED_SPELL_IN_SKILL_LINE" or "ACHIEVEMENT_EARNED"}
    if kind=="achievement" and E.MilestoneSnapshot then p.characterSnapshot=E.MilestoneSnapshot.Capture(c) end
    for k,v in pairs(extra or {}) do p[k]=v end
    if not resolve(c,p) then st.pending[key]=p; S.Touch(c); A.status[kind.."Observation"]="Notification queued; character ownership not yet verified" end
end
function P.Learned(spellID,skillLineIndex,isGuildPerk)
    local flag; if not A.Secret(isGuildPerk) and type(isGuildPerk)=="boolean" then flag=isGuildPerk end
    observe("spell",spellID,{skillLineIndex=id(skillLineIndex) and skillLineIndex or nil,isGuildPerk=flag})
end
function P.Achievement(achievementID,alreadyEarned)
    local flag; if not A.Secret(alreadyEarned) and type(alreadyEarned)=="boolean" then flag=alreadyEarned end
    observe("achievement",achievementID,{alreadyEarned=flag})
end
function P.Process(c,now,limit)
    if c~=E.current then return end
    P.ScanAchievements(c,20)
    local st=state(c); local work=0
    if not next(st.pending) and not next(st.metadata) then return end
    for _,key in ipairs(E.SortedKeys(st.pending)) do local p=st.pending[key]
        if p.due<=now or now<p.ts then
            if now-p.ts>30 or now<p.ts then
                local data=E.Copy(p.context); data.title="Unverified "..p.kind.." notification"; data.sourceID=p.sourceID; data.observedEvent=p.event
                data.coverage=p.reason or "Character ownership could not be verified"; data.notificationCount=p.count; data.notifications=p.notifications; data.observationSequence=p.notifications[1].sequence
                local linked={}; data.refs=data.refs or {}; for _,ref in ipairs(data.refs) do linked[ref]=true end
                for _,n in ipairs(p.notifications) do if n.group and not linked[n.group] then data.refs[#data.refs+1]=n.group; linked[n.group]=true end end
                S.Add(c,"gap",p.ts,data); st.pending[key]=nil
                A.status[p.kind.."Observation"]="Unverified notifications retained as coverage gaps"
            elseif resolve(c,p) then st.pending[key]=nil; S.Touch(c) else p.due=now+2 end
            work=work+1; if work>=(limit or 2) then return end
        end
    end
    for _,recordID in ipairs(E.SortedKeys(st.metadata)) do local job=st.metadata[recordID]
        if job.due<=now then
            local r=c.records[recordID]; job.tries=job.tries+1
            if not r or enrich(c,r) or job.tries>=6 then st.metadata[recordID]=nil else job.due=now+5 end
            work=work+1; if work>=(limit or 2) then return end
        end
    end
end
function P.SpellText(spellID,success)
    if not E.current or not id(spellID) or A.Secret(success) or success==false then return end
    for _,r in ipairs(E.Query.Kind(E.current,"spell")) do if r.spellID==spellID then enrich(E.current,r) end end
end
E.Collectors.handlers.LEARNED_SPELL_IN_SKILL_LINE=P.Learned
E.Collectors.handlers.ACHIEVEMENT_EARNED=P.Achievement
E.Collectors.handlers.SPELLS_CHANGED=function()P.Refresh(E.current)end
E.Collectors.handlers.SPELL_TEXT_UPDATE=P.SpellText
E.Collectors.handlers.SPELL_DATA_LOAD_RESULT=P.SpellText
