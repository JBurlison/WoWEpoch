local _, E = ...
local D,S,Q={},E.Store,E.Query; E.Diary=D
local recapTypes={level=true,skill=true,profession=true}
-- Keep these sets aligned with the writer branches; the broad-input oracle
-- verifies facts, narrative and source-link equivalence.
local recapSources={milestone=true,crafted=true,gathered=true,death=true,gold=true,damage=true,health=true,auction=true,xp=true,travel=true,duel=true,battleground=true,roll_win=true,loot=true,quest=true}
local dailySources=Q.DailySourceKinds
local function sortedKeys(values,work)
    if not work then return E.SortedKeys(values)end
    local out={};for k in pairs(values)do work();out[#out+1]=k end
    E.RetentionWork.Sort(out,function(a,b)return tostring(a)<tostring(b)end,work);return out
end
local function variationSeed(key)
    local seed=0;for i=1,#key do seed=(seed+key:byte(i)*i)%997 end;return seed
end
function D.Family(r) return Q.MilestoneFamily(r) end
function D.MilestoneWindow(c,event)
    assert(event.kind=="milestone" and recapTypes[event.milestoneType] and event.subject==c.id,"Not a recap milestone")
    local previous=Q.PreviousMajor(c,event)
    return previous and previous.ts or (c.state.firstObserved or event.ts), event.ts, previous==nil,previous
end
function D.Facts(c,from,through,milestone,options,work)
    options=options or {}
    local facts={levels={},skills={},professions={},crafted={},gathered={},refs={},partial=true,
        counts={levels=0,skills=0,professions=0,crafted=0,gathered=0,deaths=0,auctionsBought=0,auctionsSold=0,quests=0,looted=0,rollsWon=0,duelsWon=0,duelsLost=0,bgsWon=0,bgsLost=0},
        goldGained=0,goldLost=0,damageTaken=nil,healthGained=nil}
    local progress={levels={},skills={},professions={}}
    facts.progress=progress;facts.playSegments={};facts.auctionOutcomes={};facts.rollupVersion=1
    local play
    facts.time,play=Q.TimeStats(c,from,through,nil,true,work); facts.activeSeconds=facts.time.activeSeconds
    facts.longestSessionSeconds=facts.time.longestSessionSeconds
    for _,r in ipairs(Q.RangeKinds(c,from,through+1,recapSources,work)) do
        if work then work()end
        local afterStart=r.ts>from or r.ts==from and (not milestone or options.partialBoundary or options.fromSequence and S.Sequence(r)>options.fromSequence)
        local beforeEnd=r.ts<through or milestone and r.ts==through and (not options.throughSequence or S.Sequence(r)<=options.throughSequence)
        local inside=afterStart and beforeEnd
        if inside and milestone and r.datePrecision=="day" then
            local day=E.API.DayStart(r.ts)
            if day<=from or E.API.ShiftDay(day,1)>through then inside=false end
        end
        if inside then
            local bucket
            local metric=false
            if r.kind=="milestone" and r.subject==c.id then
                bucket=({level="levels",skill="skills",profession="professions"})[r.milestoneType]
                if bucket then
                    local key=bucket=="levels" and "character" or r.skillID or r.id
                    local p=progress[bucket][key]
                    if not p then p={before=r.before,count=0,name=r.skillName,lastTitle=r.title}; progress[bucket][key]=p end
                    p.after=r.after; p.count=p.count+1; p.lastTitle=r.title
                end
            elseif (r.kind=="crafted" or r.kind=="gathered") and r.recipient==c.id then
                bucket=r.kind; local key=r.itemID
                local item=facts[bucket][key] or {title=r.title or tostring(key),quantity=0}; item.quantity=item.quantity+r.quantity;if r.gathering and r.gathering.state=="inferred"then item.inferred=(item.inferred or 0)+r.quantity end; facts[bucket][key]=item
            elseif r.kind=='death'and r.subject==c.id then bucket='deaths'
            elseif r.kind=='quest'and r.status=='completed'then bucket='quests'
            elseif r.kind=='loot'and r.recipient==c.id and type(r.quantity)=='number'and r.quantity>0 then
                facts.counts.looted=facts.counts.looted+r.quantity;metric=true
            elseif r.kind=='roll_win'and r.subject==c.id and r.confirmed==true then bucket='rollsWon'
            elseif (r.kind=='duel'or r.kind=='battleground')and r.subject==c.id then
                if r.outcome=='won'then bucket=r.kind=='duel'and'duelsWon'or'bgsWon'
                elseif r.outcome=='lost'then bucket=r.kind=='duel'and'duelsLost'or'bgsLost'end
            elseif (r.kind=='xp'or r.kind=='travel')and r.subject==c.id and type(r.amount)=='number'and r.amount>=0 and r.amount<=9007199254740991 then
                local key=r.kind=='xp'and'xpGained'or'distanceYards';facts[key]=(facts[key]or 0)+r.amount;metric=true
            elseif r.kind=='gold'and type(r.amount)=='number'and r.amount==r.amount and math.abs(r.amount)<=9007199254740991 then
                if r.amount>0 then facts.goldGained=facts.goldGained+r.amount
                elseif r.amount<0 then facts.goldLost=facts.goldLost-r.amount end
                metric=r.amount~=0
            elseif (r.kind=='damage'or r.kind=='health')and r.subject==c.id and type(r.amount)=='number'and r.amount>=0 and r.amount<=9007199254740991 then
                local key=r.kind=='damage'and'damageTaken'or'healthGained'
                facts[key]=(facts[key]or 0)+r.amount;metric=true
            elseif r.kind=='auction' then
                local first=r.recapAuctionFirst
                if first==nil then first=Q.FirstAuctionOutcome(c,r,work)end
                if first then bucket=Q.AuctionOutcome(r);if bucket and r.auctionID then facts.auctionOutcomes[bucket..':'..tostring(r.auctionID)]=bucket end end
            end
            if metric then facts.refs[#facts.refs+1]=r.id end
            if bucket then
                facts.refs[#facts.refs+1]=r.id
                facts.counts[bucket]=facts.counts[bucket]+((bucket=="crafted" or bucket=="gathered") and r.quantity or 1)
            end
        end
    end
    for _,bucket in ipairs({"levels","skills","professions"}) do for _,key in ipairs(sortedKeys(progress[bucket],work)) do
        if work then work()end
        local p=progress[bucket][key]; local title=p.lastTitle
        if p.before~=nil and p.after~=nil then
            title=(bucket=="levels" and "Character level" or p.name or "Skill "..tostring(key))..": "..E.Number(p.before).." -> "..E.Number(p.after)
        end
        if p.count>1 then title=title.." ("..E.Number(p.count).." recorded changes)" end
        facts[bucket][#facts[bucket]+1]=title
    end end
    for _,r in ipairs(play)do
        if work then work()end
        facts.refs[#facts.refs+1]=r.id
        facts.playSegments[#facts.playSegments+1]={id=r.id,ts=math.max(from,r.ts),ended=math.min(through,r.ended),status=r.status,session=r.session}
    end
    facts.netGold=facts.goldGained-facts.goldLost
    return facts
end
-- A calendar recap is eligible only at a verified later login. Its daily
-- sufficient statistics retain endpoints and clipped session intervals.
function D.PeriodAllowed(c,through)
    local today=E.API.DayStart(E.API.Now())
    local cutoff=c.state.recapLoginThrough
    return type(through)=='number'and type(today)=='number'and type(cutoff)=='number'and through<=math.min(cutoff,today)
end
function D.Completed(r)
    return r and not r.inProgress and type(r.facts)=='table'and type(r.text)=='string'
end
function D.Visible(c,r)
    if r.periodKind=='milestone'then return true end
    if r.inProgress then return false end
    if D.PeriodAllowed(c,r.through)then return true end
    -- Earlier builds saved finished recaps before the per-login cutoff existed.
    -- Reading those offline journals must not require another character login.
    return c.state.recapLoginThrough==nil and D.Completed(r)
        and type(r.through)=='number'and r.through<=E.API.DayStart(E.API.Now())
end
function D.PeriodFacts(c,view,from,through,work)
    local total={levels={},skills={},professions={},crafted={},gathered={},refs={},counts={},
        progress={levels={},skills={},professions={}},playSegments={},auctionOutcomes={},dayKeys={},partial=true,rollupVersion=1}
    local pending,seen={},{}
    local playView={id=c.id,records={}}
    local day=from
    while day<through do
        if work then work()end
        local finish=math.min(E.API.ShiftDay(day,1),through)
        local key='daily:'..E.API.Day(day)
        total.dayKeys[#total.dayKeys+1]=key
        local saved=c.records[(c.state.recaps or{})[key]]
        local facts=saved and not saved.inProgress and saved.from==day and saved.through==finish and saved.facts
        if not facts or facts.rollupVersion~=1 then
            facts=D.Facts(view,day,finish,nil,nil,work)
            if #facts.refs>0 and not D.Expired(c,'recaps',key)then pending[#pending+1]={key=key,from=day,through=finish,facts=facts}end
        end
        for k,n in pairs(facts.counts)do if work then work()end;total.counts[k]=(total.counts[k]or 0)+n end
        for id,bucket in pairs(facts.auctionOutcomes or{})do
            if work then work()end
            if total.auctionOutcomes[id]then total.counts[bucket]=total.counts[bucket]-1
            else total.auctionOutcomes[id]=bucket end
        end
        for _,k in ipairs({'goldGained','goldLost','damageTaken','healthGained','xpGained','distanceYards'})do
            if facts[k]~=nil then total[k]=(total[k]or 0)+facts[k]end
        end
        for _,bucket in ipairs({'crafted','gathered'})do for id,item in pairs(facts[bucket])do
            if work then work()end
            local out=total[bucket][id]or{title=item.title,quantity=0};total[bucket][id]=out
            out.quantity=out.quantity+item.quantity
            if item.inferred then out.inferred=(out.inferred or 0)+item.inferred end
        end end
        for _,bucket in ipairs({'levels','skills','professions'})do
            for id,p in pairs(facts.progress[bucket])do
                if work then work()end
                local out=total.progress[bucket][id]
                if not out then out={before=p.before,count=0,name=p.name};total.progress[bucket][id]=out end
                out.after=p.after;out.count=out.count+p.count;out.lastTitle=p.lastTitle
            end
        end
        for _,id in ipairs(facts.refs)do if work then work()end;if not seen[id]then seen[id]=true;total.refs[#total.refs+1]=id end end
        for _,segment in ipairs(facts.playSegments)do
            if work then work()end
            total.playSegments[#total.playSegments+1]=segment
            local id=tostring(day)..':'..segment.id
            playView.records[id]={id=id,kind='play',ts=segment.ts,ended=segment.ended,status=segment.status,session=segment.session}
        end
        day=finish
    end
    for _,bucket in ipairs({'levels','skills','professions'})do for _,id in ipairs(sortedKeys(total.progress[bucket],work))do
        local p=total.progress[bucket][id];local title=p.lastTitle
        if p.before~=nil and p.after~=nil then title=(bucket=='levels'and'Character level'or p.name or'Skill '..tostring(id))..': '..E.Number(p.before)..' -> '..E.Number(p.after)end
        if p.count>1 then title=title..' ('..E.Number(p.count)..' recorded changes)'end
        total[bucket][#total[bucket]+1]=title
    end end
    Q.WarmSnapshot(playView,work)
    total.time=Q.TimeStats(playView,from,through,nil,true,work)
    total.activeSeconds=total.time.activeSeconds;total.longestSessionSeconds=total.time.longestSessionSeconds
    total.netGold=(total.goldGained or 0)-(total.goldLost or 0)
    return total,pending
end
function D.Write(facts,variation,work)
    local starts={"A little more of the journey is now behind you.","Here is how your recorded time took shape.","Another page of progress to keep.",
        "The recorded progress has a page of its own.","A few figures tell this part of the story.","Time spent, skills practiced, and things made:",
        "These are the steps recorded along the way.","The book has a little more progress to remember."}
    local lines={starts[(variation or 0)%#starts+1]}
    if facts.activeSeconds and facts.activeSeconds>0 then lines[#lines+1]=E.Duration(facts.activeSeconds).." of active play, excluding recorded AFK time." end
    local counts=facts.counts or{}
    if (counts.deaths or 0)>0 then lines[#lines+1]='Recorded '..E.Number(counts.deaths)..(counts.deaths==1 and ' death.'or' deaths.')end
    if facts.damageTaken and facts.damageTaken>0 then lines[#lines+1]='Observed '..E.Number(facts.damageTaken)..' damage taken.'end
    if facts.healthGained and facts.healthGained>0 then lines[#lines+1]='Observed '..E.Number(facts.healthGained)..' health gained, including regeneration.'end
    if (facts.goldGained or 0)>0 then lines[#lines+1]='Wallet gains totaled '..E.Money(facts.goldGained)..'.'end
    if (facts.goldLost or 0)>0 then lines[#lines+1]='Wallet losses totaled '..E.Money(facts.goldLost)..'.'end
    if (facts.goldGained or 0)>0 or (facts.goldLost or 0)>0 then lines[#lines+1]='Net gold change: '..E.Money(facts.netGold or (facts.goldGained or 0)-(facts.goldLost or 0))..'.'end
    if (counts.auctionsBought or 0)>0 then lines[#lines+1]='Recorded '..E.Number(counts.auctionsBought)..(counts.auctionsBought==1 and' auction purchase.'or' auction purchases.')end
    if (counts.auctionsSold or 0)>0 then lines[#lines+1]='Recorded '..E.Number(counts.auctionsSold)..(counts.auctionsSold==1 and' auction reported sold.'or' auctions reported sold.')end
    for _,entry in ipairs({{'quests','quest completed','quests completed'},{'looted','item looted (personal receipt)','items looted (personal receipts)'},{'rollsWon','item roll won','item rolls won'},
        {'duelsWon','duel won','duels won'},{'duelsLost','duel lost','duels lost'},{'bgsWon','battleground won','battlegrounds won'},{'bgsLost','battleground lost','battlegrounds lost'}})do
        local n=counts[entry[1]]or 0;if n>0 then lines[#lines+1]='Recorded '..E.Number(n)..' '..entry[n==1 and 2 or 3]..'.'end
    end
    if (facts.xpGained or 0)>0 then lines[#lines+1]='Gained '..E.Number(facts.xpGained)..' observed XP.'end
    if (facts.distanceYards or 0)>0 then lines[#lines+1]='Observed travel covered approximately '..E.Number(facts.distanceYards)..' yards.'end
    if (facts.longestSessionSeconds or 0)>0 then lines[#lines+1]='Longest observed active session in this interval: '..E.Duration(facts.longestSessionSeconds)..'.'end
    for _,key in ipairs({"levels","skills","professions"}) do for _,title in ipairs(facts[key]) do if work then work()end;lines[#lines+1]=title.."." end end
    for _,kind in ipairs({"crafted","gathered"}) do for _,id in ipairs(sortedKeys(facts[kind],work)) do
        if work then work()end
        local item=facts[kind][id]; lines[#lines+1]=(kind=="crafted" and "Crafted " or "Gathered ")..E.Number(item.quantity).." x "..item.title..(item.inferred and " ("..E.Number(item.inferred).." inferred gathered)"or"").."."
    end end
    if #lines==1 then return "No supported progress was observed in this interval. Missing history remains unknown." end
    if #lines>2 and variation then
        local ordered={lines[1]}
        for i=2,#lines do if work then work()end;ordered[i]=lines[2+(i-2+variation)%(#lines-1)]end
        lines=ordered
    end
    return table.concat(lines," ")
end
function D.Expired(c,category,key)
    local groups=c.state.expiredSummaries
    local r=groups and groups[category]and groups[category][key]
    if r and r.batch then return {expiredAt=r.batch.expiredAt,from=r.from,through=r.through}end
    return r
end
local function publishRecap(c,key,r,from,through,title,options,facts,text,changed)
    c.state.recaps=c.state.recaps or {}
    local refs,seen,missing={},{},0
    for _,id in ipairs(facts.refs)do
        local source=c.records[id]
        if source then
            if not seen[id]then refs[#refs+1]=id;seen[id]=true end
        else missing=missing+1 end
    end
    for _,dayKey in ipairs(facts.dayKeys or{})do
        local id=c.state.recaps[dayKey]
        if dayKey~=key and id and c.records[id]and not seen[id]then refs[#refs+1]=id;seen[id]=true end
    end
    if not r then
        local seed=variationSeed(key)
        r=S.Add(c,"recap",options.now or E.API.Now(),{title=title,key=key,from=from,through=through,read=false,variation=seed,refs=refs,
            boundaryPolicy="local calendar at creation",periodKind=options.periodKind})
        c.state.recaps[key]=r.id
    end
    r.noteKey=r.noteKey or ("recap:"..key)
    if not c.notes[r.noteKey] and c.notes["record:"..r.id] then c.notes[r.noteKey]=c.notes["record:"..r.id]; c.notes["record:"..r.id]=nil; S.Touch(c); E.Emit("DATA_MIGRATED",c) end
    if not r.startStamp or options.milestone and r.from~=from then r.startStamp=E.API.ClockStamp(from) end
    if not r.endStamp or options.milestone and r.through~=through then r.endStamp=E.API.ClockStamp(through) end
    if not changed then return r,false end
    r.refs=refs;r.unavailableSourceCount=missing; r.text=text or D.Write(facts,r.variation); r.facts=facts; r.partialBoundary=options.partialBoundary
    r.inProgress=options.inProgress; r.from,r.through=from,through
    r.fromSequence,r.throughSequence=options.fromSequence,options.throughSequence
    r.generation=(r.generation or 0)+1; r.generatedAt=options.now or E.API.Now(); r.templateVersion=5
    S.Changed(c,r); E.Emit("RECAP_UPDATED",c,r)
    return r,true
end
local function publishDays(c,days,now)
    for _,day in ipairs(days or{})do
        local old=c.records[(c.state.recaps or{})[day.key]]
        if not D.Completed(old)then
            publishRecap(c,day.key,old,day.from,day.through,'Daily recap - '..E.API.Day(day.from),
                {periodKind='daily',now=now},day.facts,nil,true)
        end
    end
end
function D.Generate(c,key,from,through,title,options)
    options=options or {}; c.state.recaps=c.state.recaps or {}
    if D.Expired(c,"recaps",key)then return nil,false end
    local r=c.records[c.state.recaps[key]]
    -- Period boundaries are retained as generated, rather than silently changing after a clock-zone change.
    if r and not options.milestone then from,through=r.from,r.through end
    if not options.milestone then
        options.inProgress=nil
        if not D.PeriodAllowed(c,through)then return nil,false end
        if D.Completed(r)then return r,false end
        local facts,days=D.PeriodFacts(c,c,from,through)
        publishDays(c,days,options.now)
        r=c.records[(c.state.recaps or{})[key]]
        if options.periodKind=='daily'and D.Completed(r)then return r,true end
        return publishRecap(c,key,r,from,through,title,options,facts,nil,true)
    end
    local facts=D.Facts(c,from,through,options.milestone,options)
    local changed=not r or not E.Same(r.facts,facts) or r.inProgress~=options.inProgress or r.partialBoundary~=options.partialBoundary
        or r.from~=from or r.through~=through or r.throughSequence~=options.throughSequence or r.fromSequence~=options.fromSequence or r.templateVersion~=5
    return publishRecap(c,key,r,from,through,title,options,facts,nil,changed)
end
function D.NoteKey(c,r)
    if r.kind=="recap" then
        local key="recap:"..r.key
        if not c.notes[key] and c.notes["record:"..r.id] then c.notes[key]=c.notes["record:"..r.id]; c.notes["record:"..r.id]=nil; S.Touch(c); E.Emit("DATA_MIGRATED",c) end
        return key
    end
    local key=r.kind=="diary" and ("day:"..r.day) or ("record:"..r.id)
    -- Builds 0.31-0.32 used the raw record ID for keepsake notes.
    -- Preserve a conflicting canonical note; the memory view exposes both.
    if (r.kind=="memory" or r.kind=="screenshot") and c.notes[r.id] and not c.notes[key] then
        c.notes[key]=c.notes[r.id];c.notes[r.id]=nil;S.Touch(c);E.Emit("DATA_MIGRATED",c)
    end
    return key
end
function D.MarkRead(c,r)
    if r.read and r.readGeneration==r.generation then return end
    r.read=true; r.readGeneration=r.generation; S.Touch(c); E.Emit("RECAP_UPDATED",c,r)
end
function D.Unread(c)
    return Q.UnreadRecapCount(c)
end
function D.Daily(c,from,through,variation,work)
    local function keys(values)
        if not work then return E.SortedKeys(values)end
        local out={};for k in pairs(values)do work();out[#out+1]=k end
        E.RetentionWork.Sort(out,function(a,b)return tostring(a)<tostring(b)end,work);return out
    end
    local lines,refs={},{ }
    local quests,majors,skills,outputs,others={}, {}, {}, {crafted={},gathered={},loot={}}, 0
    local groups,deaths,spells,victories=0,0,{},{}
    local function list(values,limit)
        local parts={}; for i=1,math.min(#values,limit) do parts[#parts+1]=values[i] end
        local suffix=#values>limit and (", and "..(#values-limit).." more") or ""
        return table.concat(parts,", ")..suffix
    end
    for _,r in ipairs(Q.RangeKinds(c,from,through,dailySources,work)) do
        if work then work()end
        local used=true
        if r.kind=="quest" then quests[#quests+1]=r.title
        elseif r.kind=="milestone" and r.subject==c.id then
            if r.major then majors[#majors+1]=r.title
            elseif r.skillID then skills[r.skillID]=r.title else used=false end
        elseif outputs[r.kind] and r.recipient==c.id then
            local item=outputs[r.kind][r.itemID] or {title=r.title,quantity=0}; item.quantity=item.quantity+r.quantity;if r.gathering and r.gathering.state=="inferred"then item.inferred=(item.inferred or 0)+r.quantity end; outputs[r.kind][r.itemID]=item
        elseif r.kind=="loot" then others=others+r.quantity
        elseif r.kind=="group" then groups=groups+1
        elseif r.kind=="death" and r.subject==c.id then deaths=deaths+1
        elseif r.kind=="spell" and r.subject==c.id then spells[#spells+1]=r.spellName and (r.spellName..(r.rankText and " ("..r.rankText..")" or "")) or r.title
        elseif r.subject==c.id and E.Encounters and E.Encounters.IsVictory(r) then victories[r.encounterID]=r.encounterName or r.title
        else used=false end
        if used then refs[#refs+1]=r.id end
    end
    if #quests>0 then lines[#lines+1]="Completed "..#quests.." quest"..(#quests==1 and "" or "s")..": "..list(quests,3).."." end
    if #majors>0 then lines[#lines+1]="Milestones: "..list(majors,4).."." end
    local bosses={};for _,id in ipairs(keys(victories))do if work then work()end;bosses[#bosses+1]=victories[id]end
    if #bosses>0 then lines[#lines+1]="Boss victory notifications: "..list(bosses,4)..". Multiple notifications may describe one victory."end
    local skillNames={}; for _,id in ipairs(keys(skills)) do if work then work()end;skillNames[#skillNames+1]=skills[id] end
    if #skillNames>0 then lines[#lines+1]="Other skill progress: "..list(skillNames,3).."." end
    if groups>0 then lines[#lines+1]="Began "..groups.." recorded group adventure"..(groups==1 and "." or "s.") end
    for _,kind in ipairs({"crafted","gathered","loot"}) do
        local items={}; for _,id in ipairs(keys(outputs[kind])) do if work then work()end;local item=outputs[kind][id]; items[#items+1]=item.quantity.." x "..item.title..(item.inferred and " ("..item.inferred.." inferred gathered)"or"") end
        if #items>0 then lines[#lines+1]=({crafted="Crafted ",gathered="Gathered ",loot="Received "})[kind]..list(items,4).."." end
    end
    if others>0 then lines[#lines+1]="Recorded "..others.." items received by other or unidentified recipients." end
    if deaths>0 then lines[#lines+1]="Recorded "..deaths.." death"..(deaths==1 and "." or "s.") end
    if #spells>0 then lines[#lines+1]="Learning: "..list(spells,3).."." end
    local timeStats,play=Q.TimeStats(c,from,through,nil,true,work);local active=timeStats.activeSeconds
    if active and active>0 then
        lines[#lines+1]=E.Duration(active).." of active play was observed."
        for _,r in ipairs(play)do if work then work()end;refs[#refs+1]=r.id end
    end
    local openings={"Today's recorded adventures:","A page from your day:","Looking back at this day:","Another day, remembered in the book:",
        "Here are the moments this page keeps:","The record of a day in Azeroth:","From the day's travels and work:","These are the details worth keeping:"}
    variation=variation or 0
    if #lines>1 and variation>0 then
        local ordered={}; local shift=variation%#lines
        for i=1,#lines do ordered[i]=lines[(i+shift-1)%#lines+1]end
        lines=ordered
    end
    local text=#lines>0 and (openings[((math.floor(from/86400)+variation)%#openings)+1].." "..table.concat(lines," ")) or "No activity was observed for this day. Unrecorded time remains unknown."
    return text,refs
end
local function publishDaily(c,key,r,from,through,now,text,refs,unchanged)
    if unchanged then return r,false end
    c.state.diaries=c.state.diaries or {}
    if not r then
        r=S.Add(c,"diary",from,{title="Diary - "..key,from=from,through=through,day=key,refs=refs,variation=0})
        c.state.diaries[key]=r.id
    end
    r.text,r.refs,r.inProgress=text,refs,through>now; r.generation=(r.generation or 0)+1
    r.generatedAt=now; r.templateVersion=4; S.Changed(c,r); return r,true
end
function D.SaveDaily(c,from,through,now)
    local key=E.API.Day(from);local r=c.records[(c.state.diaries or{})[key]]
    if D.Expired(c,'diaries',key)then return nil,false end
    if r then from,through=r.from,r.through end
    local text,refs=D.Daily(c,from,through,r and r.variation or 0)
    return publishDaily(c,key,r,from,through,now,text,refs,r and r.text==text and E.Same(r.refs,refs)
        and r.inProgress==(through>now)and r.templateVersion==4)
end
local captures=setmetatable({},{__mode='k'})
local writers=setmetatable({},{__mode='k'})
-- Only immutable scalar fields consumed by the writers/Query are captured. Large chat,
-- group rosters, combat details and unrelated record payloads are never copied.
local dailyFields={'id','kind','ts','sequence','observationSequence','title','subject','major','skillID',
    'recipient','itemID','quantity','spellName','rankText','phase','success','encounterID','encounterName','ended','status','before','after','skillName','milestoneType','datePrecision','amount','source','auctionID','session','outcome','confirmed'}
local function capture(state,r)
    local inside=S.Timestamp(r) and (r.kind=='play'and r.ended>state.from and r.ts<state.through
        or (state.sources or dailySources)[r.kind]and r.ts>=state.from and r.ts<state.through)
    if not inside then state.view.records[r.id]=nil;return end
    local copy={}
    for _,key in ipairs(dailyFields)do copy[key]=r[key]end
    if r.gathering then copy.gathering={state=r.gathering.state}end
    if r.kind=='auction'and r.auctionData then copy.auctionData={statusLabel=r.auctionData.statusLabel}end
    state.view.records[r.id]=copy
end
function D.CancelDaily(state)
    if not state then return end
    state.cancelled=true
    if captures[state.owner]==state then captures[state.owner]=nil end
    if writers[state.owner]==state then writers[state.owner]=nil end
end
function D.StartDaily(c,from,through,now,retell)
    D.CancelDaily(writers[c])
    local key=E.API.Day(from);local r=c.records[(c.state.diaries or{})[key]]
    if D.Expired(c,'diaries',key)then return nil,'expired' end
    if r then from,through=r.from,r.through end
    local state={owner=c,records=c.records,key=key,from=from,through=through,record=r,phase='capture',
        variation=r and r.variation or 0,generation=r and r.generation,oldText=r and r.text,oldRefs=r and r.refs,
        oldProgress=r and r.inProgress,oldTemplate=r and r.templateVersion,view={id=c.id,records={}}}
    state.oldVariation=state.variation
    if retell then state.variation=(state.variation+1)%997 end
    state.worker=E.RetentionWork.Start(function(work)
        E.Gathering.Wait(c,state)
        if state.cancelled then return false end
        Q.EachSummarySource(c,from,through,dailySources,function(row)capture(state,row)end,work)
        -- Events up to this point have updated the capture as well. Freezing is
        -- constant-time; later observations queue a separate generation.
        E.Gathering.Wait(c,state)
        if captures[c]==state then captures[c]=nil end
        if state.cancelled then return false end
        state.phase='writing';state.now=math.max(now,E.API.Now())
        Q.WarmSnapshot(state.view,work)
        state.text,state.refs=D.Daily(state.view,from,through,state.variation,work)
        if retell and #state.refs==0 then state.variation=state.oldVariation end
        state.unchanged=r and state.oldText==state.text and E.RetentionWork.Same(state.oldRefs,state.refs,work)
            and state.oldProgress==(through>state.now)and state.oldTemplate==4
        state.phase='ready';return true
    end)
    if not state.worker then return nil,'unavailable' end
    captures[c]=state;writers[c]=state;return state
end
function D.FinishDaily(state)
    local c=state.owner;local r=c.records[(c.state.diaries or{})[state.key]]
    local valid=not state.cancelled and writers[c]==state and state.phase=='ready'
        and E.db.characters[c.id]==c and c.records==state.records and r==state.record
        and not D.Expired(c,'diaries',state.key)
    if valid and r then
        valid=r.generation==state.generation and (r.variation or 0)==state.oldVariation and r.from==state.from
            and r.through==state.through and r.text==state.oldText and r.refs==state.oldRefs
            and r.inProgress==state.oldProgress and r.templateVersion==state.oldTemplate
    end
    D.CancelDaily(state)
    if not valid then return nil,false,'stale' end
    if r then r.variation=state.variation end
    return publishDaily(c,state.key,r,state.from,state.through,state.now,state.text,state.refs,state.unchanged)
end
local recapGuards={'generation','variation','from','through','fromSequence','throughSequence','text','refs','facts','inProgress','partialBoundary','templateVersion'}
function D.StartRecap(c,job,now)
    D.CancelDaily(writers[c])
    local key=job.kind=='milestone'and('milestone:'..job.event)or job.key
    if D.Expired(c,'recaps',key)then return nil,'expired'end
    local r=c.records[(c.state.recaps or{})[key]]
    if job.kind~='milestone'and not D.PeriodAllowed(c,r and r.through or job.through)then return nil,'pending-login'end

    local state={owner=c,records=c.records,key=key,record=r,phase='initial',view={id=c.id,records={}},
        sources=recapSources,recap=true,eventID=job.kind=='milestone'and job.event or nil,old={},variation=r and r.variation or variationSeed(key)}
    if r then for _,field in ipairs(recapGuards)do state.old[field]=r[field]end end
    if job.kind~='milestone'and D.Completed(r)then
        state.worker=E.RetentionWork.Start(function()
            state.actualFrom,state.actualThrough,state.title=r.from,r.through,r.title
            state.options={periodKind=r.periodKind,now=now}
            state.facts,state.changed,state.now=r.facts,false,now;state.phase='ready';return true
        end)
        if not state.worker then return nil,'unavailable'end
        writers[c]=state;return state
    end
    local function window()
        if job.kind=='milestone'then
            local event=c.records[job.event]
            if not event or event.kind~='milestone'or event.subject~=c.id or not event.major or not recapTypes[event.milestoneType]then return end
            state.boundaryFamily=D.Family(event)
            local start,finish,partial,previous=D.MilestoneWindow(c,event)
            return start,finish,event.title..' - the journey',{milestone=true,partialBoundary=partial,
                fromSequence=previous and S.Sequence(previous),throughSequence=S.Sequence(event),periodKind='milestone'}
        end
        local start,finish=r and r.from or job.from,r and r.through or job.through
        return start,finish,(job.kind=='dailyRecap'and'Daily'or job.kind)..' recap - '..E.API.Day(job.from),{periodKind=job.kind=='dailyRecap'and'daily'or job.kind}
    end
    state.worker=E.RetentionWork.Start(function(work)
        E.Gathering.Wait(c,state)
        if state.cancelled then return false end
        local start,finish,title,options=window()
        if not start then state.invalid=true;return false end
        state.phase='capture';state.from=math.min(start,finish);state.through=finish+1;captures[c]=state
        Q.EachSummarySource(c,state.from,state.through,recapSources,function(row)capture(state,row)end,work)
        -- A corrected predecessor can move the interval earlier, and a corrected
        -- event can move its end later. Extend capture before freezing; existing
        -- copied values keep receiving changes while each extension is scanned.
        while true do
            E.Gathering.Wait(c,state)
            if state.cancelled then return false end
            start,finish,title,options=window()
            if not start then state.invalid=true;if captures[c]==state then captures[c]=nil end;return false end
            local lower,upper=math.min(start,finish),finish+1
            if lower<state.from then
                local old=state.from;state.from=lower
                Q.EachSummarySource(c,lower,old,recapSources,function(row)capture(state,row)end,work)
            elseif upper>state.through then
                local old=state.through;state.through=upper
                Q.EachSummarySource(c,old,upper,recapSources,function(row)capture(state,row)end,work)
            else break end
        end
        if captures[c]==state then captures[c]=nil end
        state.phase='writing';state.now=math.max(now,E.API.Now())
        state.actualFrom,state.actualThrough,state.title,state.options=start,finish,title,options
        -- Resolve identity against the full history, not only this period's
        -- copied rows. A later refresh of last week's sale is not another sale.
        for _,row in pairs(state.view.records)do if row.kind=='auction'then
            work();row.recapAuctionFirst=Q.FirstAuctionOutcome(c,row,work)
        end end
        options.now=state.now;if not options.milestone then options.inProgress=finish>state.now end
        Q.WarmSnapshot(state.view,work)
        if options.milestone then state.facts=D.Facts(state.view,start,finish,true,options,work)
        else state.facts,state.days=D.PeriodFacts(c,state.view,start,finish,work)end
        state.changed=not r or not E.RetentionWork.Same(state.old.facts,state.facts,work)
            or state.old.inProgress~=options.inProgress or state.old.partialBoundary~=options.partialBoundary
            or state.old.from~=start or state.old.through~=finish or state.old.throughSequence~=options.throughSequence
            or state.old.fromSequence~=options.fromSequence or state.old.templateVersion~=5
        if state.changed then state.text=D.Write(state.facts,state.variation,work)end
        state.phase='ready';return true
    end)
    if not state.worker then return nil,'unavailable'end
    writers[c]=state;return state
end
function D.FinishRecap(state)
    local c=state.owner;local r=c.records[(c.state.recaps or{})[state.key]]
    if state.eventID then
        local event=c.records[state.eventID]
        if not event or event.kind~='milestone'or event.subject~=c.id or not event.major or not recapTypes[event.milestoneType]then state.invalid=true end
    end
    local valid=not state.cancelled and not state.invalid and writers[c]==state and state.phase=='ready'
        and E.db.characters[c.id]==c and c.records==state.records and r==state.record
        and not D.Expired(c,'recaps',state.key)
    if valid and r then for _,field in ipairs(recapGuards)do if r[field]~=state.old[field]then valid=false;break end end end
    if valid and not state.eventID then valid=D.PeriodAllowed(c,state.actualThrough)end
    if valid and not state.eventID and state.days and #state.days>0 then
        state.dayCursor=(state.dayCursor or 0)+1
        publishDays(c,{state.days[state.dayCursor]},state.now)
        if state.dayCursor<#state.days then return nil,false,'continuing'end
        state.days=nil
        if state.options.periodKind=='daily'then
            D.CancelDaily(state)
            return c.records[(c.state.recaps or{})[state.key]],true
        end
    end
    D.CancelDaily(state)
    if state.invalid then return nil,false,'invalid'end
    if not valid then return nil,false,'stale'end
    if not state.eventID then
        if not D.PeriodAllowed(c,state.actualThrough)then return nil,false,'invalid'end
        publishDays(c,state.days,state.now)
        r=c.records[(c.state.recaps or{})[state.key]]
        if state.options.periodKind=='daily'and D.Completed(r)then return r,true end
    end
    return publishRecap(c,state.key,r,state.actualFrom,state.actualThrough,state.title,state.options,state.facts,state.text,state.changed)
end
function D.StartRetell(c,r,now)
    if not c or E.db.characters[c.id]~=c or c.records[r.id]~=r then return nil,'invalid'end
    if r.kind=='diary'then return D.StartDaily(c,r.from,r.through,now,true)end
    if r.kind~='recap'or not r.facts then return nil,'invalid'end
    if D.Expired(c,'recaps',r.key)then return nil,'expired'end
    D.CancelDaily(writers[c])
    local state={owner=c,records=c.records,record=r,key=r.key,retellRecap=true,old={},phase='writing'}
    for _,field in ipairs(recapGuards)do state.old[field]=r[field]end
    state.worker=E.RetentionWork.Start(function(work)
        -- Saved recap facts remain useful after their original observations expire.
        local facts=E.RetentionWork.Copy(state.old.facts,work)
        state.variation=(state.old.variation or 0)+1
        state.text=D.Write(facts,state.variation,work)
        state.phase='ready';return true
    end)
    if not state.worker then return nil,'unavailable'end
    writers[c]=state;return state
end
function D.FinishRetell(state)
    if not state.retellRecap then return D.FinishDaily(state)end
    local c,r=state.owner,state.record
    local valid=not state.cancelled and not state.invalidated and writers[c]==state and state.phase=='ready'
        and E.db.characters[c.id]==c and c.records==state.records and c.records[r.id]==r
        and (c.state.recaps or{})[state.key]==r.id and not D.Expired(c,'recaps',state.key)
    if valid then for _,field in ipairs(recapGuards)do if r[field]~=state.old[field]then valid=false;break end end end
    D.CancelDaily(state)
    if not valid then return nil,false,'stale'end
    r.variation,r.text=state.variation,state.text;S.Changed(c,r);return r,true
end
local function captureChange(c,r)
    local writing=writers[c]
    if writing and writing.retellRecap and writing.record==r then writing.invalidated=true end
    local state=captures[c]
    if state then capture(state,r)
    else
        state=writers[c]
        if state and state.from and(state.view.records[r.id]or state.boundaryFamily and r.kind=='milestone'and r.subject==c.id and D.Family(r)==state.boundaryFamily
            or S.Timestamp(r) and (r.kind=='play'and r.ended>state.from and r.ts<state.through
                or (state.sources or dailySources)[r.kind]and r.ts>=state.from and r.ts<state.through))then state.dirty=true end
    end
end
E.On('RECORD_ADDED',captureChange);E.On('RECORD_CHANGED',captureChange)
E.On('RECORDS_REMOVED',function(c)D.CancelDaily(writers[c])end)
function D.RetellDaily(c,from,through,now)
    local r=D.SaveDaily(c,from,through,now)
    if not r or #(r.refs or {})==0 then return r,false end
    r.variation=((r.variation or 0)+1)%997
    return D.SaveDaily(c,from,through,now)
end
function D.Refresh(c,now)
    local periods={}; local milestones={}
    for _,r in ipairs(S.List(c)) do
        if S.Timestamp(r) and (r.kind=="play" or r.kind=="crafted" or r.kind=="gathered" or Q.RecapExtraKinds[r.kind] or (r.kind=="milestone" and recapTypes[r.milestoneType] and r.subject==c.id)) then
            local day=E.API.DayStart(r.ts); local last=r.kind=="play" and (r.ended or r.ts) or r.ts
            repeat
                for _,kind in ipairs({"daily","weekly","monthly","yearly"}) do
                    local from,through=E.API.Period(day,kind); local key=kind..":"..E.API.Day(from)
                    periods[key]={from=from,through=through,kind=kind}
                end
                day=E.API.ShiftDay(day,1)
            until day>last
            if r.kind=="milestone" and r.major then milestones[#milestones+1]=r end
        end
    end
    for _,key in ipairs(E.SortedKeys(periods)) do local p=periods[key]
        D.Generate(c,key,p.from,p.through,p.kind.." recap - "..E.API.Day(p.from),{inProgress=p.through>now,periodKind=p.kind,now=now})
    end
    for _,r in ipairs(milestones) do
        local from,through,partial,previous=D.MilestoneWindow(c,r)
        D.Generate(c,"milestone:"..r.id,from,through,r.title.." - the journey",{milestone=true,partialBoundary=partial,
            fromSequence=previous and S.Sequence(previous),throughSequence=S.Sequence(r),periodKind="milestone",now=now})
    end
end
