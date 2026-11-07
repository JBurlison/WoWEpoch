local _, E = ...
local S = {}; E.Store = S
S.categories = {quest="quests",quest_attempt="quests",objective="questKills",credit="questKills",kill="questKills",
    group="groups",encounter="groups",chat="chat",pull="pulls",auction="gold",trade="gold",trade_offer="gold",trade_notice="gold",loot="loot",drop="loot",loot_window="loot",crafted="production",gathered="production",craft_request="production",craft_begin="production",craft_result="production",
    gold="gold",balance="gold",milestone="milestones",death="milestones",spell="milestones",weapon_observation="milestones",
    memory="memories",screenshot="memories",recap="recaps",diary="diaries",note="notes",play="time",gap="coverage",
    wallet_window="gold",money_evidence="gold",merchant="gold",inventory="gold",inventory_gap="gold",bank="gold",bank_gap="gold",cost_lot="gold",item_sale="gold",stock_move="gold",stock_reset="gold",sale_return="gold"}
for _,kind in ipairs({'mail','mail_scan','mail_collection','mail_request','mail_notice','mail_draft'})do S.categories[kind]='gold'end
S.categories.gather_action='production'
S.categories.damage='pulls';S.categories.health='pulls'
S.categories.xp='milestones';S.categories.travel='time';S.categories.duel='groups';S.categories.battleground='groups';S.categories.roll_win='loot'
S.categories.craft_gap='production'
-- The cooperative query enumerates display order. Loaded malformed books
-- can have a canonical request outside that array. Reuse Open's existing
-- records pass and keep a small unsaved set of actual craft-source keys.
local craftSeeds=setmetatable({},{__mode='k'})
local function rememberCraft(c,id,r,seeds)
    seeds=seeds or craftSeeds
    local seed=seeds[c]
    local present=r and S.CraftRequestSource(r)
    if not seed then
        if not present then return end
        seed={ids={},slots={},generation=0};seeds[c]=seed
    end
    local i=seed.slots[id]
    if present and not i then seed.ids[#seed.ids+1]=id;seed.slots[id]=#seed.ids
    elseif not present and i then
        local last=seed.ids[#seed.ids];seed.ids[i]=last;seed.slots[last]=i;seed.ids[#seed.ids]=nil;seed.slots[id]=nil
    else return end
    seed.generation=seed.generation+1
end
function S.CraftSeed(c)return craftSeeds[c]end
function S.Open(db)
    if db == nil then db = {schema=E.schema, characters={}, settings={scale=1, combatClose=false}} end
    assert(type(db) == "table" and db.schema == E.schema, "Unsupported saved-data schema; data was not replaced")
    assert(type(db.characters) == "table" and type(db.settings) == "table", "Invalid saved-data root; data was not replaced")
    local order=type(db.bankOrder)=='number' and db.bankOrder>=0 and db.bankOrder%1==0 and db.bankOrder or 0
    local seeds,bindings,owners={},{},{}
    for owner,c in pairs(db.characters)do
        assert(type(owner)=="string" and owner~="" and type(c)=="table" and not owners[c] and (c.id==nil or c.id==owner),"Invalid character identity")
        owners[c]=owner
        assert(type(c.identity)=="table" and type(c.state)=="table" and type(c.records)=="table" and type(c.order)=="table"
            and type(c.dedup)=="table" and type(c.notes)=="table" and (c.retention==nil or type(c.retention)=="table"),"Incomplete character journal")
        if c.id==nil then assert(c.identity.id==nil or c.identity.id==owner,"Missing character identity disagrees with retained identity")end
        assert(type(c.seq)=="number" and c.seq>=0 and c.seq<=9007199254740991 and c.seq%1==0
            and type(c.revision)=="number" and c.revision>=0 and c.revision<=9007199254740991 and c.revision%1==0,"Invalid character counters")
        if c.state and c.state.inventoryCostLinks and E.Inventory then
            bindings[#bindings+1]=E.Inventory.PrepareQueuedCostLinks(c)
        end
        for id,r in pairs(c.records)do
            assert(type(r)=="table","Invalid character journal record")
            if c.id==nil then assert(r.id==id and r.character==owner,"Missing character identity has conflicting record ownership")end
            if S.CraftRequestSource(r)then rememberCraft(c,id,r,seeds) end
            if r.kind=='bank' and type(r.bankOrder)=='number' and r.bankOrder%1==0 and r.bankOrder>order then order=r.bankOrder end
        end
    end
    -- Finish checking the entire account before publishing a migrated field
    -- or replacing a live character's lookup table.
    for _,apply in ipairs(bindings)do apply()end
    for c,owner in pairs(owners)do
        if c.id==nil then c.id=owner end
        if c.retention==nil then c.retention={}end
        craftSeeds[c]=seeds[c]
    end
    db.bankOrder=order
    E.db = db; return db
end
function S.Character(id, identity)
    assert(type(id)=="string" and id~="", "Character identity is required")
    local c = E.db.characters[id]
    if not c then
        c = {id=id, identity=E.Copy(identity or {}), seq=0, records={}, order={}, dedup={},
            retention={}, notes={}, art={}, state={}, revision=0}
        E.db.characters[id] = c
    elseif identity then
        local known=identity.nameKnown~=false and type(identity.name)=='string'and identity.name~=''
        local changed=false
        if known and c.identity.name and c.identity.nameKnown~=false and (c.identity.name~=identity.name or(identity.realm and identity.realm~=''and identity.realm~=c.identity.realm))then
            c.identityHistory=c.identityHistory or{};c.identityHistory[#c.identityHistory+1]={name=c.identity.name,realm=c.identity.realm,replacedAt=E.API.Now()}
        end
        for k,v in pairs(identity) do
            if not ((k=='name'or k=='nameKnown')and not known)and v~=c.identity[k]then c.identity[k]=v;changed=true end
        end
        if changed then S.Touch(c,'identity')end
    end
    return c
end
local function insert(c, kind, ts, data, dedup, observedSkill, clock)
    assert(S.categories[kind], "Unknown record kind")
    assert(type(ts)=="number" and ts==ts and ts~=math.huge and ts~=-math.huge, "Finite observation timestamp required")
    if dedup and c.dedup[kind..":"..dedup] then return c.records[c.dedup[kind..":"..dedup]], false end
    local r = E.Copy(data or {})
    for _, id in ipairs(r.refs or {}) do assert(c.records[id], "Reference must belong to this character") end
    c.seq = c.seq+1
    r.id, r.character, r.kind, r.ts, r.sequence = c.id..":"..c.seq, c.id, kind, ts, c.seq
    -- Shared-bank chronology must survive character changes and wall-clock jumps.
    if kind=="bank" then
        E.db.bankOrder=(E.db.bankOrder or 0)+1; r.bankOrder=E.db.bankOrder
    end
    if clock then r.localStamp=E.Copy(clock.value)
    elseif E.API and E.API.ClockStamp then r.localStamp=E.API.ClockStamp(ts) end
    r.category = S.categories[kind]
    local previousKind=c.records[r.id] and c.records[r.id].kind
    c.records[r.id] = r; c.order[#c.order+1] = r.id
    if previousKind or S.CraftRequestSource(r)then rememberCraft(c,r.id,r)end
    if dedup then r.dedup = kind..":"..dedup; c.dedup[r.dedup] = r.id end
    -- Publish the collector baseline with the canonical record before notifying
    -- listeners. A nested skill event must see and extend this exact reading.
    if observedSkill then
        observedSkill.weaponReadingID=r.id
        c.state.skills[r.skillID]=observedSkill
    end
    return r,true,previousKind
end
local function added(c,r,previousKind)
    local receipt=S.Touch(c,'record',{operation="add",record=r,previousKind=previousKind})
    E.Emit("RECORD_ADDED",c,r,nil,receipt)
end
local function add(c,kind,ts,data,dedup,observedSkill)
    local r,created,prior=insert(c,kind,ts,data,dedup,observedSkill)
    if created then added(c,r,prior)end
    return r,created
end
-- Both sides of a new observation interval must exist before listeners can
-- deliver a nested PLAYER_MONEY. A subsequent sample then extends this window.
function S.OpenWalletWindow(c,ts,amount,session,previous,current)
    local priorID=c.state.walletWindow;local priorWindow=c.records[priorID]
    local clock={value=E.API and E.API.ClockStamp and E.API.ClockStamp(ts)}
    if current and not current()then return end
    if c.state.wallet~=previous or c.state.walletWindow~=priorID or c.records[priorID]~=priorWindow then return end
    local baseline,_,priorBalance=insert(c,"balance",ts,{title="Observed wallet balance",balance=amount,session=session,
        priorObservation=previous and previous.ts or nil,unobservedChange=previous and amount-previous.amount or nil},nil,nil,clock)
    local window,_,priorKind=insert(c,"wallet_window",ts,{title="Wallet observation interval",ended=ts,opening=amount,closing=amount,
        transactionCount=0,session=session,refs={baseline.id}},nil,nil,clock)
    c.state.wallet={amount=amount,ts=ts,session=session}
    c.state.walletWindow=window.id;baseline.window=window.id
    local ok,err=pcall(added,c,baseline,priorBalance)
    local windowOK,windowError=true,nil
    if c.records[window.id]==window then windowOK,windowError=pcall(added,c,window,priorKind)end
    if not ok then error(err,0)end
    if not windowOK then error(windowError,0)end
    return baseline
end
function S.Add(c, kind, ts, data, dedup)
    return add(c,kind,ts,data,dedup)
end
function S.AddSkill(c,kind,ts,data,info)
    if not data.weaponReading then return S.Add(c,kind,ts,data) end
    assert(c.state.skills and (kind=="weapon_observation" or kind=="milestone") and info.skillID==data.skillID)
    return add(c,kind,ts,data,nil,info)
end
function S.Touch(c,reason,detail)
    c.revision=c.revision+1
    local receipt={character=c,revision=c.revision,reason=reason,detail=detail}
    E.Emit('HISTORY_TOUCHED',c,receipt)
    return receipt
end
function S.Changed(c,r,context)
    if c.records[r.id]==r and (S.CraftRequestSource(r) or craftSeeds[c] and craftSeeds[c].slots[r.id])then rememberCraft(c,r.id,r)end
    local detail={operation="change",record=r}
    if type(context)=="table" then
        for key,value in pairs(context) do
            if key~="operation" and key~="record" then detail[key]=value end
        end
    end
    local receipt=S.Touch(c,"record",detail); E.Emit("RECORD_CHANGED",c,r,nil,receipt)
end
function S.ReserveObservation(c) c.seq=c.seq+1; S.Touch(c,"observation"); return c.seq end
local function sequenceNumber(n)
    return type(n)=="number" and n>=0 and n<=9007199254740991 and n%1==0 and n or nil
end
function S.Sequence(r)
    local seq=r.observationSequence
    if seq==nil then seq=r.sequence end
    if seq==nil and type(r.id)=="string" then seq=tonumber(r.id:match(":(%d+)$") or "") end
    return sequenceNumber(seq) or 0
end
local function clockTime(ts)
    if type(ts)~="number" or ts~=ts or ts<=-math.huge or ts>=math.huge then return end
    -- Normal WoW observations fit every supported signed-32-bit calendar.
    -- Other finite values depend on the host renderer (which can return nil).
    if ts>=0 and ts<=2147483647 then return ts end
    local ok,day=pcall(date,"%Y-%m-%d",ts)
    if ok and type(day)=="string" and day:match("^%d%d%d%d%-%d%d%-%d%d$") then return ts end
end
function S.Timestamp(record) return clockTime(record.ts) end
function S.Before(a,b)
    local at,bt=S.Timestamp(a),S.Timestamp(b)
    if at~=bt then return at~=nil and (bt==nil or at<bt) end
    return S.Sequence(a)<S.Sequence(b)
end
-- New observations disambiguate event order within one wall-clock second.
-- Missing sequence bounds keep the interpretation of older saved intervals.
function S.QuestSequence(r)
    if r.observationSequence~=nil then return sequenceNumber(r.observationSequence) end
    if r.sequence~=nil then return sequenceNumber(r.sequence) end
    if type(r.id)=="string" and type(r.character)=="string" and r.id:sub(1,#r.character+1)==r.character..":" then
        return sequenceNumber(tonumber(r.id:sub(#r.character+2):match("^%d+$") or ""))
    end
end
function S.QuestInterval(q,i)
    if type(i)~="table" then return end
    local first,last,ended=sequenceNumber(i.fromSequence),sequenceNumber(i.throughSequence),sequenceNumber(q.endedSequence)
    if (i.fromSequence~=nil and not first) or (i.throughSequence~=nil and not last) or (q.endedSequence~=nil and not ended) then return end
    if first and last then
        local exclusive=ended and ended<=last or false
        local through=exclusive and ended or last
        if first>through or first==through and exclusive then return end
        return {axis="sequence",from=first,through=through,fromSequence=-math.huge,throughSequence=math.huge,exclusive=exclusive}
    end
    local from,through=clockTime(i.from),clockTime(i.through)
    if not from or not through then return end
    local b={axis="timestamp",from=from,through=through,fromSequence=first or -math.huge,throughSequence=last or math.huge,exclusive=false}
    if q.ended~=nil then
        local endTime=clockTime(q.ended)
        if not endTime then return end
        local endOrder=ended or -math.huge
        if endTime<b.through or endTime==b.through and endOrder<=b.throughSequence then
            b.through,b.throughSequence,b.exclusive=endTime,endOrder,true
        end
    end
    if b.through<b.from or b.through==b.from and (b.throughSequence<b.fromSequence or b.throughSequence==b.fromSequence and b.exclusive) then return end
    return b
end
function S.InQuestInterval(r,b)
    if type(b)~="table" or type(b.from)~="number" or type(b.through)~="number" or type(b.fromSequence)~="number" or type(b.throughSequence)~="number" then return false end
    if b.axis=="sequence" then
        local seq=S.QuestSequence(r)
        return seq~=nil and seq>=b.from and (seq<b.through or seq==b.through and not b.exclusive)
    end
    local ts=S.Timestamp(r)
    if not ts then return false end
    if ts>b.from and ts<b.through then return true end
    local seq=S.QuestSequence(r)
    local after=ts>b.from or ts==b.from and (b.fromSequence==-math.huge or seq and seq>=b.fromSequence)
    local before=ts<b.through or ts==b.through and (b.throughSequence==math.huge or seq and (seq<b.throughSequence or seq==b.throughSequence and not b.exclusive))
    return after and before or false
end
function S.List(c, predicate)
    local out = {}
    for _,id in ipairs(c.order) do local r=c.records[id]; if r and (not predicate or predicate(r)) then out[#out+1]=r end end
    table.sort(out,S.Before)
    return out
end
function S.Note(c, key, text, ts)
    assert(type(key)=="string" and type(text)=="string")
    c.notes[key] = {text=text, updated=ts}; S.Touch(c,"notes",key)
    E.Emit("NOTE_CHANGED",c,key)
end
function S.NoteCategory(c,key)
    local source=c.records[key] or c.records[key:match('^record:(.+)$') or '']
    if key:match('^day:') or source and source.kind=='diary' then return 'dailyNotes',source end
    if key:match('^recap:') or source and source.kind=='recap' then return 'recapNotes',source end
    return 'otherNotes',source
end
-- Successor cursors skip kills already covered by another retained quest interval.
-- Iterative path compression keeps overlapping histories from repeatedly walking
-- the same kills, without recursion. Reasons still name a retained source whose
-- recorded interval includes the kill; overlapping sources need no canonical winner.
local function checkpoint(work)if work then work()end end
local function sort(rows,less,work)
    if work then E.RetentionWork.Sort(rows,less,work)else table.sort(rows,less)end
end
-- Only use this comparator after admitting dated rows to a local index.
local function datedBefore(a,b)
    if a.ts~=b.ts then return a.ts<b.ts end
    return S.Sequence(a)<S.Sequence(b)
end
local function copy(value,work)
    return work and E.RetentionWork.Copy(value,work)or E.Copy(value)
end
local function nextUncovered(state,index,links)
    local work=state.work
    links=links or state.coveredKills;local root=index
    while links[root]do checkpoint(work); root=links[root]end
    while links[index]do checkpoint(work); local following=links[index];links[index]=root;index=following end
    return root
end
-- A request with an older observation sequence can have a later clock
-- after a rollback. Prefix maxima let normal sessions stop at their recent
-- request windows without dropping that contradictory evidence.
function S.CraftRequestSource(r)
    return r.kind=='craft_request' or r.kind=='craft_gap' and r.craftRequestOmitted==true
end
function S.NewCraftFrontier() return {members={},ids={},seen={},generation=0} end
function S.IndexCraftRequest(d,id,r)
    local old=d.members[id]
    if not r and not old then return end
    local seq=r and S.Sequence(r)
    local ts=r and S.Timestamp(r)
    local count=r and r.requestCasts
    local duration=type(count)=='number' and count>0 and count%1==0 and math.min(7200,count*60+10) or 7200
    local deadline=r and (ts and ts+duration+1 or math.huge)
    if old and r and old.sequence==seq and old.deadline==deadline and old.record==r then return end
    local row=r and {record=r,id=id,sequence=seq,deadline=deadline}
    if row and not d.seen[id]then d.seen[id]=true;d.ids[#d.ids+1]=id end
    d.members[id]=row;d.generation=d.generation+1
    local list=d.ordered
    if list and not old and row and (#list==0 or list[#list].sequence<seq) then
        local n=#list+1;local block=math.floor((n-1)/64)
        list.maxima[n]=math.max(deadline,list.maxima[n-1] or -math.huge)
        list.blockMax[block]=math.max(deadline,list.blockMax[block] or -math.huge);list[n]=row
    else d.ordered=nil end
end
function S.PrepareCraftFrontier(d,work)
    while not d.ordered do
        local generation=d.generation;local list={maxima={},blockMax={}}
        for n=1,#d.ids do checkpoint(work);local row=d.members[d.ids[n]];if row then list[#list+1]=row end end
        sort(list,function(a,b)return a.sequence<b.sequence end,work)
        local maximum=-math.huge
        for n,row in ipairs(list)do checkpoint(work)
            local block=math.floor((n-1)/64);list.blockMax[block]=math.max(row.deadline,list.blockMax[block] or -math.huge)
            maximum=math.max(maximum,row.deadline);list.maxima[n]=maximum
        end
        if d.generation==generation then d.ordered=list end
    end
    return d.ordered
end
-- An earlier, independently observed normal item recipe with a different
-- primary output cannot explain this nonreward result. Keep ambiguous
-- schematics and all hooks actually inside the observation span.
local function distinctCraftOutput(a,b)
    local spec=a.materialSpec;local target=b.materialSpec
    return a.kind=='craft_request' and a.character==b.character and a.subject==a.character
        and a.requestMethod=='CraftRecipe' and a.npcCrafting==false and not a.orderID and type(spec)=='table'
        and spec.source=='C_TradeSkillUI.GetRecipeSchematic' and spec.recipeID==a.recipeID
        and type(spec.outputItemID)=='number' and spec.outputItemID>0 and spec.outputItemID%1==0
        and type(target)=='table' and target.recipeID==b.recipeID and type(target.outputItemID)=='number'
        and spec.outputItemID~=target.outputItemID
end
function S.CraftPredecessors(d,r,work,throughSequence,keys)
    local list=S.PrepareCraftFrontier(d,work)
    local sequence,at=S.Sequence(r),S.Timestamp(r) or -math.huge
    local lo,hi=1,#list+1
    while lo<hi do checkpoint(work);local mid=math.floor((lo+hi)/2)
        if list[mid].sequence<=(throughSequence or sequence) then lo=mid+1 else hi=mid end
    end
    local out={}
    local n=lo-1
    while n>0 do checkpoint(work);local row=list[n]
        if row.sequence<sequence and list.maxima[n]<=at then break end
        if row.sequence<sequence and n%64==0 and list.blockMax[math.floor((n-1)/64)]<=at then n=n-64
        else
            if (row.sequence>=sequence or row.deadline>at and not distinctCraftOutput(row.record,r)) and row.record~=r then out[#out+1]=keys and row.id or row.record end
            n=n-1
        end
    end
    return out
end
local craftEvidence={craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true,
    inventory=true,inventory_gap=true,bank=true,bank_gap=true,stock_move=true,stock_reset=true,cost_lot=true,
    item_sale=true,sale_return=true,merchant=true,auction=true,trade=true,trade_offer=true,trade_notice=true,
    mail=true,mail_collection=true,mail_scan=true,mail_request=true,mail_notice=true,mail_draft=true}
local function retainCraftEvidence(c,request,add,state)
    if request.requestMethod~='CraftRecipe' or type(request.requestCasts)~='number' or request.requestCasts<1 or request.requestCasts>1000 or request.requestCasts%1~=0 or request.character~=c.id
        or request.subject~=c.id or not request.materialSpec or not request.inventoryAnchor or not S.Timestamp(request) then return end
    -- CraftCosts checks the 15-second inventory anchor, the 70-second
    -- single-cast result window, then up to two seconds for inventory.
    -- Keep rivals as well as the selected rows. Deleting a second result
    -- must not turn an ambiguous old request into one completed operation.
    local work=state.work
    local evidence=state.singleCastEvidence
    if not evidence then
        evidence={rows={},covered={}}
        for _,row in pairs(c.records)do
            checkpoint(work)
            if (craftEvidence[row.kind] or S.CraftRequestSource(row)) and S.Timestamp(row)then evidence.rows[#evidence.rows+1]=row end
        end
        sort(evidence.rows,datedBefore,work)
        evidence.blockMax={}
        for n,row in ipairs(evidence.rows)do checkpoint(work)
            local block=math.floor((n-1)/64);evidence.blockMax[block]=math.max(evidence.blockMax[block] or 0,S.Sequence(row))
        end
        state.singleCastEvidence=evidence
    end
    local rows,covered=evidence.rows,evidence.covered
    local first,through=request.ts-15,request.ts+math.min(7200,request.requestCasts*60+10)+3
    local lo,hi=1,#rows+1
    while lo<hi do
        checkpoint(work)
        local middle=math.floor((lo+hi)/2)
        if rows[middle].ts<first then lo=middle+1 else hi=middle end
    end
    local bound,top=lo,#rows+1
    while bound<top do checkpoint(work);local mid=math.floor((bound+top)/2)
        if rows[mid].ts<through then bound=mid+1 else top=mid end
    end
    local last,scan=S.Sequence(request),lo
    while scan<bound do checkpoint(work)
        if (scan-1)%64==0 and scan+64<=bound then
            last=math.max(last,evidence.blockMax[math.floor((scan-1)/64)]);scan=scan+64
        else last=math.max(last,S.Sequence(rows[scan]));scan=scan+1 end
    end
    for _,id in ipairs(S.CraftPredecessors(state.craftFrontier,request,work,last,true))do
        add(id,{kind='linked',source=request.id})
    end
    local index=nextUncovered(state,lo,covered)
    while rows[index]and rows[index].ts<through do
        checkpoint(work)
        local row=rows[index]
        if row.id~=request.id then add(row.id,{kind="linked",source=request.id})end
        local following=nextUncovered(state,index+1,covered)
        covered[index]=following
        index=following
    end
end
local function dependencies(c,r,add,state)
    local work=state.work
    for _,ref in ipairs(r.refs or {})do checkpoint(work); add(ref,{kind="linked",source=r.id})end
    if E.Chapters then E.Chapters.Retention(c,r,add,state)end
    if E.PullLinks then E.PullLinks.Retention(c,r,add,state)end
    if E.AuctionLinks then E.AuctionLinks.Retention(c,r,add,state)end
    if E.AuctionSettlement then E.AuctionSettlement.Retention(c,r,add,state)end
    if E.AuctionReturns then E.AuctionReturns.Retention(c,r,add,state)end
    if r.kind=='craft_request' and r.materialSpec and r.inventoryAnchor and S.Timestamp(r) then
        if not state.craftFrontier then
            state.craftFrontier=S.NewCraftFrontier()
            for id,row in pairs(c.records)do checkpoint(work)
                if S.CraftRequestSource(row) then S.IndexCraftRequest(state.craftFrontier,id,row)end
            end
        end
        retainCraftEvidence(c,r,add,state)
    end
    if r.kind=="craft_result" and r.operationKey and E.Production and not state.operations[r.operationKey] then
        state.operations[r.operationKey]=true
        for _,related in ipairs(E.Production.Related(c,r,work))do checkpoint(work); add(related.id,{kind="operation",source=r.id})end
    end
    if r.kind=="quest_attempt" then
        for _,interval in ipairs(r.intervals or {})do checkpoint(work);
            local bounds=S.QuestInterval(r,interval)
            if bounds then
                local bySequence=bounds.axis=='sequence'
                local key=bySequence and 'sequenceKills' or 'datedKills'
                local index=state[key]
                if not index then
                    index={kills={},coveredKills={},work=work}
                    for _,kill in pairs(c.records)do checkpoint(work)
                        if kill.kind=="kill" and (not kill.character or kill.character==c.id) and c.records[kill.id]==kill and ((bySequence and S.QuestSequence(kill)) or (not bySequence and S.Timestamp(kill))) then index.kills[#index.kills+1]=kill end
                    end
                    local less=bySequence and function(a,b)return S.QuestSequence(a)<S.QuestSequence(b)end or function(a,b)
                        if a.ts~=b.ts then return a.ts<b.ts end
                        return (S.QuestSequence(a) or -math.huge)<(S.QuestSequence(b) or -math.huge)
                    end
                    sort(index.kills,less,work)
                    state[key]=index
                end
                local lo,hi=1,#index.kills+1
                while lo<hi do checkpoint(work); local mid=math.floor((lo+hi)/2);local kill=index.kills[mid]
                    local point=bySequence and S.QuestSequence(kill) or kill.ts
                    if point<bounds.from or point==bounds.from and (S.QuestSequence(kill) or -math.huge)<bounds.fromSequence then lo=mid+1 else hi=mid end end
                lo=nextUncovered(index,lo)
                while index.kills[lo]do checkpoint(work);
                    local kill=index.kills[lo]
                    if not S.InQuestInterval(kill,bounds) then
                        -- An undetermined tie at a timestamp endpoint can precede other
                        -- kills with known tie order. Do not consume that candidate.
                        if not bySequence and kill.ts==bounds.through and not S.QuestSequence(kill) then
                            lo=nextUncovered(index,lo+1)
                        else break end
                    else
                        add(kill.id,{kind="quest",source=r.id})
                        local following=nextUncovered(index,lo+1);index.coveredKills[lo]=following;lo=following
                    end
                end
            end
        end
        if not state.credits then
            state.credits={}
            for id,credit in pairs(c.records)do checkpoint(work); if (credit.kind=="credit"or credit.kind=="objective") and credit.attempt then
                local list=state.credits[credit.attempt]or{};state.credits[credit.attempt]=list;list[#list+1]=id
            end end
        end
        for _,id in ipairs(state.credits[r.id]or{})do checkpoint(work); add(id,{kind="quest",source=r.id})end
    end
end
function S.Protected(c,work)
    local protected,reasons,state = {},{},{operations={},work=work}
    local function visit(id,reason)
        local pending={{id=id,reason=reason}}
        while #pending>0 do checkpoint(work);
            local entry=table.remove(pending); local key=entry.id
            if not protected[key] then
                protected[key]=true; reasons[key]=entry.reason or {kind="linked"}
                local r=c.records[key]; local children={}
                local function add(child,why) children[#children+1]={id=child,reason=why}end
                if r then dependencies(c,r,add,state)end
                -- Preserve depth-first source ordering without consuming the Lua call stack.
                for index=#children,1,-1 do checkpoint(work); pending[#pending+1]=children[index]end
            end
        end
    end
    for id,r in pairs(c.records) do checkpoint(work); if r.starred then visit(id,{kind="starred"}) end end
    for id,r in pairs(c.records)do checkpoint(work); if (r.kind=="diary"or r.kind=="recap")and r.inProgress then visit(id,{kind="active"})end end
    -- Live collector state must not be invalidated by cleanup.
    for _,id in pairs(c.state.activeQuests or {}) do checkpoint(work); visit(id,{kind="active"}) end
    if c.state.activeEncounter then visit(c.state.activeEncounter,{kind="active"})end
    for id in pairs(c.state.activePullRecords or{})do checkpoint(work); visit(id,{kind="active"})end
    for _,key in ipairs({"group","activeLootWindow","activeTrade","activeMailbox","activeMailCollection","activeMailDraft","play","walletWindow"})do checkpoint(work); if c.state[key] then visit(c.state[key],{kind="active"})end end
    for id,r in pairs(c.records)do checkpoint(work); if r.kind=="screenshot" and r.status=="pending" then visit(id,{kind="active"})end end
    local merchant=E.Merchant
    if c.state.inventory then
        if c.state.inventory.record then visit(c.state.inventory.record,{kind="active"})end
        if c.state.inventory.gap then visit(c.state.inventory.gap,{kind="active"})end
    end
    if merchant and merchant.owner==c and merchant.pending then
        visit(merchant.pending.id,{kind="active"})
        for _,r in ipairs(merchant.wallets or {})do checkpoint(work); visit(r.id,{kind="active"})end
    end
    if E.Economy and E.Economy.RetentionRoots then
        for id in pairs(E.Economy.RetentionRoots(c,work))do checkpoint(work); visit(id,{kind="accounting"})end
    end
    for _,pending in pairs(c.state.progress and c.state.progress.pending or {}) do checkpoint(work);
        for _,ref in ipairs(pending.context and pending.context.refs or {}) do checkpoint(work); visit(ref) end
        for _,observation in ipairs(pending.notifications or {}) do checkpoint(work); if observation.group then visit(observation.group) end end
    end
    return protected,reasons
end
function S.PreviewExpiry(c, now, work)
    -- The default Forever policy cannot expire anything. Do not build protection
    -- graphs or enumerate an unlimited scrapbook merely to prove that again.
    local finite=false
    for _,days in pairs(c.retention)do checkpoint(work);
        if type(days)=="number"and days>0 and days<math.huge then finite=true;break end
    end
    if not finite then
        return {character=c.id,ids={},aged={},reasons={},count=0,revision=c.revision,at=now,policies=copy(c.retention,work),
            noteIDs={},noteAged={},noteReasons={},noteValues={},noteCount=0}
    end
    local keep,reasons = S.Protected(c,work); local expired,aged = {},{}; local count = 0
    for id,r in pairs(c.records) do checkpoint(work);
        local days = c.retention[r.category]
        if type(days)=="number" and days>0 and days<math.huge and S.Timestamp(r)
            and (r.ended==nil or clockTime(r.ended)) and (r.ended or r.ts)<now-days*86400 then
            aged[id]=true
            if not keep[id] then expired[id]=true; count=count+1 end
        end
    end
    -- Walk survivors once. Implicit quest/operation links have the same lifetime
    -- guarantee as explicit references, including a source rescued later in the walk.
    if count>0 then
        local pending,seen,state={}, {},{operations={},work=work}
        local function retain(id,reason)
            if expired[id]then expired[id]=nil;count=count-1;reasons[id]=reason end
            if c.records[id]and not seen[id]then seen[id]=true;pending[#pending+1]=id end
        end
        for id in pairs(c.records)do checkpoint(work); if not expired[id]then retain(id)end end
        local cursor=1
        while count>0 and cursor<=#pending do checkpoint(work);
            local r=c.records[pending[cursor]];cursor=cursor+1
            dependencies(c,r,function(id,reason)
                if reason.kind=="linked"then reason.kind="retainedReference"end
                retain(id,reason)
            end,state)
        end
    end
    local noteIDs,noteAged,noteReasons,noteValues={}, {},{},{};local noteCount=0
    local noteSources={}
    for id,r in pairs(c.records)do checkpoint(work);
        if r.kind=='diary'and type(r.day)=='string'then noteSources['day:'..r.day]=id end
        if r.kind=='recap'and type(r.key)=='string'then noteSources['recap:'..r.key]=id end
    end
    for key,note in pairs(c.notes)do checkpoint(work); if type(key)=='string'and type(note)=='table'then
        local category,source=S.NoteCategory(c,key);local days=c.retention[category];local updated=note.updated
        if type(days)=='number'and days>0 and days<math.huge and type(updated)=='number'and updated==updated and updated>-math.huge and updated<now-days*86400 then
            noteAged[key]=true;local id=source and source.id or noteSources[key]
            if id and keep[id]then noteReasons[key]=reasons[id]or{kind='linked',source=id}
            else noteIDs[key]=true;noteValues[key]=copy(note,work);noteCount=noteCount+1 end
        end
    end end
    return {character=c.id,ids=expired,aged=aged,reasons=reasons,count=count,revision=c.revision,at=now,policies=copy(c.retention,work),
        noteIDs=noteIDs,noteAged=noteAged,noteReasons=noteReasons,noteValues=noteValues,noteCount=noteCount}
end
local function shallow(values,work)
    local out={};for key,value in pairs(values or{})do checkpoint(work);out[key]=value end;return out
end
local function prepareExpiry(c,preview,work)
    local p={removed={},ranges={},kinds={},records=c.records,order=c.order,dedup=c.dedup,notes=shallow(c.notes,work),
        diaries=c.state.diaries,recaps=c.state.recaps,expired=c.state.expiredSummaries,stamp={}}
    local function removed(category,from,through)
        p.removed[category]=(p.removed[category]or 0)+1
        local range=p.ranges[category]or{from=from,through=through};p.ranges[category]=range
        range.from=math.min(range.from,from);range.through=math.max(range.through,through)
    end
    -- Plan note expiry before migrating legacy summary-note keys. All values in
    -- this plan are private maps or unchanged surviving record/note objects.
    for key in pairs(preview.noteIDs)do checkpoint(work)
        local note=c.notes[key];removed(S.NoteCategory(c,key),note.updated,note.updated);p.notes[key]=nil
    end
    local copied={};local deletedDedup={}
    if next(preview.ids)then
        p.records={};p.order={};p.dedup={}
        p.craftSeed={ids={},slots={},generation=0}
        for id,r in pairs(c.records)do checkpoint(work)
            if not preview.ids[id]then
                p.records[id]=r
                if S.CraftRequestSource(r)then
                    local seed=p.craftSeed;seed.ids[#seed.ids+1]=id;seed.slots[id]=#seed.ids
                end
            else
                p.kinds[r.kind]=true
                removed(r.category,r.ts,r.ended or r.ts)
                if r.dedup then deletedDedup[r.dedup]=true end
                if r.kind=='diary'or r.kind=='recap'then
                    local category=r.kind=='diary'and'diaries'or'recaps';local key=r.kind=='diary'and r.day or r.key
                    if type(key)=='string'then
                        if not copied[category]then
                            if not p.copiedExpired then p.expired=shallow(p.expired,work);p.copiedExpired=true end
                            p.expired[category]=shallow(p.expired[category],work)
                            if p[category]then p[category]=shallow(p[category],work)end
                            copied[category]=true
                        end
                        -- One shared, privately staged stamp gets the actual commit
                        -- time in O(1), even when thousands of summaries expire.
                        p.expired[category][key]={batch=p.stamp,from=r.from,through=r.through}
                        if p[category]and p[category][key]==id then p[category][key]=nil end
                        if r.kind=='recap'and E.Diary then
                            local canonical='recap:'..key;local legacy='record:'..id
                            if not p.notes[canonical]and p.notes[legacy]then
                                p.notes[canonical]=p.notes[legacy];p.notes[legacy]=nil;p.migrated=true
                            end
                        end
                    end
                end
            end
        end
        for _,id in ipairs(c.order)do checkpoint(work);if p.records[id]then p.order[#p.order+1]=id end end
        for key,id in pairs(c.dedup)do checkpoint(work);if not deletedDedup[key]then p.dedup[key]=id end end
    end
    return p
end
-- These record kinds cannot be trade/mail/gathering evidence. Older callers
-- without a typed batch still take the conservative reconciliation path.
function S.JournalOnlyRemoval(batch)
    if type(batch)~='table'or type(batch.kinds)~='table'then return false end
    for kind in pairs(batch.kinds)do
        if kind~='chat'and kind~='diary'and kind~='recap'and kind~='note'then return false end
    end
    return true
end
function S.ApplyExpiry(c, preview, work, beforeCommit, beforePrepare)
    assert(not c.state.inventoryCostLinks,"Inventory source checks are pending; review cleanup after they finish.")
    assert(preview.character==c.id,"Cleanup review belongs to another character")
    assert(preview.revision==c.revision, "History changed; review cleanup again")
    local current = S.PreviewExpiry(c, preview.at, work)
    -- Validate the entire transaction before changing even one record.
    local same=work and function(a,b)return E.RetentionWork.Same(a,b,work)end or E.Same
    assert(same(preview.policies,c.retention) and same(preview.ids,current.ids),"Retention or protection changed; review cleanup again")
    assert(same(preview.noteIDs,current.noteIDs) and same(preview.noteValues,current.noteValues),'Personal notes changed; review cleanup again')
    local records,notes,order,dedup=c.records,c.notes,c.order,c.dedup
    if beforePrepare then beforePrepare()end
    local p=prepareExpiry(c,preview,work)
    local queryIndex=E.Query and E.Query.PrepareExpiry(c,p.records,work)
    -- Recheck after the last possible yield. Publishing the prepared maps has no
    -- record-count-dependent loop and keeps surviving record identities intact.
    assert(preview.revision==c.revision,'History changed; review cleanup again')
    assert(c.records==records and c.notes==notes and c.order==order and c.dedup==dedup,'History tables changed during cleanup')
    if beforeCommit then beforeCommit()end
    -- Commit hooks must not invalidate either the prepared history or its index.
    local at=E.API and E.API.Now()or preview.at;p.stamp.expiredAt=at
    assert(preview.revision==c.revision and c.records==records and c.notes==notes and c.order==order and c.dedup==dedup,'History changed before cleanup publication')
    assert(not c.state.inventoryCostLinks,"Inventory source checks are pending; review cleanup after they finish.")
    c.records,c.order,c.dedup,c.notes=p.records,p.order,p.dedup,p.notes
    if p.craftSeed then craftSeeds[c]=#p.craftSeed.ids>0 and p.craftSeed or nil end
    c.state.diaries,c.state.recaps,c.state.expiredSummaries=p.diaries,p.recaps,p.expired
    local batch={noteIDs=preview.noteIDs,migrated=p.migrated,kinds=p.kinds,queryIndex=queryIndex}
    local receipt=S.Touch(c,'retention',{ids=preview.ids,batch=batch})
    -- All note removals and migrations are already published. Existing search
    -- consumers invalidate from this batch instead of one redraw per note.
    E.Emit('RECORDS_REMOVED',c,preview.ids,batch,receipt)
    if p.migrated then E.Emit('DATA_MIGRATED',c,receipt)end
    if next(p.removed)then S.Add(c,'gap',at,{title='History expired under your retention settings',removed=p.removed,
        removedRanges=p.ranges,reviewedAt=preview.at,policies=E.Copy(preview.policies)})end
    return p.removed
end
