-- Generated private read engines. Regenerate/check with tools/build_auction_readers.py.
local _,E=...
E.AuctionReaderFactories={}
E.AuctionReaderSources={}
E.AuctionWalletReadInstrumentation=1

-- Store.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Store';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local S = {}; E.Store = S
S.categories = {quest="quests",quest_attempt="quests",objective="questKills",credit="questKills",kill="questKills",
    group="groups",encounter="groups",chat="chat",pull="pulls",auction="gold",trade="gold",trade_offer="gold",trade_notice="gold",loot="loot",drop="loot",loot_window="loot",crafted="production",gathered="production",craft_request="production",craft_begin="production",craft_result="production",
    gold="gold",balance="gold",milestone="milestones",death="milestones",spell="milestones",weapon_observation="milestones",
    memory="memories",screenshot="memories",recap="recaps",diary="diaries",note="notes",play="time",gap="coverage",
    wallet_window="gold",money_evidence="gold",merchant="gold",inventory="gold",inventory_gap="gold",bank="gold",bank_gap="gold",cost_lot="gold",item_sale="gold",stock_move="gold",stock_reset="gold",sale_return="gold"}
for _,kind in ipairs({'mail','mail_scan','mail_collection','mail_request','mail_notice','mail_draft'})do _auctionTick(); S.categories[kind]='gold'end
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
    for owner,c in pairs(db.characters)do _auctionTick();
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
        for id,r in pairs(c.records)do _auctionTick();
            assert(type(r)=="table","Invalid character journal record")
            if c.id==nil then assert(r.id==id and r.character==owner,"Missing character identity has conflicting record ownership")end
            if S.CraftRequestSource(r)then rememberCraft(c,id,r,seeds) end
            if r.kind=='bank' and type(r.bankOrder)=='number' and r.bankOrder%1==0 and r.bankOrder>order then order=r.bankOrder end
        end
    end
    -- Finish checking the entire account before publishing a migrated field
    -- or replacing a live character's lookup table.
    for _,apply in ipairs(bindings)do _auctionTick(); apply()end
    for c,owner in pairs(owners)do _auctionTick();
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
        c = {id=id, identity=_auctionCopy(identity or {}), seq=0, records={}, order={}, dedup={},
            retention={}, notes={}, art={}, state={}, revision=0}
        E.db.characters[id] = c
    elseif identity then
        local known=identity.nameKnown~=false and type(identity.name)=='string'and identity.name~=''
        local changed=false
        if known and c.identity.name and c.identity.nameKnown~=false and (c.identity.name~=identity.name or(identity.realm and identity.realm~=''and identity.realm~=c.identity.realm))then
            c.identityHistory=c.identityHistory or{};c.identityHistory[#c.identityHistory+1]={name=c.identity.name,realm=c.identity.realm,replacedAt=E.API.Now()}
        end
        for k,v in pairs(identity) do _auctionTick();
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
    local r = _auctionCopy(data or {})
    for _, id in ipairs(r.refs or {}) do _auctionTick(); assert(c.records[id], "Reference must belong to this character") end
    c.seq = c.seq+1
    r.id, r.character, r.kind, r.ts, r.sequence = c.id..":"..c.seq, c.id, kind, ts, c.seq
    -- Shared-bank chronology must survive character changes and wall-clock jumps.
    if kind=="bank" then
        E.db.bankOrder=(E.db.bankOrder or 0)+1; r.bankOrder=E.db.bankOrder
    end
    if clock then r.localStamp=_auctionCopy(clock.value)
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
        for key,value in pairs(context) do _auctionTick();
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
    for _,id in ipairs(c.order) do _auctionTick(); local r=c.records[id]; if r and (not predicate or predicate(r)) then out[#out+1]=r end end
    _auctionSort(out,S.Before)
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
    if work then E.RetentionWork.Sort(rows,less,work)else _auctionSort(rows,less)end
end
-- Only use this comparator after admitting dated rows to a local index.
local function datedBefore(a,b)
    if a.ts~=b.ts then return a.ts<b.ts end
    return S.Sequence(a)<S.Sequence(b)
end
local function copy(value,work)
    return work and E.RetentionWork.Copy(value,work)or _auctionCopy(value)
end
local function nextUncovered(state,index,links)
    local work=state.work
    links=links or state.coveredKills;local root=index
    while links[root]do _auctionTick(); checkpoint(work); root=links[root]end
    while links[index]do _auctionTick(); checkpoint(work); local following=links[index];links[index]=root;index=following end
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
    while not d.ordered do _auctionTick();
        local generation=d.generation;local list={maxima={},blockMax={}}
        for n=1,#d.ids do _auctionTick(); checkpoint(work);local row=d.members[d.ids[n]];if row then list[#list+1]=row end end
        sort(list,function(a,b)return a.sequence<b.sequence end,work)
        local maximum=-math.huge
        for n,row in ipairs(list)do _auctionTick(); checkpoint(work)
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
    while lo<hi do _auctionTick(); checkpoint(work);local mid=math.floor((lo+hi)/2)
        if list[mid].sequence<=(throughSequence or sequence) then lo=mid+1 else hi=mid end
    end
    local out={}
    local n=lo-1
    while n>0 do _auctionTick(); checkpoint(work);local row=list[n]
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
        for _,row in pairs(c.records)do _auctionTick();
            checkpoint(work)
            if (craftEvidence[row.kind] or S.CraftRequestSource(row)) and S.Timestamp(row)then evidence.rows[#evidence.rows+1]=row end
        end
        sort(evidence.rows,datedBefore,work)
        evidence.blockMax={}
        for n,row in ipairs(evidence.rows)do _auctionTick(); checkpoint(work)
            local block=math.floor((n-1)/64);evidence.blockMax[block]=math.max(evidence.blockMax[block] or 0,S.Sequence(row))
        end
        state.singleCastEvidence=evidence
    end
    local rows,covered=evidence.rows,evidence.covered
    local first,through=request.ts-15,request.ts+math.min(7200,request.requestCasts*60+10)+3
    local lo,hi=1,#rows+1
    while lo<hi do _auctionTick();
        checkpoint(work)
        local middle=math.floor((lo+hi)/2)
        if rows[middle].ts<first then lo=middle+1 else hi=middle end
    end
    local bound,top=lo,#rows+1
    while bound<top do _auctionTick(); checkpoint(work);local mid=math.floor((bound+top)/2)
        if rows[mid].ts<through then bound=mid+1 else top=mid end
    end
    local last,scan=S.Sequence(request),lo
    while scan<bound do _auctionTick(); checkpoint(work)
        if (scan-1)%64==0 and scan+64<=bound then
            last=math.max(last,evidence.blockMax[math.floor((scan-1)/64)]);scan=scan+64
        else last=math.max(last,S.Sequence(rows[scan]));scan=scan+1 end
    end
    for _,id in ipairs(S.CraftPredecessors(state.craftFrontier,request,work,last,true))do _auctionTick();
        add(id,{kind='linked',source=request.id})
    end
    local index=nextUncovered(state,lo,covered)
    while rows[index]and rows[index].ts<through do _auctionTick();
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
    for _,ref in ipairs(r.refs or {})do _auctionTick(); checkpoint(work); add(ref,{kind="linked",source=r.id})end
    if E.Chapters then E.Chapters.Retention(c,r,add,state)end
    if E.AuctionLinks then E.AuctionLinks.Retention(c,r,add,state)end
    if E.AuctionSettlement then E.AuctionSettlement.Retention(c,r,add,state)end
    if E.AuctionReturns then E.AuctionReturns.Retention(c,r,add,state)end
    if r.kind=='craft_request' and r.materialSpec and r.inventoryAnchor and S.Timestamp(r) then
        if not state.craftFrontier then
            state.craftFrontier=S.NewCraftFrontier()
            for id,row in pairs(c.records)do _auctionTick(); checkpoint(work)
                if S.CraftRequestSource(row) then S.IndexCraftRequest(state.craftFrontier,id,row)end
            end
        end
        retainCraftEvidence(c,r,add,state)
    end
    if r.kind=="craft_result" and r.operationKey and E.Production and not state.operations[r.operationKey] then
        state.operations[r.operationKey]=true
        for _,related in ipairs(E.Production.Related(c,r,work))do _auctionTick(); checkpoint(work); add(related.id,{kind="operation",source=r.id})end
    end
    if r.kind=="quest_attempt" then
        for _,interval in ipairs(r.intervals or {})do _auctionTick(); checkpoint(work);
            local bounds=S.QuestInterval(r,interval)
            if bounds then
                local bySequence=bounds.axis=='sequence'
                local key=bySequence and 'sequenceKills' or 'datedKills'
                local index=state[key]
                if not index then
                    index={kills={},coveredKills={},work=work}
                    for _,kill in pairs(c.records)do _auctionTick(); checkpoint(work)
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
                while lo<hi do _auctionTick(); checkpoint(work); local mid=math.floor((lo+hi)/2);local kill=index.kills[mid]
                    local point=bySequence and S.QuestSequence(kill) or kill.ts
                    if point<bounds.from or point==bounds.from and (S.QuestSequence(kill) or -math.huge)<bounds.fromSequence then lo=mid+1 else hi=mid end end
                lo=nextUncovered(index,lo)
                while index.kills[lo]do _auctionTick(); checkpoint(work);
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
            for id,credit in pairs(c.records)do _auctionTick(); checkpoint(work); if (credit.kind=="credit"or credit.kind=="objective") and credit.attempt then
                local list=state.credits[credit.attempt]or{};state.credits[credit.attempt]=list;list[#list+1]=id
            end end
        end
        for _,id in ipairs(state.credits[r.id]or{})do _auctionTick(); checkpoint(work); add(id,{kind="quest",source=r.id})end
    end
end
function S.Protected(c,work)
    local protected,reasons,state = {},{},{operations={},work=work}
    local function visit(id,reason)
        local pending={{id=id,reason=reason}}
        while #pending>0 do _auctionTick(); checkpoint(work);
            local entry=table.remove(pending); local key=entry.id
            if not protected[key] then
                protected[key]=true; reasons[key]=entry.reason or {kind="linked"}
                local r=c.records[key]; local children={}
                local function add(child,why) children[#children+1]={id=child,reason=why}end
                if r then dependencies(c,r,add,state)end
                -- Preserve depth-first source ordering without consuming the Lua call stack.
                for index=#children,1,-1 do _auctionTick(); checkpoint(work); pending[#pending+1]=children[index]end
            end
        end
    end
    for id,r in pairs(c.records) do _auctionTick(); checkpoint(work); if r.starred then visit(id,{kind="starred"}) end end
    for id,r in pairs(c.records)do _auctionTick(); checkpoint(work); if (r.kind=="diary"or r.kind=="recap")and r.inProgress then visit(id,{kind="active"})end end
    -- Live collector state must not be invalidated by cleanup.
    for _,id in pairs(c.state.activeQuests or {}) do _auctionTick(); checkpoint(work); visit(id,{kind="active"}) end
    if c.state.activeEncounter then visit(c.state.activeEncounter,{kind="active"})end
    for id in pairs(c.state.activePullRecords or{})do _auctionTick(); checkpoint(work); visit(id,{kind="active"})end
    for _,key in ipairs({"group","activeLootWindow","activeTrade","activeMailbox","activeMailCollection","activeMailDraft","play","walletWindow"})do _auctionTick(); checkpoint(work); if c.state[key] then visit(c.state[key],{kind="active"})end end
    for id,r in pairs(c.records)do _auctionTick(); checkpoint(work); if r.kind=="screenshot" and r.status=="pending" then visit(id,{kind="active"})end end
    local merchant=E.Merchant
    if c.state.inventory then
        if c.state.inventory.record then visit(c.state.inventory.record,{kind="active"})end
        if c.state.inventory.gap then visit(c.state.inventory.gap,{kind="active"})end
    end
    if merchant and merchant.owner==c and merchant.pending then
        visit(merchant.pending.id,{kind="active"})
        for _,r in ipairs(merchant.wallets or {})do _auctionTick(); checkpoint(work); visit(r.id,{kind="active"})end
    end
    if E.Economy and E.Economy.RetentionRoots then
        for id in pairs(E.Economy.RetentionRoots(c,work))do _auctionTick(); checkpoint(work); visit(id,{kind="accounting"})end
    end
    for _,pending in pairs(c.state.progress and c.state.progress.pending or {}) do _auctionTick(); checkpoint(work);
        for _,ref in ipairs(pending.context and pending.context.refs or {}) do _auctionTick(); checkpoint(work); visit(ref) end
        for _,observation in ipairs(pending.notifications or {}) do _auctionTick(); checkpoint(work); if observation.group then visit(observation.group) end end
    end
    return protected,reasons
end
function S.PreviewExpiry(c, now, work)
    -- The default Forever policy cannot expire anything. Do not build protection
    -- graphs or enumerate an unlimited scrapbook merely to prove that again.
    local finite=false
    for _,days in pairs(c.retention)do _auctionTick(); checkpoint(work);
        if type(days)=="number"and days>0 and days<math.huge then finite=true;break end
    end
    if not finite then
        return {character=c.id,ids={},aged={},reasons={},count=0,revision=c.revision,at=now,policies=copy(c.retention,work),
            noteIDs={},noteAged={},noteReasons={},noteValues={},noteCount=0}
    end
    local keep,reasons = S.Protected(c,work); local expired,aged = {},{}; local count = 0
    for id,r in pairs(c.records) do _auctionTick(); checkpoint(work);
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
        for id in pairs(c.records)do _auctionTick(); checkpoint(work); if not expired[id]then retain(id)end end
        local cursor=1
        while count>0 and cursor<=#pending do _auctionTick(); checkpoint(work);
            local r=c.records[pending[cursor]];cursor=cursor+1
            dependencies(c,r,function(id,reason)
                if reason.kind=="linked"then reason.kind="retainedReference"end
                retain(id,reason)
            end,state)
        end
    end
    local noteIDs,noteAged,noteReasons,noteValues={}, {},{},{};local noteCount=0
    local noteSources={}
    for id,r in pairs(c.records)do _auctionTick(); checkpoint(work);
        if r.kind=='diary'and type(r.day)=='string'then noteSources['day:'..r.day]=id end
        if r.kind=='recap'and type(r.key)=='string'then noteSources['recap:'..r.key]=id end
    end
    for key,note in pairs(c.notes)do _auctionTick(); checkpoint(work); if type(key)=='string'and type(note)=='table'then
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
    local out={};for key,value in pairs(values or{})do _auctionTick(); checkpoint(work);out[key]=value end;return out
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
    for key in pairs(preview.noteIDs)do _auctionTick(); checkpoint(work)
        local note=c.notes[key];removed(S.NoteCategory(c,key),note.updated,note.updated);p.notes[key]=nil
    end
    local copied={};local deletedDedup={}
    if next(preview.ids)then
        p.records={};p.order={};p.dedup={}
        p.craftSeed={ids={},slots={},generation=0}
        for id,r in pairs(c.records)do _auctionTick(); checkpoint(work)
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
        for _,id in ipairs(c.order)do _auctionTick(); checkpoint(work);if p.records[id]then p.order[#p.order+1]=id end end
        for key,id in pairs(c.dedup)do _auctionTick(); checkpoint(work);if not deletedDedup[key]then p.dedup[key]=id end end
    end
    return p
end
-- These record kinds cannot be trade/mail/gathering evidence. Older callers
-- without a typed batch still take the conservative reconciliation path.
function S.JournalOnlyRemoval(batch)
    if type(batch)~='table'or type(batch.kinds)~='table'then return false end
    for kind in pairs(batch.kinds)do _auctionTick();
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
    local same=work and function(a,b)return E.RetentionWork.Same(a,b,work)end or _auctionSame
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
        removedRanges=p.ranges,reviewedAt=preview.at,policies=_auctionCopy(preview.policies)})end
    return p.removed
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="Store",create=create}
E.AuctionReaderSources["Store.lua"]="e6935f03cd894eddab0b70106f7cb140ac65567003471ef79544194ec3ded943"
end

-- Query.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Query';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local Q,S={},E.Store; E.Query=Q
local indexes=setmetatable({},{__mode="k"})
local prepared=setmetatable({},{__mode="k"})
local warming=setmetatable({},{__mode="k"})
local warmQueue,warmHead,warmTail={},1,0
Q.DailySourceKinds={quest=true,milestone=true,crafted=true,gathered=true,loot=true,group=true,death=true,spell=true,encounter=true}
Q.RecapExtraKinds={death=true,gold=true,damage=true,health=true,auction=true,xp=true,travel=true,duel=true,battleground=true,roll_win=true,loot=true,quest=true}
function Q.AuctionOutcome(r)
    local id=r.auctionID
    if r.kind~='auction'or type(id)~='number'or id<1 or id>9007199254740991 or id%1~=0 then return end
    if r.source=='purchase'then return 'auctionsBought' end
    if r.source=='owned'and r.auctionData and r.auctionData.statusLabel=='Reported sold'then return 'auctionsSold'end
end
function Q.MilestoneFamily(r)
    return (r.milestoneType or "")..":"..tostring(r.skillID or "")
end
local function chronological(a,b)
    local at,bt=S.Timestamp(a),S.Timestamp(b)
    if at~=bt then return at~=nil and (bt==nil or at<bt) end
    local left,right=S.Sequence(a),S.Sequence(b)
    if left~=right then return left<right end
    -- Linked records may share one observation sequence. Keep their canonical
    -- creation order stable when unrelated record kinds are excluded.
    left,right=a.sequence or 0,b.sequence or 0
    if left~=right then return left<right end
    return a.id<b.id
end
local function lowerBound(keys,value)
    local lo,hi=1,#keys+1
    while lo<hi do _auctionTick(); local mid=math.floor((lo+hi)/2);if keys[mid]<value then lo=mid+1 else hi=mid end end
    return lo
end
local killBlockSize=256
local function newBucket(index,buckets,keys,key)
    local rows=buckets[key]
    if not rows then
        rows={};buckets[key]=rows
        if index.building then keys[#keys+1]=key
        else table.insert(keys,lowerBound(keys,key),key)end
    end
    return rows
end
local function remember(groups,key,id)
    local log=groups[key]
    if not log then log={ids={},seen={}};groups[key]=log end
    if not log.seen[id]then log.seen[id]=true;log.ids[#log.ids+1]=id end
end
function Q.LootWindowKey(r)
    if r.kind=='loot_window'then return r.id end
    if r.kind=='drop'and r.source=='loot_window'then return r.window end
    if r.kind=='loot'or r.kind=='crafted'or r.kind=='gathered'then
        -- An older inferred receipt may have lost its window association. Give
        -- it its own review bucket so startup can restore its original kind.
        return r.observedLootWindow or(r.gatheringOriginal and r.id)
    end
end
local function depositBucket(window,amount,bucket)
    if type(window)=='string' and type(amount)=='number' and amount<0 then
        return window..'|'..tostring(amount)..'|'..tostring(bucket)
    end
end
local function companyCounter(kind,completed)
    if kind=="quest" and completed then return "quests" end
    if kind=="loot" or kind=="drop" then return "loot" end
    if kind=="pull" then return "pulls" end
end
local function countCompany(index,id,field,delta)
    if not field then return end
    local counts=index.companyTotals[id] or {};index.companyTotals[id]=counts
    counts[field]=(counts[field] or 0)+delta
end
-- A dated range is also used to prove that a wallet match or an acquisition
-- has no rival. Publishing a partial financial directory could invent one.
local costSources={loot=true,crafted=true,gathered=true,craft_request=true,craft_begin=true,craft_result=true}
local function needsFinancialClock(kind)
    return S.categories[kind]=="gold" or costSources[kind]
end
local function clockIssue(id)
    return "A financial source has an unreadable date ("..id.."). Its original record is preserved; dated matches cannot be checked."
end
local function indexRecord(index,r,work,detail)
    local stamp=S.Timestamp(r)
    if not stamp and needsFinancialClock(r.kind) then
        index.clockFaultID=r.id;error(clockIssue(r.id))
    end
    local old=index.locations[r.id]
    local keeper=rawget(E,"CalendarView")
    local watch=keeper and (r.kind=="group" or r.kind=="quest_attempt")
    local previous=old and index.kinds[old.kind] and index.kinds[old.kind][r.id]
    local playExtension=keeper and r.kind=="play" and previous==r and old.kind=="play" and old.calendarStamp==stamp
        and old.calendarStatus==r.status and type(r.ended)=="number" and type(old.calendarEnd)=="number" and r.ended>=old.calendarEnd
    local stable=watch and previous==r and old.kind==r.kind and old.calendarStamp==stamp
        and old.calendarSequence==S.Sequence(r) and old.calendarTie==r.sequence and old.calendarOwner==r.character
        and old.calendarGroup==r.group and old.calendarGroupState==r.groupState
    if S.CraftRequestSource(r) or index.craftFrontier.members[r.id] then
        S.IndexCraftRequest(index.craftFrontier,r.id,S.CraftRequestSource(r) and r or nil)
    end
    -- An append-only ID directory lets a visible picker hold a finite cut while
    -- live events append newer screenshots. Reclassified IDs are checked against
    -- the canonical row. Cleanup replaces the directory along with the index.
    local screenshotIndexed=old and old.screenshotIndexed
    if r.kind=="screenshot" and not screenshotIndexed and rawget(E,"ScreenshotPages") then
        index.screenshotIDs=index.screenshotIDs or {}
        index.screenshotIDs[#index.screenshotIDs+1]=r.id
        screenshotIndexed=true
    end
    local chatSlot=old and old.chatSlot
    if chatSlot then
        local oldGroup=next(old.groups)
        if r.kind~="chat" or r.group~=oldGroup then
            local log=index.chatLogs[oldGroup]
            local last=#log
            if chatSlot<last then
                local moved=log[last]
                log[chatSlot]=moved
                index.locations[moved].chatSlot=chatSlot
            end
            log[last]=nil
            log.generation=(log.generation or 0)+1
            if last==1 then index.chatLogs[oldGroup]=nil end
            chatSlot=nil
        end
    end
    if old then
        if old.killBlock then index.killBlocks[old.killBlock][r.id]=nil end
        if old.creditAttempt then
            local links=index.creditsByAttempt[old.creditAttempt];links[r.id]=nil
            if not next(links) then index.creditsByAttempt[old.creditAttempt]=nil end
        end
        if old.auction then local group=index.auctionOutcomes[old.auction];group.records[r.id]=nil;group.first=nil end
        if old.bucket then index.days[old.bucket][old.kind][r.id]=nil end
        index.kinds[old.kind][r.id]=nil
        if old.major then old.major.records[r.id]=nil;old.major.ordered=nil end
        if old.window then index.windows[old.window][r.id]=nil end
        for id in pairs(old.groups or{})do _auctionTick();
            if index.companyTotals then countCompany(index,id,old.companyCounter,-1) end
            index.groups[id][r.id]=nil
            if not next(index.groups[id])then index.groups[id]=nil end
        end
        for _,id in ipairs(old.actionRefs or{})do _auctionTick(); index.actionWindows[id][r.id]=nil end
    end
    -- A saved row may lack a usable clock. Keep its identity and links in
    -- non-date directories without assigning it a day or money-match window.
    local bucket=stamp and math.floor(stamp/86400)
    if bucket then
        local kinds=newBucket(index,index.days,index.dayKeys,bucket);kinds[r.kind]=kinds[r.kind]or{};kinds[r.kind][r.id]=r
    end
    -- Preserve stable finite cuts for a Calendar reader while unrelated new
    -- records append. A correction that moves a slot invalidates that reader.
    local calendarSlot=old and old.calendarSlot
    local calendarBucket
    if rawget(E,"CalendarView") then
        local calendarTime=E.CalendarView.IndexStamp(r)
        local day=calendarTime and E.CalendarView.IndexKind(r.kind) and math.floor(calendarTime/86400)
        calendarBucket=day or nil
        local priorDay=old and (old.calendarBucket or old.bucket)
        if calendarSlot and priorDay~=day then
            local prior=index.calendarDays[priorDay]
            local moved=prior[#prior];prior[calendarSlot]=moved;prior[#prior]=nil
            index.locations[moved].calendarSlot=calendarSlot
            if #prior==0 then index.calendarDays[priorDay]=nil end
            calendarSlot=nil
        end
        if day and not calendarSlot then
            index.calendarDays=index.calendarDays or {}
            local rows=index.calendarDays[day] or {};index.calendarDays[day]=rows
            calendarSlot=#rows+1;rows[calendarSlot]=r.id
        end
    end
    local killBlock,creditAttempt
    if r.kind=='kill' then
        local seq=S.QuestSequence(r)
        if seq then
            killBlock=math.floor(seq/killBlockSize)
            newBucket(index,index.killBlocks,index.killBlockKeys,killBlock)[r.id]=r
        end
    elseif r.kind=='credit' and type(r.attempt)=='string' then
        creditAttempt=r.attempt
        local links=index.creditsByAttempt[creditAttempt] or {};index.creditsByAttempt[creditAttempt]=links;links[r.id]=r
    end
    index.kinds[r.kind]=index.kinds[r.kind] or {}; index.kinds[r.kind][r.id]=r
    -- Append-only source directories permit bounded capture while normal
    -- recording mutates the lookup maps. Old memberships are skipped on read.
    if bucket and (Q.DailySourceKinds[r.kind] or Q.RecapExtraKinds[r.kind]) then
        index.dayLogs[bucket]=index.dayLogs[bucket]or{}
        remember(index.dayLogs[bucket],r.kind,r.id)
    elseif r.kind=='play'then remember(index.playLog,'play',r.id)end
    if r.kind=='gold'then remember(index.walletLog,'gold',r.id)end
    if (r.kind=='money_evidence' or r.kind=='gold') and r.source=='auctionDeposit' then remember(index.depositSubjects,'rows',r.id) end
    if r.kind=='money_evidence' and r.source=='auctionDeposit' and type(r.auctionID)=='number' then
        remember(index.depositListings,r.auctionID,r.id)
    end
    if stamp and r.kind=='gold' then
        local key=depositBucket(r.window,r.amount,math.floor(stamp/5))
        if key then
            local group=index.depositWallets[key]
            if not group then index.depositWallets[key]=r.id
            elseif type(group)=='table' then remember(index.depositWallets,key,r.id)
            elseif group~=r.id then
                index.depositWallets[key]={ids={group,r.id},seen={[group]=true,[r.id]=true}}
            end
        end
    end
    local major
    if r.kind=="milestone" and r.major==true and r.subject then
        local subjects=index.majorFamilies
        subjects[r.subject]=subjects[r.subject]or{}
        local families=subjects[r.subject];local family=Q.MilestoneFamily(r)
        major=families[family]
        if not major then major={records={}};families[family]=major end
        major.records[r.id]=r;major.ordered=nil
    end
    local window=Q.LootWindowKey(r)
    if window then
        if not index.windows[window]then index.windows[window]={};index.windowKeys[#index.windowKeys+1]=window end
        index.windows[window][r.id]=r
    end
    local actionRefs
    if r.kind=='loot_window'then actionRefs={};for _,id in ipairs(r.gatherActions or{})do _auctionTick();
        index.actionWindows[id]=index.actionWindows[id]or{};index.actionWindows[id][r.id]=true
        actionRefs[#actionRefs+1]=id
    end end
    local groups=r.group and{[r.group]=true}or nil
    if r.kind=="encounter_loot" or r.kind=="quest_reward" or r.kind=="gold" and r.observerGroupState then
        groups=r.observerGroupState=="group" and type(r.observerGroup)=="string" and {[r.observerGroup]=true} or nil
    end
    if r.kind=='pull'then for id,observed in pairs(r.observedGroups or{})do _auctionTick(); if observed==true then
        groups=groups or{};groups[id]=true
    end end end
    local counted
    if groups and rawget(E,"History") then
        index.companyTotals=index.companyTotals or {}
        counted=companyCounter(r.kind,r.status=="completed")
        if r.kind=="chat" and not chatSlot then
            index.chatLogs=index.chatLogs or {}
            local log=index.chatLogs[r.group] or {};index.chatLogs[r.group]=log
            chatSlot=#log+1;log[chatSlot]=r.id
        end
    end
    for id in pairs(groups or{})do _auctionTick();
        index.groups[id]=index.groups[id]or{};index.groups[id][r.id]=r
        if counted then countCompany(index,id,counted,1) end
    end
    local outcome=Q.AuctionOutcome(r);local auction=outcome and(outcome..':'..r.auctionID)
    if auction then
        local group=index.auctionOutcomes[auction]or{records={}};index.auctionOutcomes[auction]=group
        group.records[r.id]=r;group.first=nil
    end
    local encounterLoot
    if (r.kind=="encounter_loot" or old and old.encounterLoot) and rawget(E,"EncounterLoot") then
        encounterLoot=E.EncounterLoot.Index(index,r,old and old.encounterLoot)
    end
    local reward
    if (r.kind=="quest_reward" or old and old.reward) and rawget(E,"QuestRewards") then
        reward=E.QuestRewards.Index(index,r,old and old.reward)
    end
    index.locations[r.id]={calendarSlot=calendarSlot,calendarBucket=calendarBucket,screenshotIndexed=screenshotIndexed,encounterLoot=encounterLoot,reward=reward,bucket=bucket,kind=r.kind,previousKind=old and old.kind,major=major,window=window,previousWindow=old and old.window,actionRefs=actionRefs,groups=groups,auction=auction,companyCounter=counted,chatSlot=chatSlot,killBlock=killBlock,creditAttempt=creditAttempt,
        unanchoredOffer=r.kind=='trade_offer' and r.inventoryAnchor==nil or nil}
    if watch then
        local token=index.locations[r.id]
        token.calendarStamp=stamp;token.calendarSequence=S.Sequence(r);token.calendarTie=r.sequence
        token.calendarOwner=r.character;token.calendarGroup=r.group;token.calendarGroupState=r.groupState
    end
    if keeper and r.kind=="play" then
        local token=index.locations[r.id]
        token.calendarStamp=stamp;token.calendarStatus=r.status;token.calendarEnd=r.ended
    end
    if keeper and not work and not index.building then
        index.calendarChange={record=r,before=old and (old.calendarBucket or old.bucket),after=calendarBucket or bucket,prior=old and old.kind,stable=stable,playExtension=playExtension}
    end
    -- Private financial projections need no Calendar directory.
    if (r.kind=="group" or old and old.kind=="group") and rawget(E,"History") then
        E.History.IndexRosterDays(index,r,detail,work)
    end
end
local function newIndex()
    return {craftFrontier=S.NewCraftFrontier(),days={},dayKeys={},killBlocks={},killBlockKeys={},creditsByAttempt={},kinds={},locations={},majorFamilies={},dayLogs={},playLog={},walletLog={gold={ids={},seen={}}},depositSubjects={rows={ids={},seen={}}},depositWallets={},depositListings={},windows={},windowKeys={},actionWindows={},groups={},auctionOutcomes={},building=true}
end
local function build(records,work)
    local i=newIndex()
    for id,r in pairs(records)do _auctionTick(); if work then work()end;indexRecord(i,r,work)
        if id~=r.id and S.CraftRequestSource(r)then S.IndexCraftRequest(i.craftFrontier,id,r)end
    end
    E.RetentionWork.Sort(i.dayKeys,function(a,b)return a<b end,work)
    E.RetentionWork.Sort(i.killBlockKeys,function(a,b)return a<b end,work)
    S.PrepareCraftFrontier(i.craftFrontier,work)
    i.building=nil;return i
end
function Q.WarmSnapshot(c,work)
    assert(not E.db or E.db.characters[c.id]~=c,'Only a private snapshot may be warmed cooperatively')
    indexes[c]=build(c.records,work)
end
-- The Store's append-only canonical order is stable while observations arrive.
-- Retention replaces that order and cancels preparation; no partial index leaks.
function Q.IsWarm(c)return indexes[c]~=nil end
function Q.Preparation(c)return warming[c]end
function Q.DepositSubjects(c)
    return indexes[c] and indexes[c].depositSubjects.rows.ids
end
function Q.DepositListingProofs(c,auctionID)
    local log=indexes[c] and indexes[c].depositListings[auctionID]
    return log and log.ids
end
function Q.DepositWallets(c,window,amount,bucket)
    local index=indexes[c]
    local key=depositBucket(window,amount,bucket)
    local log=index and key and index.depositWallets[key]
    return type(log)=='table' and log.ids or log
end
function Q.WalletKeys(c)return indexes[c]and indexes[c].walletLog.gold.ids end
-- Kind captured by the last index update, usable before RECORD_CHANGED dispatch.
function Q.RecordedKind(c,id)local r=indexes[c]and indexes[c].locations[id];return r and r.kind end
function Q.RecordedUnanchoredOffer(c,id)local r=indexes[c]and indexes[c].locations[id];return r and r.unanchoredOffer end
function Q.PreviousKind(c,id)local r=indexes[c]and indexes[c].locations[id];return r and r.previousKind end
function Q.LootWindowRows(c,key)
    local cached=indexes[c];if not cached then return end
    local out={};for id,r in pairs(cached.windows[key]or{})do _auctionTick(); if c.records[id]==r and Q.LootWindowKey(r)==key then out[#out+1]=r end end;return out
end
function Q.GatherActionWindows(c,id)
    local cached=indexes[c];if not cached then return end
    local out={};for key in pairs(cached.actionWindows[id]or{})do _auctionTick(); out[#out+1]=key end;return out
end
function Q.LootWindowKeys(c)return indexes[c]and indexes[c].windowKeys end
function Q.PreviousLootWindow(c,id)
    local row=indexes[c]and indexes[c].locations[id];return row and row.previousWindow
end
local function warmValid(state)
    local c=state.owner
    return not state.cancelled and E.db.characters[c.id]==c and c.records==state.records and c.order==state.order
end
local function enqueue(state)
    warmTail=warmTail+1;warmQueue[warmTail]=state
end
local function startWarm(c)
    local state={owner=c,records=c.records,order=c.order,last=#c.order,index=newIndex(),status='preparing',scanned=0}
    state.worker=E.RetentionWork.Start(function(work)
        for n=1,state.last do _auctionTick();
            work();local r=c.records[state.order[n]]
            if r then indexRecord(state.index,r,work)end
            state.scanned=n
        end
        local seed=S.CraftSeed(c)
        if seed then
            repeat _auctionTick();
                local generation=seed.generation
                for n=1,#seed.ids do _auctionTick(); work()
                    local id=seed.ids[n];local r=c.records[id]
                    if r and S.CraftRequestSource(r) then S.IndexCraftRequest(state.index.craftFrontier,id,r)end
                end
                local stable=generation==seed.generation
            until stable
        end
        -- Live writes may append a day or a kill block while sorting yields.
        local function sortedCopy(keys)
            local sorted={}
            for n=1,#keys do _auctionTick(); work();sorted[n]=keys[n]end
            E.RetentionWork.Sort(sorted,function(a,b)return a<b end,work)
            return sorted
        end
        while true do _auctionTick();
            local i=state.index
            local days=sortedCopy(i.dayKeys)
            local blocks=sortedCopy(i.killBlockKeys)
            if #days==#i.dayKeys and #blocks==#i.killBlockKeys then
                i.dayKeys=days;i.killBlockKeys=blocks;break
            end
        end
        S.PrepareCraftFrontier(state.index.craftFrontier,work)
        state.index.building=nil;return state.index
    end)
    if not state.worker then state.status='failed';state.error='Background preparation is unavailable.'end
    warming[c]=state;return state
end
local function stepWarm(state,budget)
    if indexes[state.owner]then state.status='ready';state.worker=nil;state.index=nil;return end
    if not warmValid(state)then state.status='cancelled';state.cancelled=true;state.worker=nil;state.index=nil;return end
    if state.status~='preparing'then return end
    local result,value=E.RetentionWork.Step(state.worker,budget)
    if result=='failed'then
        state.status='failed';state.clockFaultID=state.index.clockFaultID
        state.error=state.clockFaultID and clockIssue(state.clockFaultID) or 'The history could not be prepared. Your saved records are unchanged.'
        state.worker=nil;state.index=nil
    elseif result=='done'then
        indexes[state.owner]=value;state.status='ready';state.worker=nil;state.index=nil
    end
end
function Q.EnsureWarm(c)
    if indexes[c]then return 'ready'end
    local state=warming[c]
    if state and not warmValid(state)then state.cancelled=true;state.worker=nil;warming[c]=nil;state=nil end
    if not state then
        if not E.db or E.db.characters[c.id]~=c then return 'unavailable'end
        state=startWarm(c)
        -- A small book opens immediately, with a fixed checkpoint allowance.
        stepWarm(state,64)
        if state.status=='preparing'then enqueue(state)end
    end
    return state.status,state.error
end
function Q.RetryWarm(c)
    local state=warming[c];if state then state.cancelled=true;state.worker=nil end
    warming[c]=nil;return Q.EnsureWarm(c)
end
function Q.ProcessPreparation(budget)
    local state=warmQueue[warmHead];if not state then return end
    warmQueue[warmHead]=nil;warmHead=warmHead+1
    if warmHead>warmTail then warmQueue={};warmHead,warmTail=1,0 end
    if warming[state.owner]==state then stepWarm(state,budget)end
    if state.status=='preparing'and not state.cancelled then enqueue(state)end
end
function Q.EachSummarySource(c,from,through,kinds,visit,work)
    local cached=indexes[c]
    local function read(id,bucket,kind)
        local r=c.records[id]
        if r and S.Timestamp(r) and (not kind or r.kind==kind) and (not bucket or math.floor(r.ts/86400)==bucket)then
            if r.kind=='play'and r.ended>from and r.ts<through
                or kinds[r.kind]and r.ts>=from and r.ts<through then visit(r)end
        end
    end
    if not cached then
        -- Cold capture avoids synchronously building a lifetime query index.
        local order,last=c.order,#c.order
        for n=1,last do _auctionTick(); work();read(order[n])end
        return
    end
    for bucket=math.floor(from/86400),math.floor(through/86400)do _auctionTick();
        work();local groups=cached.dayLogs[bucket]
        if groups then for kind,enabled in pairs(kinds)do _auctionTick(); if enabled then
            local log=groups[kind];local last=log and #log.ids or 0
            for n=1,last do _auctionTick(); work();read(log.ids[n],bucket,kind)end
        end end end
    end
    local log=cached.playLog.play;local last=log and #log.ids or 0
    for n=1,last do _auctionTick(); work();read(log.ids[n],nil,'play')end
end
local function index(c)
    local state=warming[c]
    if state and state.clockFaultID and warmValid(state) then error(state.error) end
    if not indexes[c]then indexes[c]=build(c.records)end
    return indexes[c]
end
function Q.CalendarBefore(a,b)
    local left,right=E.CalendarView.IndexStamp(a),E.CalendarView.IndexStamp(b)
    if left~=right then return left<right end
    return chronological(a,b)
end
function Q.CalendarChange(c,r)
    local i=indexes[c];local change=i and i.calendarChange
    return change and change.record==r and change
end
function Q.CalendarCut(c,from,through)
    local i=indexes[c];if not i then return end
    local cut={}
    for bucket=math.floor(from/86400),math.ceil(through/86400)-1 do _auctionTick();
        local ids=i.calendarDays and i.calendarDays[bucket]
        if ids then cut[#cut+1]={ids=ids,last=#ids}end
    end
    return cut
end
function Q.CalendarRange(c,from,through,cut,work)
    local out,ordered={},true
    for _,part in ipairs(cut)do _auctionTick(); for n=1,part.last do _auctionTick();
        if work then work()end;local r=c.records[part.ids[n]];local stamp=r and E.CalendarView.IndexStamp(r)
        if stamp and stamp>=from and stamp<through then
            if ordered and #out>0 and Q.CalendarBefore(r,out[#out])then ordered=false end
            out[#out+1]=r
        end
    end end
    if not ordered then E.RetentionWork.Sort(out,Q.CalendarBefore,work)end
    return out
end
function Q.RosterDay(c,from,through,work)
    return E.History.RosterDay(index(c),c,from,through,work)
end
function Q.FirstAuctionOutcome(c,r,work)
    local outcome=Q.AuctionOutcome(r);if not outcome then return false end
    local group=index(c).auctionOutcomes[outcome..':'..r.auctionID]
    if not group then return false end
    if not group.first then
        local first
        for _,row in pairs(group.records)do _auctionTick();
            if work then work()end
            if not first or chronological(row,first)then first=row end
        end
        group.first=first
    end
    return group.first and group.first.id==r.id or false
end
-- Retention already stages canonical survivors. Prepare a replacement for a
-- warm query cache before its atomic publication, without exposing partial data.
-- The opaque token is transient, owner/revision-bound, and accepted only once.
function Q.PrepareExpiry(c,records,work)
    local existing=indexes[c];if not existing then return end
    local revision=c.revision
    local replacement=records==c.records and existing or build(records,work)
    local token={};prepared[token]={owner=c,records=records,revision=revision,index=replacement}
    return token
end

local function changed(c,r,_,receipt)
    local prior=warming[c]
    if needsFinancialClock(r.kind) and not S.Timestamp(r) then
        if c.records[r.id]~=r then return end
        if prior then prior.cancelled=true;prior.worker=nil;prior.index=nil end
        indexes[c]=nil
        warming[c]={owner=c,records=c.records,order=c.order,status="failed",clockFaultID=r.id,error=clockIssue(r.id)}
        return
    elseif prior and prior.clockFaultID==r.id and c.records[r.id]==r then
        prior.cancelled=true;warming[c]=nil
    end
    local detail=type(receipt)=="table" and receipt.character==c and receipt.revision==c.revision and receipt.detail
    if type(detail)~="table" or detail.operation~="change" or detail.record~=r then detail=nil end
    if indexes[c]then indexRecord(indexes[c],r,nil,detail)end
    local state=warming[c]
    if state and state.status=='preparing'and warmValid(state)then indexRecord(state.index,r,nil,detail)end
end
E.On("RECORD_ADDED",changed)
E.On("RECORD_CHANGED",changed)
E.On("RECORDS_REMOVED",function(c,ids,batch)
    local state=warming[c];if state then state.cancelled=true;state.worker=nil;warming[c]=nil end
    local token=type(batch)=="table"and batch.queryIndex
    local candidate=token and prepared[token]
    if token then prepared[token]=nil end
    if candidate and candidate.owner==c and candidate.records==c.records and c.revision==candidate.revision+1 then
        indexes[c]=candidate.index
    else indexes[c]=nil end
end)
function Q.CraftPredecessors(c,request,throughSequence,work)
    return S.CraftPredecessors(index(c).craftFrontier,request,work,throughSequence)
end
function Q.EncounterLootDirectory(c)
    local i=indexes[c]
    return i and i.encounterLoot
end
function Q.QuestRewardDirectory(c)
    local i=indexes[c]
    return i and i.questRewards
end
local noScreenshots={}
function Q.WarmScreenshotIDs(c)
    local i=indexes[c]
    if i then return i.screenshotIDs or noScreenshots end
end
function Q.Kind(c,kind)
    local out={}; for _,r in pairs(index(c).kinds[kind] or {}) do _auctionTick(); out[#out+1]=r end
    _auctionSort(out,chronological); return out
end
function Q.CreditedKills(c,attempts)
    local rows,seen,missing={},{},0
    if not next(attempts) then return rows,missing end
    local links=index(c).creditsByAttempt
    for attempt in pairs(attempts) do _auctionTick();
        for _,credit in pairs(links[attempt] or {}) do _auctionTick();
            local id=credit.kill
            if credit.character==c.id and credit.kind=='credit' and credit.attempt==attempt and c.records[credit.id]==credit
                and type(id)=='string' and not seen[id] then
                seen[id]=true
                local r=c.records[id]
                if r and r.id==id and r.kind=='kill' and r.character==c.id then rows[#rows+1]=r
                else missing=missing+1 end
            end
        end
    end
    _auctionSort(rows,chronological)
    return rows,missing
end
-- The caller merges intervals on each axis. Read each intersecting block
-- once even when several short attempts occurred on the same day.
function Q.KillsInIntervals(c,intervals,inside)
    local rows,seen={},{}
    if #intervals.sequence==0 and #intervals.timestamp==0 then return rows end
    local i=index(c)
    local function collect(axis,keys,buckets,width)
        local lastKey
        for _,span in ipairs(intervals[axis]) do _auctionTick();
            local pos=lowerBound(keys,math.floor(span.from/width))
            local stop=math.floor(span.through/width)
            while keys[pos] and keys[pos]<=stop do _auctionTick();
                local key=keys[pos]
                if key~=lastKey then
                    local records=buckets[key]
                    if axis=='timestamp' then records=records.kill end
                    for id,r in pairs(records or {}) do _auctionTick();
                        if not seen[id] and r.kind=='kill' and r.character==c.id and c.records[id]==r and inside(r,axis) then
                            seen[id]=true;rows[#rows+1]=r
                        end
                    end
                    lastKey=key
                end
                pos=pos+1
            end
        end
    end
    collect('sequence',i.killBlockKeys,i.killBlocks,killBlockSize)
    collect('timestamp',i.dayKeys,i.days,86400)
    _auctionSort(rows,chronological)
    return rows
end
function Q.UnreadRecapCount(c)
    local recaps = index(c).kinds.recap
    if not recaps then return 0 end
    local count = 0
    for _, recap in pairs(recaps) do _auctionTick();
        if not recap.read and E.Diary.Visible(c,recap) then count = count + 1 end
    end
    return count
end
-- Unordered canonical references. Include a pull's additional observed groups
-- only for session reports; companion presence still requires its direct group.
function Q.ChatDirectory(c,id)
    local i=indexes[c]
    return i and i.chatLogs and i.chatLogs[id],
        i and i.companyTotals and i.companyTotals[id]
end
local function observedWithGroup(c,id,r)
    local g=c.records[id]
    return g and g.id==id and g.kind=="group" and g.character==c.id and r.observerGroup==id and r.observerGroupState=="group"
end
function Q.GroupWalletObservation(c,id,r)
    if r.kind~="gold" or r.character~=c.id or E.db.characters[c.id]~=c or c.records[r.id]~=r or not observedWithGroup(c,id,r) then return false end
    return type(r.amount)=="number" and r.amount%1==0 and r.amount~=0 and math.abs(r.amount)<=9007199254740991
end
function Q.GroupLootNotice(c,id,r)
    if not observedWithGroup(c,id,r) then return false end
    if r.kind=="encounter_loot" then return E.EncounterLoot.Valid(c,r) end
    return r.kind=="quest_reward" and E.QuestRewards.Valid(c,r)
end
function Q.Group(c,id,includeObserved)
    local out={}
    for _,r in pairs(index(c).groups[id]or{})do _auctionTick();
        if r.kind=="encounter_loot" or r.kind=="quest_reward" then
            if includeObserved and Q.GroupLootNotice(c,id,r) then out[#out+1]=r end
        elseif r.kind=="gold" and r.observerGroupState then
            if includeObserved and Q.GroupWalletObservation(c,id,r) then out[#out+1]=r end
        elseif r.group==id or includeObserved and r.kind=='pull'and r.observedGroups and r.observedGroups[id]==true then out[#out+1]=r end
    end
    return out
end
local function range(c,from,through,kind,selected,work)
    local out={};if from>=through then return out end
    local first,last=math.floor(from/86400),math.floor(through/86400);local i=index(c)
    local position=lowerBound(i.dayKeys,first)
    while position<=#i.dayKeys and i.dayKeys[position]<=last do _auctionTick();
        if work then work()end
        local kinds=i.days[i.dayKeys[position]]
        if kind then
            for _,r in pairs(kinds[kind]or{})do _auctionTick(); if r.ts>=from and r.ts<through then out[#out+1]=r end end
        elseif selected then
            for wanted,enabled in pairs(selected)do _auctionTick(); if enabled then
                for _,r in pairs(kinds[wanted]or{})do _auctionTick(); if work then work()end;if r.ts>=from and r.ts<through then out[#out+1]=r end end
            end end
        else
            for _,records in pairs(kinds)do _auctionTick(); for _,r in pairs(records)do _auctionTick(); if r.ts>=from and r.ts<through then out[#out+1]=r end end end
        end
        position=position+1
    end
    E.RetentionWork.Sort(out,chronological,work); return out
end
function Q.Range(c,from,through,kind)return range(c,from,through,kind)end
-- Select canonical kind buckets before copying/sorting records. An empty set
-- means no kinds; nil is not a request to broaden a summary's source scope.
function Q.RangeKinds(c,from,through,kinds,work)
    assert(type(kinds)=="table","A record-kind set is required")
    if not next(kinds)then return {}end
    return range(c,from,through,nil,kinds,work)
end
local function union(intervals,work)
    E.RetentionWork.Sort(intervals,function(a,b) return a[1]<b[1] end,work)
    local out={}
    for _,i in ipairs(intervals) do _auctionTick();
        if work then work()end
        local last=out[#out]
        if last and i[1]<=last[2] then last[2]=math.max(last[2],i[2]) else out[#out+1]={i[1],i[2]} end
    end
    return out
end
local function measure(intervals,excluded,work)
    local total,j=0,1; excluded=excluded or {}
    for _,i in ipairs(intervals) do _auctionTick();
        if work then work()end
        local duration=i[2]-i[1]
        while excluded[j] and excluded[j][2]<=i[1] do _auctionTick(); if work then work()end;j=j+1 end
        local k=j
        while excluded[k] and excluded[k][1]<i[2] do _auctionTick();
            if work then work()end
            local cut=excluded[k]; duration=duration-math.max(0,math.min(i[2],cut[2])-math.max(i[1],cut[1])); k=k+1
        end
        total=total+math.max(0,duration)
    end
    return total
end
local function intersection(a,b,work)
    local out,i,j={},1,1
    while a[i] and b[j] do _auctionTick();
        if work then work()end
        local start,finish=math.max(a[i][1],b[j][1]),math.min(a[i][2],b[j][2])
        if finish>start then out[#out+1]={start,finish} end
        if a[i][2]<b[j][2] then i=i+1 else j=j+1 end
    end
    return out
end
-- withRecords returns a second value: chronological canonical play records
-- overlapping from/through (before any optional within-mask restriction).
-- A frozen visit horizon remains traversable while newer play intervals arrive.
-- The normal query keeps its synchronous callers' original directory semantics.
function Q.CalendarPlayCut(c)
    local i=indexes[c];local log=i and i.playLog.play
    return {ids=log and log.ids or {},last=log and #log.ids or 0}
end
function Q.TimeStats(c,from,through,within,withRecords,work,playCut)
    local records=withRecords and {}or nil
    local active,afk,unknown,known={},{},{},{}
    local sessions={}
    local function read(r)
        if work then work()end
        if S.Timestamp(r) and r.ended>from and r.ts<through then
            if records then records[#records+1]=r end
            local interval={math.max(from,r.ts),math.min(through,r.ended)}
            if r.status=="active" then active[#active+1]=interval; known[#known+1]=interval
                if withRecords and type(r.session)=='string'then sessions[r.session]=sessions[r.session]or{};sessions[r.session][#sessions[r.session]+1]=interval end
            elseif r.status=="afk" then afk[#afk+1]=interval; known[#known+1]=interval
            else unknown[#unknown+1]=interval end
        end
    end
    if playCut then
        -- Lua 5.1 cannot yield from a generic-for iterator. Keep checkpoints
        -- in this numeric traversal, including missing/reclassified IDs.
        for n=1,playCut.last do _auctionTick();
            if work then work()end
            local r=c.records[playCut.ids[n]]
            if r and r.kind=="play" then read(r)end
        end
    else
        for _,r in pairs(index(c).kinds.play or {})do _auctionTick(); read(r)end
    end
    local exclusions={}; for _,i in ipairs(afk) do _auctionTick(); if work then work()end;exclusions[#exclusions+1]=i end
    for _,i in ipairs(unknown) do _auctionTick(); if work then work()end;exclusions[#exclusions+1]=i end
    local unknownUnion,knownUnion,activeUnion,afkUnion=union(unknown,work),union(known,work),union(active,work),union(afk,work)
    if within then local allowed=union(within,work)
        unknownUnion=intersection(unknownUnion,allowed,work); knownUnion=intersection(knownUnion,allowed,work)
        activeUnion=intersection(activeUnion,allowed,work); afkUnion=intersection(afkUnion,allowed,work)
    end
    local knownSeconds=measure(knownUnion,unknownUnion,work)
    if records then E.RetentionWork.Sort(records,chronological,work)end
    local result={activeSeconds=knownSeconds>0 and measure(activeUnion,union(exclusions,work),work) or nil,
        afkSeconds=knownSeconds>0 and measure(afkUnion,unknownUnion,work) or nil,
        knownSeconds=knownSeconds,unknownSeconds=measure(unknownUnion,nil,work),coverage="observed intervals only"}
    if withRecords then
        local excluded=union(exclusions,work)
        for _,intervals in pairs(sessions)do _auctionTick();
            if work then work()end
            local observed=union(intervals,work);if within then observed=intersection(observed,union(within,work),work)end
            result.longestSessionSeconds=math.max(result.longestSessionSeconds or 0,measure(observed,excluded,work))
        end
        return result,records
    end
    return result
end
function Q.ActiveTime(c,from,through)
    return Q.TimeStats(c,from,through).activeSeconds
end
function Q.Search(c,text,kind,page)
    return E.Search.Find(c,text,kind,page)
end
function Q.Major(c)
    local out={}; for _,r in ipairs(Q.Kind(c,"milestone")) do _auctionTick(); if r.subject==c.id and r.major==true then out[#out+1]=r end end
    return out
end
-- Previous means strictly earlier in observation order. Linked milestones can
-- share that order; preserve the first canonical record at the winning point,
-- matching the existing chronological Major scan's tie behavior.
function Q.PreviousMajor(c,event)
    if not S.Timestamp(event) then return end
    local families=index(c).majorFamilies[c.id]
    local family=families and families[Q.MilestoneFamily(event)]
    if not family then return end
    local rows=family.ordered
    if not rows then
        rows={};for _,r in pairs(family.records)do _auctionTick(); rows[#rows+1]=r end
        _auctionSort(rows,chronological);family.ordered=rows
    end
    local function firstAt(point)
        local lo,hi=1,#rows+1
        while lo<hi do _auctionTick();
            local mid=math.floor((lo+hi)/2)
            if S.Before(rows[mid],point)then lo=mid+1 else hi=mid end
        end
        return lo
    end
    local previous=rows[firstAt(event)-1]
    if previous then return rows[firstAt(previous)]end
end
function Q.Finance(c,from,through)
    local out={cashIn=0,cashOut=0,net=0,unknown=0,sources={},transactions={},balances={},coverage="observed transactions only"}
    for _,r in ipairs(Q.Range(c,from,through)) do _auctionTick();
        if r.kind=="gold" then
            out.transactions[#out.transactions+1]=r
            if r.amount>0 then out.cashIn=out.cashIn+r.amount else out.cashOut=out.cashOut-r.amount end
            out.net=out.net+r.amount
            local source=r.source or "unknown"; out.sources[source]=(out.sources[source] or 0)+r.amount
            if source=="unknown" then out.unknown=out.unknown+1 end
            out.balances[#out.balances+1]={ts=r.ts,balance=r.after,session=r.session}
        elseif r.kind=="balance" then out.balances[#out.balances+1]={ts=r.ts,balance=r.balance,session=r.session} end
    end
    out.activeSeconds=Q.ActiveTime(c,from,through)
    return out
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="Query",create=create}
E.AuctionReaderSources["Query.lua"]="85f9f542a9d4e431b31033b88ebdee6d381bda4840487fad61d21532bbf14184"
end

-- Economy.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Economy';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local F,S,Q={},E.Store,E.Query; E.Economy=F
local economic={cost_lot=true,item_sale=true,stock_move=true,stock_reset=true,sale_return=true}
function F.RetentionRoots(c,work)
    -- Accounting and cross-character custody need the complete retained chain.
    -- These are set memberships, so scanning once needs no sorted Query index.
    local roots={}
    for id,r in pairs(c.records)do _auctionTick();
        if work then work()end
        if economic[r.kind]or r.kind=="bank"or r.kind=="bank_gap"then roots[id]=true end
        if economic[r.kind]and type(r.evidence)=="string"and c.records[r.evidence]then roots[r.evidence]=true end
    end
    return roots
end
local revisions,caches=setmetatable({},{__mode="k"}),setmetatable({},{__mode="k"})
local movementCertificates=setmetatable({},{__mode="k"})
local movementAllocations,allocationGeneration=setmetatable({},{__mode="k"}),{}

local replayEvidence={craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true,auction=true,merchant=true,inventory=true,inventory_gap=true,gold=true,money_evidence=true,bank=true,bank_gap=true,trade=true,trade_offer=true,trade_notice=true,wallet_window=true,mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true}
local function invalidate(c,r)
    -- Query retains prior membership before other correction listeners run.
    -- Reclassifying evidence must invalidate donor and recipient replay caches.
    local old=r and Q.PreviousKind(c,r.id)
    if not r or not Q.IsWarm(c) or economic[r.kind] or replayEvidence[r.kind] or economic[old] or replayEvidence[old] then
    revisions[c]=(revisions[c] or 0)+1
    -- A donor's revised evidence also changes recipients' derived cost basis.
    caches=setmetatable({},{__mode="k"})
    movementAllocations=setmetatable({},{__mode="k"});allocationGeneration={}
    movementCertificates=setmetatable({},{__mode="k"})
end end
E.On("RECORD_ADDED",invalidate); E.On("RECORD_CHANGED",invalidate); E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
local function integer(n,zero)
    return type(n)=="number" and n==n and n%1==0 and n>=(zero and 0 or 1) and n<=9007199254740991
end
local function validateItem(data)
    assert(integer(data.itemID),"Item identity required")
    assert(integer(data.quantity) and data.quantity<=67108864,"Positive bounded item quantity required")
end
local function copper(value,label) assert(value==nil or integer(value,true),label.." must be integer copper or unknown") end
-- Allocate integer copper cumulatively, preserving every copper across partial-stack operations.
function F.Part(total,quantity,used,count)
    if total==nil then return nil end
    local quotient=math.floor(total/quantity); local remainder=total%quantity
    return quotient*count+math.floor(remainder*(used+count)/quantity)-math.floor(remainder*used/quantity)
end
-- Retain the original integer-copper distribution through nested splits.
function F.SliceCost(row,offset,count)
    local total=row.baseCost or row.cost;local quantity=row.baseQuantity or row.quantity
    local start=(row.baseOffset or 0)+offset
    return F.Part(total,quantity,start,count),total,quantity,start
end
local function record(c,kind,ts,data,key)
    assert(type(key)=="string" and key~="","Stable economic observation key required")
    validateItem(data); return S.Add(c,kind,ts,data,key)
end
function F.Lot(c,ts,data,key)
    copper(data.cost,"Lot cost")
    assert(data.cost==nil or data.evidence,"Known costs require acquisition evidence")
    data=_auctionCopy(data); data.title=data.title or "Recorded acquisition cost"; data.basis="FIFO"
    return record(c,"cost_lot",ts,data,key)
end
function F.Sale(c,ts,data,key)
    copper(data.gross,"Sale proceeds"); copper(data.fees,"Nonrefundable selling fees")
    assert(data.evidence,"Sale completion requires evidence")
    data=_auctionCopy(data); data.title=data.title or "Recorded item sale"
    return record(c,"item_sale",ts,data,key)
end
function F.Move(c,ts,data,key)
    assert(data.reason and data.evidence,"Inventory outflow needs a reason and evidence")
    data=_auctionCopy(data); data.title=data.title or "Recorded inventory outflow"
    return record(c,"stock_move",ts,data,key)
end
function F.Reset(c,ts,data,key)
    assert(integer(data.itemID) and integer(data.quantity,true),"Observed item count required")
    assert(data.evidence,"Inventory boundary requires evidence")
    data=_auctionCopy(data); data.title=data.title or "Inventory cost coverage boundary"
    -- An observed count cannot establish how the existing units were acquired.
    return S.Add(c,"stock_reset",ts,data,key)
end
function F.Return(c,ts,data,key)
    local sale=c.records[data.sale]
    assert(sale and sale.kind=="item_sale" and ts>=sale.ts,"Return requires an earlier sale from this character")
    assert(integer(data.quantity) and data.quantity<=sale.quantity,"Invalid returned quantity")
    copper(data.refund,"Refund paid"); copper(data.feeRefund,"Selling fee refund")
    assert(data.evidence,"Return requires evidence")
    local returned=0
    for _,r in ipairs(Q.Kind(c,"sale_return")) do _auctionTick(); if r.sale==data.sale then returned=returned+r.quantity end end
    local existing=c.dedup["sale_return:"..key]
    assert(existing or returned+data.quantity<=sale.quantity,"Cannot return more units than were sold")
    data=_auctionCopy(data); data.itemID=sale.itemID; data.title=data.title or "Recorded sale return"
    data.refs=data.refs or {}; data.refs[#data.refs+1]=sale.id
    return record(c,"sale_return",ts,data,key)
end
function F.LotBefore(a,b)
        if (a.unknownAge==true)~=(b.unknownAge==true) then return a.unknownAge==true end
        if (a.acquired or 0)~=(b.acquired or 0) then return (a.acquired or 0)<(b.acquired or 0) end
        if (a.sequence or 0)~=(b.sequence or 0) then return (a.sequence or 0)<(b.sequence or 0) end
        if (a.acquisitionOrder or 0)~=(b.acquisitionOrder or 0) then return (a.acquisitionOrder or 0)<(b.acquisitionOrder or 0) end
        if a.sourceRecord and a.sourceRecord==b.sourceRecord and a.sourceCharacter==b.sourceCharacter
            and (a.baseQuantity or a.quantity)==(b.baseQuantity or b.quantity) and (a.baseCost or a.cost)==(b.baseCost or b.cost) and (a.baseOffset or 0)+(a.used or 0)~=(b.baseOffset or 0)+(b.used or 0) then
            return (a.baseOffset or 0)+(a.used or 0)<(b.baseOffset or 0)+(b.used or 0)
        end
        return (a.order or 0)<(b.order or 0)
end
local function insertLot(stock,lot)
    stock.nextOrder=(stock.nextOrder or 0)+1; lot.order=stock.nextOrder
    local before=F.LotBefore
    local position=#stock+1
    if #stock>0 and before(lot,stock[#stock]) then
        local lo,hi=1,#stock
        while lo<=hi do _auctionTick(); local mid=math.floor((lo+hi)/2); if before(lot,stock[mid]) then hi=mid-1 else lo=mid+1 end end
        position=lo
    end
    table.insert(stock,position,lot); stock.head=math.min(stock.head or 1,position)
end
local function consume(stock,quantity)
    local allocations={}; local remaining=quantity; local knownCost,unknown=0,0
    for i=stock.head or 1,#stock do _auctionTick();
        local lot=stock[i]
        local take=math.min(remaining,lot.quantity-lot.used)
        if take>0 then
            local cost,total,basis,offset=F.SliceCost(lot,lot.used,take)
            allocations[#allocations+1]={lot=lot.id,quantity=take,cost=cost,baseCost=total,baseQuantity=basis,baseOffset=offset,acquired=lot.acquired,sequence=lot.sequence,unknownAge=lot.unknownAge,quality=lot.quality,acquisitionOrder=lot.acquisitionOrder,sourceCharacter=lot.sourceCharacter,sourceRecord=lot.sourceRecord}
            if cost==nil then unknown=unknown+take else knownCost=knownCost+cost end
            lot.used=lot.used+take; remaining=remaining-take
        end
        if remaining==0 then break end
    end
    local head=stock.head or 1
    while stock[head] and stock[head].used>=stock[head].quantity do _auctionTick(); head=head+1 end
    stock.head=head
    if remaining>0 then allocations[#allocations+1]={quantity=remaining}; unknown=unknown+remaining end
    return allocations,knownCost,unknown,remaining
end
local function restoreReturn(result,stock,r,c)
    local history=r.kind=="stock_return" and result.movements or result.sales
    local original=history[r.sale]
    local parts=r.returnParts or {{sale=r.sale,offset=original and (original.returned or 0) or 0,quantity=r.quantity}}
    local valid=type(parts)=='table' and #parts>0;local count=0;local claims={};local allocations={}
    local inferred=r.quality=='inferred'
    for _,part in ipairs(parts)do _auctionTick();
        local sale=history[part.sale]
        if not sale or sale.record.itemID~=r.itemID or not integer(part.offset,true) or not integer(part.quantity)
            or part.offset+part.quantity>sale.record.quantity then valid=false;break end
        local first,last=part.offset,part.offset+part.quantity
        local ranges=claims[part.sale] or _auctionCopy(sale.returnedRanges or {});claims[part.sale]=ranges
        for _,range in ipairs(ranges)do _auctionTick(); if first<range[2] and last>range[1]then valid=false;break end end
        if not valid then break end
        ranges[#ranges+1]={first,last};count=count+part.quantity;inferred=inferred or sale.inferred
        local position=0
        for _,allocation in ipairs(sale.allocations)do _auctionTick();
            if r.kind=="stock_return" and allocation.lot and (not c.records[allocation.lot] or c.records[allocation.lot].character~=c.id)then valid=false;break end
            local start=math.max(first,position);local finish=math.min(last,position+allocation.quantity)
            if finish>start then
                local copy=_auctionCopy(allocation);copy.quantity=finish-start
                copy.cost,copy.baseCost,copy.baseQuantity,copy.baseOffset=F.SliceCost(allocation,start-position,copy.quantity)
                if r.quality=='inferred' then copy.quality='inferred' end
                allocations[#allocations+1]=copy
            end
            position=position+allocation.quantity
        end
    end
    valid=valid and count==r.quantity
    local knownCost,unknown=0,0
    if valid then
        for id,ranges in pairs(claims)do _auctionTick();
            local sale=history[id];sale.returnedRanges=ranges;sale.returned=0
            for _,range in ipairs(ranges)do _auctionTick(); sale.returned=sale.returned+range[2]-range[1]end
        end
        for _,a in ipairs(allocations)do _auctionTick();
            insertLot(stock,{id=r.id,quantity=a.quantity,cost=a.cost,baseCost=a.baseCost,baseQuantity=a.baseQuantity,baseOffset=a.baseOffset,
                used=0,acquired=a.acquired or r.ts,sequence=a.sequence or S.Sequence(r),unknownAge=a.unknownAge or not a.acquired,
                quality=a.quality,acquisitionOrder=a.acquisitionOrder,sourceCharacter=a.sourceCharacter,sourceRecord=a.sourceRecord})
            if a.cost==nil then unknown=unknown+a.quantity else knownCost=knownCost+a.cost end
        end
    else
        allocations={};unknown=r.quantity
        insertLot(stock,{id=r.id,quantity=r.quantity,used=0,acquired=r.ts,sequence=S.Sequence(r),unknownAge=true,quality=r.quality})
    end
    local info={record=r,allocations=allocations,cost=unknown==0 and knownCost or nil,unknownQuantity=unknown,inferred=not not inferred}
    info.complete=valid and info.cost~=nil and r.refund~=nil and r.feeRefund~=nil
    if info.complete then info.profit=info.cost-r.refund+r.feeRefund end
    return info
end

local function replayBefore(a,b)
    local at,bt=a.accountingTime or a.ts,b.accountingTime or b.ts
    if at~=bt then return at<bt end
    if S.Sequence(a)~=S.Sequence(b)then return S.Sequence(a)<S.Sequence(b)end
    return (a.projectionOrder or 0)<(b.projectionOrder or 0)
end
function F.Replay(c,through,sequenceLimit)
    local revision=revisions[c] or 0; local cache=caches[c]
    if cache and cache.revision==revision and cache.through==through and cache.sequenceLimit==sequenceLimit then return cache.result end
    local certify=through==math.huge and sequenceLimit==nil
    local origins,unsafe,required,maxSequence={},{},{},{}
    local events={}; for kind in pairs(economic) do _auctionTick(); for _,r in ipairs(Q.Kind(c,kind)) do _auctionTick(); if r.ts<through and (not sequenceLimit or r.sequence<=sequenceLimit) then
        local projected=E.CostMatch and E.CostMatch.Project(c,r)
        if not projected and E.BankCosts then projected=E.BankCosts.Project(c,r) end
        if not projected and E.TradeCosts then projected=E.TradeCosts.Project(c,r) end
        if not projected and E.AuctionReturns then projected=E.AuctionReturns.Project(c,r) end
        if not projected and E.MailCosts then projected=E.MailCosts.Project(c,r) end
        if not projected and E.SentMailCosts then projected=E.SentMailCosts.Project(c,r) end
        if not projected and E.CraftCosts then projected=E.CraftCosts.Project(c,r) end
        if projected then for _,entry in ipairs(projected)do _auctionTick();
            events[#events+1]=entry
            if certify then
                origins[entry]=r.sequence
                -- These projections recursively derive costs from other replay
                -- boundaries. Keep their item histories on the reference path.
                if entry.bankReceipt or entry.craftRequest then unsafe[entry.itemID]=true end
            end
        end else events[#events+1]=r;if certify then origins[r]=r.sequence end end
    end end end
    _auctionSort(events,replayBefore)
    if certify then
        local previous={}
        for _,r in ipairs(events)do _auctionTick();
            local prior=previous[r.itemID]
            if prior and not replayBefore(prior,r)and not replayBefore(r,prior)then unsafe[r.itemID]=true end
            if not integer(origins[r],true)then unsafe[r.itemID]=true end
            previous[r.itemID]=r
        end
    end
    local result={stock={},sales={},returns={},order={},movements={},gaps=0,shortfall=0,acquired=0,sold=0,returned=0,stockReturned=0,stockReturns={}}
    for _,r in ipairs(events) do _auctionTick();
        if certify then maxSequence[r.itemID]=math.max(maxSequence[r.itemID]or 0,integer(origins[r],true)and origins[r]or 0)end
        local stock=result.stock[r.itemID] or {}; result.stock[r.itemID]=stock
        if r.kind=="stock_reset" then
            stock={}; result.stock[r.itemID]=stock; result.gaps=result.gaps+1
            if r.quantity>0 then insertLot(stock,{id=r.id,quantity=r.quantity,used=0,acquired=r.ts,sequence=S.Sequence(r),unknownAge=true,sourceCharacter=c.id,sourceRecord=r.id}) end
        elseif r.kind=="cost_lot" then
            insertLot(stock,{id=r.id,quantity=r.quantity,cost=r.cost,baseCost=r.baseCost,baseQuantity=r.baseQuantity,baseOffset=r.baseOffset,used=0,acquired=r.acquired or r.ts,sequence=r.acquisitionSequence or S.Sequence(r),quality=r.quality,acquisitionOrder=r.projectionOrder,unknownAge=r.unknownAge,sourceCharacter=r.sourceCharacter or c.id,sourceRecord=r.sourceRecord or r.id})
            result.acquired=result.acquired+r.quantity
        elseif r.kind=="item_sale" or r.kind=="stock_move" then
            local allocations,knownCost,unknown,shortfall=consume(stock,r.quantity)
            result.shortfall=result.shortfall+shortfall
            local info={record=r,allocations=allocations,knownCost=knownCost,unknownQuantity=unknown,matchedQuantity=r.quantity-unknown,
                cost=unknown==0 and knownCost or nil,shortfall=shortfall}
            info.inferred=r.quality=="inferred"
            for _,allocation in ipairs(allocations)do _auctionTick(); if allocation.quality=="inferred" then info.inferred=true end end
            if r.kind=="item_sale" then
                info.complete=info.cost~=nil and r.gross~=nil and r.fees~=nil
                if info.complete then info.profit=r.gross-info.cost-r.fees end
                result.sales[r.id]=info; result.order[#result.order+1]=info; result.sold=result.sold+r.quantity
            else result.movements[r.id]=info;if certify then required[r.id]=maxSequence[r.itemID]end end
        elseif r.kind=="stock_return" then
            local info=restoreReturn(result,stock,r,c)
            result.stockReturns[r.id]=info;result.stockReturned=result.stockReturned+r.quantity
        elseif r.kind=="sale_return" then
            local info=restoreReturn(result,stock,r)
            result.returns[r.id]=info; result.order[#result.order+1]=info; result.returned=result.returned+r.quantity
        end
    end
    result.inventoryKnownCost,result.inventoryUnknownQuantity,result.inventoryQuantity=0,0,0
    for _,stock in pairs(result.stock) do _auctionTick(); for _,lot in ipairs(stock) do _auctionTick();
        local remaining=lot.quantity-lot.used
        if remaining>0 then
            result.inventoryQuantity=result.inventoryQuantity+remaining
            local value=F.SliceCost(lot,lot.used,remaining)
            if value==nil then result.inventoryUnknownQuantity=result.inventoryUnknownQuantity+remaining else result.inventoryKnownCost=result.inventoryKnownCost+value end
        end
    end end
    if certify then movementCertificates[result]={required=required,unsafe=unsafe}end
    caches[c]={revision=revision,through=through,sequenceLimit=sequenceLimit,result=result}; return result
end
-- A present-day allocation is reusable only with a sequence/order witness.
-- Unsafe items and retroactive prefixes use the original per-movement replay.
function F.MovementAllocation(c,raw)
    if not raw or c.records[raw.id]~=raw or raw.kind~='stock_move'then return end
    local limit=S.Sequence(raw);local prepared=movementAllocations[c]
    if not prepared or prepared.generation~=allocationGeneration or prepared.database[1]~=E.db then
        local generation=allocationGeneration
        local full=F.Replay(c,math.huge)
        local proof=movementCertificates[full]
        if generation~=allocationGeneration or not proof then return F.Replay(c,math.huge,limit).movements[raw.id]end
        -- A weak database identity avoids retaining a replaced SavedVariables
        -- tree through a weak-key cache's strongly held value in Lua 5.1.
        prepared={generation=generation,database=setmetatable({E.db},{__mode='v'}),movements=full.movements,proof=proof,fallback={}}
        movementAllocations[c]=prepared
    end
    local info=prepared.movements[raw.id];local required=prepared.proof.required[raw.id]
    if info and required and required<=limit and not prepared.proof.unsafe[info.record.itemID]then return info end
    local saved=prepared.fallback[raw.id]
    if saved==nil then
        saved=F.Replay(c,math.huge,limit).movements[raw.id]or false
        if prepared.generation==allocationGeneration then prepared.fallback[raw.id]=saved end
    end
    return saved or nil
end

function F.Profit(c,from,through)
    local state=F.Replay(c,through)
    local out={profit=0,gross=0,cost=0,fees=0,matched=0,inferredMatched=0,inferredProfit=0,unmatched=0,unmatchedGross=0,unknownGross=0,returned=0,records={},
        inventoryKnownCost=state.inventoryKnownCost,inventoryUnknownQuantity=state.inventoryUnknownQuantity,inventoryQuantity=state.inventoryQuantity}
    for _,info in ipairs(state.order) do _auctionTick(); local r=info.record
        if r.ts>=from then
            out.records[#out.records+1]=info
            if info.complete then
                out.profit=out.profit+info.profit; out.matched=out.matched+1
                if info.inferred then out.inferredMatched=out.inferredMatched+1; out.inferredProfit=out.inferredProfit+info.profit end
                if r.kind=="item_sale" then out.gross=out.gross+r.gross; out.cost=out.cost+info.cost; out.fees=out.fees+r.fees
                else out.gross=out.gross-r.refund; out.cost=out.cost-info.cost; out.fees=out.fees-r.feeRefund; out.returned=out.returned+r.quantity end
            else
                out.unmatched=out.unmatched+1
                if r.gross then out.unmatchedGross=out.unmatchedGross+r.gross else out.unknownGross=out.unknownGross+1 end
            end
        end
    end
    if out.matched==0 then out.profit=nil end
    if out.profit~=nil and out.gross>0 then out.margin=out.profit/out.gross*100 end
    if out.profit~=nil and out.cost+out.fees>0 then out.roi=out.profit/(out.cost+out.fees)*100 end
    out.basis="FIFO of recorded lots; unmatched costs are excluded from realized profit"
    return out
end
F.sources={unknown="Unknown",quest="Quest rewards",loot="Looted money",vendorSale="Vendor sales",vendorPurchase="Vendor purchases",
    buyback="Buybacks",repair="Repairs",trade="Player trades",mail="Mail",mailSent="Outgoing mail",auctionSale="Auction sales",auctionPurchase="Auction purchases",
    auctionFee="Auction fees",auctionDeposit="Posting deposits",transfer="Character transfers",training="Training",travel="Travel",consumables="Consumables"}
F.operating={quest=true,loot=true,repair=true,training=true,travel=true,consumables=true}
F.inventoryCash={vendorSale=true,vendorPurchase=true,buyback=true,auctionSale=true,auctionPurchase=true,auctionFee=true,auctionDeposit=true}
local attributing=setmetatable({},{__mode="k"})
function F.Attributing(c)return attributing[c]==true end
function F.Attribute(c,id,source,quality,evidence,automatic)
    local r=c.records[id]; assert(r and r.kind=="gold","Wallet transaction required")
    assert(F.sources[source],"Unknown financial source")
    assert(quality=="confirmed" or quality=="inferred" or quality=="unknown","Invalid attribution quality")
    assert(source=="unknown" or evidence and #evidence>0,"Attribution requires evidence")
    for _,ref in ipairs(evidence or {}) do _auctionTick();
        local proof=c.records[ref]; assert(proof,"Evidence must belong to this character")
        assert(proof.kind~="money_evidence" or proof.source==source,"Money evidence must agree with the assigned source")
    end
    if r.quality=="confirmed" and (r.source~=source or quality~="confirmed") then return nil,"Confirmed attribution was preserved" end
    if r.source==source and r.quality==quality and r.automaticAttribution==automatic and _auctionSame(r.evidenceRefs or {},evidence or {}) then return r end
    r.attributionHistory=r.attributionHistory or {}
    r.attributionHistory[#r.attributionHistory+1]={source=r.source,quality=r.quality,evidenceRefs=r.evidenceRefs,changedAt=E.API.Now()}
    r.source,r.quality,r.evidenceRefs,r.automaticAttribution=source,quality,_auctionCopy(evidence or {}),automatic
    local refs={}; if r.window and c.records[r.window] then refs[#refs+1]=r.window end
    local group=r.observerGroupState=="group" and type(r.observerGroup)=="string" and c.records[r.observerGroup]
    if r.id==id and r.character==c.id and type(group)=="table" and group.id==r.observerGroup and group.character==c.id and group.kind=="group" then
        refs[#refs+1]=group.id
    else group=nil end
    for _,ref in ipairs(evidence or {}) do _auctionTick(); if not group or ref~=group.id then refs[#refs+1]=ref end end
    r.refs=refs
    local previous=attributing[c];attributing[c]=true
    local ok,why=pcall(S.Changed,c,r);attributing[c]=previous
    if not ok then error(why)end
    return r
end
local function eligibleWallet(r)
    return r.kind=="gold" and r.quality~="confirmed" and r.automaticAttribution~=false and (r.source=="unknown" or r.automaticAttribution)
end
function F.ValidLootMoneyProof(c,p)
    if p.kind~='money_evidence' or c.records[p.id]~=p or p.character~=c.id or p.source~='loot'
        or p.lootMoneyVersion~=1 or p.observationType~='loot_money_slot' or p.lootMoneyConflict
        or p.slotType~=2 or not integer(p.slot) or p.soloObserved~=true or not integer(p.amount) or p.formattedAmount~=p.amount
        or type(p.slotName)~='string' or p.slotName=='' or p.coinText~=p.slotName
        or p.moneyMatch~='exact client coin text' or not integer(p.slotObservedSequence) or S.Sequence(p)<=p.slotObservedSequence
        or not integer(p.slotObservedAt,true) or not integer(p.ts,true) or p.clearedAt~=p.ts
        or type(p.session)~='string' or p.session==''
        or p.slotObservedAt>p.ts or p.ts-p.slotObservedAt>120 then return false end
    local w=c.records[p.walletID];local window=c.records[p.walletWindow]
    if not w or w.kind~='gold' or w.character~=c.id or w.session~=p.session or w.window~=p.walletWindow
        or not window or window.kind~='wallet_window' or window.character~=c.id or window.session~=p.session
        or w.amount~=p.amount or not integer(w.ts,true) or w.ts<p.slotObservedAt or math.abs(w.ts-p.ts)>2
        or not integer(window.ts,true) or not integer(window.ended,true)
        or S.Sequence(w)<=p.slotObservedSequence or window.ts>p.slotObservedAt or window.ended<w.ts
        or type(w.before)~='number' or type(w.after)~='number' or w.after-w.before~=w.amount then return false end
    -- A later equal wallet change makes the original match ambiguous too.
    -- Do not use the selected walletID to manufacture uniqueness.
    local count=0
    for _,other in ipairs(Q.Range(c,p.ts-2,p.ts+3,'gold'))do _auctionTick();
        if other.session==p.session and other.window==p.walletWindow and other.amount==p.amount and math.abs(other.ts-p.ts)<=2
            and other.ts>=p.slotObservedAt and S.Sequence(other)>p.slotObservedSequence then count=count+1 end
    end
    return count==1
end
function F.ValidTravelMoneyProof(c,p)
    if p.kind~='money_evidence' or c.records[p.id]~=p or p.character~=c.id or p.source~='travel'
        or p.travelMoneyVersion~=1 or p.observationType~='flight_fare' or p.withdrawnReason
        or not integer(p.quotedCost) or p.amount~=-p.quotedCost or p.uiQuotedCost~=p.quotedCost or p.requestQuotedCost~=p.quotedCost
        or not integer(p.taxiNode) or p.uiTaxiNode~=p.taxiNode or type(p.destination)~='string' or p.destination=='' or p.uiDestination~=p.destination
        or p.initialOffTaxi~=true or p.flightObserved~=true or p.uiNodeType~='REACHABLE' or p.requestNodeType~='REACHABLE'
        or not integer(p.initialStateAt,true) or not integer(p.fareQuotedAt,true) or not integer(p.requestedAt,true) or not integer(p.flightObservedAt,true)
        or p.initialStateAt>p.fareQuotedAt or p.fareQuotedAt>p.requestedAt or p.requestQuotedAt~=p.requestedAt or p.ts~=p.requestedAt
        or p.flightObservedAt<p.requestedAt or p.flightObservedAt-p.requestedAt>2
        or not integer(p.uiQuoteSequence) or not integer(p.requestObservedSequence) or not integer(p.flightObservedSequence)
        or p.uiQuoteSequence>=p.requestObservedSequence or p.requestObservedSequence>=p.flightObservedSequence or p.flightObservedSequence>=S.Sequence(p)
        or type(p.session)~='string' or p.session=='' then return false end
    if p.walletWindow~=p.requestWalletWindow or p.walletWindow~=p.flightWalletWindow then return false end
    local window=c.records[p.walletWindow]
    if not window or window.kind~='wallet_window' or window.character~=c.id or window.session~=p.session
        or not integer(window.ts,true) or not integer(window.ended,true) or window.ts>p.fareQuotedAt then return false end
    local count,chosen=0,nil
    for _,w in ipairs(Q.Range(c,p.ts-2,p.ts+3,'gold'))do _auctionTick();
        if w.session==p.session and w.window==p.walletWindow and w.amount==p.amount and math.abs(w.ts-p.ts)<=2 then count=count+1;chosen=w end
    end
    -- PLAYER_MONEY can precede the secure post-hook. It must still follow the
    -- observed UI quote and be the sole matching delta in that wallet window.
    return count==1 and chosen.character==c.id and chosen.ts>=p.fareQuotedAt and S.Sequence(chosen)>p.uiQuoteSequence
        and window.ended>=chosen.ts and type(chosen.before)=='number' and type(chosen.after)=='number' and chosen.after-chosen.before==p.amount
end
function F.ValidTrainingLearningProof(c,p)
    if p.kind~='money_evidence'or c.records[p.id]~=p or p.character~=c.id or p.source~='training'
        or p.trainingLearningVersion~=1 or type(p.session)~='string'or p.session==''or not integer(p.requestSequence)or p.withdrawnReason or(p.trainerType~='General'and p.trainerType~='Tradeskills')
        or type(p.trainerGUID)~='string'or p.trainerGUID==''or type(p.service)~='table'
        or type(p.service.name)~='string'or not integer(p.service.cost)or p.amount~=-p.service.cost
        or not integer(p.quoteAt,true)or not integer(p.requestedAt,true)or p.ts~=p.requestedAt
        or p.requestedAt<p.quoteAt or p.requestedAt-p.quoteAt>300 then return false end
    local w,l,window=c.records[p.walletID],c.records[p.learnedID],c.records[p.walletWindow]
    if type(w)~='table'or type(l)~='table'or type(window)~='table'or type(l.notifications)~='table'
        or not integer(window.ts,true)or not integer(window.ended,true)then return false end
    local wallets,learnings=0,0
    for _,r in ipairs(Q.RangeKinds(c,p.ts-2,p.ts+3,{gold=true,spell=true}))do _auctionTick();
        if r.kind=='gold'and r.session==p.session and r.window==p.walletWindow and r.amount==p.amount and r.ts>=p.quoteAt then wallets=wallets+1 end
        if r.kind=='spell'and r.subject==c.id and r.observedEvent=='LEARNED_SPELL_IN_SKILL_LINE'and r.spellName==p.service.name and r.isGuildPerk~=true and r.ts>=p.quoteAt then learnings=learnings+1 end
    end
    if wallets~=1 or learnings~=1 then return false end
    local sessionKnown=false
    for _,n in ipairs(l.notifications)do _auctionTick(); if type(n)=='table'and n.session==p.session and n.ts==l.ts then sessionKnown=true end end
    return sessionKnown and w and l and window and w.kind=='gold'and w.character==c.id and w.session==p.session and w.window==p.walletWindow
        and w.amount==p.amount and type(w.before)=='number'and type(w.after)=='number'and w.after-w.before==p.amount
        and type(w.ts)=='number'and math.abs(w.ts-p.ts)<=2 and w.ts>=p.quoteAt
        and l.kind=='spell'and l.character==c.id and l.subject==c.id and l.observedEvent=='LEARNED_SPELL_IN_SKILL_LINE'
        and l.isGuildPerk~=true and l.spellName==p.service.name and type(l.ts)=='number'and math.abs(l.ts-p.ts)<=2 and l.ts>=p.quoteAt
        and window.kind=='wallet_window'and window.character==c.id and window.session==p.session
        and window.ts<=p.quoteAt and window.ended>=w.ts
end
function F.ValidTrainingMoneyProof(c,p)
    if p.kind~='money_evidence'or c.records[p.id]~=p or p.character~=c.id or p.source~='training'
        or p.trainingMoneyVersion~=1 or p.observationType~='trainer_service'or p.withdrawnReason
        or(p.trainerType~='General'and p.trainerType~='Tradeskills')
        or type(p.trainerGUID)~='string'or p.trainerGUID==''or p.requestTrainerGUID~=p.trainerGUID or p.usedTrainerGUID~=p.trainerGUID
        or not integer(p.quotedCost)or p.amount~=-p.quotedCost or p.requestQuotedCost~=p.quotedCost or not integer(p.serviceIndex)
        or p.requestIndex~=p.serviceIndex or p.usedIndex~=p.serviceIndex
        or p.initialServiceType~='available'or p.requestServiceType~='available'or p.usedServiceType~='used'or p.uniqueService~=true
        or type(p.service)~='table'or type(p.service.name)~='string'or p.service.name==''or not integer(p.service.level,true)
        or(p.service.subText~=nil and type(p.service.subText)~='string')
        or(p.service.category~=nil and type(p.service.category)~='string'and not integer(p.service.category,true))
        or not _auctionSame(p.service,p.requestService)or not _auctionSame(p.service,p.usedService)
        or type(p.filters)~='table'or type(p.filters.available)~='boolean'or type(p.filters.unavailable)~='boolean'or type(p.filters.used)~='boolean'
        or not _auctionSame(p.filters,p.requestFilters)or not _auctionSame(p.filters,p.usedFilters)
        or not integer(p.quoteAt,true)or not integer(p.requestedAt,true)or not integer(p.usedAt,true)
        or p.quoteAt>p.requestedAt or p.ts~=p.requestedAt or p.usedAt<p.requestedAt or p.usedAt-p.requestedAt>2
        or not integer(p.quoteSequence)or not integer(p.requestSequence)or not integer(p.usedSequence)
        or p.quoteSequence>=p.requestSequence or p.requestSequence>=p.usedSequence or p.usedSequence>=S.Sequence(p)
        or type(p.session)~='string'or p.session==''then return false end
    local window=c.records[p.walletWindow]
    if not window or window.kind~='wallet_window'or window.character~=c.id or window.session~=p.session
        or not integer(window.ts,true)or not integer(window.ended,true)or window.ts>p.quoteAt then return false end
    local count,chosen=0,nil
    for _,w in ipairs(Q.Range(c,p.ts-2,p.ts+3,'gold'))do _auctionTick();
        if w.session==p.session and w.window==p.walletWindow and w.amount==p.amount and math.abs(w.ts-p.ts)<=2 then count=count+1;chosen=w end
    end
    return count==1 and chosen.character==c.id and chosen.ts>=p.quoteAt and S.Sequence(chosen)>p.quoteSequence
        and window.ended>=chosen.ts and type(chosen.before)=='number'and type(chosen.after)=='number'and chosen.after-chosen.before==p.amount
end
local function usableProof(c,p)
    if p.kind~="money_evidence" or c.records[p.id]~=p or not F.sources[p.source] or p.source=="unknown"
        or type(p.amount)~="number" or p.amount~=p.amount or p.amount==0 or p.amount%1~=0 then return false end
    if p.trade and (p.source~="trade" or not E.Trades or not E.Trades.ValidProof(c,p))then return false end
    if p.mailCollection and (not E.MailMoney or not E.MailMoney.ValidProof(c,p))then return false end
    if (p.lootMoneyVersion~=nil or p.observationType=='loot_money_slot') and not F.ValidLootMoneyProof(c,p)then return false end
    if (p.travelMoneyVersion~=nil or p.observationType=='flight_fare') and not F.ValidTravelMoneyProof(c,p)then return false end
    if (p.source=='auctionDeposit' or p.auctionDepositVersion~=nil or p.observationType=='auction_posting_deposit') and (not E.AuctionDeposits or not E.AuctionDeposits.ValidProof(c,p))then return false end
    if p.trainingLearningVersion~=nil and not F.ValidTrainingLearningProof(c,p)then return false end
    if (p.trainingMoneyVersion~=nil or p.observationType=='trainer_service') and not F.ValidTrainingMoneyProof(c,p)then return false end
    return true
end
local function matches(w,p)
    return w.session==p.session and w.amount==p.amount and math.abs(w.ts-p.ts)<=2 and (not p.walletID or p.walletID==w.id) and (not p.walletWindow or p.walletWindow==w.window)
end
function F.CheckWallet(c,w)
    if c.records[w.id]~=w or not eligibleWallet(w)then return end
    -- A proof is at most two seconds from this wallet; another wallet claiming
    -- that proof can therefore be four seconds away. Read only financial kinds.
    local rows=Q.RangeKinds(c,w.ts-4,w.ts+5,{gold=true,money_evidence=true})
    local choice,count=nil,0
    for _,p in ipairs(rows)do _auctionTick(); if p.kind=="money_evidence" and matches(w,p)and usableProof(c,p)then choice=p;count=count+1 end end
    if count==1 then
        local claims=0
        for _,r in ipairs(rows)do _auctionTick(); if r.kind=="gold" and matches(r,choice)then claims=claims+1 end end
        if claims==1 then return F.Attribute(c,w.id,choice.source,"inferred",{choice.id},true)end
    end
    if w.automaticAttribution then return F.Attribute(c,w.id,"unknown","unknown",{},true)end
end
local recent=setmetatable({},{__mode="k"})
E.On("RECORD_CHANGED",function(c,r)
    if F.Attributing(c)then return end
    local old=Q.PreviousKind(c,r.id)
    if r.kind=="gold" or r.kind=="money_evidence" or old=="gold" or old=="money_evidence" then recent[c]=nil end
end)
function F.ReconcileEvidence(c,session,now,added)
    if Q.EnsureWarm(c)~='ready'then
        recent[c]=nil
        E.GoldChecks.RequestColdReview(c)
        return
    end
    local cache=recent[c]
    if not cache or cache.session~=session or now<cache.now then
        cache={session=session,records={}}
        for _,r in ipairs(Q.RangeKinds(c,now-10,now+11,{gold=true,money_evidence=true})) do _auctionTick(); if r.kind=="gold" or r.kind=="money_evidence" then cache.records[r.id]=r end end
        recent[c]=cache
    end
    cache.now=now; if added then cache.records[added.id]=added end
    local deltas,evidence={},{}
    for id,r in pairs(cache.records) do _auctionTick();
        if r.session~=session or math.abs(now-r.ts)>10 or c.records[id]~=r or (r.kind~="gold" and r.kind~="money_evidence") then cache.records[id]=nil
        elseif r.kind=="money_evidence" then
            if usableProof(c,r)then evidence[#evidence+1]=r end
        elseif r.kind=="gold" then deltas[#deltas+1]=r end
    end
    local byDelta,byEvidence={},{}
    for _,r in ipairs(deltas) do _auctionTick(); for _,proof in ipairs(evidence) do _auctionTick();
        if r.amount==proof.amount and math.abs(r.ts-proof.ts)<=2 and (not proof.walletID or proof.walletID==r.id) and (not proof.walletWindow or proof.walletWindow==r.window) then
            byDelta[r.id]=byDelta[r.id] or {}; table.insert(byDelta[r.id],proof)
            byEvidence[proof.id]=(byEvidence[proof.id] or 0)+1
        end
    end end
    for _,r in ipairs(deltas) do _auctionTick(); if eligibleWallet(r)then local choices=byDelta[r.id] or {}
        if #choices==1 and byEvidence[choices[1].id]==1 then
            F.Attribute(c,r.id,choices[1].source,"inferred",{choices[1].id},true)
        elseif r.automaticAttribution then F.Attribute(c,r.id,"unknown","unknown",{},true) end
    end end
end
function F.Evidence(c,ts,data,key)
    assert(type(data.amount)=="number" and data.amount%1==0 and data.amount~=0 and F.sources[data.source],"Signed money evidence required")
    return S.Add(c,"money_evidence",ts,data,key)
end
E.On("RECORD_ADDED",function(c,r)
    if r.kind=="gold" or r.kind=="money_evidence" then F.ReconcileEvidence(c,r.session,r.ts,r) end
end)
local walletIndexes=setmetatable({},{__mode="k"})
local function walletIndex(c)
    if not walletIndexes[c] then
        local byWindow={}
        for _,r in ipairs(Q.Kind(c,"gold")) do _auctionTick(); if r.window then
            byWindow[r.window]=byWindow[r.window] or {}; table.insert(byWindow[r.window],r)
        end end
        walletIndexes[c]=byWindow
    end
    return walletIndexes[c]
end
E.On("RECORD_ADDED",function(c,r)
    local i=walletIndexes[c]; if i and r.kind=="gold" and r.window then
        i[r.window]=i[r.window] or {}; table.insert(i[r.window],r); _auctionSort(i[r.window],S.Before)
    end
end)
E.On("RECORD_CHANGED",function(c,r)
    -- Cached arrays retain canonical references, but not changed membership or
    -- ordering. Rebuild after either direction of a gold reclassification too.
    if walletIndexes[c] and (r.kind=="gold" or not Q.IsWarm(c) or Q.PreviousKind(c,r.id)=="gold") then
        walletIndexes[c]=nil
    end
end)
E.On("RECORDS_REMOVED",function(c) walletIndexes[c]=nil; recent[c]=nil end)
function F.WalletCoverage(c,from,through)
    local windows=Q.Kind(c,"wallet_window"); local byWindow=walletIndex(c)
    local out={windows={},points={},knownSeconds=0,complete=false,opening=nil,closing=nil,gaps=0}
    local coveredTo,lastEnd=from,from
    for _,w in ipairs(windows) do _auctionTick(); if w.ended>=from and w.ts<through then
        local list=byWindow[w.id] or {}; local sum,chain=w.opening,true
        for _,r in ipairs(list) do _auctionTick();
            if r.before~=sum or r.after-r.before~=r.amount or r.ts<w.ts or r.ts>w.ended then chain=false end
            sum=sum+r.amount
        end
        local intact=chain and #list==w.transactionCount and sum==w.closing
        local start,finish=math.max(from,w.ts),math.min(through,w.ended)
        local opening,closing=w.opening,w.opening
        for _,r in ipairs(list) do _auctionTick(); if r.ts<from then opening=r.after end; if r.ts<through then closing=r.after end end
        if intact then
            if w.ts<=from and w.ended>=from then out.opening=opening end
            if w.ts<through and w.ended>=through then out.closing=closing end
            if start<lastEnd then out.overlapConflict=true end
            if finish>start then out.knownSeconds=out.knownSeconds+math.max(0,finish-math.max(start,lastEnd)) end
            if start>lastEnd then out.gaps=out.gaps+1 end
            lastEnd=math.max(lastEnd,finish)
            if start<=coveredTo then coveredTo=math.max(coveredTo,finish) end
        else out.gaps=out.gaps+1 end
        out.windows[#out.windows+1]={record=w,from=start,through=finish,intact=intact}
        local value=w.opening
        for _,r in ipairs(list) do _auctionTick(); if r.ts<start then value=r.after end end
        out.points[#out.points+1]={ts=start,balance=value,window=w.id,breakBefore=true,observed=intact}
        for _,r in ipairs(list) do _auctionTick(); if r.ts>=start and r.ts<through and r.ts<=finish then
            out.points[#out.points+1]={ts=r.ts,balance=r.after,window=w.id,record=r.id,observed=intact}
        end end
        if finish>start then out.points[#out.points+1]={ts=finish,balance=closing,window=w.id,observed=intact} end
    end end
    if lastEnd<through then out.gaps=out.gaps+1 end
    out.complete=coveredTo>=through and out.gaps==0 and not out.overlapConflict
    if out.overlapConflict then out.opening,out.closing=nil,nil end
    return out
end
function F.Report(c,from,through)
    local out=Q.Finance(c,from,through)
    out.wallet=F.WalletCoverage(c,from,through); out.trading=F.Profit(c,from,through)
    out.operatingIn,out.operatingOut,out.transfers,out.inferred=0,0,0,0
    out.inventoryCashIn,out.inventoryCashOut,out.costs=0,0,{}
    -- Preserve the confirmed-only public fields. Attributed summaries add a
    -- separately reported inferred contribution; no record quality is changed.
    out.inferredOperatingIn,out.inferredOperatingOut,out.inferredOperatingCount=0,0,0
    out.inferredCosts,out.attributedCosts={},{}
    out.auctionDepositsPaid,out.inferredAuctionDepositsPaid=0,0
    out.sourceRows={}
    for _,r in ipairs(out.transactions) do _auctionTick();
        local source,quality=r.source or "unknown",r.quality or "unknown"
        local key=source..":"..quality; local row=out.sourceRows[key] or {source=source,quality=quality,amount=0,count=0,cashIn=0,cashOut=0}
        row.amount=row.amount+r.amount; row.count=row.count+1; out.sourceRows[key]=row
        if r.amount>0 then row.cashIn=row.cashIn+r.amount else row.cashOut=row.cashOut-r.amount end
        if source=='auctionDeposit' and r.amount<0 then
            if quality=='confirmed' then out.auctionDepositsPaid=out.auctionDepositsPaid-r.amount
            elseif quality=='inferred' then out.inferredAuctionDepositsPaid=out.inferredAuctionDepositsPaid-r.amount end
        end
        if quality=="confirmed" then
            if F.operating[source] then if r.amount>0 then out.operatingIn=out.operatingIn+r.amount else out.operatingOut=out.operatingOut-r.amount end
            elseif F.inventoryCash[source] then if r.amount>0 then out.inventoryCashIn=out.inventoryCashIn+r.amount else out.inventoryCashOut=out.inventoryCashOut-r.amount end
            elseif source=="transfer" then out.transfers=out.transfers+r.amount end
            if source=="repair" or source=="training" or source=="travel" or source=="consumables" or source=="auctionFee" then out.costs[source]=(out.costs[source] or 0)-r.amount end
        elseif quality=="inferred" then
            out.inferred=out.inferred+1
            if F.operating[source] then
                out.inferredOperatingCount=out.inferredOperatingCount+1
                if r.amount>0 then out.inferredOperatingIn=out.inferredOperatingIn+r.amount
                else out.inferredOperatingOut=out.inferredOperatingOut-r.amount end
            end
            if source=="repair" or source=="training" or source=="travel" or source=="consumables" or source=="auctionFee" then
                out.inferredCosts[source]=(out.inferredCosts[source] or 0)-r.amount
            end
        end
    end
    out.attributedAuctionDepositsPaid=out.auctionDepositsPaid+out.inferredAuctionDepositsPaid
    out.operatingSurplus=out.operatingIn-out.operatingOut
    if out.operatingIn>0 then out.spendingRatio=out.operatingOut/out.operatingIn*100 end
    out.inferredOperatingSurplus=out.inferredOperatingIn-out.inferredOperatingOut
    out.attributedOperatingIn=out.operatingIn+out.inferredOperatingIn
    out.attributedOperatingOut=out.operatingOut+out.inferredOperatingOut
    out.attributedOperatingSurplus=out.attributedOperatingIn-out.attributedOperatingOut
    if out.attributedOperatingIn>0 then out.attributedSpendingRatio=out.attributedOperatingOut/out.attributedOperatingIn*100 end
    for _,source in ipairs({"repair","training","travel","consumables","auctionFee"}) do _auctionTick();
        if out.costs[source]~=nil or out.inferredCosts[source]~=nil then
            out.attributedCosts[source]=(out.costs[source] or 0)+(out.inferredCosts[source] or 0)
        end
    end
    local intervals,eligible={},{}
    for _,w in ipairs(out.wallet.windows) do _auctionTick(); if w.intact and w.through>w.from then
        intervals[#intervals+1]={w.from,w.through}; eligible[w.record.id]=true
    end end
    local stats=Q.TimeStats(c,from,through,intervals); local allCovered=not out.wallet.overlapConflict
    for _,r in ipairs(out.transactions) do _auctionTick(); if not eligible[r.window] then allCovered=false end end
    if allCovered and (stats.activeSeconds or 0)>0 and stats.knownSeconds>=out.wallet.knownSeconds then
        out.rateActiveSeconds=stats.activeSeconds
        out.cashInPerActiveHour=out.cashIn/stats.activeSeconds*3600; out.netPerActiveHour=out.net/stats.activeSeconds*3600
    end
    out.rateCoverage="Recorded wallet intervals with complete active/AFK observations"
    if out.wallet.complete then
        local previousFrom=F.PreviousStart(from,through); local previous=F.WalletCoverage(c,previousFrom,from)
        if previous.complete then out.previousNet=Q.Finance(c,previousFrom,from).net; out.changeVsPrevious=out.net-out.previousNet end
    end
    return out
end
local function civilDay(ts)
    local d=date("*t",ts); local a=math.floor((14-d.month)/12); local y=d.year+4800-a; local m=d.month+12*a-3
    return d.day+math.floor((153*m+2)/5)+365*y+math.floor(y/4)-math.floor(y/100)+math.floor(y/400)-32045
end
local stockReports=setmetatable({},{__mode="k"})
F.stockAges={{"recent","0-6 local days"},{"week","7-29 local days"},{"month","30-89 local days"},{"old","90+ local days"},{"unknown","Age unknown"}}
local function stockTotals()
    return {quantity=0,pricedQuantity=0,unknownQuantity=0,cost=0,inferredCost=0,inferredQuantity=0}
end
local function addStock(total,quantity,cost,inferred)
    total.quantity=total.quantity+quantity
    if cost==nil then total.unknownQuantity=total.unknownQuantity+quantity
    else
        total.pricedQuantity=total.pricedQuantity+quantity; total.cost=total.cost+cost
        if inferred then total.inferredQuantity=total.inferredQuantity+quantity; total.inferredCost=total.inferredCost+cost end
    end
end
function F.Stock(c,through)
    local state=F.Replay(c,through); local cached=stockReports[c]
    if cached and cached.state==state then return cached.report end
    local out=stockTotals(); out.items={}; out.byItem={}; out.ages={}; out.through=through
    local function latest(kind)
        local rows=Q.Kind(c,kind)
        for i=#rows,1,-1 do _auctionTick(); if rows[i].ts<through then return rows[i]end end
    end
    out.countRecord=latest("inventory")
    local gap=latest("inventory_gap")
    if gap and (not out.countRecord or S.Before(out.countRecord,gap))then out.openGap=gap end
    local asOfDay=civilDay(through-1)
    for _,age in ipairs(F.stockAges)do _auctionTick(); out.ages[age[1]]=stockTotals()end
    for itemID,stock in pairs(state.stock)do _auctionTick();
        local row=stockTotals(); row.itemID=itemID; row.lots={}
        for _,lot in ipairs(stock)do _auctionTick();
            local quantity=lot.quantity-lot.used
            if quantity>0 then
                local cost=F.SliceCost(lot,lot.used,quantity); local inferred=lot.quality=="inferred"
                local days=not lot.unknownAge and lot.acquired and asOfDay-civilDay(lot.acquired) or nil
                if days and days<0 then days=nil end
                local age=not days and "unknown" or days<7 and "recent" or days<30 and "week" or days<90 and "month" or "old"
                addStock(out,quantity,cost,inferred); addStock(row,quantity,cost,inferred); addStock(out.ages[age],quantity,cost,inferred)
                row.lots[#row.lots+1]={record=lot.id,quantity=quantity,cost=cost,inferred=inferred,days=days,age=age,acquired=not lot.unknownAge and lot.acquired or nil}
            end
        end
        if row.quantity>0 then
            row.coverage=row.pricedQuantity/row.quantity*100; out.items[#out.items+1]=row; out.byItem[itemID]=row
        end
    end
    _auctionSort(out.items,function(a,b)if a.cost~=b.cost then return a.cost>b.cost end; return a.itemID<b.itemID end)
    if out.quantity>0 then out.coverage=out.pricedQuantity/out.quantity*100 end
    stockReports[c]={state=state,report=out}; return out
end
function F.PreviousStart(from,through)
    local A=E.API
    if from==A.DayStart(from) and through==A.DayStart(through) then return A.ShiftDay(from,-(civilDay(through)-civilDay(from))) end
    return from-(through-from)
end
F.presets={{"today","Today"},{"yesterday","Yesterday"},{"last3","Last 3 days"},{"last7","Last 7 days"},{"last30","Last 30 days"},
    {"last90","Last 90 days"},{"mtd","MTD"},{"qtd","QTD"},{"ytd","YTD"},{"previousMonth","Previous month"},{"all","All history"}}
function F.Range(c,preset,now,fromText,throughText)
    local A=E.API; local today=A.DayStart(now); local from,through=today,A.ShiftDay(today,1)
    if preset=="custom" then
        local err; from,err=A.ParseDay(fromText); if not from then return nil,err end
        local last; last,err=A.ParseDay(throughText); if not last then return nil,err end
        if last<from then return nil,"Through must be on or after From." end
        through=A.ShiftDay(last,1)
    elseif preset=="yesterday" then from,through=A.ShiftDay(today,-1),today
    elseif preset=="mtd" then from=A.Period(today,"monthly")
    elseif preset=="ytd" then from=A.Period(today,"yearly")
    elseif preset=="qtd" then
        local d=date("*t",today); d.month=math.floor((d.month-1)/3)*3+1; d.day=1; d.isdst=nil; from=time(d)
    elseif preset=="previousMonth" then through=A.Period(today,"monthly"); from=A.ShiftPeriod(through,"monthly",-1)
    elseif preset=="all" then
        from=c.state.firstObserved or now
        for _,kind in ipairs({"gold","balance","cost_lot","item_sale","sale_return","auction","trade","trade_notice","mail","mail_scan","mail_collection","mail_notice"}) do _auctionTick(); local rows=Q.Kind(c,kind)
            if rows[1] then from=math.min(from,rows[1].ts) end
        end
        from=A.DayStart(from)
    elseif preset~="today" then
        local days=tonumber((preset or ""):match("^last(%d+)$"))
        if not days or days<1 or days>366 then return nil,"Choose a supported date range." end
        from=A.ShiftDay(today,1-days)
    end
    return {from=from,through=through,first=A.Day(from),last=A.Day(A.ShiftDay(through,-1)),clock="local",preset=preset}
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="Economy",create=create}
E.AuctionReaderSources["Economy.lua"]="8ab6288bca92335779e116a1dd42bb8f0b6d89a15dd9be4082558167bda6b68c"
end

-- Trades.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Trades';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local T,A,S,C={},E.API,E.Store,E.Collectors;E.Trades=T
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function plain(v)local ok,value=pcall(A.Plain,v);if ok then return value end end
local function text(v)return type(v)=='string'and v~=''and v or nil end
local function live()return T.owner and T.owner==E.current and T.session==C.session end
function T.Diagnose()
    return 'Trade collector: '..(live()and'ready'or'not recording')..'; initialized '..tostring(T.owner~=nil)..
        '; character matches '..tostring(T.owner==E.current)..'; session matches '..tostring(T.session==C.session)..
        '; open '..tostring(T.current~=nil)..'; settling '..tostring(T.pending~=nil)..'; last event '..(T.lastEvent or'none')
end
local function readable(key)return A.status[key]=='call succeeded; client behavior still needs validation'end
local function ref(r,id)if id then for _,v in ipairs(r.refs)do _auctionTick(); if v==id then return end end;r.refs[#r.refs+1]=id end end
local function release()if T.owner then T.owner.state.activeTrade=nil end;T.current=nil;T.pending=nil;T.quiet=0 end
function T.Interrupt(reason)
    local r=T.current or T.pending
    if r and T.owner then r.interrupted=true;r.status='Recording interrupted';r.matchReason=reason;S.Changed(T.owner,r)end
    release()
end
function T.Start(c,session,ownerOnly)
    T.Interrupt('Recording continuity was lost.')
    for _,old in pairs(ownerOnly and {c} or E.db.characters)do _auctionTick(); local r=old.records[old.state.activeTrade]
        if r then r.interrupted=true;r.status='Recording interrupted';r.matchReason='Recording continuity was lost.';S.Changed(old,r)end
        old.state.activeTrade=nil
    end
    T.owner=c;T.session=session;T.lastTime=A.Now()
end
function T.Read()
    local data={player={},target={},complete=true}
    for _,side in ipairs({'player','target'})do _auctionTick();
        local key='tradeMoney'..side
        local money=A.Call(key,side=='player'and GetPlayerTradeMoney or GetTargetTradeMoney)
        if integer(money)and readable(key)then data[side..'Money']=money else data.complete=false end
        for slot=1,7 do _auctionTick();
            key='tradeItem'..side
            local name,texture,quantity,quality,fifth,sixth,seventh,eighth=A.Call(key,side=='player'and GetTradePlayerItemInfo or GetTradeTargetItemInfo,slot)
            local ok=readable(key);local enchant,itemID
            if side=='player'then enchant,itemID=fifth,eighth else enchant,itemID=sixth,seventh end
            local itemLink=A.Call('tradeLink'..side,side=='player'and GetTradePlayerItemLink or GetTradeTargetItemLink,slot)
            ok=ok and readable('tradeLink'..side)
            if text(name)or integer(itemID,1)or text(itemLink)or texture~=nil and texture~=0 then
                local row={slot=slot,name=text(name),itemID=integer(itemID,1)and itemID or nil,
                    quantity=integer(quantity,1)and quantity or nil,quality=integer(quality)and quality or nil,
                    itemLink=text(itemLink),enchantment=text(enchant),serviceSlot=slot==7}
                row.complete=ok and row.itemID~=nil and row.quantity~=nil
                data[side][#data[side]+1]=row;if not row.complete then data.complete=false end
            elseif not ok or name~=nil and name~=''or itemID~=nil and itemID~=0 or quantity~=nil and quantity~=0 then
                data.complete=false;data[side][#data[side]+1]={slot=slot,unavailable=true,serviceSlot=slot==7}
            end
        end
    end
    return data
end
function T.Observe(event,playerAccepted,targetAccepted)
    if not live()or not T.current then return end
    local r=T.current;local data=T.Read()
    local previous=r.offers[#r.offers]and T.owner.records[r.offers[#r.offers]]
    if event=='TRADE_ACCEPT_UPDATE'then
        playerAccepted,targetAccepted=plain(playerAccepted),plain(targetAccepted)
        data.playerAccepted=(playerAccepted==0 or playerAccepted==1)and playerAccepted or nil
        data.targetAccepted=(targetAccepted==0 or targetAccepted==1)and targetAccepted or nil
    end
    -- An update can reset acceptance even when item values look unchanged.
    -- Never carry acceptance flags across an offer refresh.
    r.lastObservedAt=A.Now()
    if not previous or not _auctionSame(previous.offer,data)then
        local inventory=T.owner.state.inventory;local liveInventory=E.Inventory and E.Inventory.live
        local anchor
        if inventory and inventory.record and inventory.session==T.session and liveInventory and liveInventory.c==T.owner
            and liveInventory.session==T.session and liveInventory.continuous and not liveInventory.suspended
            and A.Now()>=inventory.ts and A.Now()-inventory.ts<=15 then
            anchor={record=inventory.record,ts=inventory.ts,sequence=T.owner.seq,scope=inventory.scope,session=T.session}
        end
        local offer=S.Add(T.owner,'trade_offer',A.Now(),{title='Offer with '..(r.partner or'unknown player'),trade=r.id,
            offer=data,event=event,session=T.session,refs=anchor and{r.id,anchor.record}or{r.id},inventoryAnchor=anchor,zone=r.zone,partner=r.partner})
        r.offers[#r.offers+1]=offer.id;ref(r,offer.id)
        if r.completionOffer and r.completionOffer~=offer.id then r.changedAfterCompletion=true end
    end
    S.Changed(T.owner,r);return r
end
function T.Open()
    if not live()then return end
    local old=T.current or T.pending;local overlap=old~=nil
    if old then old.ambiguous=true;T.Interrupt('Another trade opened before the earlier observations settled.')end
    local partner,realm=A.Call('tradePartner',UnitName,'npc')
    partner=text(partner);if partner and text(realm)then partner=partner..'-'..realm end
    local balance=A.Call('tradeWallet',GetMoney)
    if integer(balance)then E.History.Wallet(T.owner,A.Now(),balance,T.session)end
    local r=S.Add(T.owner,'trade',A.Now(),C.Context({title='Trade with '..(partner or'unknown player'),partner=partner,
        partnerGUID=text(A.Call('tradePartnerGUID',UnitGUID,'npc')),session=T.session,status='Open',offers={},wallets={},notices={},refs={},
        walletBefore=integer(balance)and balance or nil,walletWindow=T.owner.state.walletWindow,ambiguous=overlap or nil}))
    ref(r,r.walletWindow);if old then ref(r,old.id)end
    T.current=r;T.owner.state.activeTrade=r.id;T.lastTime=A.Now();T.Observe('TRADE_SHOW');return r
end
function T.Close()
    if not live()or not T.current then return end
    local r=T.current;r.closedAt=A.Now();r.status=r.cancelled and'Cancellation reported'or r.completionAt and'Completion reported (inferred link)'or'Closed / outcome unknown'
    T.current=nil;T.pending=r;T.quiet=0;S.Changed(T.owner,r);return r
end
function T.Info(errorType,message)
    if not live()then return end
    message=plain(message);local complete=plain(ERR_TRADE_COMPLETE)
    if not text(complete)or message~=complete then return end
    local r=T.current or T.pending;local now=A.Now()
    local nearby=r and now>=r.ts and(not r.closedAt or now-r.closedAt>=0 and now-r.closedAt<=2)
    local notice=S.Add(T.owner,'trade_notice',now,{title='Trade completion notification',message=message,errorType=plain(errorType),session=T.session,refs={}})
    if nearby then
        notice.trade=r.id;ref(notice,r.id);r.notices[#r.notices+1]=notice.id;ref(r,notice.id)
        local offer=T.owner.records[r.offers[#r.offers]]
        if not r.ambiguous and not r.cancelled and not r.interrupted and not r.completionAt and offer
            and offer.offer.playerAccepted==1 and offer.offer.targetAccepted==1 then
            r.completionAt=now;r.completionOffer=offer.id;r.completionNotice=notice.id
            r.status='Completion reported (inferred link)'
        end
        S.Changed(T.owner,r)
    end
    S.Changed(T.owner,notice);return notice
end
-- Re-evaluated from retained original records. No item receipt, sale, acquisition
-- cost or enchant completion is manufactured from an offered item.
function T.Accepted(c,r)
    local offer=r and c.records[r.completionOffer];local d=offer and offer.offer
    local notice=r and c.records[r.completionNotice]
    if not r or r.character~=c.id or r.kind~='trade'or r.ambiguous or r.cancelled or r.interrupted or r.changedAfterCompletion
        or not r.closedAt or not r.completionAt or math.abs(r.closedAt-r.completionAt)>2
        or not notice or notice.kind~='trade_notice'or notice.trade~=r.id or notice.session~=r.session or notice.ts~=r.completionAt
        or not d or not d.complete or offer.kind~='trade_offer'or offer.trade~=r.id or offer.session~=r.session
        or r.offers[#r.offers]~=offer.id or d.playerAccepted~=1 or d.targetAccepted~=1
        or not integer(d.playerMoney)or not integer(d.targetMoney)then
        return nil,'No complete, uninterrupted accepted offer and nearby completion match.'
    end
    return offer
end
function T.Plan(c,r)
    local offer,reason=T.Accepted(c,r);if not offer then return nil,reason end
    local d=offer.offer
    if not integer(r.walletBefore)then return nil,'The opening wallet balance is unavailable.'end
    local window=c.records[r.walletWindow]
    if not window or window.kind~='wallet_window'or window.session~=r.session then return nil,'The original wallet observation interval is unavailable.'end
    local expected=d.targetMoney-d.playerMoney
    if expected==0 then return nil,'No net gold was offered; no income or expense is inferred.'end
    local balance=r.walletBefore;local seen={};local rows={}
    for _,id in ipairs(r.wallets or{})do _auctionTick(); local w=c.records[id]
        if seen[id]or not w or w.kind~='gold'or w.session~=r.session or w.window~=r.walletWindow or w.before~=balance or not integer(w.after)
            or w.after-w.before~=w.amount or w.amount*expected<=0 or w.ts<offer.ts or w.ts>r.closedAt+2
            or math.abs(w.ts-r.completionAt)>2 or math.abs(w.ts-r.closedAt)>2
            or S.Sequence(w)<=S.Sequence(offer)then
            return nil,'Wallet observations do not form a matching trade-only chain.'
        end
        seen[id]=true;balance=w.after;rows[#rows+1]=w
    end
    if #rows==0 or balance~=r.walletAfter or balance-r.walletBefore~=expected then return nil,'Observed wallet changes do not match the offered net gold.'end
    return {wallets=rows,offer=offer,amount=expected},'Accepted offer, completion notification and wallet chain match; attribution is inferred.'
end
local dependencies=setmetatable({},{__mode='k'})
local function trackProof(c,p)
    local cache=dependencies[c]or{rows={},windows={}};dependencies[c]=cache
    if type(p.walletID)~='string'then return end
    local function link(id)if type(id)=='string'then cache.rows[id]=cache.rows[id]or{};cache.rows[id][p.walletID]=true end end
    link(p.id);link(p.trade);link(p.walletID)
    local r=c.records[p.trade]
    if r then
        link(r.completionOffer);link(r.completionNotice);link(r.walletWindow)
        for _,key in ipairs({'offers','wallets','refs'})do _auctionTick(); for _,id in ipairs(r[key]or{})do _auctionTick(); link(id)end end
        local w=c.records[r.walletWindow]
        if w then cache.windows[w.id]={kind=w.kind,session=w.session,character=w.character}end
    end
end
E.On('RECORDS_REMOVED',function(c)dependencies[c]=nil end)
function T.ValidProof(c,proof)
    trackProof(c,proof)
    local plan=T.Plan(c,c.records[proof.trade]);if not plan then return false end
    for _,w in ipairs(plan.wallets)do _auctionTick(); if w.id==proof.walletID and w.amount==proof.amount and w.ts==proof.ts and w.session==proof.session then return true end end
    return false
end
function T.Finish(r)
    local c=T.owner;local after=A.Call('tradeWalletAfter',GetMoney);r.walletAfter=integer(after)and after or nil
    local plan,reason=T.Plan(c,r);r.matchReason=reason;r.settledAt=A.Now();S.Changed(c,r)
    if plan then for _,w in ipairs(plan.wallets)do _auctionTick();
        local proof=E.Economy.Evidence(c,w.ts,{title='Trade gold match (inferred)',source='trade',amount=w.amount,walletID=w.id,
            session=r.session,refs={r.id,plan.offer.id,r.completionNotice},trade=r.id},'trade-money:'..r.id..':'..w.id)
        ref(r,proof.id)
    end end
    S.Changed(c,r);release()
end
function T.Tick(delta)
    if not live()then return end
    local now=A.Now()
    if T.lastTime and now<T.lastTime then T.Interrupt('The local clock moved backwards during the trade.')end;T.lastTime=now
    if T.pending then T.quiet=(T.quiet or 0)+(delta or 0);if T.quiet>=3 and now-T.pending.closedAt>=3 then T.Finish(T.pending)end end
end
E.On('RECORD_ADDED',function(c,r)
    local trade=T.current or T.pending
    if live()and c==T.owner and trade and r.kind=='gold'and r.session==T.session then
        trade.wallets[#trade.wallets+1]=r.id;ref(trade,r.id);S.Changed(c,trade)
    end
end)
-- Invalidate linked automatic attribution if its retained evidence changes or
-- expires. Reconciliation also considers competing evidence added later.
local refreshing=false
function T.CheckWallet(c,w)
    if w.kind~='gold'or not w.automaticAttribution or w.source~='trade'then return end
    for _,id in ipairs(w.evidenceRefs or{})do _auctionTick(); local proof=c.records[id]
        if not proof or proof.trade and not T.ValidProof(c,proof)then E.Economy.Attribute(c,w.id,'unknown','unknown',{},true);break end
    end
end
local function recheck(c,r)
    if refreshing or not r then return end
    local cache=dependencies[c];local old=E.Query.PreviousKind(c,r.id)
    local previous=cache and cache.windows[r.id]
    if r.kind=='wallet_window'and previous and previous.kind==r.kind and previous.session==r.session and previous.character==r.character then return end
    refreshing=true
    local rows,seen={},{}
    local function add(id)local w=c.records[id];if w and w.kind=='gold'and not seen[id]then seen[id]=true;rows[#rows+1]=w end end
    if r.kind=='gold'then add(r.id)
    else local trade=(r.kind=='trade'or old=='trade')and r or c.records[r.trade]
        for _,id in ipairs(trade and trade.wallets or{})do _auctionTick(); add(id)end
        for id in pairs(cache and cache.rows[r.id]or{})do _auctionTick(); add(id)end
    end
    local ok,why=pcall(function()for _,w in ipairs(rows)do _auctionTick(); T.CheckWallet(c,w)end end)
    refreshing=false
    if not ok then error(why)end
    if r.kind~='gold'and E.GoldChecks then E.GoldChecks.RequestWallets(c,rows)end
end
E.On('RECORD_CHANGED',recheck)
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)T.lastEvent=event;if old then old(...)end;return fn(...)end end
wrap('TRADE_SHOW',T.Open);wrap('TRADE_CLOSED',T.Close);wrap('UI_INFO_MESSAGE',T.Info)
for _,event in ipairs({'TRADE_UPDATE','PLAYER_TRADE_MONEY','TRADE_MONEY_CHANGED','TRADE_PLAYER_ITEM_CHANGED','TRADE_TARGET_ITEM_CHANGED','TRADE_ACCEPT_UPDATE'})do _auctionTick();
    local key=event;wrap(key,function(...)return T.Observe(key,...)end)
end
wrap('TRADE_REQUEST_CANCEL',function()if live()then local r=T.current or T.pending;if r then r.cancelled=true;r.status='Cancellation reported';S.Changed(T.owner,r);if T.current then T.Close()end end end end)
wrap('PLAYER_LEAVING_WORLD',function()if live()then T.Interrupt('World transition interrupted the trade recording.')end end)
wrap('PLAYER_LOGOUT',function()T.Interrupt('Recording ended before reconciliation.');T.owner=nil end)

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="Trades",create=create}
E.AuctionReaderSources["Trades.lua"]="e69aa92b2e8900406ef0234a54b065ad0dd17d720374907670d2681781c4c63d"
end

-- Mail.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Mail';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local M,A,S,C={},E.API,E.Store,E.Collectors;E.Mail=M
local hooks={};local methods={TakeInboxMoney=true,TakeInboxItem=true,AutoLootMailItem=true,SendMail=true,DeleteInboxItem=true,ReturnInboxItem=true}
local function integer(n,min)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=9007199254740991 end
local function text(v)return type(v)=='string'and v~=''and v or nil end
local function plain(v)local ok,value,hidden=pcall(A.Plain,v);if ok then return value,hidden end;return nil,true end
local function readOK(key)return A.status[key]=='call succeeded; client behavior still needs validation'end
local function live()return M.owner and M.owner==E.current and M.session==C.session end
local function ref(r,id)if not id then return end;r.refs=r.refs or{};for _,v in ipairs(r.refs)do _auctionTick(); if v==id then return end end;r.refs[#r.refs+1]=id end
local function release()if M.owner then M.owner.state.activeMailCollection=nil end;M.pending=nil;M.quiet=0 end
function M.Close(reason,ownerChanged)
 if M.draft and M.owner then
  M.draft.interrupted=true
  if ownerChanged then M.draft.interruptionObservedAt=A.Now() else M.draft.closedAt=A.Now() end
  S.Changed(M.owner,M.draft)
 end
 if M.owner then M.owner.state.activeMailDraft=nil end;M.draft=nil
 if M.pending then M.pending.interrupted=true;M.pending.status=reason or'Mailbox closed before reconciliation';S.Changed(M.owner,M.pending)end
 release();if M.owner then M.owner.state.activeMailbox=nil end
 M.open=false;M.job=nil;M.dirty=false;M.last=nil;M.wallet=nil;M.dirtySinceRead=true;M.sendIntent={}
end
function M.Start(c,session,ownerOnly)
 M.Close('Recording restarted')
 for _,old in pairs(ownerOnly and {c} or E.db.characters)do _auctionTick(); local r=old.records[old.state.activeMailCollection]
  if r then r.interrupted=true;r.status='Recording interrupted';S.Changed(old,r)end
  old.state.activeMailCollection=nil;old.state.activeMailbox=nil
  local draft=old.records[old.state.activeMailDraft];if draft then draft.interrupted=true;S.Changed(old,draft)end;old.state.activeMailDraft=nil
 end
 M.owner=c;M.session=session;M.visitCount=0;M.elapsed=0;M.idle=0;M.lastTime=A.Now();M.generation=0
 M.InstallHooks()
end
function M.Dirty()
 if not live()or not M.open then return end
 M.generation=M.generation+1;M.job=nil;M.dirty=true;M.dirtySinceRead=true
end
function M.Open()
 if not live()then return end
 M.Close('Mailbox reopened');M.open=true;M.visitCount=M.visitCount+1;M.visit=M.session..':mail:'..M.visitCount
 M.InstallHooks();M.Dirty();M.ObserveDraft()
end
function M.SendItems()
 local out={items={},complete=true}
 for n=1,12 do _auctionTick();
  local present=A.Call('outgoingAttachmentPresent',HasSendMailItem,n)
  if present==true then
   local name,id,_,count,quality=A.Call('outgoingAttachment',GetSendMailItem,n)
   local item={slot=n,name=text(name),itemID=integer(id,1)and id or nil,quantity=integer(count,1)and count or nil,quality=integer(quality)and quality or nil}
   if not readOK('outgoingAttachment')or not item.itemID or not item.quantity then out.complete=false end
   out.items[#out.items+1]=item
  elseif present~=false or not readOK('outgoingAttachmentPresent')then out.complete=false end
 end
 return out
end
function M.ObserveDraft(snapshot)
 if not live()or not M.open then return end
 local c,now=M.owner,A.Now();snapshot=snapshot or M.SendItems()
 local r=M.draft
 if not r then
  local a=c.state.inventory;local w=E.Inventory and E.Inventory.live;local anchor
  if snapshot.complete and #snapshot.items==0 and a and a.record and a.session==M.session and w and w.c==c and w.session==M.session
   and w.continuous and not w.suspended and now>=a.ts and now-a.ts<=15 then
   anchor={record=a.record,ts=a.ts,sequence=c.seq,scope=a.scope,session=M.session}
  end
  r=S.Add(c,'mail_draft',now,{title='Outgoing attachment observations',session=M.session,visit=M.visit,inventoryAnchor=anchor,snapshots={},refs={}})
  ref(r,anchor and anchor.record);M.draft=r;c.state.activeMailDraft=r.id
 end
 local last=r.snapshots[#r.snapshots]
 if not last or not _auctionSame(last.data,snapshot)then r.snapshots[#r.snapshots+1]={ts=now,data=_auctionCopy(snapshot)};S.Changed(c,r)end
 return r,#r.snapshots
end
function M.Read(index)
 local _,_,sender,subject,money,cod,days,itemCount,wasRead,returned,_,reply,gm=A.Call('mailHeader',GetInboxHeaderInfo,index)
 local d={sender=text(sender),subject=text(subject),money=integer(money)and money or nil,cod=integer(cod)and cod or nil,
  daysLeft=type(days)=='number'and days>=0 and days or nil,itemCount=integer(itemCount)and itemCount or nil,
  wasRead=type(wasRead)=='boolean'and wasRead or nil,returned=type(returned)=='boolean'and returned or nil,
  canReply=type(reply)=='boolean'and reply or nil,isGM=type(gm)=='boolean'and gm or nil,items={}}
 if itemCount==nil and readOK('mailHeader')and d.sender and d.subject then d.itemCount=0 end
 d.complete=readOK('mailHeader')and d.sender~=nil and d.subject~=nil and d.money~=nil and d.cod~=nil and d.itemCount~=nil
 for slot=1,16 do _auctionTick();
  local name,id,texture,quantity,quality,usable,currency=A.Call('mailAttachment',GetInboxItem,index,slot)
  local ok=readOK('mailAttachment')
  if name~=nil or id~=nil or texture~=nil and texture~=0 then
   local link=A.Call('mailItemLink',GetInboxItemLink,index,slot)
   local row={slot=slot,name=text(name),quantity=integer(quantity,1)and quantity or nil,quality=integer(quality)and quality or nil,isCurrency=currency==true}
   if integer(id,1)then if currency==true then row.currencyID=id else row.itemID=id end end
   row.itemLink=text(link);row.complete=ok and readOK('mailItemLink')and row.quantity~=nil and(row.itemID~=nil or row.currencyID~=nil)
   if currency~=nil and type(currency)~='boolean'then row.complete=false end
   d.items[#d.items+1]=row;if not row.complete then d.complete=false end
  elseif not ok then d.items[#d.items+1]={slot=slot,unavailable=true};d.complete=false end
 end
 if d.itemCount~=#d.items then d.complete=false end
 local kind,itemName,player,bid,buyout,deposit,cut,delay,hour,minute,count,commerce=A.Call('mailInvoice',GetInboxInvoiceInfo,index)
 if not readOK('mailInvoice')then d.complete=false;d.invoiceUnavailable=true
 elseif kind~=nil then
  local invoice={type=text(kind),itemName=text(itemName),player=text(player),commerce=type(commerce)=='boolean'and commerce or nil}
  for key,value in pairs({bid=bid,buyout=buyout,deposit=deposit,cut=cut,count=count,moneyDelay=delay,etaHour=hour,etaMinute=minute})do _auctionTick(); if integer(value)then invoice[key]=value end end
  d.invoice=invoice
 end
 return d
end
function M.Comparable(d,ignoreMoney)
 local copy=_auctionCopy(d);copy.daysLeft=nil;copy.wasRead=nil
 if ignoreMoney then copy.money=nil end
 return copy
end
function M.Snapshot(job)
 if not live()or job.generation~=M.generation then return end
 local c=M.owner;local previous=M.last and c.records[M.last];local same=previous and previous.loaded==job.loaded and previous.total==job.total and previous.complete==job.complete and #previous.entries==#job.rows
 if same then for i,d in ipairs(job.rows)do _auctionTick(); local row=c.records[previous.entries[i]];if not row or not _auctionSame(M.Comparable(row.mailData),M.Comparable(d))then same=false;break end end end
 local scan
 if same then scan=previous;scan.lastObservedAt=A.Now();S.Changed(c,scan)
 else
  scan=S.Add(c,'mail_scan',job.started,{title='Mailbox observation',loaded=job.loaded,total=job.total,complete=job.complete,entries={},session=M.session,visit=M.visit,
   finishedAt=A.Now(),lastObservedAt=A.Now(),refs={}})
  for i,d in ipairs(job.rows)do _auctionTick(); local r=S.Add(c,'mail',job.started,{title=d.subject or'Mail details unavailable',sender=d.sender,mailData=d,index=i,scan=scan.id,session=M.session,visit=M.visit,refs={scan.id}})
   scan.entries[#scan.entries+1]=r.id;ref(scan,r.id)
  end
  S.Changed(c,scan)
 end
 M.last=scan.id;M.dirtySinceRead=false;c.state.activeMailbox=scan.id
 if M.pending and S.Sequence(scan)>M.pending.lastRequestSequence then M.pending.afterScan=scan.id;ref(M.pending,scan.id);S.Changed(c,M.pending)end
 A.status.mail='Mailbox observations retained; '..#job.rows..' rows; '..(job.complete and'complete loaded list'or'partial or unavailable coverage')
 return scan
end
function M.Request(method,index,slot)
 if not live()or not M.open or not methods[method]then return end
 local now=A.Now();local c=M.owner;local batch=M.pending
 if batch and now-batch.lastRequestAt>10 then batch.interrupted=true;batch.status='Collection continuity lost';S.Changed(c,batch);release();batch=nil end
 if not batch then
  local prior=M.last and c.records[M.last];local anchor=M.wallet
  local valid=prior and not M.dirtySinceRead and now>=prior.lastObservedAt and now-prior.lastObservedAt<=15
  local inventory=c.state.inventory;local liveInventory=E.Inventory and E.Inventory.live;local inventoryAnchor
  if inventory and inventory.record and inventory.session==M.session and liveInventory and liveInventory.c==c and liveInventory.session==M.session
   and liveInventory.continuous and not liveInventory.suspended and now>=inventory.ts and now-inventory.ts<=15 then
   inventoryAnchor={record=inventory.record,ts=inventory.ts,sequence=c.seq,scope=inventory.scope,session=M.session}
  end
  batch=S.Add(c,'mail_collection',now,{title='Mailbox collection',status='Requests observed / settlement unknown',session=M.session,visit=M.visit,
   beforeScan=valid and prior.id or nil,walletAnchor=anchor and _auctionCopy(anchor),inventoryAnchor=inventoryAnchor,requests={},notices={},wallets={},refs={}})
  ref(batch,inventoryAnchor and inventoryAnchor.record)
  ref(batch,batch.beforeScan);ref(batch,anchor and anchor.window);M.pending=batch;c.state.activeMailCollection=batch.id
  if anchor then for _,w in ipairs(E.Query.Range(c,anchor.ts,now+1,'gold'))do _auctionTick(); if S.Sequence(w)>anchor.sequence then batch.wallets[#batch.wallets+1]=w.id;ref(batch,w.id)end end end
 end
 local i,hidden=plain(index);local part,partHidden=plain(slot)
 local sendData
 if method=='SendMail'then
  local price=A.Call('outgoingPostage',GetSendMailPrice)
  local intent=M.sendIntent or{}
  sendData={postageQuote=integer(price)and price or nil,moneyRequested=intent.money,codRequested=intent.cod,items={},attachmentsComplete=true,
   coverage='Intent setters and post-request attachment snapshot; delivery and consumption unknown'}
  local snapshot=M.SendItems();sendData.items=snapshot.items;sendData.attachmentsComplete=snapshot.complete
  local draft,position=M.ObserveDraft(snapshot);sendData.draft=draft and draft.id;sendData.draftSnapshot=position
 end
 local request=S.Add(c,'mail_request',now,{title=method=='SendMail'and'Send-mail request'or'Mailbox request',sendData=sendData,method=method,index=integer(i,1)and i or nil,
  slot=method=='TakeInboxItem'and integer(part,1)and part or nil,recipient=method=='SendMail'and text(i)or nil,
  subject=method=='SendMail'and text(part)or nil,unavailable=hidden or partHidden,collection=batch.id,session=M.session,visit=M.visit,refs={batch.id}})
 batch.requests[#batch.requests+1]=request.id;ref(batch,request.id);batch.lastRequestAt=now;batch.lastRequestSequence=S.Sequence(request)
 if method=='SendMail'then
  ref(request,sendData.draft);ref(batch,sendData.draft)
  if M.draft then M.draft.requests=M.draft.requests or{};M.draft.requests[#M.draft.requests+1]=request.id;ref(M.draft,request.id);S.Changed(c,M.draft)end
  batch.sendRequest=request.id;batch.recipient=request.recipient;batch.subject=request.subject;batch.title='Outgoing mail to '..(request.recipient or'unknown recipient')
  M.sendIntent={}
 end
 if #batch.requests>100 then batch.overflow=true end
 M.quiet=0;M.Dirty();S.Changed(c,batch);return request
end
function M.Notify(event,itemID)
 if not live()or not M.open then return end
 local id,hidden=plain(itemID);local r=S.Add(M.owner,'mail_notice',A.Now(),{title=event=='MAIL_SUCCESS'and'Mail operation succeeded'or event=='MAIL_FAILED'and'Mail operation failed'or'Mail sending succeeded',
  event=event,itemID=integer(id,1)and id or nil,unavailable=hidden or(id~=nil and not integer(id,1)),session=M.session,visit=M.visit,refs={}})
 local b=M.pending
 if b and r.ts>=b.ts and r.ts-b.lastRequestAt<=5 then
  r.collection=b.id;ref(r,b.id);b.notices[#b.notices+1]=r.id;ref(b,r.id)
  if event=='MAIL_FAILED'then b.failed=true end;S.Changed(M.owner,b);S.Changed(M.owner,r)
  if event=='MAIL_SEND_SUCCESS'and M.draft then M.draft.closedAt=r.ts;M.draft.successNotice=r.id;ref(M.draft,r.id);S.Changed(M.owner,M.draft);M.draft=nil;M.owner.state.activeMailDraft=nil end
 end
 M.Dirty();return r
end
function M.InstallHooks()
 if type(hooksecurefunc)~='function'then return end
 for name,key in pairs({SetSendMailMoney='money',SetSendMailCOD='cod'})do _auctionTick(); if not hooks[name]and type(_G[name])=='function'then
  local field=key;local ok=pcall(hooksecurefunc,name,function(raw)
   if not E.RecorderReady() or not live() or not M.open then return end
   local value,hidden=plain(raw);M.sendIntent=M.sendIntent or{};M.sendIntent[field]=not hidden and integer(value)and value or nil
  end);if ok then hooks[name]=true end
 end end
 for name in pairs(methods)do _auctionTick(); if not hooks[name]and type(_G[name])=='function'then local method=name
  local ok=pcall(hooksecurefunc,name,function(...)
   if not E.RecorderReady() then return end
   local success=pcall(M.Request,method,...)
   if not success then A.status.mail='Mail request could not be recorded; no settlement inferred'end
  end)
  if ok then hooks[name]=true end
 end end
end
function M.Finish()
 local b=M.pending;if not b then return end
 local amount=A.Call('mailWallet',GetMoney);if integer(amount)then E.History.Wallet(M.owner,A.Now(),amount,M.session);b.walletAfter=amount end
 b.settledAt=A.Now();S.Changed(M.owner,b)
 local plan,reason=E.MailMoney.Plan(M.owner,b);local receipt=E.MailCosts and E.MailCosts.Plan(M.owner,b)
 local sent,sentReason=E.SentMailCosts.Resolve(M.owner,b)
 b.matchReason=not plan and sent and sentReason or reason;b.status=plan and'Gold matched (inferred)'or sent and'Outgoing items matched (inferred)'or receipt and'Items matched (inferred)'or'Unresolved collection';S.Changed(M.owner,b)
 if plan then for _,w in ipairs(plan.wallets)do _auctionTick(); local proof=E.Economy.Evidence(M.owner,w.ts,{title=plan.outgoing and'Outgoing mail match (inferred)'or'Mail collection match (inferred)',amount=w.amount,source=plan.source,session=b.session,
  walletID=w.id,mailCollection=b.id,refs={b.id,b.beforeScan,b.afterScan}},'mail-money:'..b.id..':'..w.id);ref(b,proof.id)end end
 S.Changed(M.owner,b);release()
 if integer(amount)then M.wallet={amount=amount,ts=A.Now(),sequence=M.owner.seq,window=M.owner.state.walletWindow,session=M.session}end
end
function M.Tick(delta)
 if not live()or not M.open then return end
 local now=A.Now()
 if now<M.lastTime then M.Close('Local clock moved backwards');return end;M.lastTime=now
 M.elapsed=(M.elapsed or 0)+(delta or 0);M.idle=(M.idle or 0)+(delta or 0);M.quiet=(M.quiet or 0)+(delta or 0)
 if M.elapsed<.1 then return end;M.elapsed=0
 if not M.pending then
  local amount=A.Call('mailWallet',GetMoney)
  if integer(amount)then
   local last=M.owner.state.wallet
   if not last or last.amount~=amount or last.session~=M.session or now-last.ts>=1 then E.History.Wallet(M.owner,now,amount,M.session)end
   M.wallet={amount=amount,ts=now,sequence=M.owner.seq,window=M.owner.state.walletWindow,session=M.session}
  end
 end
 if M.idle>=5 and not M.job then M.idle=0;M.dirty=true end
 if M.dirty then
  M.dirty=false;local loaded,total=A.Call('mailCount',GetInboxNumItems)
  if integer(loaded)then M.job={started=now,generation=M.generation,loaded=loaded,total=integer(total)and total or nil,complete=readOK('mailCount')and loaded==total and loaded<=100,limit=math.min(loaded,100),index=1,rows={}}
  else A.status.mail='Inbox count unavailable; no empty history inferred'end
 end
 local job=M.job
 if job then
  for _=1,4 do _auctionTick();
   if job.index>job.limit then
    local loaded,total=A.Call('mailCount',GetInboxNumItems)
    if loaded==job.loaded and total==job.total and readOK('mailCount')then M.Snapshot(job)else M.Dirty()end
    if M.job==job then M.job=nil end;break
   end
   local d=M.Read(job.index);job.rows[#job.rows+1]=d;if not d.complete then job.complete=false end;job.index=job.index+1
   if M.job~=job or job.generation~=M.generation then return end
  end
 end
 if M.pending and M.quiet>=3 and now-M.pending.lastRequestAt>=3 and not M.job and not M.dirty then M.Finish()end
end
E.On('RECORD_ADDED',function(c,r)
 local b=M.pending;if b and c==M.owner and r.kind=='gold'then b.wallets[#b.wallets+1]=r.id;ref(b,r.id);S.Changed(c,b)end
end)
function M.Diagnose()return 'Mail collector: '..(live()and'ready'or'not recording')..'; mailbox '..tostring(M.open==true)..'; pending '..tostring(M.pending~=nil)..'; '..(A.status.mail or'awaiting mailbox')end
local function wrap(event,fn)local old=C.handlers[event];C.handlers[event]=function(...)if old then old(...)end;return fn(...)end end
wrap('MAIL_SHOW',M.Open);wrap('MAIL_CLOSED',function()M.Close('Mailbox closed')end);wrap('MAIL_INBOX_UPDATE',M.Dirty)
wrap('MAIL_SEND_INFO_UPDATE',function()M.ObserveDraft()end)
for _,event in ipairs({'MAIL_SUCCESS','MAIL_FAILED','MAIL_SEND_SUCCESS'})do _auctionTick(); local name=event;wrap(name,function(...)return M.Notify(name,...)end)end
wrap('PLAYER_LEAVING_WORLD',function()M.Close('World changed')end)
wrap('PLAYER_LOGOUT',function()M.Close('Recording ended');M.owner=nil end)

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="Mail",create=create}
E.AuctionReaderSources["Mail.lua"]="cea7f719ffa567b69eaf046d3bc5a5937fa4eed8a3e7db919a196ab96cf08024"
end

-- Buyback.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='Buyback';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local B,S,Q={},E.Store,E.Query; E.Buyback=B
-- Receipt provenance only. This does not create a return, restore a cost, or
-- prove which physical stack satisfied a net bag-count observation.
local caches=setmetatable({},{__mode="k"})
local function invalidate(c,r)if not r or not Q.IsWarm(c) or r.kind=="merchant" or Q.PreviousKind(c,r.id)=="merchant" then caches[c]=nil end end
E.On("RECORD_ADDED",invalidate);E.On("RECORD_CHANGED",invalidate)
E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
local function integer(n,min,max)return type(n)=="number" and n==n and n%1==0 and n>=min and n<=(max or 9007199254740991)end
local function queueValid(q)
    if type(q)~="table" or #q>12 then return false end
    local count=0
    for i,v in pairs(q)do _auctionTick();
        if not integer(i,1,12) or type(v)~="table" or not integer(v.itemID,1) or not integer(v.quantity,1,67108864) or not integer(v.amount,0) then return false end
        count=count+1
    end
    return count==#q
end
local function usable(c,r)
    return r and r.character==c.id and r.kind=="merchant" and r.status=="matched observations" and not r.overflow
        and type(r.merchantVisit)=="string" and type(r.session)=="string"
        and type(r.observedFrom)=="number" and type(r.observedThrough)=="number" and r.observedFrom<=r.ts and r.ts<=r.observedThrough
        and queueValid(r.buybackBefore) and queueValid(r.buybackAfter) and type(r.attempts)=="table" and #r.attempts>0 and #r.attempts<=100
end
local function prior(c,r)
    local p=r.previousMerchant and c.records[r.previousMerchant]
    if usable(c,p) and p.merchantVisit==r.merchantVisit and p.session==r.session
        and p.observedThrough<=r.observedFrom and S.Sequence(p)<S.Sequence(r)
        and integer(p.observedThroughSequence,0) and p.observedThroughSequence<S.Sequence(r)
        and _auctionSame(p.buybackAfter,r.buybackBefore) then return p end
end
local function apply(r,previous)
    local queue=_auctionCopy(r.buybackBefore);local origins={};local returns={}
    for i=1,#queue do _auctionTick(); origins[i]=previous and previous.queue[i] or false end
    for i,op in ipairs(r.attempts)do _auctionTick();
        if type(op)~="table" or op.invalid then return false end
        if op.source=="vendorSale" then
            if not integer(op.itemID,1) or not integer(op.quantity,1,67108864) or not integer(op.amount,0) then return false end
            queue[#queue+1]={itemID=op.itemID,quantity=op.quantity,amount=op.amount}
            origins[#origins+1]={receipt=r.id,attempt=i,itemID=op.itemID,quantity=op.quantity,amount=op.amount,quality="inferred"}
            if #queue>12 then table.remove(queue,1);table.remove(origins,1)end
        elseif op.source=="buyback" then
            if #r.attempts~=1 or not integer(op.buybackIndex,1,#queue) or type(op.amount)~="number" then return false end
            local entry=queue[op.buybackIndex]
            if entry.itemID~=op.itemID or entry.quantity~=op.quantity or entry.amount~=-op.amount then return false end
            returns[i]=origins[op.buybackIndex] or false
            table.remove(queue,op.buybackIndex);table.remove(origins,op.buybackIndex)
        elseif op.source~="vendorPurchase" and op.source~="repair" then return false end
    end
    if not _auctionSame(queue,r.buybackAfter) then return false end
    return {queue=origins,returns=returns}
end
function B.Origins(c,r)
    if not usable(c,r) then return {},"Buyback history is unavailable or the merchant observations are unverified." end
    local cache=caches[c];if not cache then cache={};caches[c]=cache end
    local chain,seen={},{};local current=r
    while current and cache[current.id]==nil do _auctionTick();
        if seen[current.id]then return {},"The merchant history contains a cycle." end
        seen[current.id]=true;chain[#chain+1]=current;current=prior(c,current)
    end
    local state=current and cache[current.id] or nil
    for i=#chain,1,-1 do _auctionTick();
        local entry=chain[i];state=apply(entry,state);cache[entry.id]=state
    end
    local result=cache[r.id]
    if not result then return {},"Recorded buyback-list changes do not match the requests." end
    return _auctionCopy(result.returns),"A matching buyback-list history identifies the earlier sale request; the link is inferred, not a restored FIFO cost."
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="Buyback",create=create}
E.AuctionReaderSources["Buyback.lua"]="cf90d6bc8f2390ae67b497e3847c0fbc45c90cfe4c81b7bcda72c004b8135cff"
end

-- AuctionCosts.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='AuctionCosts';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.AuctionCosts=K
-- A derived posting association, never an accepted-action callback or a sale.
local caches=setmetatable({},{__mode='k'})
local relevant={auction=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,merchant=true,
 trade=true,trade_offer=true,trade_notice=true,mail_collection=true,mail=true,mail_scan=true,mail_request=true,mail_notice=true,mail_draft=true,gold=true,money_evidence=true,wallet_window=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function counts(r)
 if not r or r.kind~='inventory'or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
 local out={};for _,map in ipairs({r.carried,r.equipment})do _auctionTick(); for id,n in pairs(map)do _auctionTick();
  if not integer(id,1)or not integer(n)or n>67108864 then return end;out[id]=(out[id]or 0)+n;if out[id]>67108864 then return end
 end end;return out
end
local function equal(a,b)
 for id,n in pairs(a)do _auctionTick(); if n~=(b[id]or 0)then return false end end
 for id,n in pairs(b)do _auctionTick(); if n~=(a[id]or 0)then return false end end;return true
end
local ownedIndexes=setmetatable({},{__mode='k'})
local function invalidateOwned(c)ownedIndexes[c]=nil end
E.On('RECORD_ADDED',invalidateOwned);E.On('RECORD_CHANGED',invalidateOwned);E.On('RECORDS_REMOVED',invalidateOwned)
local function firstOwned(c,id,session)
 local index=ownedIndexes[c]
 if not index or index.revision~=c.revision then
  index={revision=c.revision,ids={}}
  for _,v in ipairs(Q.Kind(c,'auction'))do _auctionTick();
   if v.source=='owned'and integer(v.auctionID,1)and v.session~=nil then
    local sessions=index.ids[v.auctionID];if not sessions then sessions={};index.ids[v.auctionID]=sessions end
    local first=sessions[v.session];if not first or v.ts<first then sessions[v.session]=v.ts end
   end
  end
  ownedIndexes[c]=index
 end
 local sessions=index.ids[id];return sessions and sessions[session]
end
local function build(c,r)
 if not r or r.kind~='auction'or r.source~='post'or r.character~=c.id or not r.session then return end
 local d=r.auctionData or{};local a=r.inventoryAnchor
 if d.requestMethod~='PostItem'and d.requestMethod~='PostCommodity'then return end
 if d.coverage~='request arguments observed'or not integer(r.itemID,1)or d.itemID~=r.itemID or not integer(d.quantity,1)or d.quantity>67108864
  or not a or a.session~=r.session or a.scope~='bags and equipment'or not integer(a.sequence)or type(a.ts)~='number'
  or a.ts>r.ts or r.ts-a.ts>15 or a.sequence>=S.Sequence(r)then return end
 local base=c.records[a.record];local current=counts(base)
 if not current or base.character~=c.id or base.session~=r.session or base.ts>a.ts or S.Sequence(base)>a.sequence or(current[r.itemID]or 0)<d.quantity then return end
 local created,listing;local observations=Q.Range(c,r.ts-5,r.ts+6,'auction')
 for _,v in ipairs(observations)do _auctionTick(); if v.session==r.session then
  -- Even an unreadable competing request can own the creation notification.
  if v.source=='post'and v.id~=r.id then return end
  if v.source=='created'and v.ts>=r.ts then
   if created or not integer(v.auctionID,1)or not v.auctionData or v.auctionData.event~='AUCTION_HOUSE_AUCTION_CREATED'then return end;created=v
  end
 end end
 if not created then return end
 for _,v in ipairs(observations)do _auctionTick(); if v.session==r.session and v.source=='owned'and v.auctionID==created.auctionID then
  if v.ts<r.ts then return end
  if not listing or S.Before(v,listing)then listing=v end
 end end
 local ld=listing and listing.auctionData
 if not ld or listing.itemID~=r.itemID or ld.quantity~=d.quantity or(ld.statusLabel~='Active'and ld.statusLabel~='Reported sold')then return end
 -- A prior observation of this ID in the same session contradicts a new post.
 local prior=firstOwned(c,created.auctionID,r.session);if prior and prior<r.ts then return end
 local successors={}
 for _,v in ipairs(Q.Range(c,a.ts,r.ts+6,'inventory'))do _auctionTick(); if v.previousRecord and S.Sequence(v)>a.sequence then
  if successors[v.previousRecord]~=nil then successors[v.previousRecord]=false else successors[v.previousRecord]=v end
 end end
 local plan={request=r,created=created,listing=listing,records={},rows={},quantity=d.quantity,itemID=r.itemID,refs={base.id,created.id,listing.id}}
 local previous,stamp,sequence,left=base.id,a.ts,a.sequence,d.quantity
 while left>0 do _auctionTick();
  local v=successors[previous];local actual=counts(v)
  if not actual or v.character~=c.id or v.baseline or v.session~=r.session or S.Sequence(v)<=sequence or S.Sequence(v)<=S.Sequence(r)
   or not v.observedFrom or v.observedFrom<stamp or v.ts<v.observedFrom or v.ts<r.ts or(v.accountingTime or v.ts)~=v.ts
   or not _auctionSame(base.equipment,v.equipment)or #(v.items or{})~=1 then return end
  local row=v.items[1]
  if row.itemID~=r.itemID or not integer(row.before)or not integer(row.after)or row.before~=(current[r.itemID]or 0)
   or row.delta~=row.after-row.before or row.delta>=0 or -row.delta>left then return end
  current[r.itemID]=row.after;if not equal(current,actual)then return end
  plan.records[#plan.records+1]=v;plan.rows[v.id]={quantity=-row.delta,offset=d.quantity-left};plan.refs[#plan.refs+1]=v.id
  left=left+row.delta;previous,stamp,sequence=v.id,v.ts,S.Sequence(v)
 end
 if successors[previous]~=nil then return end
 for _,gap in ipairs(Q.Range(c,a.ts,r.ts+6,'inventory_gap'))do _auctionTick(); if S.Sequence(gap)>a.sequence then return end end
 return plan
end
function K.Plan(c,r)
 if not r then return end;local cache=caches[c];if not cache then cache={};caches[c]=cache end
 if cache[r.id]==nil then cache[r.id]=build(c,r)or false end;return cache[r.id]or nil
end
function K.Claim(c,inv)
 if not inv or inv.kind~='inventory'then return false end
 for _,r in ipairs(Q.Range(c,inv.ts-5,inv.ts+1,'auction'))do _auctionTick(); local p=K.Plan(c,r);if p and p.rows[inv.id]then return true end end
 return false
end
function K.Resolve(c,r)
 local plan=K.Plan(c,r);if not plan then return nil,'No unique posting and inventory match.'end
 -- Rejection hides the derived association, never the conflicting source
 -- evidence. Claim intentionally continues to use Plan so another matcher
 -- cannot relabel the same outflow merely because this inference was rejected.
 if r.rejectPostingCosts then return nil,'This inferred posting-cost match was rejected.'end
 for _,inv in ipairs(plan.records)do _auctionTick();
  if E.CraftCosts and E.CraftCosts.Claim(c,inv)then return nil,'Crafting and auction evidence overlap; item costs remain unknown.'end
  if E.SentMailCosts and E.SentMailCosts.Claim(c,inv)then return nil,"Outgoing mail and auction evidence overlap."end
  if E.TradeCosts.Claim(c,inv)or E.MailCosts.Claim(c,inv)then return nil,'Trade or mail also claims this inventory interval.'end
  for _,id in ipairs(inv.merchantCandidates or{})do _auctionTick(); if E.CostMatch.Compatible(c,inv,c.records[id])then return nil,'Merchant evidence overlaps this posting.'end end
  for _,bank in ipairs(Q.Range(c,inv.ts,inv.ts+1,'bank'))do _auctionTick(); if bank.inventoryRecord==inv.id and #(bank.transfers or{})>0 then return nil,'Bank evidence overlaps this posting.'end end
 end
 return plan,'Inferred from a unique request, new-auction notification, listing and continuous inventory changes.'
end
function K.Info(c,r)
 local plan,reason=K.Resolve(c,r);if not plan then return nil,reason end
 local out={plan=plan,quantity=plan.quantity,knownCost=0,unknownQuantity=0,parts={},movements={}}
 for _,inv in ipairs(plan.records)do _auctionTick(); local raw
  for _,id in ipairs(inv.refs or{})do _auctionTick(); local v=c.records[id]
   if v and v.kind=='stock_move'and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==plan.itemID and v.quantity==plan.rows[inv.id].quantity then
    if raw then return nil,'More than one accounting movement claims this inventory record.'end;raw=v
   end
  end
  if not raw then return nil,'The original inventory accounting movement is unavailable.'end
  local info=F.MovementAllocation(c,raw)
  if not info then return nil,'The original FIFO allocation is unavailable.'end
  out.movements[#out.movements+1]=raw;out.knownCost=out.knownCost+info.knownCost;out.unknownQuantity=out.unknownQuantity+info.unknownQuantity
  for _,part in ipairs(info.allocations)do _auctionTick(); out.parts[#out.parts+1]=_auctionCopy(part)end
 end
 if out.unknownQuantity==0 then out.cost=out.knownCost end
 return out,reason
end
local linking=setmetatable({},{__mode='k'})
local function linkAt(c,ts)
 for _,post in ipairs(Q.Range(c,ts-5,ts+6,'auction'))do _auctionTick(); local p=K.Plan(c,post)
  if p then local changed=false;local seen={};for _,id in ipairs(post.refs or{})do _auctionTick(); seen[id]=true end;post.refs=post.refs or{}
   for _,id in ipairs(p.refs)do _auctionTick(); if not seen[id]then post.refs[#post.refs+1]=id;seen[id]=true;changed=true end end
   if changed then S.Changed(c,post)end
  end
 end
end
function K.LinkAt(c,ts)
 if linking[c]then return end
 linking[c]=true
 local ok,why=pcall(linkAt,c,ts)
 linking[c]=nil
 if not ok then error(why,0)end
end
local function link(c,r)
 if (r.kind~='auction'and r.kind~='inventory')or E.db.characters[c.id]~=c then return end
 if Q.EnsureWarm(c)=='ready'then K.LinkAt(c,r.ts)
 else E.AuctionDeposits.Defer(c,r.ts,true)end
end
E.On('RECORD_ADDED',link);E.On('RECORD_CHANGED',link)

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="AuctionCosts",create=create}
E.AuctionReaderSources["AuctionCosts.lua"]="14aeeff45425c0c0c7f287193eca2ee3321e301156d2a504edeec7c47ba914fc"
end

-- CostMatch.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='CostMatch';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local K,S,Q,F={},E.Store,E.Query,E.Economy; E.CostMatch=K
local function integer(n,min)return type(n)=="number" and n==n and n%1==0 and n>=min and n<=9007199254740991 end
local function contains(list,id)for _,value in ipairs(list or {})do _auctionTick(); if value==id then return true end end end
local planCache=setmetatable({},{__mode="k"})
local relevant={inventory=true,merchant=true}
local function invalidate(c,r)
    if not r or not Q.IsWarm(c) or relevant[r.kind] or relevant[Q.PreviousKind(c,r.id)] then planCache[c]=nil end
end
E.On("RECORD_ADDED",invalidate); E.On("RECORD_CHANGED",invalidate)
E.On("RECORDS_REMOVED",function(c)invalidate(c)end)
-- Follow the actual predecessor chain; never join unrelated nearby item changes.
local function buildPlan(c,receipt)
    local anchor=receipt and receipt.inventoryAnchor
    if not receipt or receipt.character~=c.id or not anchor or receipt.kind~="merchant" or receipt.status~="matched observations" or receipt.overflow
        or (receipt.source~="vendorPurchase" and receipt.source~="vendorSale" and receipt.source~="buyback")
        or not c.records[anchor.record] or c.records[anchor.record].kind~="inventory" or not integer(anchor.sequence,0) or type(anchor.ts)~="number" or anchor.ts>receipt.ts
        or type(receipt.observedThrough)~="number" or receipt.observedThrough<receipt.ts then return end
    local scope=anchor.scope or "carried bags"
    if scope~="carried bags" and scope~="bags and equipment" then return end
    if scope=="bags and equipment" and type(anchor.equipment)~="table" then return end
    local items={}; local remaining=0; local direction=receipt.source=="vendorSale" and -1 or 1
    for _,row in ipairs(receipt.items or {})do _auctionTick();
        if not integer(row.itemID,1) or not integer(row.before,0) or not integer(row.after,0) or items[row.itemID]
            or (row.after-row.before)*direction<=0 then return end
        local quantity=(row.after-row.before)*direction
        items[row.itemID]={current=row.before,after=row.after,quantity=quantity,requested=0,used=0,ops={}}
        remaining=remaining+quantity
    end
    for index,op in ipairs(receipt.attempts or {})do _auctionTick();
        if op.invalid or op.source~=receipt.source or not integer(op.itemID,1) or not integer(op.quantity,1)
            or type(op.amount)~="number" or not integer(math.abs(op.amount),0)
            or (direction==1 and op.amount>0) or (direction==-1 and op.amount<=0) then return end
        local item=items[op.itemID]; if not item then return end
        item.ops[#item.ops+1]={request=op,index=index,start=item.requested}; item.requested=item.requested+op.quantity
    end
    if remaining==0 then return end
    for _,item in pairs(items)do _auctionTick(); if item.requested~=item.quantity then return end end
    local successors={}
    for _,inv in ipairs(Q.Range(c,receipt.ts,receipt.observedThrough+3,"inventory"))do _auctionTick();
        if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
            if successors[inv.previousRecord] then successors[inv.previousRecord]=false
            elseif successors[inv.previousRecord]==nil then successors[inv.previousRecord]=inv end
        end
    end
    local plan={records={},rows={}}; local previous=anchor.record; local previousTime=anchor.ts; local previousSequence=anchor.sequence
    while remaining>0 do _auctionTick();
        local inv=successors[previous]
        if not inv or inv.character~=c.id or inv.baseline or inv.scope~=scope or inv.session~=receipt.session
            or S.Sequence(inv)<=previousSequence or not inv.observedFrom or inv.observedFrom<previousTime
            or inv.ts<inv.observedFrom or inv.ts<previousTime or (inv.accountingTime or inv.ts)~=inv.ts
            or inv.ts>receipt.observedThrough+2 then return end
        if scope=="bags and equipment" and not _auctionSame(anchor.equipment,inv.equipment) then return end
        local rows={}; local changed=0
        for _,row in ipairs(inv.items or {})do _auctionTick();
            local item=items[row.itemID]
            local equipped=scope=="bags and equipment" and (anchor.equipment[row.itemID] or 0) or 0
            if not item or rows[row.itemID] or not integer(row.before,0) or not integer(row.after,0) or not integer(equipped,0)
                or row.delta~=row.after-row.before or row.before-equipped~=item.current or row.delta*direction<=0 then return end
            local quantity=row.delta*direction
            if item.used+quantity>item.quantity then return end
            local parts={}; local allocated=0
            for _,entry in ipairs(item.ops)do _auctionTick(); local op=entry.request
                local offset=math.max(0,item.used-entry.start)
                local finish=math.min(op.quantity,item.used+quantity-entry.start)
                local take=finish-offset
                if take>0 then
                    if op.observationSequence and op.observationSequence>=S.Sequence(inv) or op.requestedAt and op.requestedAt>inv.ts then return end
                    parts[#parts+1]={quantity=take,amount=F.Part(math.abs(op.amount),op.quantity,offset,take),order=entry.index,requestOffset=offset,intervalOffset=allocated}
                    allocated=allocated+take
                end
            end
            if allocated~=quantity then return end
            rows[row.itemID]={quantity=quantity,parts=parts}; changed=changed+quantity
            item.current=row.after-equipped; item.used=item.used+quantity
        end
        if changed==0 then return end
        remaining=remaining-changed; plan.records[#plan.records+1]=inv; plan.rows[inv.id]=rows
        previous,previousTime,previousSequence=inv.id,inv.ts,S.Sequence(inv)
    end
    local following=successors[previous]
    if following and receipt.observedThroughSequence and S.Sequence(following)<=receipt.observedThroughSequence then return end
    return plan
end
function K.Plan(c,receipt)
    if not receipt then return end
    local cache=planCache[c]; if not cache then cache={}; planCache[c]=cache end
    if cache[receipt.id]==nil then cache[receipt.id]=buildPlan(c,receipt) or false end
    return cache[receipt.id] or nil
end
function K.Compatible(c,inv,receipt)
    if not inv or inv.character~=c.id then return false end
    local plan=K.Plan(c,receipt); return not not (plan and plan.rows[inv.id])
end
local function walletValid(c,r)
    if not r.walletMatched then return false end
    local total,expected,seen=0,0,{}
    for _,op in ipairs(r.attempts)do _auctionTick(); expected=expected+op.amount end
    for _,id in ipairs(r.walletIDs or {})do _auctionTick();
        local delta=c.records[id]
        if seen[id] or not delta or delta.kind~="gold" or delta.session~=r.session or delta.source~=r.source
            or (delta.quality~="inferred" and delta.quality~="confirmed") then return false end
        seen[id]=true; local linked=false
        for _,ref in ipairs(delta.evidenceRefs or {})do _auctionTick(); local evidence=c.records[ref]
            if evidence and evidence.kind=="money_evidence" and evidence.walletID==id and evidence.source==r.source
                and evidence.amount==delta.amount and contains(evidence.refs,r.id) then linked=true end
        end
        if not linked then return false end
        total=total+delta.amount
    end
    return total==expected
end
function K.Resolve(c,inv)
    local match
    for _,id in ipairs(inv and inv.merchantCandidates or {})do _auctionTick(); local receipt=c.records[id]
        if K.Compatible(c,inv,receipt) then
            if match then return nil,"More than one merchant receipt matches this interval." end
            match=receipt
        end
    end
    if not match then return nil,"No uniquely matching complete merchant batch for this count interval." end
    -- A partial overlap makes the entire batch ambiguous, not just one of its rows.
    local plan=K.Plan(c,match)
    for _,part in ipairs(plan.records)do _auctionTick();
        if E.CraftCosts and E.CraftCosts.Claim(c,part)then return nil,"Crafting and merchant evidence overlap; item costs remain unknown."end
        if E.AuctionCosts and E.AuctionCosts.Claim(c,part)then return nil,"Auction and merchant evidence overlap; item costs remain unknown."end
        if E.SentMailCosts and E.SentMailCosts.Claim(c,part)then return nil,"Outgoing mail and merchant evidence overlap; item costs remain unknown."end
        if E.MailCosts and E.MailCosts.Claim(c,part)then return nil,"Mail and merchant observations overlap; the item source remains unknown."end
        if E.TradeCosts and E.TradeCosts.Claim(c,part)then return nil,"Trade and merchant observations overlap; the item source remains unknown."end
    end
    for _,part in ipairs(plan.records)do _auctionTick(); for _,id in ipairs(part.merchantCandidates or {})do _auctionTick();
        if id~=match.id and K.Compatible(c,part,c.records[id]) then return nil,"Another receipt overlaps this merchant batch; its movements remain unknown." end
    end end
    if not walletValid(c,match) then return nil,"Merchant wallet evidence is missing or conflicts; FIFO uses the original unknown movement." end
    return match,"Inferred from matching merchant requests, quoted prices, wallet evidence and "..#plan.records.." linked bag-count interval(s)."
end
local function link(c,inv,r)
    if contains(inv.merchantCandidates,r.id) then return end
    inv.merchantCandidates=inv.merchantCandidates or {}; inv.merchantCandidates[#inv.merchantCandidates+1]=r.id
    inv.refs=inv.refs or {}; if not contains(inv.refs,r.id) then inv.refs[#inv.refs+1]=r.id end
    r.costInventoryIDs=r.costInventoryIDs or {}; r.costInventoryIDs[#r.costInventoryIDs+1]=inv.id
    if not contains(r.refs,inv.id) then r.refs[#r.refs+1]=inv.id end
    S.Changed(c,inv); S.Changed(c,r)
end
local function linkPlan(c,receipt)
    local plan=K.Plan(c,receipt)
    if plan then for _,inv in ipairs(plan.records)do _auctionTick(); link(c,inv,receipt)end end
end
local function linkRecord(c,r)
    if r.kind=="inventory" and not r.baseline then
        for _,receipt in ipairs(Q.Range(c,r.ts-10,r.ts+1,"merchant"))do _auctionTick(); linkPlan(c,receipt)end
    elseif r.kind=="merchant" and r.status=="matched observations" and r.observedThrough then
        linkPlan(c,r)
    end
end
local update=E.Inventory.CostLinkHandler(K,'CostMatch',function(_,r)
    return r.kind=='inventory'and not r.baseline or r.kind=='merchant'
end,linkRecord)
E.On("RECORD_ADDED",update); E.On("RECORD_CHANGED",update)
-- Derived replay substitutes the original movement, never adds another physical item.
-- Stored raw observations remain unchanged; revoking wallet evidence restores them.
function K.Project(c,r)
    if r.source~="inventory observation" or (r.kind~="cost_lot" and r.kind~="stock_move") then return end
    local inv=c.records[r.evidence]; local receipt=K.Resolve(c,inv)
    if not receipt then return end
    local item=K.Plan(c,receipt).rows[inv.id][r.itemID]
    if not item or item.quantity~=r.quantity then return end
    local projected={}; local gross=0
    for _,part in ipairs(item.parts)do _auctionTick();
        gross=gross+part.amount
        if receipt.source=="vendorPurchase" then
            local copy=_auctionCopy(r); copy.quantity=part.quantity; copy.cost=part.amount; copy.projectionOrder=part.order
            copy.merchantReceipt=receipt.id; copy.quality="inferred"; copy.title="Inferred vendor purchase cost"
            projected[#projected+1]=copy
        end
    end
    if receipt.source=="vendorPurchase" and r.kind=="cost_lot" then return projected end
    if receipt.source=="buyback" and r.kind=="cost_lot" and E.BuybackCosts then return E.BuybackCosts.Project(c,r,receipt) end
    if receipt.source=="vendorSale" and r.kind=="stock_move" then
        local copy=_auctionCopy(r); copy.kind="item_sale"; copy.gross=gross; copy.fees=0
        copy.merchantReceipt=receipt.id; copy.quality="inferred"; copy.title="Inferred vendor sale"
        return {copy}
    end
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="CostMatch",create=create}
E.AuctionReaderSources["CostMatch.lua"]="34c5aa062cab36522bb6cde97c033a7dc623e596eca6d71948c08741d4228c82"
end

-- BuybackCosts.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='BuybackCosts';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local B,K,Q,S={},E.CostMatch,E.Query,E.Store;E.BuybackCosts=B
local caches=setmetatable({},{__mode='k'})
-- Resolved returns depend on both merchant batches remaining unambiguous.
-- An already-linked competing source can change without touching inventory.
local relevant={merchant=true,inventory=true,inventory_gap=true,cost_lot=true,stock_move=true,gold=true,money_evidence=true,wallet_window=true,
 auction=true,trade=true,trade_offer=true,trade_notice=true,bank=true,bank_gap=true,
 mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,
 craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function key(origin)return origin.receipt..':'..origin.attempt end
local function cacheFor(c)
 local cache=caches[c];if cache then return cache end
 cache={claims={},plans={}};caches[c]=cache
 for _,r in ipairs(Q.Kind(c,'merchant'))do _auctionTick(); if r.source=='buyback' then
  local origin=E.Buyback.Origins(c,r)[1]
  if origin then local k=key(origin);if cache.claims[k]==nil then cache.claims[k]=r.id else cache.claims[k]=false end end
 end end
 return cache
end
local function rawSale(c,inv,itemID,quantity)
 local found
 for _,id in ipairs(inv.refs or {})do _auctionTick(); local r=c.records[id]
  if r and r.kind=='stock_move' and r.source=='inventory observation' and r.evidence==inv.id and r.itemID==itemID and r.quantity==quantity then
   if found then return end;found=r
  end
 end
 return found
end
local function build(c,r,cache)
 local plan=K.Plan(c,r);if not plan or K.Resolve(c,plan.records[1])~=r then return end
 local origin=E.Buyback.Origins(c,r)[1];if not origin or cache.claims[key(origin)]~=r.id then return end
 local sale=c.records[origin.receipt];local salePlan=K.Plan(c,sale)
 if not salePlan or sale.source~='vendorSale' or K.Resolve(c,salePlan.records[1])~=sale then return end
 local op=r.attempts[1]
 if #r.attempts~=1 or op.itemID~=origin.itemID or op.quantity~=origin.quantity or -op.amount~=origin.amount then return end
 local segments={};local total=0
 for _,inv in ipairs(salePlan.records)do _auctionTick(); local item=salePlan.rows[inv.id][origin.itemID]
  if item then
   local raw=rawSale(c,inv,origin.itemID,item.quantity)
   if not raw or raw.ts>r.ts or S.Sequence(raw)>=S.Sequence(r) then return end
   for _,part in ipairs(item.parts)do _auctionTick(); if part.order==origin.attempt then
    segments[#segments+1]={sale=raw.id,start=part.requestOffset,offset=part.intervalOffset,quantity=part.quantity}
    total=total+part.quantity
   end end
  end
 end
 if total~=op.quantity then return end
 return {receipt=r,origin=origin,plan=plan,segments=segments}
end
function B.Plan(c,r)
 if not r or r.source~='buyback' then return end
 local cache=cacheFor(c);if cache.plans[r.id]==nil then cache.plans[r.id]=build(c,r,cache) or false end
 return cache.plans[r.id] or nil
end
function B.Project(c,raw,receipt)
 local binding=B.Plan(c,receipt);if not binding then return end
 local item=binding.plan.rows[raw.evidence] and binding.plan.rows[raw.evidence][raw.itemID]
 if not item or item.quantity~=raw.quantity then return end
 local parts={};local quantity,refund=0,0
 for _,part in ipairs(item.parts)do _auctionTick();
  refund=refund+part.amount
  for _,segment in ipairs(binding.segments)do _auctionTick();
   local first=math.max(part.requestOffset,segment.start)
   local last=math.min(part.requestOffset+part.quantity,segment.start+segment.quantity)
   if last>first then
    parts[#parts+1]={sale=segment.sale,offset=segment.offset+first-segment.start,quantity=last-first}
    quantity=quantity+last-first
   end
  end
 end
 if quantity~=raw.quantity then return end
 local copy=_auctionCopy(raw);copy.kind='sale_return';copy.returnParts=parts;copy.refund=refund;copy.feeRefund=0
 copy.merchantReceipt=receipt.id;copy.originalMerchant=binding.origin.receipt;copy.quality='inferred';copy.title='Inferred vendor buyback return'
 return {copy}
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="BuybackCosts",create=create}
E.AuctionReaderSources["BuybackCosts.lua"]="123dbc81001de55188be99dc639a50bdba80df79a5c029246d2cc6291dce968c"
end

-- BankCosts.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='BankCosts';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local B,S,F,Q={},E.Store,E.Economy,E.Query; E.BankCosts=B
-- Derived custody only: raw counts, wallet entries and acquisition records are
-- never rewritten. Rebuilding revokes costs when their original evidence changes.
local cache
local relevant={craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true,auction=true,bank=true,bank_gap=true,inventory=true,inventory_gap=true,merchant=true,gold=true,money_evidence=true,mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,
    cost_lot=true,stock_move=true,stock_reset=true,item_sale=true,sale_return=true,trade=true,trade_offer=true,trade_notice=true,wallet_window=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c) or relevant[r.kind] or relevant[Q.PreviousKind(c,r.id)] then cache=nil end end
E.On('RECORD_ADDED',invalidate); E.On('RECORD_CHANGED',invalidate); E.On('RECORDS_REMOVED',function()cache=nil end)
local function integer(n,min)return type(n)=='number' and n==n and n%1==0 and n>=min and n<=9007199254740991 end
local function countsValid(counts)
    if type(counts)~='table' then return false end
    for id,n in pairs(counts)do _auctionTick(); if not integer(id,1) or not integer(n,0) or n>67108864 then return false end end
    return true
end
local function key(c,r)return r.bankType=='account' and 'account' or 'character:'..c.id end
local function unknown(n)return {quantity=n,lots=n>0 and {{quantity=n,used=0,unknownAge=true}} or {}} end
local function append(item,part)
    local copy=_auctionCopy(part);copy.used=0
    local position=#item.lots+1
    for i,lot in ipairs(item.lots)do _auctionTick();
        if F.LotBefore(copy,lot) then position=i;break end
    end
    table.insert(item.lots,position,copy);item.quantity=item.quantity+copy.quantity
end
local function take(item,n)
    local out={}; local left=n
    for _,lot in ipairs(item.lots)do _auctionTick(); local amount=math.min(left,lot.quantity-lot.used)
        if amount>0 then
            local part=_auctionCopy(lot);part.quantity=amount;part.cost,part.baseCost,part.baseQuantity,part.baseOffset=F.SliceCost(lot,lot.used,amount);part.used=nil
            out[#out+1]=part;lot.used=lot.used+amount;left=left-amount
        end
        if left==0 then break end
    end
    if left>0 then out[#out+1]={quantity=left,unknownAge=true} end
    local retained={};for _,lot in ipairs(item.lots)do _auctionTick(); if lot.used<lot.quantity then retained[#retained+1]=lot end end;item.lots=retained
    item.quantity=math.max(0,item.quantity-n);return out
end
local function movement(c,r,transfer)
    local inv=c.records[r.inventoryRecord]
    if not inv or inv.kind~='inventory' or inv.baseline or inv.character~=c.id
        or inv.ts~=r.ts or inv.sequence>=r.sequence or inv.previousRecord==nil
        or E.CraftCosts and E.CraftCosts.Claim(c,inv)
        or E.SentMailCosts and E.SentMailCosts.Claim(c,inv)
        or E.AuctionCosts and E.AuctionCosts.Claim(c,inv)
        or #(inv.merchantCandidates or {})>0 or E.TradeCosts and E.TradeCosts.Claim(c,inv) or E.MailCosts and E.MailCosts.Claim(c,inv) then return end
    local match
    for _,id in ipairs(inv.refs or {})do _auctionTick(); local raw=c.records[id]
        if raw and raw.source=='inventory observation' and raw.evidence==inv.id and raw.itemID==transfer.itemID
            and raw.quantity==transfer.quantity and raw.kind==(transfer.direction=='deposit' and 'stock_move' or 'cost_lot')
            and raw.sequence<r.sequence then
            if match then return end;match=raw
        end
    end
    return match
end
local function initialize()
    if cache and cache.db==E.db then return cache end
    local state={db=E.db,rows={},pools={},results={},byMovement={},position=1,orders={}}
    for _,c in pairs(E.db.characters)do _auctionTick(); for _,r in ipairs(Q.Kind(c,'bank'))do _auctionTick();
        if integer(r.bankOrder,1) and (r.bankType=='account' or r.bankType=='character') then
            state.rows[#state.rows+1]={c=c,r=r};state.orders[r.bankOrder]=(state.orders[r.bankOrder] or 0)+1
            for _,t in ipairs(r.transfers or {})do _auctionTick(); local raw=movement(c,r,t)
                if raw then
                    if state.byMovement[raw.id] then state.byMovement[raw.id]=false
                    elseif state.byMovement[raw.id]==nil then state.byMovement[raw.id]=r end
                end
            end
        end
    end end
    _auctionSort(state.rows,function(a,b)return a.r.bankOrder<b.r.bankOrder end);cache=state;return state
end
local function process(state,c,r)
    local poolKey=key(c,r);local pool=state.pools[poolKey]
    if state.orders[r.bankOrder]~=1 or not countsValid(r.counts) then state.pools[poolKey]=nil;return end
    if not pool then
        pool={items={}};state.pools[poolKey]=pool
        local previous=c.records[r.previousRecord]
        if previous and previous.kind=='bank' and previous.bankType==r.bankType and countsValid(previous.counts) then
            for id,n in pairs(previous.counts)do _auctionTick(); pool.items[id]=unknown(n)end
            pool.last=previous.id;pool.tabs=previous.tabs;pool.usesBags=previous.usesBags
        end
    end
    local continuous=not r.baseline and pool.last==r.previousRecord and _auctionSame(pool.tabs,r.tabs) and pool.usesBags==r.usesBags
    local transfers={}
    for _,t in ipairs(r.transfers or {})do _auctionTick();
        if integer(t.itemID,1) and integer(t.quantity,1) and t.quantity<=67108864 and (t.direction=='deposit' or t.direction=='withdrawal') then
            if transfers[t.itemID]~=nil then transfers[t.itemID]=false else transfers[t.itemID]=t end
        end
    end
    local rows={};for _,row in ipairs(r.items or {})do _auctionTick(); if rows[row.itemID]~=nil then rows[row.itemID]=false else rows[row.itemID]=row end end
    local ids={};for id in pairs(pool.items)do _auctionTick(); ids[id]=true end;for id in pairs(r.counts)do _auctionTick(); ids[id]=true end
    for id in pairs(ids)do _auctionTick();
        local item=pool.items[id] or unknown(0);local after=r.counts[id] or 0;local row=rows[id];local transfer=transfers[id]
        local sameLayout=_auctionSame(pool.tabs,r.tabs) and pool.usesBags==r.usesBags
        -- Equal complete snapshots allow *inferred* continuity across characters.
        -- A changed count/layout or unexplained movement loses only that item's basis.
        if continuous and row and row.before==item.quantity and row.after==after and row.delta==after-item.quantity
            and transfer and math.abs(row.delta)==transfer.quantity and (row.delta>0)==(transfer.direction=='deposit') then
            local raw=movement(c,r,transfer)
            if raw and state.byMovement[raw.id]==r then
                if transfer.direction=='deposit' then
                    local replay=F.Replay(c,math.huge,raw.sequence);local info=replay.movements[raw.id]
                    if info then for _,part in ipairs(info.allocations)do _auctionTick(); append(item,part)end
                    else append(item,{quantity=transfer.quantity,unknownAge=true})end
                else
                    state.results[raw.id]={parts=take(item,transfer.quantity),bank=r.id,character=c.id}
                end
            elseif after~=item.quantity then item=unknown(after) end
        elseif after~=item.quantity or not sameLayout or not continuous and not r.baseline then item=unknown(after) end
        if item.quantity~=after then item=unknown(after) end
        pool.items[id]=item
    end
    pool.last=r.id;pool.tabs=_auctionCopy(r.tabs);pool.usesBags=r.usesBags
end
function B.Info(c,r)
    if not r or r.kind~='cost_lot' or r.source~='inventory observation' then return end
    local state=initialize();local bank=state.byMovement[r.id];if not bank then return end
    if state.busy then return state.results[r.id] end
    state.busy=true
    while state.rows[state.position] and state.rows[state.position].r.bankOrder<=bank.bankOrder do _auctionTick();
        local row=state.rows[state.position];state.position=state.position+1;process(state,row.c,row.r)
    end
    state.busy=false;return state.results[r.id]
end
function B.Project(c,r)
    local info=B.Info(c,r);if not info then return end
    local out={}
    for i,part in ipairs(info.parts)do _auctionTick();
        local copy=_auctionCopy(r);copy.quantity=part.quantity;copy.cost=part.cost;copy.projectionOrder=i
        copy.baseCost,copy.baseQuantity,copy.baseOffset=part.baseCost,part.baseQuantity,part.baseOffset
        copy.acquired=part.acquired;copy.acquisitionSequence=part.sequence;copy.unknownAge=part.unknownAge or not part.acquired
        copy.sourceCharacter=part.sourceCharacter;copy.sourceRecord=part.sourceRecord
        copy.quality='inferred';copy.bankReceipt=info.bank;copy.title='Inferred bank withdrawal cost'
        out[#out+1]=copy
    end
    return out
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="BankCosts",create=create}
E.AuctionReaderSources["BankCosts.lua"]="a883f40fb70d66c72e4a2809e008addb7571bc30bc200a6ce75520512cc1bca9"
end

-- TradeCosts.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='TradeCosts';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.TradeCosts=K
local relevant={trade=true,trade_offer=true,trade_notice=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,
    gold=true,money_evidence=true,wallet_window=true,merchant=true}
local caches=setmetatable({},{__mode='k'})
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function integer(n,min)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=67108864 end
local function contains(list,id)for _,v in ipairs(list or{})do _auctionTick(); if v==id then return true end end end
local function counts(r)
    if not r or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
    local out={}
    for _,map in ipairs({r.carried,r.equipment})do _auctionTick(); for id,n in pairs(map)do _auctionTick();
        if not integer(id,1)or not integer(n)then return end
        out[id]=(out[id]or 0)+n;if not integer(out[id])then return end
    end end
    return out
end
local function equalCounts(a,b)
    if not a or not b then return false end
    for id,n in pairs(a)do _auctionTick(); if n~=(b[id]or 0)then return false end end
    for id,n in pairs(b)do _auctionTick(); if n~=(a[id]or 0)then return false end end
    return true
end
local function build(c,r)
    local offer=E.Trades.Accepted(c,r);local anchor=offer and offer.inventoryAnchor
    if not offer or not r.settledAt or not anchor or anchor.session~=r.session or not integer(anchor.sequence)
        or type(anchor.ts)~='number'or anchor.ts>offer.ts or offer.ts-anchor.ts>15 or anchor.sequence>=S.Sequence(offer)then return end
    local base=c.records[anchor.record];local current=counts(base)
    if not current or base.kind~='inventory'or base.character~=c.id or base.session~=r.session or base.scope~=anchor.scope
        or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
    local expected={};local remaining=0;local service=false
    for _,side in ipairs({'player','target'})do _auctionTick(); local sign=side=='player'and -1 or 1
        for _,item in ipairs(offer.offer[side]or{})do _auctionTick();
            if item.serviceSlot or item.slot==7 then service=true
            else
                if not item.complete or not integer(item.itemID,1)or not integer(item.quantity,1)or not integer(item.slot,1)or item.slot>6 then return end
                local row=expected[item.itemID]
                -- Gross exchanges of the same item on both sides cannot be
                -- recovered from net bag counts, even if their net is nonzero.
                if row and row.direction~=sign then return end
                row=row or{direction=sign,quantity=0,used=0};expected[item.itemID]=row
                row.quantity=row.quantity+item.quantity;if not integer(row.quantity,1)then return end
                remaining=remaining+item.quantity
            end
        end
    end
    if remaining==0 then return end
    local successors={}
    for _,inv in ipairs(Q.Range(c,anchor.ts,r.closedAt+6,'inventory'))do _auctionTick();
        if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
            if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
        end
    end
    local plan={records={},rows={},items=expected,offer=offer,service=service};local previous=base.id;local ts=anchor.ts;local sequence=anchor.sequence
    while remaining>0 do _auctionTick();
        local inv=successors[previous];local actual=counts(inv)
        if not inv or not actual or inv.character~=c.id or inv.baseline or inv.session~=r.session or inv.scope~=anchor.scope
            or S.Sequence(inv)<=sequence or S.Sequence(inv)<=S.Sequence(offer)or not inv.observedFrom or inv.observedFrom<ts
            or inv.ts<inv.observedFrom or inv.ts<offer.ts or math.abs(inv.ts-r.closedAt)>5
            or (inv.accountingTime or inv.ts)~=inv.ts or not _auctionSame(base.equipment,inv.equipment)then return end
        local rows={};local changed=0
        for _,item in ipairs(inv.items or{})do _auctionTick(); local exp=expected[item.itemID]
            if not exp or rows[item.itemID]or not integer(item.before)or not integer(item.after)
                or item.before~=(current[item.itemID]or 0)or item.delta~=item.after-item.before or item.delta*exp.direction<=0 then return end
            local n=math.abs(item.delta);if exp.used+n>exp.quantity then return end
            rows[item.itemID]={quantity=n,offset=exp.used,direction=exp.direction};exp.used=exp.used+n
            current[item.itemID]=item.after;changed=changed+n
        end
        if changed==0 or not equalCounts(current,actual)then return end
        remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows
        previous,ts,sequence=inv.id,inv.ts,S.Sequence(inv)
    end
    -- Any additional observation before settlement makes the proposed full
    -- trade interval ambiguous. Later unrelated observations stay separate.
    local nextRecord=successors[previous]
    if nextRecord==false or nextRecord and nextRecord.ts<=r.settledAt then return end
    for _,gap in ipairs(Q.Range(c,anchor.ts,math.max(ts,r.closedAt)+1,'inventory_gap'))do _auctionTick();
        if S.Sequence(gap)>anchor.sequence then return end
    end
    return plan
end
function K.Plan(c,r)
    if not r then return end
    local cache=caches[c];if not cache then cache={};caches[c]=cache end
    if cache[r.id]==nil then cache[r.id]=build(c,r)or false end
    return cache[r.id]or nil
end
function K.Claim(c,inv)
    for _,id in ipairs(inv and inv.tradeCandidates or{})do _auctionTick(); local plan=K.Plan(c,c.records[id]);if plan and plan.rows[inv.id]then return true end end
    return false
end
function K.Resolve(c,inv)
    local match
    for _,id in ipairs(inv and inv.tradeCandidates or{})do _auctionTick(); local r=c.records[id];local plan=K.Plan(c,r)
        if plan and plan.rows[inv.id]then if match then return nil,'Overlapping trades claim the same inventory changes.'end;match=r end
    end
    if not match then return nil,'No complete trade matches this inventory chain.'end
    local plan=K.Plan(c,match)
    for _,part in ipairs(plan.records)do _auctionTick();
        if E.CraftCosts and E.CraftCosts.Claim(c,part)then return nil,'Crafting and trade evidence overlap; item costs remain unknown.'end
        if E.AuctionCosts and E.AuctionCosts.Claim(c,part)then return nil,'Auction and trade evidence overlap; item costs remain unknown.'end
        if E.SentMailCosts and E.SentMailCosts.Claim(c,part)then return nil,"Outgoing mail and trade evidence overlap; item costs remain unknown."end
        if E.MailCosts and E.MailCosts.Claim(c,part)then return nil,'Mail and trade observations overlap; the item source remains unknown.'end
        for _,id in ipairs(part.tradeCandidates or{})do _auctionTick(); if id~=match.id then local other=K.Plan(c,c.records[id]);if other and other.rows[part.id]then return nil,'Another trade overlaps part of this exchange.'end end end
        for _,id in ipairs(part.merchantCandidates or{})do _auctionTick(); if E.CostMatch.Compatible(c,part,c.records[id])then return nil,'Merchant and trade evidence overlap; the item source remains unknown.'end end
        for _,bank in ipairs(Q.Range(c,part.ts,part.ts+1,'bank'))do _auctionTick(); if bank.inventoryRecord==part.id and #(bank.transfers or{})>0 then return nil,'Bank and trade observations overlap; the item source remains unknown.'end end
    end
    return match,'Inferred from the accepted offer, completion and '..#plan.records..' linked inventory observation(s).'
end
function K.Price(c,r)
    local plan=K.Plan(c,r);if not plan then return nil,'Inventory match is unavailable.'end
    if plan.service then return nil,'Gold may cover the service slot; individual item prices remain unknown.'end
    local incoming,outgoing,which=0,0
    for id,item in pairs(plan.items)do _auctionTick(); which=id;if item.direction>0 then incoming=incoming+1 else outgoing=outgoing+1 end end
    local d=plan.offer.offer;local source,amount
    if incoming==1 and outgoing==0 and d.playerMoney>0 and d.targetMoney==0 then source,amount='purchase',d.playerMoney
    elseif outgoing==1 and incoming==0 and d.targetMoney>0 and d.playerMoney==0 then source,amount='sale',d.targetMoney
    else return nil,'Bundled items, barter or a non-cash exchange need separate price evidence.'end
    local cash=E.Trades.Plan(c,r);if not cash then return nil,'Matching trade gold evidence is unavailable.'end
    for _,w in ipairs(cash.wallets)do _auctionTick();
        if w.source~='trade'or(w.quality~='inferred'and w.quality~='confirmed')then return nil,'Trade gold attribution is missing or conflicts.'end
        local linked=false
        for _,id in ipairs(w.evidenceRefs or{})do _auctionTick(); local proof=c.records[id]
            if proof and proof.kind=='money_evidence'and proof.trade==r.id and proof.walletID==w.id and E.Trades.ValidProof(c,proof)then linked=true end
        end
        if not linked then return nil,'Original trade payment evidence is unavailable.'end
    end
    return {source=source,amount=amount,itemID=which,quantity=plan.items[which].quantity},'Single-item price inferred from the observed trade payment.'
end
local function link(c,inv,r)
    if contains(inv.tradeCandidates,r.id)then return end
    inv.tradeCandidates=inv.tradeCandidates or{};inv.tradeCandidates[#inv.tradeCandidates+1]=r.id
    inv.refs=inv.refs or{};if not contains(inv.refs,r.id)then inv.refs[#inv.refs+1]=r.id end
    if not contains(r.refs,inv.id)then r.refs[#r.refs+1]=inv.id end
    S.Changed(c,inv);S.Changed(c,r)
end
local recent=setmetatable({},{__mode='k'})
local function linkRecord(c,r,saved)
    if r.kind=='trade'and r.closedAt then recent[c]=r.id end
    local trades=r.kind=='trade'and{r}or Q.Range(c,r.ts-300,r.ts+1,'trade')
    -- Active offers may last longer than five minutes; their owning trade is
    -- also a candidate even when its original opening date is older.
    if r.kind=='inventory'then
        local function include(id)
            local trade=c.records[id]
            if trade and trade.kind=='trade' and trade.character==c.id and not contains(trades,trade)then trades[#trades+1]=trade end
        end
        if saved then for id in pairs(saved)do _auctionTick(); include(id)end
        else
            include(c.state.activeTrade)
            local closed=c.records[recent[c]]
            if closed and r.ts<=closed.closedAt+5 then include(closed.id)end
        end
    end
    for _,trade in ipairs(trades)do _auctionTick(); local plan=K.Plan(c,trade);if plan then for _,inv in ipairs(plan.records)do _auctionTick(); link(c,inv,trade)end end end
end
local update=E.Inventory.CostLinkHandler(K,'TradeCosts',function(_,r)return r.kind=='trade'or r.kind=='inventory'end,
    linkRecord,function(c,r)
        local closed=c.records[recent[c]]
        return c.state.activeTrade,closed and closed.closedAt and r.ts<=closed.closedAt+5 and closed.id
    end)
E.On('RECORD_ADDED',update);E.On('RECORD_CHANGED',update)
function K.Project(c,r)
    if r.source~='inventory observation'or(r.kind~='cost_lot'and r.kind~='stock_move')then return end
    local inv=c.records[r.evidence];local trade=K.Resolve(c,inv);if not trade then return end
    local price=K.Price(c,trade);if not price or price.itemID~=r.itemID then return end
    local part=K.Plan(c,trade).rows[inv.id][r.itemID]
    if not part or part.quantity~=r.quantity then return end
    local amount=F.Part(price.amount,price.quantity,part.offset,part.quantity)
    local copy=_auctionCopy(r);copy.tradeReceipt=trade.id;copy.quality='inferred'
    if price.source=='purchase'and r.kind=='cost_lot'then
        copy.cost=amount;copy.baseCost=price.amount;copy.baseQuantity=price.quantity;copy.baseOffset=part.offset
        copy.title='Inferred player-trade acquisition cost'
    elseif price.source=='sale'and r.kind=='stock_move'then copy.kind='item_sale';copy.gross=amount;copy.fees=0;copy.title='Inferred player-trade sale'
    else return end
    return {copy}
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="TradeCosts",create=create}
E.AuctionReaderSources["TradeCosts.lua"]="3f1e0dfcc82f530174b430f5ad89c62e72050d780d48e044c4cc830288843b4a"
end

-- MailCosts.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='MailCosts';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
-- Load before MailMoney: invalidate receipt plans before cash proofs are rechecked.
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.MailCosts=K
local relevant={mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,inventory=true,inventory_gap=true,
 bank=true,bank_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,gold=true,money_evidence=true,wallet_window=true}
local caches=setmetatable({},{__mode='k'})
local dependencies=setmetatable({},{__mode='k'})
local function depend(c,batch,id)
 if not batch or type(batch.id)~='string'or type(id)~='string'then return end
 local index=dependencies[c];if not index then index={};dependencies[c]=index end
 index[id]=index[id]or{};index[id][batch.id]=true
end
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]or dependencies[c]and dependencies[c][r.id]then caches[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c);dependencies[c]=nil end)
local function integer(n,min,max)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=(max or 67108864)end
local function contains(list,id)for _,v in ipairs(list or{})do _auctionTick(); if v==id then return true end end end
local function identity(d)local v=E.Mail.Comparable(d,true);v.items=nil;v.itemCount=nil;v.cod=nil;return v end
local function itemKey(v)return {itemID=v.itemID,currencyID=v.currencyID,quantity=v.quantity,itemLink=v.itemLink}end
local function items(d)
 if not d.complete or not integer(d.money,0,9007199254740991)or not integer(d.cod,0,9007199254740991)or type(d.items)~='table'or d.itemCount~=#d.items then return end
 local slots={};for _,v in ipairs(d.items)do _auctionTick();
  local identified=v.isCurrency and integer(v.currencyID,1)and v.itemID==nil or not v.isCurrency and integer(v.itemID,1)and v.currencyID==nil
  if not v.complete or not identified or not integer(v.quantity,1)or not integer(v.slot,1,16)or slots[v.slot]then return end
  slots[v.slot]=v
 end
 return slots
end
local function scan(c,id,r)
 local s=c.records[id];if not s or s.kind~='mail_scan'or not s.complete or s.session~=r.session or s.visit~=r.visit or s.loaded~=s.total or type(s.entries)~='table'or #s.entries~=s.loaded then return end
 local rows,seen={},{};for _,id in ipairs(s.entries)do _auctionTick(); local row=c.records[id]
  if seen[id]or not row or row.kind~='mail'or row.character~=c.id or row.scan~=s.id or row.session~=r.session or row.visit~=r.visit or not row.mailData or not items(row.mailData)then return end
  seen[id]=true;rows[#rows+1]=row
 end
 return rows,s
end
local function changes(c,r)
 if not r or r.kind~='mail_collection'or r.character~=c.id or not r.settledAt or r.interrupted or r.failed or r.overflow then return end
 local before,old=scan(c,r.beforeScan,r);local after,new=scan(c,r.afterScan,r)
 if not before or not after or S.Sequence(old)>=S.Sequence(r)or S.Sequence(new)<=r.lastRequestSequence or new.ts<r.lastRequestAt or new.finishedAt>r.settledAt then return end
 local plan={items={},components={},gold=0,removedStacks=0};local matched={};local changed={}
 for i,row in ipairs(before)do _auctionTick(); local d=row.mailData;local key=identity(d);local found
  for j=1,i-1 do _auctionTick(); if _auctionSame(key,identity(before[j].mailData))then return end end
  for j,nextRow in ipairs(after)do _auctionTick(); if _auctionSame(key,identity(nextRow.mailData))then if found then return end;found=j end end
  if found then if matched[found]then return end;matched[found]=true end
  local nextData=found and after[found].mailData or{items={},money=0,cod=0}
  local used={};for _,item in ipairs(nextData.items)do _auctionTick(); local match
   for n,original in ipairs(d.items)do _auctionTick(); if not used[n]and _auctionSame(itemKey(item),itemKey(original))then match=n;break end end
   if not match then return end;used[match]=true
  end
  local part={record=row.id,items={},removed={},beforeItems={},cod=0,money=0}
  for n,item in ipairs(d.items)do _auctionTick();
   if item.isCurrency and not used[n]then return end
   if item.itemID then part.beforeItems[item.itemID]=(part.beforeItems[item.itemID]or 0)+item.quantity end
   if not used[n]then
    part.items[item.itemID]=(part.items[item.itemID]or 0)+item.quantity;part.removed[#part.removed+1]=item;plan.removedStacks=plan.removedStacks+1
    local total=plan.items[item.itemID]or{quantity=0,used=0};total.quantity=total.quantity+item.quantity;if not integer(total.quantity,1)then return end;plan.items[item.itemID]=total
   end
  end
  if nextData.money~=d.money and nextData.money~=0 or nextData.cod~=d.cod and nextData.cod~=0 then return end
  part.money=d.money-nextData.money;part.cod=d.cod-nextData.cod
  if part.cod>0 and #part.removed==0 then return end
  if #part.removed>0 or part.money>0 or part.cod>0 then
   changed[i]=part;plan.components[#plan.components+1]=part;plan.gold=plan.gold+part.money-part.cod
   if not integer(math.abs(plan.gold),0,9007199254740991)then return end
  elseif not found then return end
 end
 for i in ipairs(after)do _auctionTick(); if not matched[i]then return end end
 if plan.removedStacks==0 or #r.requests==0 or #r.requests>100 or #r.notices<#r.requests or #r.notices>#r.requests+plan.removedStacks then return end
 local seen={};for n,id in ipairs(r.requests)do _auctionTick(); local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_request'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.unavailable
   or not integer(v.index,1,#before)or v.ts<r.ts or v.ts>r.lastRequestAt then return end;seen[id]=true
  if v.method~='TakeInboxItem'and v.method~='AutoLootMailItem'and v.method~='TakeInboxMoney'then return end
  if v.method=='TakeInboxItem'and not integer(v.slot,1,16)then return end
  if n==1 then
   local part=changed[v.index];if not part then return end
   if v.method=='TakeInboxMoney'and part.money==0 then return end
   if v.method=='TakeInboxItem'then
    local target=items(before[v.index].mailData)[v.slot];local found=false
    for _,item in ipairs(part.removed)do _auctionTick(); if target and _auctionSame(itemKey(item),itemKey(target))then found=true end end
    if not found then return end
   end
  end
 end
 for _,id in ipairs(r.notices)do _auctionTick(); local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_notice'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.unavailable or v.event~='MAIL_SUCCESS'
   or v.ts<r.ts or v.ts>r.lastRequestAt+5 or v.itemID and not plan.items[v.itemID]then return end;seen[id]=true
 end
 return plan
end
local function counts(r)
 if not r or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
 local out={};for _,map in ipairs({r.carried,r.equipment})do _auctionTick(); for id,n in pairs(map)do _auctionTick();
  if not integer(id,1)or not integer(n)then return end;out[id]=(out[id]or 0)+n;if not integer(out[id])then return end
 end end;return out
end
local function equal(a,b)
 for id,n in pairs(a)do _auctionTick(); if n~=(b[id]or 0)then return false end end
 for id,n in pairs(b)do _auctionTick(); if n~=(a[id]or 0)then return false end end;return true
end
local function build(c,r)
 local plan=changes(c,r);local anchor=r and r.inventoryAnchor
 if not plan or not anchor or anchor.session~=r.session or anchor.scope~='bags and equipment'or not integer(anchor.sequence,0,9007199254740991)
  or type(anchor.ts)~='number'or anchor.ts>r.ts or r.ts-anchor.ts>15 or anchor.sequence>=S.Sequence(r)then return end
 local base=c.records[anchor.record];local current=counts(base)
 if not current or base.kind~='inventory'or base.character~=c.id or base.session~=r.session or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
 local successors={};for _,inv in ipairs(Q.Range(c,anchor.ts,r.settledAt+1,'inventory'))do _auctionTick();
  depend(c,r,inv.id)
  if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
  if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
 end end
 local remaining=0;for _,v in pairs(plan.items)do _auctionTick(); remaining=remaining+v.quantity end
 plan.records={};plan.rows={};local previous,ts,seq=base.id,anchor.ts,anchor.sequence
 while remaining>0 do _auctionTick(); local inv=successors[previous];local actual=counts(inv)
  if not actual or inv.character~=c.id or inv.baseline or inv.session~=r.session or S.Sequence(inv)<=seq or S.Sequence(inv)<=S.Sequence(r)
   or not inv.observedFrom or inv.observedFrom<ts or inv.ts<inv.observedFrom or inv.ts<r.ts or inv.ts>r.lastRequestAt+5
   or inv.ts>r.settledAt or(inv.accountingTime or inv.ts)~=inv.ts or not _auctionSame(base.equipment,inv.equipment)then return end
  local rows={};local changed=0;for _,v in ipairs(inv.items or{})do _auctionTick(); local expected=plan.items[v.itemID]
   if not expected or rows[v.itemID]or not integer(v.before)or not integer(v.after)or v.before~=(current[v.itemID]or 0)
    or v.delta~=v.after-v.before or v.delta<=0 or expected.used+v.delta>expected.quantity then return end
   rows[v.itemID]={quantity=v.delta,offset=expected.used};expected.used=expected.used+v.delta;current[v.itemID]=v.after;changed=changed+v.delta
  end
  if changed==0 or not equal(current,actual)then return end
  remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows;previous,ts,seq=inv.id,inv.ts,S.Sequence(inv)
 end
 if successors[previous]~=nil then return end
 for _,gap in ipairs(Q.Range(c,anchor.ts,r.settledAt+1,'inventory_gap'))do _auctionTick(); depend(c,r,gap.id);if S.Sequence(gap)>anchor.sequence then return end end
 return plan
end
function K.Plan(c,r)
 if not r then return end
 local cache=caches[c];if not cache then cache={};caches[c]=cache end
 if cache[r.id]==nil then
  depend(c,r,r.id);if r.inventoryAnchor then depend(c,r,r.inventoryAnchor.record)end
  -- MailMoney owns wallet-window identity checks; ordinary balance heartbeats
  -- must not become receipt-dependency edits just because refs include a window.
  for _,id in ipairs(r.refs or{})do _auctionTick(); local row=c.records[id]
   if row and row.kind~='wallet_window'and row.kind~='gold'and row.kind~='money_evidence'then depend(c,r,id)end
  end
  cache[r.id]=build(c,r)or false
 end;return cache[r.id]or nil
end
function K.Claim(c,inv)
 for _,id in ipairs(inv and inv.mailCandidates or{})do _auctionTick(); local plan=K.Plan(c,c.records[id]);if plan and plan.rows[inv.id]then return true end end
 return false
end
function K.Resolve(c,inv)
 local match;for _,id in ipairs(inv and inv.mailCandidates or{})do _auctionTick(); local r=c.records[id];local plan=K.Plan(c,r)
  if plan and plan.rows[inv.id]then if match then return nil,'Overlapping mail collections claim these items.'end;match=r end
 end
 if not match then return nil,'No complete mail collection matches these inventory changes.'end
 for _,part in ipairs(K.Plan(c,match).records)do _auctionTick();
  if E.CraftCosts and E.CraftCosts.Claim(c,part)then return nil,'Crafting and mail evidence overlap; item costs remain unknown.'end
  if E.AuctionCosts and E.AuctionCosts.Claim(c,part)then return nil,'Auction and mail evidence overlap; item costs remain unknown.'end
  for _,id in ipairs(part.mailCandidates or{})do _auctionTick(); local p=K.Plan(c,c.records[id]);if id~=match.id and p and p.rows[part.id]then return nil,'Another collection overlaps these items.'end end
  if E.SentMailCosts and E.SentMailCosts.Claim(c,part)then return nil,"Incoming and outgoing mail evidence overlap."end
  if E.TradeCosts.Claim(c,part)then return nil,'Mail and trade evidence overlap; item costs remain unknown.'end
  for _,id in ipairs(part.merchantCandidates or{})do _auctionTick(); if E.CostMatch.Compatible(c,part,c.records[id])then return nil,'Mail and merchant evidence overlap; item costs remain unknown.'end end
  for _,bank in ipairs(Q.Range(c,part.ts,part.ts+1,'bank'))do _auctionTick();
   depend(c,match,bank.id)
   if bank.inventoryRecord==part.id and #(bank.transfers or{})>0 then return nil,'Mail and bank evidence overlap; item costs remain unknown.'end
  end
 end
 return match,'Mail requests, success notifications, removed attachments and continuous inventory counts match; receipt is inferred.'
end
function K.Cash(c,r)
 local plan=K.Plan(c,r);if not plan or plan.gold==0 then return end
 if K.Resolve(c,plan.records[1])~=r then return end
 local anchor=r.walletAnchor;local window=anchor and c.records[anchor.window]
 if not anchor or anchor.session~=r.session or not integer(anchor.amount,0,9007199254740991)or not integer(anchor.sequence,0,9007199254740991)or type(anchor.ts)~='number'or r.ts<anchor.ts or r.ts-anchor.ts>15
  or not window or window.kind~='wallet_window'or window.session~=r.session then return end
 local balance=anchor.amount;local seen={};local wallets={}
 for _,id in ipairs(r.wallets or{})do _auctionTick(); local w=c.records[id]
  if seen[id]or not w or w.kind~='gold'or w.session~=r.session or w.window~=window.id or w.before~=balance or not integer(w.after,0,9007199254740991)
   or w.amount~=w.after-w.before or w.amount*plan.gold<=0 or S.Sequence(w)<=anchor.sequence or w.ts<r.ts or w.ts>r.lastRequestAt+5 or w.ts>r.settledAt then return end
  seen[id]=true;balance=w.after;wallets[#wallets+1]=w
 end
 if #wallets==0 or balance~=r.walletAfter or balance-anchor.amount~=plan.gold then return end
 return {wallets=wallets,amount=plan.gold,source='mail',components=plan.components},'Collected attachments and net mail gold match the observed inventory and wallet chains; attribution is inferred.'
end
function K.Price(c,r,itemID)
 local plan=K.Plan(c,r);if not plan then return nil,'Mail receipt evidence is incomplete.'end
 local part;for _,v in ipairs(plan.components)do _auctionTick(); if v.items[itemID]then if part then return nil,'Multiple envelopes contribute this item; price ordering is unresolved.'end;part=v end end
 if not part then return nil,'This item has no linked envelope.'end
 local data=c.records[part.record].mailData;local quantity=part.beforeItems[itemID];local types=0;for _ in pairs(part.beforeItems)do _auctionTick(); types=types+1 end
 if types~=1 then return nil,'A bundled price needs an explicit allocation across item types.'end
 local invoice=data.invoice
 local named=invoice and type(invoice.itemName)=='string';for _,item in ipairs(data.items)do _auctionTick(); if not invoice or item.name~=invoice.itemName then named=false end end
 if named and invoice.type=='buyer'and data.cod==0 and integer(invoice.bid,0,9007199254740991)and integer(invoice.count,1)and quantity<=invoice.count then
  return {amount=invoice.bid,quantity=invoice.count,offset=invoice.count-quantity,envelope=part.record},'Cost inferred from the reported auction purchase invoice; no additional gold transaction is created.'
 end
 if part.cod>0 and part.items[itemID]==quantity then
  local cash=K.Cash(c,r);if not cash then return nil,'The COD payment does not match the wallet evidence.'end
  for _,w in ipairs(cash.wallets)do _auctionTick(); if w.source~='mail'or(w.quality~='inferred'and w.quality~='confirmed')then return nil,'The COD payment source is unknown or disputed.'end end
  return {amount=part.cod,quantity=quantity,offset=0,envelope=part.record},'Cost inferred from a full single-item COD collection and matching payment.'
 end
 return nil,'No complete purchase invoice or supported COD payment establishes an acquisition cost.'
end
local affecting={mail_collection=true,inventory=true,inventory_gap=true,bank=true,merchant=true,trade=true,trade_offer=true,trade_notice=true}
local function linkRecord(c,r,saved)
 local prior=dependencies[c]and dependencies[c][r.id]
 local batches=r.kind=='mail_collection'and{r}or Q.Range(c,r.ts-1015,r.ts+1,'mail_collection')
 local function include(id)
  local active=c.records[id]
  if active and active.kind=='mail_collection' and active.character==c.id and not contains(batches,active)then batches[#batches+1]=active end
 end
 if saved then for id in pairs(saved)do _auctionTick(); include(id)end else include(c.state.activeMailCollection)end
 local parent=r.trade and c.records[r.trade]or r;local refs=_auctionCopy(parent.refs or{});refs[#refs+1]=r.inventoryRecord or r.id
 local linked={};for key in pairs(prior or{})do _auctionTick(); local batch=c.records[key]
  if batch and batch.kind=='mail_collection'then linked[key]=true;if not contains(batches,batch)then batches[#batches+1]=batch end end
 end
 for _,id in ipairs(refs)do _auctionTick(); local inv=c.records[id];if inv and inv.kind=='inventory'then for _,key in ipairs(inv.mailCandidates or{})do _auctionTick();
  local batch=c.records[key];if batch then linked[batch.id]=true;if not contains(batches,batch)then batches[#batches+1]=batch end end
 end end end
 for _,batch in ipairs(batches)do _auctionTick();
  local affects=batch.settledAt and batch.inventoryAnchor and(linked[batch.id]or r.ts>=batch.inventoryAnchor.ts and r.ts<=batch.settledAt)
  if affects then depend(c,batch,r.id)end
  local plan=K.Plan(c,batch);if plan then for _,inv in ipairs(plan.records)do _auctionTick();
  if not contains(inv.mailCandidates,batch.id)then
   inv.mailCandidates=inv.mailCandidates or{};inv.mailCandidates[#inv.mailCandidates+1]=batch.id
   inv.refs=inv.refs or{};if not contains(inv.refs,batch.id)then inv.refs[#inv.refs+1]=batch.id end
   batch.refs=batch.refs or{};if not contains(batch.refs,inv.id)then batch.refs[#batch.refs+1]=inv.id end
   S.Changed(c,inv);S.Changed(c,batch)
  end
 end end
  if r.kind~='mail_collection'and affects then S.Changed(c,batch)end
 end
end
local update=E.Inventory.CostLinkHandler(K,'MailCosts',function(c,r,receipt)
 if E.AuctionPreparation and E.AuctionPreparation.ReturnReviewReceipt(c,r,receipt)then return false end
 return affecting[r.kind]or affecting[Q.PreviousKind(c,r.id)]or dependencies[c]and dependencies[c][r.id]
end,linkRecord,function(c)return c.state.activeMailCollection end)
E.On('RECORD_ADDED',update);E.On('RECORD_CHANGED',update)
function K.Project(c,r)
 if r.kind~='cost_lot'or r.source~='inventory observation'then return end
 local inv=c.records[r.evidence];local batch=K.Resolve(c,inv);if not batch then return end
 local price=K.Price(c,batch,r.itemID);local part=K.Plan(c,batch).rows[inv.id][r.itemID]
 if not price or not part or part.quantity~=r.quantity then return end
 local copy=_auctionCopy(r);copy.cost=F.Part(price.amount,price.quantity,price.offset+part.offset,r.quantity)
 copy.baseCost,copy.baseQuantity,copy.baseOffset=price.amount,price.quantity,price.offset+part.offset
 copy.mailReceipt=batch.id;copy.quality='inferred';copy.title='Inferred mail acquisition cost';return {copy}
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="MailCosts",create=create}
E.AuctionReaderSources["MailCosts.lua"]="59e7265298a4b80e7c7f47a0f2356d67048a32affb4c4159b96e708b865f5d9a"
end

-- SentMailCosts.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='SentMailCosts';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local K,S,Q,F={},E.Store,E.Query,E.Economy;E.SentMailCosts=K
local caches=setmetatable({},{__mode='k'})
local function integer(v,min,max)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=(max or 67108864)end
local function contains(rows,id)for _,v in ipairs(rows or{})do _auctionTick(); if v==id then return true end end end
local function counts(r)
 if not r or r.kind~='inventory'or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
 local out={};for _,map in ipairs({r.carried,r.equipment})do _auctionTick(); for id,n in pairs(map)do _auctionTick();
  if not integer(id,1)or not integer(n)then return end;out[id]=(out[id]or 0)+n;if not integer(out[id])then return end
 end end;return out
end
local function same(a,b)
 for id,n in pairs(a)do _auctionTick(); if n~=(b[id]or 0)then return false end end
 for id,n in pairs(b)do _auctionTick(); if n~=(a[id]or 0)then return false end end;return true
end
local function attachments(data)
 if not data or data.complete~=true or type(data.items)~='table'or #data.items>12 then return end
 local out,slots={},{};for _,v in ipairs(data.items)do _auctionTick();
  if not integer(v.slot,1,12)or slots[v.slot]or not integer(v.itemID,1)or not integer(v.quantity,1)then return end
  slots[v.slot]=true;out[v.itemID]=(out[v.itemID]or 0)+v.quantity;if not integer(out[v.itemID],1)then return end
 end;return out
end
local function build(c,b)
 if not b or b.kind~='mail_collection'or b.character~=c.id or not b.session or not b.visit or not b.settledAt or b.interrupted or b.failed or b.overflow
  or #(b.requests or{})~=1 or #(b.notices or{})~=1 or b.requests[1]~=b.sendRequest then return end
 local r,n=c.records[b.sendRequest],c.records[b.notices[1]]
 if not r or r.kind~='mail_request'or r.character~=c.id or r.method~='SendMail'or r.unavailable or r.collection~=b.id or r.session~=b.session or r.visit~=b.visit
  or not n or n.kind~='mail_notice'or n.character~=c.id or n.collection~=b.id or n.session~=b.session or n.visit~=b.visit or n.unavailable or n.event~='MAIL_SEND_SUCCESS'
  or n.ts<r.ts or n.ts>r.ts+5 or n.ts>b.settledAt or S.Sequence(n)<=S.Sequence(r)then return end
 local d=r.sendData;local expected=d and attachments({complete=d.attachmentsComplete,items=d.items});if not expected or not next(expected)then return end
 local anchor=b.inventoryAnchor;local draft=d.draft and c.records[d.draft];local draftBased=false
 if d.draft then
  if not draft or draft.kind~='mail_draft'or draft.character~=c.id or draft.session~=b.session or draft.visit~=b.visit or draft.interrupted
   or #(draft.requests or{})~=1 or draft.requests[1]~=r.id or type(draft.snapshots)~='table'or not integer(d.draftSnapshot,1)or not draft.snapshots[d.draftSnapshot]then return end
  local previous,stamp={},draft.ts
  for i=1,d.draftSnapshot do _auctionTick(); local snap=draft.snapshots[i];local amounts=attachments(snap.data)
   if not amounts or snap.ts<stamp or snap.ts>r.ts then return end
   for id,qty in pairs(previous)do _auctionTick(); if (amounts[id]or 0)<qty then return end end
   for id,qty in pairs(amounts)do _auctionTick(); if qty>(expected[id]or 0)then return end end
   previous=amounts;stamp=snap.ts
  end
  if not same(previous,expected)then return end
  if draft.inventoryAnchor then
   local first=attachments(draft.snapshots[1].data)
   if not first or next(first)then return end
   anchor=draft.inventoryAnchor;draftBased=true
  end
 end
 if not anchor or anchor.session~=b.session or anchor.scope~='bags and equipment'or not integer(anchor.sequence,0,9007199254740991)
  or type(anchor.ts)~='number'or anchor.ts>(draftBased and draft.ts or b.ts)or(draftBased and draft.ts or b.ts)-anchor.ts>15
  or anchor.sequence>=S.Sequence(draftBased and draft or b)then return end
 local base=c.records[anchor.record];local current=counts(base)
 if not current or base.character~=c.id or base.session~=b.session or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
 local left=_auctionCopy(expected);local remaining=0;for id,qty in pairs(left)do _auctionTick(); if qty>(current[id]or 0)then return end;remaining=remaining+qty end
 local plan={batch=b,request=r,notice=n,draft=draft,anchor=anchor,items=expected,quantity=remaining,records={},rows={},refs={r.id,n.id,base.id}}
 if draft then plan.refs[#plan.refs+1]=draft.id end
 local successors={};for _,inv in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'inventory'))do _auctionTick(); if inv.previousRecord and S.Sequence(inv)>anchor.sequence then
  if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
 end end
 local previous,stamp,sequence=base.id,anchor.ts,anchor.sequence
 while remaining>0 do _auctionTick(); local inv=successors[previous];local actual=counts(inv)
  if not actual or inv.character~=c.id or inv.baseline or inv.session~=b.session or S.Sequence(inv)<=sequence
   or not inv.observedFrom or inv.observedFrom<stamp or inv.ts<inv.observedFrom or inv.ts>r.ts+5 or inv.ts>b.settledAt
   or(inv.accountingTime or inv.ts)~=inv.ts or not _auctionSame(base.equipment,inv.equipment)then return end
  local rows,changed={},0
  for _,v in ipairs(inv.items or{})do _auctionTick();
   if not left[v.itemID]or rows[v.itemID]or not integer(v.before)or not integer(v.after)or v.before~=(current[v.itemID]or 0)
    or v.delta~=v.after-v.before or v.delta>=0 or -v.delta>left[v.itemID]then return end
   rows[v.itemID]={quantity=-v.delta};left[v.itemID]=left[v.itemID]+v.delta;current[v.itemID]=v.after;changed=changed-v.delta
  end
  if changed==0 or not same(current,actual)then return end
  remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows;plan.refs[#plan.refs+1]=inv.id
  previous,stamp,sequence=inv.id,inv.ts,S.Sequence(inv)
 end
 if successors[previous]~=nil then return end
 for _,gap in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'inventory_gap'))do _auctionTick(); if S.Sequence(gap)>anchor.sequence then return end end
 for _,other in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'mail_request'))do _auctionTick(); if other.id~=r.id and S.Sequence(other)>anchor.sequence then return end end
 for _,other in ipairs(Q.Range(c,anchor.ts,b.settledAt+1,'mail_notice'))do _auctionTick(); if other.id~=n.id and S.Sequence(other)>anchor.sequence then return end end
 return plan
end
local function cache(c)
 local out=caches[c];if not out or out.revision~=c.revision then out={revision=c.revision,plans={}};caches[c]=out end;return out
end
function K.Plan(c,r)
 if not r then return end;local saved=cache(c)
 if saved.plans[r.id]==nil then saved.plans[r.id]=build(c,r)or false end;return saved.plans[r.id]or nil
end
function K.Claim(c,inv)
 if not inv or inv.kind~='inventory'then return false end
 local saved=cache(c)
 if not saved.claims then
  saved.claims={};for _,b in ipairs(Q.Kind(c,'mail_collection'))do _auctionTick(); local p=K.Plan(c,b)
   if p then for _,r in ipairs(p.records)do _auctionTick(); local rows=saved.claims[r.id]or{};saved.claims[r.id]=rows;rows[#rows+1]=b end end
  end
 end
 return saved.claims[inv.id]and #saved.claims[inv.id]>0 or false,saved.claims[inv.id]
end
function K.Resolve(c,b)
 local p=K.Plan(c,b);if not p then return nil,'No complete send, attachment and continuous inventory match.'end
 if b.rejectSentItems then return nil,'This inferred outgoing-item match was rejected.'end
 for _,inv in ipairs(p.records)do _auctionTick();
  if E.CraftCosts and E.CraftCosts.Claim(c,inv)then return nil,'Crafting and outgoing mail evidence overlap; item costs remain unknown.'end
  local _,claims=K.Claim(c,inv);if not claims or #claims~=1 then return nil,'More than one send claims these items.'end
  if E.AuctionCosts.Claim(c,inv)or E.TradeCosts.Claim(c,inv)or E.MailCosts.Claim(c,inv)then return nil,'Other transaction evidence also claims these items.'end
  for _,id in ipairs(inv.merchantCandidates or{})do _auctionTick(); if E.CostMatch.Compatible(c,inv,c.records[id])then return nil,'Merchant evidence overlaps these items.'end end
  for _,bank in ipairs(Q.Range(c,inv.ts,inv.ts+1,'bank'))do _auctionTick(); if bank.inventoryRecord==inv.id and #(bank.transfers or{})>0 then return nil,'Bank evidence overlaps these items.'end end
 end
 return p,'Send success, attachments and uninterrupted inventory decreases agree; outgoing items are inferred, delivery remains unknown.'
end
function K.Project(c,r)
 if r.kind~='stock_move'or r.source~='inventory observation'then return end
 local inv=c.records[r.evidence];local _,claims=K.Claim(c,inv)
 if not claims or #claims~=1 then return end
 local p=K.Resolve(c,claims[1]);local row=p and p.rows[inv.id][r.itemID]
 if not row or row.quantity~=r.quantity then return end
 local copy=_auctionCopy(r);copy.sentMail=claims[1].id;copy.quality='inferred';copy.title='Inferred outgoing mailed items';copy.reason='Outgoing mail / recipient delivery not observed';return {copy}
end
function K.Info(c,b)
 local p,why=K.Resolve(c,b);if not p then return nil,why end
 local out={plan=p,items={},quantity=p.quantity,knownCost=0,unknownQuantity=0,movements={}}
 for _,inv in ipairs(p.records)do _auctionTick(); for itemID,row in pairs(p.rows[inv.id])do _auctionTick(); local raw
  for _,id in ipairs(inv.refs or{})do _auctionTick(); local r=c.records[id]
   if r and r.kind=='stock_move'and r.source=='inventory observation'and r.evidence==inv.id and r.itemID==itemID and r.quantity==row.quantity then
    if raw then return nil,'Duplicate accounting movements prevent a unique cost match.'end;raw=r
   end
  end
  if not raw then return nil,'The original inventory outflow is unavailable.'end
  local info=F.Replay(c,math.huge,S.Sequence(raw)).movements[raw.id]
  if not info or info.record.kind~='stock_move'or info.record.sentMail~=b.id then return nil,'The original FIFO movement is unavailable or disputed.'end
  local item=out.items[itemID]or{quantity=0,knownCost=0,unknownQuantity=0,parts={}};out.items[itemID]=item
  item.quantity=item.quantity+row.quantity;item.knownCost=item.knownCost+info.knownCost;item.unknownQuantity=item.unknownQuantity+info.unknownQuantity
  for _,part in ipairs(info.allocations)do _auctionTick(); item.parts[#item.parts+1]=_auctionCopy(part)end
  out.knownCost=out.knownCost+info.knownCost;out.unknownQuantity=out.unknownQuantity+info.unknownQuantity;out.movements[#out.movements+1]=raw
 end end
 for _,item in pairs(out.items)do _auctionTick(); if item.unknownQuantity==0 then item.cost=item.knownCost end end
 if out.unknownQuantity==0 then out.cost=out.knownCost end;return out,why
end
local function linkRecord(c,r)
 local batches
 if r.kind=='mail_collection'then batches={r}
 elseif r.kind=='inventory'then batches=Q.Kind(c,'mail_collection')
 else
  batches={};local ids=r.kind=='mail_draft'and r.requests or{r.id}
  for _,id in ipairs(ids or{})do _auctionTick(); local source=c.records[id];local batch=source and c.records[source.collection]
   if batch then batches[#batches+1]=batch end
  end
 end
 for _,b in ipairs(batches)do _auctionTick(); local p=K.Plan(c,b)
  if p then local changed=false;b.refs=b.refs or{}
   for _,id in ipairs(p.refs)do _auctionTick(); if not contains(b.refs,id)then b.refs[#b.refs+1]=id;changed=true end end
   for _,inv in ipairs(p.records)do _auctionTick(); inv.refs=inv.refs or{};if not contains(inv.refs,b.id)then inv.refs[#inv.refs+1]=b.id;S.Changed(c,inv)end end
   if changed then S.Changed(c,b)end
  end
 end
end
local link=E.Inventory.CostLinkHandler(K,'SentMailCosts',function(_,r)
 return r.kind=='mail_collection'or r.kind=='inventory'or r.kind=='mail_request'or r.kind=='mail_notice'or r.kind=='mail_draft'
end,linkRecord)
E.On('RECORD_ADDED',link);E.On('RECORD_CHANGED',link)
E.On('RECORDS_REMOVED',function(c)caches[c]=nil end)

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="SentMailCosts",create=create}
E.AuctionReaderSources["SentMailCosts.lua"]="453b3d2759286498bb73721c29709ca968d4e274f3510e9e578866f1419dfa96"
end

-- CraftCosts.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='CraftCosts';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local K,S,Q,F,A={},E.Store,E.Query,E.Economy,E.API;E.CraftCosts=K
local caches=setmetatable({},{__mode='k'})
-- A donor character's changed bank costs can change crafted material basis here.
local function invalidate()caches=setmetatable({},{__mode='k'})end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',invalidate)
local function integer(v,min,max)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=(max or 67108864)end
local function contains(list,id)for _,v in ipairs(list or{})do _auctionTick(); if v==id then return true end end end
local function dense(t,limit)
 if type(t)~='table'or #t>limit then return false end
 local n=0;for k in pairs(t)do _auctionTick(); if not integer(k,1,limit)then return false end;n=n+1 end
 return n==#t
end
local function cache(c)
 local out=caches[c];if not out or out.revision~=c.revision then out={revision=c.revision,plans={},costs={}};caches[c]=out end;return out
end
function K.Capture(r,incomplete)
 r.materialCoverage='Recipe material requirements unavailable.'
 if r.requestMethod~='CraftRecipe'or r.orderID or incomplete or(r.reagentCoverage~='observed argument list'and r.reagentCoverage~='not supplied')then return end
 local spec=A.Call('craftMaterialSchematic',C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic,r.recipeID,false,r.recipeLevel)
 if A.status.craftMaterialSchematic~='call succeeded; client behavior still needs validation'or type(spec)~='table'or spec.recipeID~=r.recipeID
  or spec.isRecraft~=false or spec.recipeType~=1 or not integer(spec.outputItemID,1)or not integer(spec.quantityMin,1)
  or not integer(spec.quantityMax,spec.quantityMin)or not dense(spec.reagentSlotSchematics,128)then return end
 local selected={};for _,v in ipairs(r.requestedReagents or{})do _auctionTick();
  if v.quantity>0 then
   if not v.itemID or v.currencyID then r.materialCoverage='Currency material costs remain unknown.';return end
   local slot=selected[v.slot]or{};selected[v.slot]=slot;slot[v.itemID]=(slot[v.itemID]or 0)+v.quantity
  end
 end
 local amounts,slots={},{}
 for _,slot in ipairs(spec.reagentSlotSchematics)do _auctionTick();
  if not integer(slot.dataSlotIndex,1)or slots[slot.dataSlotIndex]or slot.dataSlotType~=1 or type(slot.required)~='boolean'
   or not integer(slot.quantityRequired)or not dense(slot.reagents,128)or not dense(slot.variableQuantities,128)or #slot.variableQuantities>0 then
   r.materialCoverage='Variable, modified or incomplete material requirements remain unknown.';return
  end
  slots[slot.dataSlotIndex]=true;local choices={}
  for _,v in ipairs(slot.reagents)do _auctionTick(); if not integer(v.itemID,1)or v.currencyID or choices[v.itemID]then return end;choices[v.itemID]=true end
  local allocation=selected[slot.dataSlotIndex]
  if not allocation and slot.required then
   if #slot.reagents~=1 then r.materialCoverage='A required reagent choice was not recorded.';return end
   allocation={[slot.reagents[1].itemID]=slot.quantityRequired}
  end
  local total=0
  for id,n in pairs(allocation or{})do _auctionTick();
   if not choices[id]or not integer(n,1)then return end
   total=total+n;amounts[id]=(amounts[id]or 0)+n;if not integer(amounts[id],1)then return end
  end
  if (slot.required or allocation)and total~=slot.quantityRequired then r.materialCoverage='Selected quantities do not match the recipe requirements.';return end
 end
 for id in pairs(selected)do _auctionTick(); if not slots[id]then r.materialCoverage='Selected inputs include an unknown recipe slot.';return end end
 if not next(amounts)or amounts[spec.outputItemID]then r.materialCoverage='Material-free or same-item transformations have no supported cost allocation.';return end
 local items={};for _,id in ipairs(E.SortedKeys(amounts))do _auctionTick(); items[#items+1]={itemID=id,quantity=amounts[id]}end
 r.materialSpec={items=items,outputItemID=spec.outputItemID,quantityMin=spec.quantityMin,quantityMax=spec.quantityMax,
  recipeID=spec.recipeID,recipeLevel=r.recipeLevel,source='C_TradeSkillUI.GetRecipeSchematic',meaning='requirements per cast, not observed consumption'}
 r.materialCoverage='Fixed item requirements observed; consumption still unconfirmed.'
end
local function counts(r)
 if not r or r.kind~='inventory'or r.scope~='bags and equipment'or type(r.carried)~='table'or type(r.equipment)~='table'then return end
 local out={};for _,map in ipairs({r.carried,r.equipment})do _auctionTick(); for id,n in pairs(map)do _auctionTick();
  if not integer(id,1)or not integer(n)then return end;out[id]=(out[id]or 0)+n;if not integer(out[id])then return end
 end end;return out
end
local function same(a,b)
 for id,n in pairs(a)do _auctionTick(); if n~=(b[id]or 0)then return false end end
 for id,n in pairs(b)do _auctionTick(); if n~=(a[id]or 0)then return false end end;return true
end
local function outputPayload(link,itemID)
 if type(link)~='string'then return end
 local payload=link:match('|H(item:[^|]+)|h')
 if payload and tonumber(payload:match('^item:(%d+):')or payload:match('^item:(%d+)$'))==itemID then return payload end
end
local function build(c,r,asClosure)
 local spec=r and r.materialSpec;local anchor=r and r.inventoryAnchor
 if not r or r.kind~='craft_request'or r.character~=c.id or r.subject~=c.id or not r.session or r.requestMethod~='CraftRecipe'or r.orderID or r.npcCrafting~=false
  or not integer(r.requestCasts,1,1000)or not spec or spec.recipeID~=r.recipeID or not dense(spec.items,128)
  or not integer(spec.outputItemID,1)or not integer(spec.quantityMin,1)or not integer(spec.quantityMax,spec.quantityMin)
  or not anchor or anchor.session~=r.session or anchor.scope~='bags and equipment'or not integer(anchor.sequence,0,9007199254740991)
  or type(anchor.ts)~='number'or anchor.ts>r.ts or r.ts-anchor.ts>15 or anchor.sequence>=S.Sequence(r)then return end
 local base=c.records[anchor.record];local current=counts(base)
 if not current or base.character~=c.id or base.session~=r.session or base.ts>anchor.ts or S.Sequence(base)>anchor.sequence then return end
 local inputs,perCast={},{};for _,v in ipairs(spec.items)do _auctionTick();
  if not integer(v.itemID,1)or not integer(v.quantity,1)or inputs[v.itemID]or v.itemID==spec.outputItemID then return end
  local n=v.quantity*r.requestCasts;if not integer(n,1)or v.quantity>(current[v.itemID]or 0)then return end
  inputs[v.itemID]=n;perCast[v.itemID]=v.quantity
 end
 if not next(inputs)then return end
 -- A bounded window is only a candidate search. Starts, results, personal
 -- creation receipts and every inventory delta must independently agree.
 local finish=r.ts+math.min(7200,r.requestCasts*60+10);local boundary=math.huge
 for _,other in ipairs(Q.Range(c,r.ts-15,finish+1,'craft_request'))do _auctionTick(); if other.id~=r.id and S.Sequence(other)>S.Sequence(base) then
  if S.Sequence(other)<S.Sequence(r)then return end
  boundary=math.min(boundary,S.Sequence(other))
 end end
 local multicraftPayload
 local starts,results,receipts={},{},{};local quantity,last,lastSequence=0,r.ts,S.Sequence(r)
 local function eligible(v)return v.ts>=r.ts and S.Sequence(v)>S.Sequence(r)and S.Sequence(v)<boundary end
 for _,v in ipairs(Q.Range(c,r.ts,finish+1,'craft_begin'))do _auctionTick(); if eligible(v)then
  if v.character~=c.id or v.session~=r.session or v.subject~=c.id or v.recipeID~=r.recipeID or v.npcCrafting~=false then return end
  starts[#starts+1]=v;last=math.max(last,v.ts);lastSequence=math.max(lastSequence,S.Sequence(v))
 end end
 if #starts~=r.requestCasts then return end
 for _,v in ipairs(Q.Range(c,r.ts,finish+1,'craft_result'))do _auctionTick(); if eligible(v)then local d=v.result
  if v.character~=c.id or v.session~=r.session or v.subject~=c.id or v.npcCrafting~=false or v.coverage~='notification observed'or v.unresolvedCraftRequestAtObservation or not d
   or d.itemID~=spec.outputItemID or not integer(d.quantity,1) or not integer(d.multicraft)
   or d.isEnchant~=false or d.firstCraftReward~=false or d.bonusCraft~=false
   or(d.resourcesCoverage~='observed'and d.resourcesCoverage~='none reported')or not dense(d.resourcesReturned,128)
   or d.resourcesCoverage=='none reported'and #d.resourcesReturned>0 then return end
  -- The result item count already includes any separately reported multicraft
  -- units. Check the implied ordinary output against the schematic, then
  -- require the observed total in both the personal receipt and bag chain.
  if not integer(d.quantity-d.multicraft,spec.quantityMin,spec.quantityMax)then return end
  if d.multicraft>0 then
   if r.requestCasts~=1 or not integer(r.recipeID,1)or r.subject~=c.id or c.records[r.id]~=r
    or r.source~='C_TradeSkillUI.CraftRecipe' or c.records[v.id]~=v or v.source~='TRADE_SKILL_ITEM_CRAFTED_RESULT'
    or v.multicraftRequestAtObservation~=r.id or v.itemID~=spec.outputItemID or c.records[starts[1].id]~=starts[1] or starts[1].source~='TRADE_SKILL_CRAFT_BEGIN' then return end
   multicraftPayload=outputPayload(d.hyperlink,spec.outputItemID)
   if not multicraftPayload then return end
  end
  local returned={};for _,a in ipairs(d.resourcesReturned)do _auctionTick();
   if a.currencyID or not inputs[a.itemID]or not integer(a.quantity,1)or a.quantity>inputs[a.itemID]then return end
   returned[a.itemID]=(returned[a.itemID]or 0)+a.quantity;if returned[a.itemID]>perCast[a.itemID]then return end
   inputs[a.itemID]=inputs[a.itemID]-a.quantity
  end
  results[#results+1]=v;quantity=quantity+d.quantity;last=math.max(last,v.ts);lastSequence=math.max(lastSequence,S.Sequence(v))
 end end
 if #results~=r.requestCasts or not integer(quantity,1)then return end
 for i,v in ipairs(results)do _auctionTick(); if not S.Before(starts[i],v)or S.Sequence(starts[i])>=S.Sequence(v)then return end end
 local received=0
 for _,v in ipairs(Q.Range(c,r.ts,finish+1,'crafted'))do _auctionTick(); if eligible(v)and v.recipient==c.id then
  if v.character~=c.id or v.session~=r.session or v.itemID~=spec.outputItemID or not integer(v.quantity,1)or not S.Before(starts[1],v)or S.Sequence(starts[1])>=S.Sequence(v)then return end
  receipts[#receipts+1]=v;received=received+v.quantity;last=math.max(last,v.ts);lastSequence=math.max(lastSequence,S.Sequence(v))
 end end
 if received~=quantity then return end
 if multicraftPayload then
  local receipt=receipts[1]
  if #receipts~=1 or c.records[receipt.id]~=receipt or receipt.observationType~='receipt'
   or outputPayload(receipt.itemLink,spec.outputItemID)~=multicraftPayload then return end
 end
 local expected={};local remaining=quantity
 for id,n in pairs(inputs)do _auctionTick(); if n>0 then expected[id]=-n;remaining=remaining+n end end;expected[spec.outputItemID]=quantity
 local plan={request=r,anchor=anchor,base=base,inputs=inputs,outputItemID=spec.outputItemID,quantity=quantity,records={},rows={},raw={},refs={base.id},starts=starts,results=results,receipts=receipts}
 for _,rows in ipairs({starts,results,receipts})do _auctionTick(); for _,v in ipairs(rows)do _auctionTick(); plan.refs[#plan.refs+1]=v.id end end
 local successors={}
 for _,inv in ipairs(Q.Range(c,anchor.ts,last+3,'inventory'))do _auctionTick(); if inv.previousRecord and S.Sequence(inv)>anchor.sequence and S.Sequence(inv)<boundary then
  if successors[inv.previousRecord]~=nil then successors[inv.previousRecord]=false else successors[inv.previousRecord]=inv end
 end end
 local previous,stamp,sequence=base.id,anchor.ts,anchor.sequence;local left=_auctionCopy(expected);local outputOffset=0
 while remaining>0 do _auctionTick();
  local inv=successors[previous];local actual=counts(inv)
  if not actual or inv.character~=c.id or inv.baseline or inv.session~=r.session or S.Sequence(inv)<=sequence or inv.ts<r.ts
   or not inv.observedFrom or inv.observedFrom<stamp or inv.ts<inv.observedFrom or inv.ts>last+2
   or(inv.accountingTime or inv.ts)~=inv.ts or not _auctionSame(base.equipment,inv.equipment)then return end
  local rows,changed={},0
  for _,v in ipairs(inv.items or{})do _auctionTick();
   if not left[v.itemID]or rows[v.itemID]or not integer(v.before)or not integer(v.after)or v.before~=(current[v.itemID]or 0)
    or v.delta~=v.after-v.before or v.delta==0 or v.delta*left[v.itemID]<=0 or math.abs(v.delta)>math.abs(left[v.itemID])then return end
   rows[v.itemID]={quantity=math.abs(v.delta),input=v.delta<0,offset=v.delta>0 and outputOffset or nil}
   if v.delta>0 then outputOffset=outputOffset+v.delta end
   left[v.itemID]=left[v.itemID]-v.delta;current[v.itemID]=v.after;changed=changed+math.abs(v.delta)
  end
  if changed==0 or not same(current,actual)then return end
  for itemID,row in pairs(rows)do _auctionTick(); local raw
   for _,id in ipairs(inv.refs or{})do _auctionTick(); local v=c.records[id]
    if v and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==itemID and v.kind==(row.input and'stock_move'or'cost_lot')then
     if raw or v.quantity~=row.quantity or v.character~=c.id or v.ts~=inv.ts then return end;raw=v
    end
   end
   if not raw then return end;row.raw=raw.id;plan.raw[raw.id]=row;lastSequence=math.max(lastSequence,S.Sequence(raw))
  end
  remaining=remaining-changed;plan.records[#plan.records+1]=inv;plan.rows[inv.id]=rows;plan.refs[#plan.refs+1]=inv.id
  previous,stamp,sequence=inv.id,inv.ts,S.Sequence(inv)
 end
 if successors[previous]~=nil then return end
 plan.finish=math.max(last,stamp);plan.finishSequence=lastSequence
 -- A prior request needs evidence of completion before the next call. Rows
 -- observed at or after that call cannot interrupt the prior observation
 -- interval, even if the wall clock is unchanged. Keep the public cost
 -- plan's conservative full-window reconciliation intact.
 local cutoff=asClosure and math.min(boundary,lastSequence+1) or math.huge
 for _,gap in ipairs(Q.Range(c,anchor.ts,plan.finish+1,'inventory_gap'))do _auctionTick(); if S.Sequence(gap)>anchor.sequence and S.Sequence(gap)<cutoff then return end end
 -- No hidden accounting changes may alter the starting FIFO stock between its
 -- observation and the matched material outflows.
 for _,kind in ipairs({'cost_lot','stock_move','stock_reset','item_sale','sale_return'})do _auctionTick();
  for _,v in ipairs(Q.Range(c,anchor.ts,plan.finish+1,kind))do _auctionTick(); if S.Sequence(v)>anchor.sequence and S.Sequence(v)<cutoff and not plan.raw[v.id]then return end end
 end
 for _,kind in ipairs({'loot','gathered'})do _auctionTick(); for _,v in ipairs(Q.Range(c,anchor.ts,plan.finish+1,kind))do _auctionTick();
  if S.Sequence(v)>anchor.sequence and S.Sequence(v)<cutoff and v.recipient==c.id then return end
 end end
 return plan
end
local function otherClaim(c,inv)
  if E.AuctionCosts.Claim(c,inv)or E.TradeCosts.Claim(c,inv)or E.MailCosts.Claim(c,inv)or E.SentMailCosts.Claim(c,inv)then return 'Other transaction evidence also claims these items.'end
  for _,id in ipairs(inv.merchantCandidates or{})do _auctionTick(); if E.CostMatch.Compatible(c,inv,c.records[id])then return 'Merchant evidence overlaps these items.'end end
  for _,bank in ipairs(Q.Range(c,inv.ts,inv.ts+1,'bank'))do _auctionTick(); if bank.inventoryRecord==inv.id and #(bank.transfers or{})>0 then return 'Bank evidence overlaps these items.'end end
end
local function closedPrior(c,p,checks)
 local id=p.request.id
 if checks[id]==nil then
  local closed=not p.request.rejectCraftCosts and not p.request.rejectProductionAssociation
  if closed then for _,inv in ipairs(p.records)do _auctionTick(); if otherClaim(c,inv)then closed=false;break end end end
  checks[id]=closed
 end
 return checks[id]
end
function K.Plan(c,r)
 if not r or r.kind~='craft_request' or c.records[r.id]~=r then return end
 local cacheEntry=cache(c);local plans=cacheEntry.plans
 cacheEntry.closed=cacheEntry.closed or{};cacheEntry.priorPlans=cacheEntry.priorPlans or{}
 if plans[r.id]~=nil then return plans[r.id]or nil end
 -- A later hook cannot extinguish an earlier possible request. Prove each
 -- competitor finished before this request, following older proofs without
 -- Lua recursion. Caches belong to the current canonical revision.
 local stack={}
 local function push(request,asClosure)
  local target=asClosure and cacheEntry.priorPlans or plans
  local p=build(c,request,asClosure)
  if p then stack[#stack+1]={target=target,request=request,plan=p,priors=Q.CraftPredecessors(c,request,p.finishSequence),next=1}
  else target[request.id]=false end
 end
 push(r)
 while #stack>0 do _auctionTick();
  local top=stack[#stack];local prior=top.priors[top.next]
  if not prior then top.target[top.request.id]=top.plan;stack[#stack]=nil
  elseif prior.kind~='craft_request' or prior.character~=c.id or not prior.id or c.records[prior.id]~=prior
    or S.Sequence(prior)<=0 or S.Sequence(prior)>=S.Sequence(top.request) then
   top.target[top.request.id]=false;stack[#stack]=nil
  else
   local previous=cacheEntry.priorPlans[prior.id]
   if previous==nil then push(prior,true)
   elseif not previous or previous.finishSequence>=S.Sequence(top.request) or previous.finish>top.request.ts or not closedPrior(c,previous,cacheEntry.closed) then
    top.target[top.request.id]=false;stack[#stack]=nil
   else top.next=top.next+1 end
  end
 end
 return plans[r.id]or nil
end
function K.Claim(c,inv)
 if not inv or inv.kind~='inventory'then return false end
 local saved=cache(c)
 saved.claims=saved.claims or{}
 if saved.claims[inv.id]==nil then
  local list={}
  -- A valid plan starts before its inventory observation and ends within the
  -- 7200-second result horizon plus its observation allowance. Keep the same
  -- conservative 7215-second window used by evidence linking.
  for _,r in ipairs(Q.Range(c,inv.ts-7215,inv.ts+1,'craft_request'))do _auctionTick(); local p=K.Plan(c,r)
   if p and p.rows[inv.id]then list[#list+1]=r end
  end
  saved.claims[inv.id]=#list>0 and list or false
 end
 return saved.claims[inv.id]and #saved.claims[inv.id]>0 or false,saved.claims[inv.id]or nil
end
function K.Resolve(c,r)
 local p=K.Plan(c,r);if not p then return nil,'No complete recipe, result, personal receipt and inventory match.'end
 if r.rejectCraftCosts then return nil,'This inferred crafting cost was rejected.'end
 for _,inv in ipairs(p.records)do _auctionTick();
  local _,claims=K.Claim(c,inv);if not claims or #claims~=1 then return nil,'Multiple requests claim these material changes.'end
  local why=otherClaim(c,inv);if why then return nil,why end
 end
 return p,'Recipe requirements, starts, results, personal creation receipts and continuous inventory changes agree. Material costs are inferred.'
end
function K.Info(c,r)
 local p,why=K.Resolve(c,r);if not p then return nil,why end
 local saved=cache(c);if saved.costs[r.id]then return saved.costs[r.id],why end
 -- The anchor is strictly before this craft. Earlier crafted inputs can retain
 -- their own inferred cost without replaying this output recursively.
 local state=F.Replay(c,math.huge,p.anchor.sequence)
 local out={plan=p,items={},knownCost=0,unknownQuantity=0,quantity=p.quantity}
 for _,id in ipairs(E.SortedKeys(p.inputs))do _auctionTick(); local n=p.inputs[id]
  if n>0 then
   local item={itemID=id,quantity=n,knownCost=0,unknownQuantity=0,parts={}};local left=n
   for _,lot in ipairs(state.stock[id]or{})do _auctionTick();
    local take=math.min(left,lot.quantity-lot.used)
    if take>0 then
     local cost,total,basis,offset=F.SliceCost(lot,lot.used,take)
     item.parts[#item.parts+1]={lot=lot.id,quantity=take,cost=cost,baseCost=total,baseQuantity=basis,baseOffset=offset}
     if cost==nil then item.unknownQuantity=item.unknownQuantity+take
     elseif item.knownCost>9007199254740991-cost then item.overflow=true
     else item.knownCost=item.knownCost+cost end
     left=left-take
    end
    if left==0 then break end
   end
   item.unknownQuantity=item.unknownQuantity+left
   if item.overflow or out.knownCost>9007199254740991-item.knownCost then out.overflow=true
   else out.knownCost=out.knownCost+item.knownCost end
   if item.overflow then item.knownCost=nil elseif item.unknownQuantity==0 then item.cost=item.knownCost end
   out.items[#out.items+1]=item;out.unknownQuantity=out.unknownQuantity+item.unknownQuantity
  end
 end
 if out.overflow then out.knownCost=nil elseif out.unknownQuantity==0 then out.cost=out.knownCost end
 saved.costs[r.id]=out;return out,why
end
function K.Project(c,r)
 if r.source~='inventory observation'or(r.kind~='cost_lot'and r.kind~='stock_move')then return end
 local inv=c.records[r.evidence];local _,claims=K.Claim(c,inv);if not claims or #claims~=1 then return end
 local p=K.Resolve(c,claims[1]);local row=p and p.raw[r.id];if not row or row.quantity~=r.quantity then return end
 local copy=_auctionCopy(r);copy.craftRequest=claims[1].id;copy.quality='inferred'
 if row.input then copy.title='Inferred crafting material consumption';copy.reason='Materials used for a matched crafting request'
 else
  local info=K.Info(c,claims[1]);if not info then return end
  copy.cost=F.Part(info.cost,p.quantity,row.offset,r.quantity);copy.baseCost=info.cost;copy.baseQuantity=p.quantity;copy.baseOffset=row.offset
  copy.title='Inferred crafted-item material cost'
 end
 return {copy}
end
local function linkRecord(c,r)
 for _,request in ipairs(Q.Range(c,r.ts-7215,r.ts+1,'craft_request'))do _auctionTick(); local p=K.Plan(c,request)
  if p then
   local changed=false;request.refs=request.refs or{}
   for _,id in ipairs(p.refs)do _auctionTick(); if not contains(request.refs,id)then request.refs[#request.refs+1]=id;changed=true end end
   for _,inv in ipairs(p.records)do _auctionTick(); inv.refs=inv.refs or{};if not contains(inv.refs,request.id)then inv.refs[#inv.refs+1]=request.id;S.Changed(c,inv)end end
   if changed then S.Changed(c,request)end
  end
 end
end
local link=E.Inventory.CostLinkHandler(K,'CraftCosts',function(_,r)
 return r.kind=='craft_request'or r.kind=='craft_begin'or r.kind=='craft_result'or r.kind=='crafted'or r.kind=='inventory'
end,linkRecord)
E.On('RECORD_ADDED',link);E.On('RECORD_CHANGED',link)
E.On('RECORDS_REMOVED',function(c)caches[c]=nil end)

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="CraftCosts",create=create}
E.AuctionReaderSources["CraftCosts.lua"]="e0de5f94ddd43ee4bc11a4dca55a5ef13e2272ebc5e5e02cc3063b3687346c47"
end

-- MailMoney.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='MailMoney';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local K,S,Q={},E.Store,E.Query;E.MailMoney=K
local function integer(n)return type(n)=='number'and n==n and n>=0 and n%1==0 and n<=9007199254740991 end
local plans=setmetatable({},{__mode='k'})
local indexes,windowSnapshots=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
local addProof
local relevant={mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,gold=true,wallet_window=true,inventory=true,inventory_gap=true,
 bank=true,bank_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,money_evidence=true}
local function invalidate(c,r)if not r or not Q.IsWarm(c)or relevant[r.kind]or relevant[Q.PreviousKind(c,r.id)]then plans[c]=nil end end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',function(c)invalidate(c)end)
local function scanRows(c,id,r)
 local scan=c.records[id]
 if not scan or scan.kind~='mail_scan'or not scan.complete or scan.session~=r.session or scan.visit~=r.visit or scan.loaded~=scan.total or #scan.entries~=scan.loaded then return end
 local rows,seen={},{}
 for _,key in ipairs(scan.entries)do _auctionTick(); local row=c.records[key]
  if seen[key]or not row or row.kind~='mail'or row.scan~=scan.id or row.character~=c.id or row.session~=r.session or row.visit~=r.visit or not row.mailData or not row.mailData.complete then return end
  seen[key]=true;rows[#rows+1]=row
 end
 return rows,scan
end
local function outgoing(c,r)
 if #r.requests~=1 or #r.notices~=1 then return nil,'Outgoing mail needs one request and one send-success notification.'end
 local request=c.records[r.requests[1]];local notice=c.records[r.notices[1]];local d=request and request.sendData
 if not request or request.id~=r.sendRequest or request.kind~='mail_request'or request.method~='SendMail'or request.character~=c.id or request.collection~=r.id
  or request.session~=r.session or request.visit~=r.visit or request.unavailable or type(request.recipient)~='string'or request.recipient==''
  or request.ts<r.ts or request.ts~=r.lastRequestAt or S.Sequence(request)~=r.lastRequestSequence
  or not d or not integer(d.postageQuote)or not integer(d.moneyRequested)or not integer(d.codRequested)
  or d.moneyRequested>0 and d.codRequested>0 then return nil,'A readable send request, postage quote and both money-mode setters are required.'end
 if not notice or notice.kind~='mail_notice'or notice.character~=c.id or notice.collection~=r.id or notice.session~=r.session or notice.visit~=r.visit
  or notice.event~='MAIL_SEND_SUCCESS'or notice.unavailable or notice.itemID or notice.ts<request.ts or notice.ts>request.ts+5
  or notice.ts>r.settledAt or S.Sequence(notice)<=S.Sequence(request)then return nil,'A unique timely send-success notification is unavailable.'end
 local a=r.walletAnchor;local window=a and c.records[a.window]
 if not a or a.session~=r.session or not integer(a.amount)or not integer(a.sequence)or type(a.ts)~='number'
  or request.ts<a.ts or request.ts-a.ts>15 or a.sequence>=S.Sequence(request)
  or not window or window.kind~='wallet_window'or window.character~=c.id or window.session~=r.session then return nil,'Continuous pre-send wallet evidence is unavailable.'end
 local expected=d.postageQuote+d.moneyRequested
 if not integer(expected)or expected==0 then return nil,'No positive send cost to match; a send result alone is not a wallet change.'end
 local balance=a.amount;local wallets,seen={},{}
 for _,id in ipairs(r.wallets or{})do _auctionTick(); local w=c.records[id]
  if seen[id]or not w or w.kind~='gold'or w.character~=c.id or w.session~=r.session or w.window~=a.window
   or w.before~=balance or not integer(w.after)or w.amount>=0 or w.after-w.before~=w.amount
   or S.Sequence(w)<=S.Sequence(request)or w.ts<request.ts or w.ts>request.ts+5 or w.ts>r.settledAt then return nil,'Wallet changes do not form one continuous outgoing-mail interval.'end
  seen[id]=true;balance=w.after;wallets[#wallets+1]=w
 end
 if #wallets==0 or balance~=r.walletAfter or a.amount-balance~=expected then return nil,'Wallet loss does not match quoted postage plus requested attached gold.'end
 return {wallets=wallets,amount=-expected,source='mailSent',components={{record=request.id,amount=-expected,source='mailSent'}},
  outgoing=true,request=request,postage=d.postageQuote,sentGold=d.moneyRequested,codRequested=d.codRequested},
  'One send request, a send-success notification and matching wallet loss agree. Attribution is inferred; recipient delivery and item consumption are not established.'
end
local function build(c,r)
 if E.MailCosts then local plan,reason=E.MailCosts.Cash(c,r);if plan then return plan,reason end end
 if not r or r.kind~='mail_collection'or r.character~=c.id or r.interrupted or r.failed or r.overflow or not r.settledAt then return nil,'No uninterrupted completed collection interval.'end
 if r.sendRequest then return outgoing(c,r)end
 local before,old=scanRows(c,r.beforeScan,r);local after,new=scanRows(c,r.afterScan,r)
 local anchor=r.walletAnchor;local window=anchor and c.records[anchor.window]
 if not before or not after or not anchor or anchor.session~=r.session or not integer(anchor.amount)or not integer(anchor.sequence)
  or not window or window.kind~='wallet_window'or window.session~=r.session or r.ts<anchor.ts or r.ts-anchor.ts>15
  or S.Sequence(old)>=S.Sequence(r)or S.Sequence(new)<=r.lastRequestSequence or new.ts<r.lastRequestAt or new.finishedAt>r.settledAt then
  return nil,'Complete before/after mailbox and wallet evidence is unavailable.'
 end
 if #r.requests==0 or #r.requests>100 or #r.notices~=#r.requests then return nil,'Every money request needs its own success notification.'end
 local seen={}
 for _,id in ipairs(r.requests)do _auctionTick(); local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_request'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.method~='TakeInboxMoney'or not integer(v.index)or v.index<1 or v.index>old.loaded or v.unavailable
   or v.ts<r.ts or v.ts>r.lastRequestAt then return nil,'Mixed, incomplete or missing mail requests remain unclassified.'end;seen[id]=true
 end
 for _,id in ipairs(r.notices)do _auctionTick(); local v=c.records[id]
  if seen[id]or not v or v.kind~='mail_notice'or v.collection~=r.id or v.session~=r.session or v.visit~=r.visit or v.event~='MAIL_SUCCESS'or v.itemID or v.unavailable
   or v.ts<r.ts or v.ts>r.lastRequestAt+5 then return nil,'Mail notifications do not establish a money-only collection.'end;seen[id]=true
 end
 local used,components,total,source={}, {},0,nil
 for i,row in ipairs(before)do _auctionTick();
  local data=row.mailData;local identity=E.Mail.Comparable(data,true)
  for j=1,i-1 do _auctionTick(); if _auctionSame(identity,E.Mail.Comparable(before[j].mailData,true))then return nil,'Identical envelopes cannot be distinguished reliably.'end end
  local match
  for j,nextRow in ipairs(after)do _auctionTick(); if _auctionSame(identity,E.Mail.Comparable(nextRow.mailData,true))then if match then return nil,'The after-list contains ambiguous duplicates.'end;match=j end end
  local remaining=match and after[match].mailData.money or 0
  if match then if used[match]then return nil,'Mailbox match is not unique.'end;used[match]=true end
  if not match and(#(data.items or{})>0 or data.money==0)then return nil,'Items or unrelated mail disappeared during collection.'end
  if not integer(data.money)or not integer(remaining)or remaining>data.money or remaining~=0 and remaining~=data.money then return nil,'Mail gold changes do not match whole-message collections.'end
  local delta=data.money-remaining
  if delta>0 then
   if data.cod~=0 then return nil,'COD collection requires separate expense evidence.'end
   local kind='mail';local invoice=data.invoice
   if invoice and invoice.type=='seller'and integer(invoice.bid)and integer(invoice.deposit)and integer(invoice.cut)
    and integer(invoice.bid+invoice.deposit)and invoice.cut<=invoice.bid+invoice.deposit and invoice.bid+invoice.deposit-invoice.cut==delta then kind='auctionSale' end
   if invoice and invoice.type=='seller_temp_invoice'then return nil,'Pending auction invoices are not settled money.'end
   components[#components+1]={record=row.id,amount=delta,source=kind};total=total+delta
   if not integer(total)then return nil,'Mail total exceeds supported precision.'end
   if not source then source=kind elseif source~=kind then source='mail'end
  end
 end
 for i in ipairs(after)do _auctionTick(); if not used[i]then return nil,'New or changed unrelated mail makes this interval ambiguous.'end end
 if #components~=#r.requests or total<=0 then return nil,'Collected envelopes do not match the number of money requests.'end
 local first=c.records[r.requests[1]];local target=before[first.index];local targeted=false
 for _,component in ipairs(components)do _auctionTick(); if target and component.record==target.id then targeted=true end end
 if not targeted then return nil,'The first requested envelope did not lose its attached gold.'end
 local balance=anchor.amount;local wallets={};seen={}
 for _,id in ipairs(r.wallets or{})do _auctionTick(); local w=c.records[id]
  if seen[id]or not w or w.kind~='gold'or w.session~=r.session or w.window~=anchor.window or w.before~=balance or not integer(w.after)or w.after-w.before~=w.amount or w.amount<=0
   or S.Sequence(w)<=anchor.sequence or w.ts<r.ts or w.ts>r.lastRequestAt+5 or w.ts>r.settledAt then return nil,'Wallet observations do not form a matching collection chain.'end
  seen[id]=true;balance=w.after;wallets[#wallets+1]=w
 end
 if #wallets==0 or balance~=r.walletAfter or balance-anchor.amount~=total then return nil,'Wallet change does not match the collected mail gold.'end
 return {wallets=wallets,amount=total,source=source,components=components},'Money requests, success notifications, mailbox changes and wallet chain match; attribution is inferred.'
end
function K.Plan(c,r)
 if not r then return nil,'Collection record is unavailable.'end
 local cache=plans[c];if not cache then cache={};plans[c]=cache end
 if not cache[r.id]then local plan,reason=build(c,r);cache[r.id]={plan=plan,reason=reason}end
 return cache[r.id].plan,cache[r.id].reason
end
function K.ValidProof(c,proof)
 if indexes[c]then addProof(c,indexes[c],proof)end
 local plan=K.Plan(c,c.records[proof.mailCollection]);if not plan or proof.source~=plan.source then return false end
 for _,w in ipairs(plan.wallets)do _auctionTick(); if w.id==proof.walletID and w.amount==proof.amount and w.ts==proof.ts and w.session==proof.session then return true end end
 return false
end
local busy=false
addProof=function(c,out,p)
 if p and type(p.mailCollection)=='string'and type(p.walletID)=='string'then local r=c.records[p.mailCollection]
  local ids={p.id,p.walletID,p.mailCollection}
  if r then
   for _,id in ipairs(r.refs or{})do _auctionTick(); ids[#ids+1]=id end
   for _,key in ipairs({'requests','notices','wallets'})do _auctionTick(); for _,id in ipairs(r[key]or{})do _auctionTick(); ids[#ids+1]=id end end
   for _,key in ipairs({'beforeScan','afterScan','sendRequest'})do _auctionTick(); if r[key]then ids[#ids+1]=r[key]end end
   local window=r.walletAnchor and r.walletAnchor.window
   if window then
    ids[#ids+1]=window;local w=c.records[window]
    if w then windowSnapshots[c]=windowSnapshots[c]or{};windowSnapshots[c][window]={kind=w.kind,session=w.session,character=w.character}end
   end
   for _,key in ipairs({'beforeScan','afterScan'})do _auctionTick(); local scan=c.records[r[key]];if scan then ids[#ids+1]=scan.id;for _,id in ipairs(scan.entries or{})do _auctionTick(); ids[#ids+1]=id end end end
  end
  for _,id in ipairs(ids)do _auctionTick(); out[id]=out[id]or{};out[id][p.walletID]=true end
 end
end
local function index(c)
 if indexes[c]then return indexes[c]end
 local out={};indexes[c]=out
 for _,p in ipairs(Q.Kind(c,'money_evidence'))do _auctionTick(); addProof(c,out,p)end
 return out
end
E.On('RECORD_ADDED',function(c,r)if r.kind=='money_evidence'and r.mailCollection and indexes[c]then addProof(c,indexes[c],r)end end)
function K.CheckWallet(c,w)
 if w.kind~='gold'or not w.automaticAttribution or w.source=='unknown'then return end
 for _,id in ipairs(w.evidenceRefs or{})do _auctionTick(); local p=c.records[id]
  if indexes[c]then addProof(c,indexes[c],p)end
  if not p or p.mailCollection and not K.ValidProof(c,p)then E.Economy.Attribute(c,w.id,'unknown','unknown',{},true);break end
 end
end
local function recheck(c,r,_,receipt)
 if busy or not r then return end
 if E.AuctionPreparation and E.AuctionPreparation.ReturnReviewReceipt(c,r,receipt)then return end
 if not relevant[r.kind]and not relevant[Q.PreviousKind(c,r.id)]and not(indexes[c]and indexes[c][r.id])then return end
 local previous=windowSnapshots[c]and windowSnapshots[c][r.id]
 if r.kind=='wallet_window'and previous and previous.kind==r.kind and previous.session==r.session and previous.character==r.character then return end
 if Q.EnsureWarm(c)~='ready'then E.GoldChecks.RequestColdReview(c);return end
 busy=true
 local rows={}
 if r.kind=='gold'then rows={r}
 else for id in pairs(index(c)[r.id]or{})do _auctionTick(); if c.records[id]then rows[#rows+1]=c.records[id]end end end
 local ok,why=pcall(function()for _,w in ipairs(rows)do _auctionTick(); K.CheckWallet(c,w)end end)
 busy=false
 if not ok then error(why)end
 if r.kind~='gold'and E.GoldChecks then E.GoldChecks.RequestWallets(c,rows)end
end
E.On('RECORD_CHANGED',recheck)
E.On('RECORDS_REMOVED',function(c)indexes[c]=nil;windowSnapshots[c]=nil end)

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="MailMoney",create=create}
E.AuctionReaderSources["MailMoney.lua"]="90d5a5414c27905d101ceae2a9d9bba4fe8d554d2a1643cc52b33f008b457e4a"
end

-- AuctionProceeds.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='AuctionProceeds';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local P,Q={},E.Query;E.AuctionProceeds=P
local maximum=9007199254740991
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=maximum end
function P.Invoice(d,amount)
    local v=d and d.invoice
    if not d or not d.complete or d.cod~=0 or not v or v.type~='seller'or not integer(amount,1)or d.money~=amount
        or not integer(v.bid)or not integer(v.deposit)or not integer(v.cut)then return end
    local grossWithDeposit=v.bid+v.deposit
    if not integer(grossWithDeposit)or v.cut>grossWithDeposit or grossWithDeposit-v.cut~=amount then return end
    return {gross=v.bid,cut=v.cut,deposit=v.deposit,received=amount,afterCut=v.bid-v.cut,
        itemName=v.itemName,buyer=v.player,quantity=integer(v.count,1)and v.count or nil}
end
local function empty()return {rows={},gross=0,cut=0,deposit=0,received=0,unresolved=0}end
local function add(out,row)
    for _,key in ipairs({'gross','cut','deposit','received'})do _auctionTick();
        local sum=out[key]+row[key];if not integer(sum)then out.overflow=true end;out[key]=sum
    end
end
local function finish(out)
    if out.overflow then out.gross=nil;out.cut=nil;out.deposit=nil;out.received=nil
    else out.afterCut=out.gross-out.cut;out.feeRate=out.gross>0 and out.cut/out.gross*100 or nil end
    return out
end
local function candidate(c,r)
    if r.character~=c.id or r.sendRequest then return end
    local plan=E.MailMoney.Plan(c,r);if not plan or plan.outgoing then return end
    local out=empty();out.record=r.id;out.wallets={};out.envelopes={}
    for _,component in ipairs(plan.components)do _auctionTick();
        local envelope=c.records[component.record];local d=envelope and envelope.mailData
        if envelope and envelope.character==c.id and d and d.invoice and d.invoice.type=='seller'then
            out.envelopes[#out.envelopes+1]=envelope.id
            local row=P.Invoice(d,component.amount)
            if row and component.source=='auctionSale'then
                row.envelope=envelope.id;row.collection=r.id;out.rows[#out.rows+1]=row;add(out,row)
            else out.unresolved=out.unresolved+1 end
        end
    end
    if #out.envelopes==0 then return end
    for _,w in ipairs(plan.wallets)do _auctionTick();
        out.wallets[#out.wallets+1]=w.id
        out.from=out.from and math.min(out.from,w.ts)or w.ts;out.through=out.through and math.max(out.through,w.ts)or w.ts
        local refs=w.evidenceRefs or{};local proof=#refs==1 and c.records[refs[1]]
        if w.character~=c.id or w.source~=plan.source or(w.quality~='inferred'and w.quality~='confirmed')
            or not proof or proof.kind~='money_evidence'or proof.character~=c.id or proof.walletID~=w.id
            or proof.mailCollection~=r.id or not E.MailMoney.ValidProof(c,proof)then
            out.reason='The wallet evidence is missing, disputed or assigned to another collection.'
        end
    end
    if not out.from then return end
    if r.rejectAuctionProceeds then out.reason='This proceeds interpretation was rejected. Original cash and invoice observations are preserved.'end
    return finish(out)
end
local caches=setmetatable({},{__mode='k'})
local function invalidate(c)caches[c]=nil end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',invalidate)
local function index(c)
    local cached=caches[c];if cached and cached.revision==c.revision then return cached end
    local out={revision=c.revision,rows={},byID={}};local claims={}
    for _,r in ipairs(Q.Kind(c,'mail_collection'))do _auctionTick();
        local row=candidate(c,r)
        if row then
            out.rows[#out.rows+1]=row;out.byID[r.id]=row
            -- An original source can explain only one collection.
            for _,ids in ipairs({row.wallets,row.envelopes})do _auctionTick(); for _,id in ipairs(ids)do _auctionTick();
                local prior=claims[id]
                if prior then prior.reason='Collection evidence is shared by multiple claims.';row.reason=prior.reason end
                claims[id]=row
            end end
        end
    end
    caches[c]=out;return out
end
function P.Collection(c,r)
    if not r or c.records[r.id]~=r or r.kind~='mail_collection'then return end
    local row=index(c).byID[r.id]
    if row and not row.reason then return row end
    return nil,row and row.reason
end
-- Identity evidence can remain a possible seller claim after its cash proof
-- becomes incomplete. It can exclude uniqueness, never establish a link.
function P.PotentialSeller(d)
    local v=d and d.invoice
    -- Loaded MailFrame recognizes buyer, seller and seller_temp_invoice.
    -- Unknown/unreadable values do not positively identify a non-seller.
    if v and(v.type=='buyer'or v.type=='seller_temp_invoice')then return false end
    return d and(d.invoiceUnavailable==true or v~=nil)and true or false
end
function P.LinkCandidates(c)
    local out={};local validated=index(c).byID
    for _,r in ipairs(Q.Kind(c,'mail_collection'))do _auctionTick(); if r.character==c.id and not r.sendRequest then
        local batch=validated[r.id];local supported={}
        for _,row in ipairs(batch and batch.rows or{})do _auctionTick(); supported[row.envelope]=row end
        local seen={}
        local function reserve(id)
            local envelope=c.records[id];local d=envelope and envelope.mailData
            if seen[id]or not envelope or envelope.kind~='mail'or envelope.character~=c.id or not P.PotentialSeller(d)then return end
            -- A known empty envelope cannot be a money collection source.
            if integer(d.money)and d.money==0 then return end
            seen[id]=true;local v=d.invoice or{}
            local row=supported[id]or{envelope=id,collection=r.id,itemName=v.itemName,buyer=v.player,
                quantity=integer(v.count,1)and v.count or nil,gross=integer(v.bid)and v.bid or nil}
            out[#out+1]={invoice=row,supported=supported[id]~=nil and not batch.reason}
        end
        local plan=E.MailMoney.Plan(c,r)
        if plan and not plan.outgoing then
            for _,component in ipairs(plan.components)do _auctionTick(); reserve(component.record)end
        elseif not plan then
            -- A partial/invalid collection cannot prove which positive-money
            -- seller envelopes were collected. Preserve its plausible sources.
            local scan=c.records[r.beforeScan]
            if scan and scan.kind=='mail_scan'and scan.character==c.id then
                for _,id in ipairs(scan.entries or{})do _auctionTick(); reserve(id)end
            end
        end
    end end
    return out
end
-- Wallet timestamps define the interval. Never apportion an indivisible batch
-- across a reporting boundary without evidence identifying each sale's cash.
function P.Report(c,from,through,query)
    local out=empty();out.boundary=0;out.excluded=0;out.collections=0;query=(query or''):lower()
    for _,batch in ipairs(index(c).rows)do _auctionTick();
        if batch.through>=from and batch.from<through then
            if batch.from<from or batch.through>=through then out.boundary=out.boundary+1
            elseif batch.reason then out.excluded=out.excluded+1
            else
                out.unresolved=out.unresolved+batch.unresolved;local included=false
                for _,row in ipairs(batch.rows)do _auctionTick();
                    local words=((row.itemName or'')..' '..(row.buyer or'')):lower()
                    if words:find(query,1,true)then
                        local copy=_auctionCopy(row);copy.observedAt=batch.through;out.rows[#out.rows+1]=copy;add(out,row);included=true
                    end
                end
                if included then out.collections=out.collections+1 end
            end
        end
    end
    _auctionSort(out.rows,function(a,b)if a.observedAt~=b.observedAt then return a.observedAt>b.observedAt end;return a.envelope<b.envelope end)
    return finish(out)
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="AuctionProceeds",create=create}
E.AuctionReaderSources["AuctionProceeds.lua"]="8c9ae5b9370bf22e392a8c19f6b492c7ea79f724c7c49bc7db500fa331d91733"
end

-- AuctionLinks.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='AuctionLinks';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local L,Q,S={},E.Query,E.Store;E.AuctionLinks=L
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function name(v)if type(v)=='string'and v~=''then return v:lower()end end
local function itemName(r)
 local d=r.auctionData or{};local link=d.itemLink
 if type(link)=='string'and tonumber(link:match('item:(%d+)'))==r.itemID then return name(link:match('%[(.-)%]'))end
end
local function sequenced(c,row)
 return row and c.records[row.id]==row and row.character==c.id and integer(row.sequence,1)and integer(c.seq)and row.sequence<=c.seq
  and row.id==c.id..':'..tostring(row.sequence)and integer(row.ts)
end
local function before(c,a,b)
 return sequenced(c,a)and sequenced(c,b)and a.sequence<b.sequence and a.ts<=b.ts
end
-- Verify only the terminal remainder. Older quantity reductions cannot identify
-- earlier buyers or their individual invoices.
local function terminal(c,g)
 if not g.varied or not g.sold or not g.firstActive then return end
 local ordered,notices={},{}
 for _,v in ipairs(g.rows)do _auctionTick();
  if not sequenced(c,v)or v.session~=g.firstActive.session then return end
  if v.source=='sale_notice'then notices[#notices+1]=v
  elseif v.source=='owned'or v.source=='created'then ordered[#ordered+1]=v
  else return end
 end
 _auctionSort(ordered,function(a,b)return a.sequence<b.sequence end)
 local made,first,last,sold=ordered[1],ordered[2],ordered[#ordered-1],ordered[#ordered]
 if #ordered<4 or not made or made.source~='created' or made.previousObservation or type(made.auctionData)~='table'or made.auctionData.event~='AUCTION_HOUSE_AUCTION_CREATED'
  or made.auctionData.auctionID~=g.id or first~=g.firstActive or last~=g.active or sold~=g.sold then return end
 local started=first.auctionData.quantity;local following={}
 for i=2,#ordered do _auctionTick();
  local row,prior=ordered[i],ordered[i-1];local data=row.auctionData
  if not before(c,prior,row)or row.previousObservation~=prior.id or not integer(prior.lastObservedAt or prior.ts)
   or (prior.lastObservedAt or prior.ts)>row.ts or (prior.lastObservedAt or prior.ts)<prior.ts or row.source~='owned' or data.auctionID~=g.id
   or data.coverage~='observed' or data.cacheFull~=true or not integer(row.itemID,1) or data.itemID~=row.itemID or row.itemID~=g.itemID
   or type(data.itemKey)~='table'or data.itemKey.itemID~=g.itemID or not itemName(row)or itemName(row)~=g.name or not integer(data.quantity,1)
   or data.statusLabel~=(i==#ordered and 'Reported sold' or 'Active') then return end
  if i>2 and data.quantity>prior.auctionData.quantity then return end
  if i>2 and row~=sold then following[prior.id]=row end
 end
 if not g.buyer or not integer(g.price,1)or started-g.quantity>=g.quantity or started<=sold.auctionData.quantity or last.auctionData.quantity~=sold.auctionData.quantity then return end
 local final;local counted={}
 for _,notice in ipairs(notices)do _auctionTick();
  local d=notice.auctionData or{}
  if d.event~='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION'or d.notification~='AuctionSold'or d.auctionID~=g.id
   or not before(c,made,notice)or not before(c,notice,sold) then return end
  if notice.previousObservation==last.id then
   if final or not before(c,last,notice)or (last.lastObservedAt or last.ts)>notice.ts then return end
   final=notice
  else
   local prior=c.records[notice.previousObservation];local newer=prior and following[prior.id]
   if not newer or not before(c,prior,notice)or not before(c,notice,newer)or (prior.lastObservedAt or prior.ts)>notice.ts then return end
   local count=(counted[prior.id]or 0)+1;counted[prior.id]=count
   if count>prior.auctionData.quantity-newer.auctionData.quantity then return end
  end
 end
 if not final then return end
 local requests={}
 for _,request in ipairs(Q.Range(c,made.ts-5,made.ts+1,'auction'))do _auctionTick();
  if request.source=='post'and request.session==made.session then requests[#requests+1]=request end
 end
 if #requests~=1 then return end
 local request=requests[1];local d=request.auctionData or{};local plan=E.AuctionCosts.Plan(c,request)
 if not before(c,request,made)or d.requestMethod~='PostCommodity'or not integer(d.unitPrice,1)
  or d.quantity~=started or not plan or plan.listing~=first or plan.created~=made or plan.itemID~=g.itemID
  or d.unitPrice>math.floor(9007199254740991/g.quantity)or d.unitPrice*g.quantity~=g.price then return end
 return {posting=request.id,postedQuantity=started,offset=started-g.quantity,notice=final.id,created=made.id,first=first.id}
end
local function groups(c)
 local out,anonymous,notices={},{},{}
 for _,r in ipairs(Q.Kind(c,'auction'))do _auctionTick(); if r.character==c.id then
  if r.source=='sale_notice'then notices[#notices+1]=r end
  if not integer(r.auctionID,1)then anonymous[#anonymous+1]=r else
  local g=out[r.auctionID];if not g then g={id=r.auctionID,rows={}};out[r.auctionID]=g end
  g.rows[#g.rows+1]=r
 end end end
 for _,g in pairs(out)do _auctionTick();
  for _,r in ipairs(g.rows)do _auctionTick(); local d=r.auctionData or{}
   -- Closure notices conflict with a full-sale claim; they do not prove a return.
   if r.source=='cancelled'or r.source=='expired'then g.conflict=true end
   if r.source=='owned'then
    local n=itemName(r)
    if not n or d.coverage~='observed'or not integer(r.itemID,1)or not integer(d.quantity,1)
      or d.itemID~=r.itemID or d.auctionID~=r.auctionID then g.conflict=true end
    if g.quantity and g.quantity~=d.quantity then g.varied=true end
    if g.itemID and(g.itemID~=r.itemID or g.quantity~=d.quantity or g.name~=n)then g.conflict=true end
    g.itemID,g.quantity,g.name=r.itemID,d.quantity,n
    if d.statusLabel=='Active'then
     if not g.active or S.Before(g.active,r)then g.active=r end
     if not g.firstActive or S.Before(r,g.firstActive)then g.firstActive=r end
    elseif d.statusLabel=='Reported sold'then
     local buyer=name(d.bidder)
     if not buyer or not integer(d.bidAmount,1)then g.conflict=true end
     if g.sold and(g.buyer~=buyer or g.price~=d.bidAmount)then g.conflict=true end
     g.buyer,g.price=buyer,d.bidAmount
     if not g.sold or S.Before(r,g.sold)then g.sold=r end
    else g.conflict=true end
   end
  end
  if not g.active or not g.sold or not S.Before(g.active,g.sold)or
    (g.active.lastObservedAt or g.active.ts)>g.sold.ts then g.conflict=true end
  g.partial=terminal(c,g)
  if g.partial then g.conflict=false end
 end
 return out,anonymous,notices
end
local caches=setmetatable({},{__mode='k'})
local function invalidate(c)caches[c]=nil end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',invalidate)
-- Index known identity fields separately; missing fields stay in wildcard
-- buckets. Candidate rejection/support never removes a possible identity.
local unknown={}
local function candidateFrom(g)
 -- Contradictory or incomplete lifecycle evidence cannot establish a start
 -- bound. Reserve it; only a consistent full-sale history can exclude time.
 return g and not g.conflict and g.firstActive and g.firstActive.ts or -math.huge
end
local function directory()return {all={},fields={{},{},{},{}}}end
local function include(index,row)
 index.all[#index.all+1]=row
 for field=1,4 do _auctionTick(); local key=row.values[field]or unknown;local bucket=index.fields[field][key]
  if not bucket then bucket={};index.fields[field][key]=bucket end;bucket[#bucket+1]=row
 end
end
local function ready(index)
 local function before(a,b)return a.ts<b.ts end
 _auctionSort(index.all,before)
 for field=1,4 do _auctionTick(); for _,bucket in pairs(index.fields[field])do _auctionTick(); _auctionSort(bucket,before)end end
end
local function bounds(rows,first,through)
 if not rows then return 1,0 end
 local lo,hi=1,#rows+1
 while lo<hi do _auctionTick(); local mid=math.floor((lo+hi)/2);if rows[mid].ts<first then lo=mid+1 else hi=mid end end
 local start=lo;hi=#rows+1
 while lo<hi do _auctionTick(); local mid=math.floor((lo+hi)/2);if rows[mid].ts<=through then lo=mid+1 else hi=mid end end
 return start,lo-1
end
local function visit(index,values,first,through,fn)
 local a,b=index.all,nil;local af,al=bounds(a,first,through);local bf,bl=1,0;local size=al-af+1
 for field=1,4 do _auctionTick(); if values[field]~=nil then
  local exact,wild=index.fields[field][values[field]],index.fields[field][unknown]
  local ef,el=bounds(exact,first,through);local wf,wl=bounds(wild,first,through);local count=el-ef+1+wl-wf+1
  if count<size then a,b,af,al,bf,bl,size=exact,wild,ef,el,wf,wl,count end
 end end
 local function run(rows,start,last)
  for i=start,last do _auctionTick(); local row=rows[i];local compatible=true
   for field=1,4 do _auctionTick(); local x,y=values[field],row.values[field];if x~=nil and y~=nil and x~=y then compatible=false;break end end
   if compatible and fn(row)==false then return false end
  end
 end
 if run(a,af,al)==false then return end;run(b,bf,bl)
end
-- The terminal buyer comes from the Sold row. Earlier fill buyers are
-- unknown. A same-size earlier fill must remain possible if the unresolved
-- prefix is large enough (checked in terminal). Active-only rivals and
-- unsupported seller mail also reserve the identity.
local function unknownScan(c,scan,work)
 if scan.complete~=true or not integer(scan.loaded)or scan.loaded>100 or scan.total~=scan.loaded or type(scan.entries)~='table' then return true end
 local count=0
 for slot,id in pairs(scan.entries)do _auctionTick();
  if work then work()end
  local row=c.records[id]
  if not integer(slot,1)or slot>scan.loaded or not row or row.kind~='mail'or row.character~=c.id
   or row.scan~=scan.id or row.session~=scan.session or row.visit~=scan.visit or row.index~=slot then return true end
  count=count+1
 end
 return count~=scan.loaded
end
local function unknownEnvelope(d)
 return type(d)~='table' or d.complete~=true and not d.invoice
end
-- A later observation alone does not date the posting. A later posting
-- needs its own unique request, creation, first listing and outflow.
local function origin(c,g)
 local first=g.firstActive;local made=first and c.records[first.previousObservation]
 if not made or made.source~='created'or made.auctionID~=g.id or made.previousObservation
  or not before(c,made,first)or not integer(first.itemID,1)then return false end
 local event=made.auctionData
 if type(event)~='table'or event.auctionID~=g.id or event.event~='AUCTION_HOUSE_AUCTION_CREATED'then return false end
 for _,row in ipairs(g.rows)do _auctionTick();
  local data=row.auctionData
  if row.session~=made.session or type(data)~='table'or data.auctionID~=g.id
   or row~=made and (row.source=='created'or not before(c,made,row))then return false end
  if row.source=='owned'and (row.itemID~=first.itemID or data.itemID~=row.itemID or type(data.itemKey)~='table'
   or data.itemKey.itemID~=row.itemID or not itemName(row)or data.coverage~='observed')then return false end
 end
 for _,r in ipairs(Q.Range(c,made.ts-5,made.ts+1,'auction'))do _auctionTick();
  if r.source=='post'and r.session==made.session and before(c,r,made)then
   local plan=E.AuctionCosts.Plan(c,r)
   if plan and plan.created==made and plan.listing==first then return r,plan end
  end
 end
 return false
end
-- Both tables live only for one call to index(). Neither failed nor positive
-- proofs can cross snapshot, character or revision boundaries.
local function cachedOrigin(c,g,proofs)
 local result=proofs.origins[g]
 if result==nil then
  local request,plan=origin(c,g)
  result=request and {request=request,plan=plan}or false;proofs.origins[g]=result
 end
 return result
end
-- The two records are checked at the boundary where a snapshot proof
-- enters the index. Their relative order still depends on the current invoice.
local function ordered(row,envelope)
 return row.sequence<envelope.sequence and row.ts<=envelope.ts
end
local function createdAfter(c,g,envelope,proofs)
 local first=g.firstActive
 if not first or type(first.ts)~='number'or type(first.sequence)~='number'or not ordered(envelope,first)then return false end
 local result=cachedOrigin(c,g,proofs)
 return result and ordered(envelope,result.request)
end
local function invoiceRival(invoice,buyer,quantity,gross)
 -- Seller mail supplies a localized name but no item ID or source locale.
 return (not name(invoice.player)or name(invoice.player)==buyer)
  and(not integer(invoice.count,1)or invoice.count==quantity)
  and(not integer(invoice.bid,1)or invoice.bid==gross)
end
local function partialSafe(c,g,groups,anonymous,envelope,mailRows,scans,proofs)
 local t=g.partial
 if not before(c,g.sold,envelope)then return false end
 local request=c.records[t.posting]
 for _,other in pairs(groups)do _auctionTick(); if other~=g then
  local possible=false
  for _,row in ipairs(other.rows)do _auctionTick();
   if row.source=='owned'then
    local n=itemName(row)
    if not n or row.itemID==g.itemID or n==g.name then possible=true;break end
   elseif not other.name and (row.source=='created'or row.source=='sale_notice'or row.source=='expired'or row.source=='cancelled') then possible=true;break end
  end
  if possible and not createdAfter(c,other,envelope,proofs)then return false end
 end end
 for _,row in ipairs(anonymous)do _auctionTick();
  if row~=request then
   if row.source=='post'and not before(c,envelope,row)then
    local d=row.auctionData or{}
    if (not itemName(row)or row.itemID==g.itemID or itemName(row)==g.name)
      and (not integer(d.quantity,1)or d.quantity>=g.quantity)
      and (d.requestMethod~='PostCommodity'or not integer(d.unitPrice,1)or d.unitPrice==request.auctionData.unitPrice)then return false end
   elseif row.source=='sale_notice'or row.source=='created'or row.source=='owned'and(not itemName(row)or row.itemID==g.itemID or itemName(row)==g.name)then return false end
  end
 end
 for _,row in ipairs(mailRows)do _auctionTick(); if row~=envelope and not before(c,row,request)then
  local d=row.mailData
  if unknownEnvelope(d)then return false end
  if E.AuctionProceeds.PotentialSeller(d)then
   local invoice=d.invoice or{}
   if invoiceRival(invoice,g.buyer,g.quantity,g.price)then return false end
  end
 end end
 for _,scan in ipairs(scans)do _auctionTick(); if not before(c,scan,request)and unknownScan(c,scan)then return false end end
 return true
end
-- A formatted sold notification has no buyer, quantity or price. Its
-- preceding owned observation can identify an item, never a particular invoice.
local function noticeIdentity(c,r)
 local d=r.auctionData
 if not integer(r.auctionID,1)or type(d)~='table'or d.auctionID~=r.auctionID
  or d.notification~='AuctionSold'or d.event~='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION'then return end
 local prior=c.records[r.previousObservation]
 if not prior then return r.auctionID end
 if prior.kind~='auction'or prior.auctionID~=r.auctionID or prior.session~=r.session or not before(c,prior,r)then return end
 if prior.source~='owned'then return r.auctionID end
 local v=prior.auctionData
 if type(v)~='table'or v.coverage~='observed'or v.auctionID~=r.auctionID or not integer(prior.itemID,1)
  or v.itemID~=prior.itemID or type(v.itemKey)~='table'or v.itemKey.itemID~=prior.itemID or not itemName(prior)then return r.auctionID end
 return r.auctionID,prior.itemID,itemName(prior)
end
local function noticeClaims(c,rows)
 local ix={items={},names={},unknown={}}
 local function add(row)
  local auctionID,itemID,n=noticeIdentity(c,row)
  local key=auctionID or row.id
  if not itemID then ix.unknown[key]=true;return end
  ix.items[itemID]=ix.items[itemID]or{};ix.items[itemID][key]=true
  ix.names[n]=ix.names[n]or{};ix.names[n][key]=true
 end
 for _,row in ipairs(rows)do _auctionTick(); add(row)end
 return ix
end
-- An earlier notice cannot explain a second invoice when that posting's
-- entire original quantity was observed sold in one independently settled lot.
local function fullSaleProof(c,other,invoices,observations,proofs)
 if other.conflict or other.varied or #other.rows~=4 or not other.sold or other.firstActive~=other.active then return false end
 local result=cachedOrigin(c,other,proofs)
 if not result then return false end
 local request,plan=result.request,result.plan
 if plan.quantity~=other.quantity or request.auctionData.requestMethod~='PostCommodity'then return false end
 local unit=request.auctionData.unitPrice
 if not integer(unit,1)or unit>math.floor(9007199254740991/other.quantity)or unit*other.quantity~=other.price then return false end
 local active,sold=other.active,other.sold
 if active.auctionData.cacheFull~=true or sold.auctionData.cacheFull~=true or sold.previousObservation~=active.id then return false end
 local notice
 for _,r in ipairs(other.rows)do _auctionTick(); if r.source=='sale_notice'then notice=r end end
 if not notice or notice.previousObservation~=active.id or noticeIdentity(c,notice)~=other.id
  or not before(c,active,notice)or not before(c,notice,sold)or (active.lastObservedAt or active.ts)>notice.ts then return false end
 local values={other.name,other.buyer,other.quantity,other.price}
 local count,receipt=0,nil
 visit(invoices,values,-math.huge,math.huge,function(row)
  count=count+1;receipt=row.candidate;return count<2
 end)
 if count~=1 or not receipt.supported then return false end
 local inv=receipt.invoice;local prior=c.records[inv.envelope];local batch=c.records[inv.collection]
 if name(inv.itemName)~=other.name or name(inv.buyer)~=other.buyer or inv.quantity~=other.quantity or inv.gross~=other.price
  or not before(c,sold,prior)or prior.rejectAuctionLink or not sequenced(c,batch)or not integer(batch.settledAt)then return false end
 local rival=false;visit(observations,values,-math.huge,prior.ts,function(row)
  if row.id~=other.id then rival=true;return false end
 end)
 if not rival then return {invoice=prior,batch=batch}end
 return false
end
local function earlierFullSale(c,other,target,envelope,invoices,observations,proofs)
 if not other.sold or other.buyer==target.buyer and other.price==target.price and other.quantity==target.quantity then return false end
 local result=proofs.sales[other]
 if result==nil then
  result=fullSaleProof(c,other,invoices,observations,proofs);proofs.sales[other]=result
 end
 return result and ordered(result.invoice,envelope)and ordered(result.batch,envelope)and result.batch.settledAt<=envelope.ts
end
local function noticeRival(c,g,envelope,groups,ix,invoices,observations,proofs)
 local validEnvelope=sequenced(c,envelope)
 local visited={}
 local function possible(bucket)
  for key in pairs(bucket or{})do _auctionTick();
   if key~=g.id and not visited[key]then
    visited[key]=true;local other=groups[key]
    if not other or not validEnvelope or not createdAfter(c,other,envelope,proofs)and not earlierFullSale(c,other,g,envelope,invoices,observations,proofs)then return true end
   end
  end
 end
 return possible(ix.unknown)or possible(ix.items[g.itemID])or possible(ix.names[g.name])
end
local function index(c)
 local cached=caches[c];if cached and cached.revision==c.revision then return cached end
 local out={revision=c.revision,byEnvelope={},byAuction={}};local listings,anonymous,noticeRows=groups(c)
 local proofs={origins={},sales={}}
 local observations,invoices=directory(),directory();local identities={};local mailRows,scans,notices
 local function observe(r,id,g)
  local d=r.auctionData or{}
  if r.source~='owned'or d.statusLabel=='Active'then return end
  local values={itemName(r),name(d.bidder),integer(d.quantity,1)and d.quantity or nil,integer(d.bidAmount,1)and d.bidAmount or nil}
  -- A refresh can reveal the sold identity after its invoice was collected.
  -- Earlier active evidence makes that identity a possible historical claim;
  -- incomplete/conflicting groups still reserve it but cannot establish a link.
  -- Without an earlier active anchor, observation time cannot establish when
  -- this auction began. It can reserve a historical claim, never prove a link.
  local possibleFrom=candidateFrom(g)
  -- Repeated observations of one identity contribute its earliest time, not
  -- duplicate work or extra claims. Conflicting identities remain separate.
  local branch=identities[id];if not branch then branch={};identities[id]=branch end
  for field=1,4 do _auctionTick(); local key=values[field]or unknown;branch[key]=branch[key]or{};branch=branch[key]end
  if branch.row then branch.row.ts=math.min(branch.row.ts,possibleFrom)
  else local row={id=id,group=g,values=values,ts=possibleFrom};branch.row=row;include(observations,row)end
 end
 for _,g in pairs(listings)do _auctionTick(); for _,r in ipairs(g.rows)do _auctionTick(); observe(r,g.id,g)end end
 for _,r in ipairs(anonymous)do _auctionTick(); observe(r,'record:'..r.id)end
 local candidates=E.AuctionProceeds.LinkCandidates(c)
 for _,candidate in ipairs(candidates)do _auctionTick(); local row=candidate.invoice;local envelope=c.records[row.envelope]
  if envelope then include(invoices,{candidate=candidate,values={name(row.itemName),name(row.buyer),row.quantity,row.gross},ts=envelope.ts})end
 end
 ready(observations);ready(invoices)
 for _,candidate in ipairs(candidates)do _auctionTick(); local row=candidate.invoice;local envelope=c.records[row.envelope]
  local n,buyer=name(row.itemName),name(row.buyer)
  local entry={invoice=row,reason='No unique recorded listing matches this collected invoice.'};out.byEnvelope[row.envelope]=entry
  if envelope then
   local seen,possibilities,only={},0,nil
   visit(observations,{n,buyer,row.quantity,row.gross},-math.huge,envelope.ts,function(observation)
    if not seen[observation.id]then seen[observation.id]=true;possibilities=possibilities+1;only=observation.group end
    return possibilities<2
   end)
   if possibilities==1 and only and candidate.supported and n and buyer and integer(row.quantity,1)and not only.conflict
     and only.name==n and only.buyer==buyer and only.quantity==row.quantity and only.price==row.gross
     and only.active.ts<=envelope.ts
     and (only.sold.ts<=envelope.ts or(only.active.lastObservedAt or only.active.ts)<envelope.ts)then
    if only.partial then
     mailRows=mailRows or Q.Kind(c,'mail');scans=scans or Q.Kind(c,'mail_scan')
     if partialSafe(c,only,listings,anonymous,envelope,mailRows,scans,proofs)then entry.group=only
     else entry.reason='Incomplete or competing evidence prevents a unique terminal partial sale.'end
    elseif #noticeRows==0 then entry.group=only
    else
     notices=notices or noticeClaims(c,noticeRows)
     if noticeRival(c,only,envelope,listings,notices,invoices,observations,proofs)then entry.reason='Another recorded sale notification could belong to this invoice.'
     else entry.group=only end
    end
   elseif possibilities>1 then entry.reason='Competing or incomplete listing observations prevent a unique match.'end
  end
 end
 local claims={}
 for id,entry in pairs(out.byEnvelope)do _auctionTick(); local g=entry.group
  if g then
   if claims[g.id]==nil then
    local count=0
    -- Invert the competing-invoice query. Only groups that could establish a
    -- unique link need a count, and a second claim already proves ambiguity.
    visit(invoices,{g.name,g.buyer,g.quantity,g.price},candidateFrom(g),math.huge,function()count=count+1;return count<2 end)
    claims[g.id]=count
   end
   if claims[g.id]~=1 then entry.reason='Multiple collected invoices could claim this listing.'
   elseif c.records[id].rejectAuctionLink then entry.reason='This inferred listing link was rejected. Original observations are preserved.'
   else
    entry.reason=nil;entry.link={auctionID=g.id,itemID=g.itemID,listing=g.sold.id,active=g.active.id,
     envelope=id,collection=entry.invoice.collection,quantity=g.quantity,quality='inferred',
     from=g.active.ts,through=math.min(g.sold.ts,c.records[id].ts),soldObservedAt=g.sold.ts,
     invoiceBeforeSold=c.records[id].ts<g.sold.ts,invoice=entry.invoice,partial=g.partial and _auctionCopy(g.partial)}
    out.byAuction[g.id]=entry.link
   end
  end
 end
 caches[c]=out;return out
end

function L.Invoice(c,r)
 if not r or c.records[r.id]~=r or r.character~=c.id or r.kind~='mail'then return end
 local entry=index(c).byEnvelope[r.id]
 if entry then return entry.link,entry.reason end
 return nil,'No supported collected seller invoice is available.'
end
function L.Listing(c,r)
 if not r or c.records[r.id]~=r or r.kind~='auction'or r.character~=c.id then return end
 return index(c).byAuction[r.auctionID]
end
function L.Reject(c,r,rejected)
 if not r or c.records[r.id]~=r or r.kind~='mail'or r.character~=c.id or not r.mailData or not r.mailData.invoice or r.mailData.invoice.type~='seller'then return false end
 r.rejectAuctionLink=rejected and true or nil;S.Changed(c,r);return true
end
-- Retain candidate evidence as well as the selected link: cleanup must not
-- manufacture uniqueness by deleting the competing invoice or listing.
-- This is deliberately conservative by invoice item name, not financial proof.
function L.Retention(c,r,add,state)
 if r.kind~='auction'and r.kind~='mail'and r.kind~='mail_collection'and r.kind~='mail_scan'then return end
 local work=state.work;local function tick()if work then work()end end
 local unknown='\001unknown-auction-item'
 if not state.auctionLinkGroups then
  local byName,byRecord,byAuction={},{},{}
  local quantities,varied,items,noticeItems={},{},{},{}
  local function join(n,id)
   if not n then return end
   byName[n]=byName[n]or{};byName[n][id]=true
   byRecord[id]=byRecord[id]or{};byRecord[id][n]=true
  end
  for id,v in pairs(c.records)do _auctionTick(); tick()
   if v.kind=='auction'and v.source=='owned'then local n=itemName(v)or unknown;join(n,id)
    if v.auctionID then
     if n then byAuction[v.auctionID]=byAuction[v.auctionID]or{};byAuction[v.auctionID][n]=true end
     local quantity=v.auctionData and v.auctionData.quantity
     if quantity and quantities[v.auctionID]and quantity~=quantities[v.auctionID]then varied[v.auctionID]=true end
     quantities[v.auctionID]=quantity or quantities[v.auctionID]
     if integer(v.itemID,1)then items[v.auctionID]=items[v.auctionID]or{};items[v.auctionID][v.itemID]=true end
    end
   elseif v.kind=='auction'and v.source=='sale_notice'then
    local _,itemID,n=noticeIdentity(c,v)
    if itemID then noticeItems[itemID]=true;join(n,id);join('\002auction-item-'..itemID,id)
    else join(unknown,id)end
   elseif v.kind=='mail'and E.AuctionProceeds.PotentialSeller(v.mailData)then join(name((v.mailData.invoice or{}).itemName)or unknown,id)end
  end
  local partialNames,byItem,identities={},{},{}
  for auctionID in pairs(varied)do _auctionTick(); for n in pairs(byAuction[auctionID]or{})do _auctionTick();
   tick();partialNames[n]=true
   for itemID in pairs(items[auctionID]or{})do _auctionTick(); tick();byItem[itemID]=byItem[itemID] or{};byItem[itemID][n]=true end
  end end
  for id,v in pairs(c.records)do _auctionTick(); tick()
   if v.kind=='auction'and (v.source=='post'or v.source=='created'or v.source=='sale_notice'or v.source=='expired'or v.source=='cancelled')then
    -- Keep anonymous or unpaired rivals without connecting unrelated full-sale books.
    if not v.auctionID or not byAuction[v.auctionID]then
     local n=v.source=='post'and itemName(v)
     if n then
      if partialNames[n]then join(n,id)end
      for possible in pairs(byItem[v.itemID]or{})do _auctionTick(); tick();join(possible,id)end
     else for possible in pairs(partialNames)do _auctionTick(); tick();join(possible,id)end end
    end
   end
   if v.kind=='auction'and v.source=='owned'then
    if noticeItems[v.itemID]then join('\002auction-item-'..v.itemID,id)end
    for n in pairs(byItem[v.itemID]or{})do _auctionTick(); tick();join(n,id)end
    if varied[v.auctionID]and v.auctionData and v.auctionData.statusLabel=='Reported sold'then
     local d=v.auctionData;identities[#identities+1]={name=itemName(v)or unknown,buyer=name(d.bidder),quantity=d.quantity,gross=d.bidAmount}
    end
   end
   if next(partialNames) and (v.kind=='mail'and unknownEnvelope(v.mailData)or v.kind=='mail_scan'and unknownScan(c,v,work))then
    for possible in pairs(partialNames)do _auctionTick(); tick();join(possible,id)end
   end
   if v.kind=='auction'and v.auctionID then for n in pairs(byAuction[v.auctionID]or{})do _auctionTick(); tick();join(n,id)end
   elseif v.kind=='mail_collection'then local scan=c.records[v.beforeScan]
    for _,key in ipairs(scan and scan.entries or{})do _auctionTick(); tick();for n in pairs(byRecord[key]or{})do _auctionTick(); tick();join(n,id)end end
   end
  end
  if #identities>0 then
   for id,v in pairs(c.records)do _auctionTick(); tick()
    if v.kind=='mail'and E.AuctionProceeds.PotentialSeller(v.mailData)then
     for _,claim in ipairs(identities)do _auctionTick(); tick()
      if invoiceRival(v.mailData.invoice or{},claim.buyer,claim.quantity,claim.gross)then join(claim.name,id)end
     end
    end
   end
  end
  state.auctionLinkGroups={names=byName,records=byRecord,seen={}}
 end
 local g=state.auctionLinkGroups
 local function expand(n)
  tick();if g.names[n]and not g.seen[n]then
   g.seen[n]=true;for id in pairs(g.names[n])do _auctionTick(); tick();if id~=r.id then add(id,{kind='linked',source=r.id})end end
  end
 end
 local membership=g.records[r.id]
 if membership then
  for n in pairs(membership)do _auctionTick(); expand(n)end
  expand(unknown)
  if membership[unknown]then for n in pairs(g.names)do _auctionTick(); expand(n)end end
 end
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="AuctionLinks",create=create}
E.AuctionReaderSources["AuctionLinks.lua"]="0e4f1e9fdc5935a4b79c2fd3a7cf3a4357b16c0670d862e16c192f8d6c15ca6d"
end

-- AuctionSettlement.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='AuctionSettlement';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local R,S,Q,F={},E.Store,E.Query,E.Economy;E.AuctionSettlement=R
local maximum,maximumQuantity=9007199254740991,67108864
local function integer(v,min,max)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=(max or maximum)end
local function sum(a,b)if not integer(a)or not integer(b)or b>maximum-a then return end;return a+b end
local function difference(a,b)if not integer(a,-maximum)or not integer(b,-maximum)then return end
 if b<0 and a>maximum+b or b>0 and a< -maximum+b then return end;return a-b
end
local function canonical(c,r,kind)return r and c.records[r.id]==r and r.character==c.id and r.kind==kind end
local function refs(c,out,id,role)
 if type(id)=='string'and c.records[id]and not out.seen[id]then
  out.seen[id]=true;out.refs[#out.refs+1]=id;out.references[#out.references+1]={character=c.id,record=id,role=role}
 end
end
-- A slice preserves the original integer-copper allocation through split
-- posting movements. It does not claim that a partial auction sale happened.
function R.Slice(info,offset,quantity)
 if not info or not integer(info.quantity,1,maximumQuantity)or not integer(offset,0,info.quantity)
  or not integer(quantity,1,info.quantity-offset)or type(info.parts)~='table'then return nil,'Invalid allocation interval.'end
 local out={quantity=quantity,knownCost=0,unknownQuantity=0,parts={}};local position=0
 for _,part in ipairs(info.parts)do _auctionTick();
  if not integer(part.quantity,1,maximumQuantity)or position>info.quantity-part.quantity then return nil,'Invalid posting allocation quantity.'end
  local first,last=math.max(offset,position),math.min(offset+quantity,position+part.quantity)
  if last>first then
   local copy=_auctionCopy(part);copy.quantity=last-first
   if part.cost~=nil then
    local total,basis,start=part.baseCost or part.cost,part.baseQuantity or part.quantity,(part.baseOffset or 0)+first-position
    if not integer(total)or not integer(basis,1,maximumQuantity)or not integer(start,0,basis-copy.quantity)then return nil,'Invalid acquisition-cost basis.'end
    copy.cost,copy.baseCost,copy.baseQuantity,copy.baseOffset=F.Part(total,basis,start,copy.quantity),total,basis,start
    out.knownCost=sum(out.knownCost,copy.cost);if out.knownCost==nil then return nil,'Allocation total exceeds exact copper precision.'end
   else copy.cost=nil;copy.baseQuantity=part.baseQuantity or part.quantity;copy.baseOffset=(part.baseOffset or 0)+first-position;out.unknownQuantity=out.unknownQuantity+copy.quantity end
   out.parts[#out.parts+1]=copy
  end
  position=position+part.quantity
 end
 if position~=info.quantity then return nil,'Posting allocation quantities do not reconcile.'end
 if out.unknownQuantity==0 then out.cost=out.knownCost end
 return out
end
local postingIndexes=setmetatable({},{__mode='k'})
local function invalidatePosting(c)postingIndexes[c]=nil end
E.On('RECORD_ADDED',invalidatePosting);E.On('RECORD_CHANGED',invalidatePosting);E.On('RECORDS_REMOVED',invalidatePosting)
local function postingIndex(c)
 local index=postingIndexes[c];if index and index.revision==c.revision then return index end
 index={revision=c.revision,created={},unknown={},pools={}}
 for _,r in ipairs(Q.Kind(c,'auction'))do _auctionTick(); if r.source=='created'then
  if integer(r.auctionID,1)then local list=index.created[r.auctionID]or{};index.created[r.auctionID]=list;list[#list+1]=r
  else index.unknown[#index.unknown+1]=r end
 end end
 postingIndexes[c]=index;return index
end
local function pool(c,index,id)
 local cached=index.pools[id];if cached then return cached end
 local out,seen,near={},{},{}
 local function add(rows,seenRows,nearRows,created)
  -- A valid Plan uses the existing six-second query bound; incomplete
  -- request/creation claims retain their stricter five-second test below.
  for _,r in ipairs(Q.Range(c,created.ts-6,created.ts+1,'auction'))do _auctionTick();
   if r.source=='post'and r.character==c.id and r.session==created.session then
    if not seenRows[r.id]then seenRows[r.id]=true;rows[#rows+1]=r end
    local linked=nearRows[r.id]or{};nearRows[r.id]=linked;linked[#linked+1]=created
   end
  end
 end
 for _,created in ipairs(index.created[id]or{})do _auctionTick(); add(out,seen,near,created)end
 if not index.unknownPool then
  local rows,keys,links={},{},{}
  for _,created in ipairs(index.unknown)do _auctionTick(); add(rows,keys,links,created)end
  index.unknownPool={rows=rows,near=links}
 end
 _auctionSort(out,S.Before);cached={rows=out,near=near};index.pools[id]=cached;return cached
end
local function posting(c,link)
 local candidates={};local matched;local index=postingIndex(c)
 local selected=pool(c,index,link.auctionID)
 local seen={}
 local function consider(r)
  if seen[r.id]then return end;seen[r.id]=true
  local plan=E.AuctionCosts.Plan(c,r);local d=r.auctionData or{};local possible=false
  if plan then possible=plan.created.auctionID==link.auctionID
  elseif r.ts<=link.from then
   local differentItem=integer(r.itemID,1)and d.itemID==r.itemID and r.itemID~=link.itemID
   if not differentItem and(not integer(d.quantity,1)or d.quantity>=link.quantity)then
    local function compatible(rows)
     for _,created in ipairs(rows)do _auctionTick();
      if created.character==c.id and r.session==created.session and created.ts>=r.ts and created.ts<=r.ts+5 then return true end
     end
    end
    possible=compatible(selected.near[r.id]or{})or compatible(index.unknownPool.near[r.id]or{})
   end
  end
  if possible then candidates[#candidates+1]=r;matched=r end
 end
 for _,r in ipairs(selected.rows)do _auctionTick(); consider(r)end
 for _,r in ipairs(index.unknownPool.rows)do _auctionTick(); consider(r)end
 _auctionSort(candidates,S.Before)
 if #candidates~=1 then return nil,#candidates==0 and'No unique posting allocation supports this listing.'or'Multiple possible postings claim this auction.',candidates end
 local plan=E.AuctionCosts.Plan(c,matched)
 if not plan then return nil,'The possible posting has incomplete inventory or creation evidence.',candidates end
 if plan.itemID~=link.itemID or plan.quantity~=(link.partial and link.partial.postedQuantity or link.quantity) or (link.partial and matched.id~=link.partial.posting) or matched.ts>link.from then
  return nil,'Posting and sold quantities or chronology differ; partial-sale allocation remains unresolved.',candidates
 end
 return matched,nil,candidates
end

function R.Invoice(c,envelope)
 if not canonical(c,envelope,'mail')then return nil,'The invoice must belong to this character.'end
 local link,reason=E.AuctionLinks.Invoice(c,envelope);if not link then return nil,reason end
 local batch=E.AuctionProceeds.Collection(c,c.records[link.collection]);if not batch then return nil,'Collected proceeds are no longer supported.'end
 local invoice=link.invoice
 local out={envelope=envelope.id,collection=link.collection,auctionID=link.auctionID,itemID=link.itemID,quantity=link.quantity,
  quality='inferred',itemName=invoice.itemName,buyer=invoice.buyer,gross=invoice.gross,houseCut=invoice.cut,
  depositReturned=invoice.deposit,cashCollected=invoice.received,afterHouseCut=invoice.afterCut,
  observedFrom=batch.from,observedThrough=batch.through,saleTimeFrom=link.from,saleTimeThrough=link.through,
  dateMeaning='Observed collection interval; exact sale completion time unknown',knownCost=0,unknownQuantity=link.quantity,
  feeCoverage='House cut recorded; other nonrefundable fees and posting-deposit settlement unresolved',
  completeProfit=false,rejected=envelope.rejectAuctionSettlement==true,refs={},references={},seen={}}
 for _,id in ipairs({envelope.id,link.collection,link.listing,link.active})do _auctionTick(); refs(c,out,id,'sale link')end
 for _,id in ipairs(batch.wallets)do _auctionTick(); refs(c,out,id,'cash collection')end
 local post,why,candidates=posting(c,link)
 for _,r in ipairs(candidates)do _auctionTick(); refs(c,out,r.id,'possible posting');for _,id in ipairs(r.refs or{})do _auctionTick(); refs(c,out,id,'posting evidence')end end
 if not post then out.costReason=why;out.seen=nil;return out end
 out.posting=post.id
 local info;info,why=E.AuctionCosts.Info(c,post)
 if not info then out.costReason=why;out.seen=nil;return out end
 if not info.plan or not canonical(c,info.plan.created,'auction')or not canonical(c,info.plan.listing,'auction')then
  out.costReason='Original posting creation or listing evidence does not belong to this character.';out.seen=nil;return out
 end
 for _,movement in ipairs(info.movements or{})do _auctionTick();
  if not canonical(c,movement,'stock_move')then out.costReason='Original posting movements do not belong to this character.';out.seen=nil;return out end
 end
 for _,part in ipairs(info.parts or{})do _auctionTick(); if part.lot then
  local lot=c.records[part.lot]
  if not lot or lot.character~=c.id then out.costReason='A local acquisition lot does not belong to this character.';out.seen=nil;return out end
 end end
 if link.partial then
  refs(c,out,link.partial.notice,'terminal sale notification')
  refs(c,out,link.partial.first,'original posted quantity')
  out.partial=true;out.postedQuantity=link.partial.postedQuantity;out.fifoOffset=link.partial.offset
  out.unresolvedEarlierQuantity=link.partial.offset
 end
 local slice;slice,why=R.Slice(info,link.partial and link.partial.offset or 0,link.quantity)
 if not slice then out.costReason=why;out.overflow=true;out.seen=nil;return out end
 out.knownCost,out.unknownQuantity,out.cost,out.allocations=slice.knownCost,slice.unknownQuantity,slice.cost,slice.parts
 for _,r in ipairs(info.movements)do _auctionTick(); refs(c,out,r.id,'original inventory disposal')end
 for _,part in ipairs(slice.parts)do _auctionTick();
  refs(c,out,part.lot,'FIFO acquisition lot')
  if part.sourceCharacter and part.sourceRecord then
   if part.sourceCharacter==c.id then refs(c,out,part.sourceRecord,'original acquisition')
   else out.references[#out.references+1]={character=part.sourceCharacter,record=part.sourceRecord,role='transferred acquisition provenance'}end
  end
 end
 out.basisComplete=out.cost~=nil
 if out.basisComplete then
  out.marginAfterHouseCut=difference(out.afterHouseCut,out.cost)
  if out.marginAfterHouseCut==nil then out.overflow=true;out.costReason='Margin exceeds exact copper precision.'end
 else out.costReason='Some sold units have unknown acquisition cost.'end
 -- Even a zero returned deposit does not establish that no other posting
 -- expense occurred. Never call this subtotal complete net profit.
 out.marginMeaning='Sale price minus recorded house cut and FIFO acquisition cost; other fees excluded'
 if envelope.rejectAuctionSettlement then
  out.rejected=true;out.marginAfterHouseCut=nil;out.costReason='The inferred sale-cost association was rejected; original evidence is preserved.'
 end
 out.seen=nil;return out
end
function R.Reject(c,r,rejected)
 if not canonical(c,r,'mail')or not r.mailData or not r.mailData.invoice or r.mailData.invoice.type~='seller'then return false end
 if (r.rejectAuctionSettlement==true)==(rejected==true)then return true end
 r.rejectAuctionSettlement=rejected and true or nil;S.Changed(c,r);return true
end
local function summarize(c,proceeds,includeRows)
 local out={rows={},linked=0,unknownBasis=0,rejected=0,unlinked=0,matchedBasis=0,knownAllocatedCost=0,
  matchedGross=0,matchedHouseCut=0,matchedCost=0,marginAfterHouseCut=0,overflow=false,
  boundary=proceeds.boundary,excluded=proceeds.excluded,dateMeaning='Observed collection interval; exact sale completion time unknown',
  feeCoverage='House cuts only; other nonrefundable fees and deposit settlement remain unresolved'}
 local seen={}
 for _,invoice in ipairs(proceeds.rows)do _auctionTick(); if not seen[invoice.envelope]then
  seen[invoice.envelope]=true
  local row=R.Invoice(c,c.records[invoice.envelope])
  if row then
   if includeRows then out.rows[#out.rows+1]=row end
   out.linked=out.linked+1
   if row.rejected then out.rejected=out.rejected+1
   else
    if row.overflow then out.overflow=true end
    out.knownAllocatedCost=sum(out.knownAllocatedCost,row.knownCost);if not out.knownAllocatedCost then out.overflow=true end
    if row.marginAfterHouseCut~=nil then
     out.matchedBasis=out.matchedBasis+1
     out.matchedGross=sum(out.matchedGross,row.gross);out.matchedHouseCut=sum(out.matchedHouseCut,row.houseCut);out.matchedCost=sum(out.matchedCost,row.cost)
     out.marginAfterHouseCut=difference(out.marginAfterHouseCut,-row.marginAfterHouseCut)
     if not out.matchedGross or not out.matchedHouseCut or not out.matchedCost or not out.marginAfterHouseCut then out.overflow=true end
    else out.unknownBasis=out.unknownBasis+1 end
   end
  else out.unlinked=out.unlinked+1 end
 end end
 if out.overflow then out.knownAllocatedCost=nil;out.matchedGross=nil;out.matchedHouseCut=nil;out.matchedCost=nil;out.marginAfterHouseCut=nil
 elseif out.matchedBasis==0 then out.marginAfterHouseCut=nil end
 return out
end
function R.Report(c,from,through,query)
 return summarize(c,E.AuctionProceeds.Report(c,from,through,query),true)
end
function R.Proceeds(c,from,through,query)
 local proceeds=E.AuctionProceeds.Report(c,from,through,query)
 if not query or query=='' then
  -- Wallet debits identify posting cash for this character and date range;
  -- an invoice item/buyer filter cannot be applied to those debits.
  local flow={paid=0,count=0,inferred=0,invalid=0}
  for _,w in ipairs(Q.Range(c,from,through,'gold'))do _auctionTick();
   if canonical(c,w,'gold') and w.source=='auctionDeposit' and (w.quality=='inferred' or w.quality=='confirmed')then
    if integer(w.amount,-maximum,-1)then
     flow.count=flow.count+1
     flow.paid=sum(flow.paid,-w.amount)
     if w.quality=='inferred' then flow.inferred=flow.inferred+1 end
    else flow.invalid=flow.invalid+1 end
   end
  end
  if flow.count>0 or flow.invalid>0 or (proceeds.deposit or 0)>0 then
   if flow.invalid==0 and proceeds.unresolved==0 and proceeds.excluded==0 and proceeds.boundary==0 then
    flow.net=difference(proceeds.deposit,flow.paid)
   end
   proceeds.depositFlow=flow
  end
 end
 return proceeds,summarize(c,proceeds,false)
end
-- Additional implicit retention edges for integration into Store.dependencies.
-- AuctionLinks already retains same-name listing / invoice competitors.
local evidenceKinds={auction=true,inventory=true,inventory_gap=true,bank=true,bank_gap=true,merchant=true,
 trade=true,trade_offer=true,trade_notice=true,mail_collection=true,mail=true,mail_scan=true,mail_request=true,
 mail_notice=true,mail_draft=true,craft_request=true,craft_begin=true,craft_result=true,crafted=true,gold=true,money_evidence=true,wallet_window=true}
function R.Retention(c,r,add,state)
 if r.kind~='auction'then return end
 local function tick()if state.work then state.work()end end
 if not state.auctionSettlement then
  local indexed={created={},unknownCreated={},rows={},posts={},auctions={}}
  for _,v in pairs(c.records)do _auctionTick(); tick()
   if evidenceKinds[v.kind]then indexed.rows[#indexed.rows+1]=v end
   if v.kind=='auction'and v.source=='created'then
    if integer(v.auctionID,1)then local list=indexed.created[v.auctionID]or{};indexed.created[v.auctionID]=list;list[#list+1]=v
    else indexed.unknownCreated[#indexed.unknownCreated+1]=v end
   end
  end
  if state.work then E.RetentionWork.Sort(indexed.rows,S.Before,state.work)else _auctionSort(indexed.rows,S.Before)end
  state.auctionSettlement=indexed
 end
 local indexed=state.auctionSettlement
 local function interval(first,through,visit)
  local lo,hi=1,#indexed.rows+1
  while lo<hi do _auctionTick(); tick();local mid=math.floor((lo+hi)/2);if indexed.rows[mid].ts<first then lo=mid+1 else hi=mid end end
  while indexed.rows[lo]and indexed.rows[lo].ts<through do _auctionTick(); tick();visit(indexed.rows[lo]);lo=lo+1 end
 end
 if r.source=='post'then
  if indexed.posts[r.id]then return end;indexed.posts[r.id]=true
  local first=r.inventoryAnchor and r.inventoryAnchor.ts or r.ts-15
  if type(first)~='number'or first>r.ts or first<r.ts-15 then first=r.ts-15 end
  -- A fresh inventory anchor can start later than the deposit comparison.
  -- Preserve only possible debit rivals in that otherwise uncovered prefix.
  if E.AuctionDeposits and first>r.ts-2 then
   interval(r.ts-2,first,function(v)
    if E.AuctionDeposits.CandidateDebit(r,v)then add(v.id,{kind='linked',source=r.id})end
   end)
  end
  interval(first,r.ts+6,function(v)if v.id~=r.id then add(v.id,{kind='linked',source=r.id})end end)
 elseif r.auctionID then
  if indexed.auctions[r.auctionID]then return end;indexed.auctions[r.auctionID]=true
  local function preserve(created)tick()
   add(created.id,{kind='linked',source=r.id})
   interval(created.ts-5,created.ts+1,function(post)
    if post.kind=='auction'and post.source=='post'and post.session==created.session then add(post.id,{kind='linked',source=r.id})end
   end)
  end
  for _,created in ipairs(indexed.created[r.auctionID]or{})do _auctionTick(); preserve(created)end
  if not indexed.unknownExpanded then indexed.unknownExpanded=true;for _,created in ipairs(indexed.unknownCreated)do _auctionTick(); preserve(created)end end
 end
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="AuctionSettlement",create=create}
E.AuctionReaderSources["AuctionSettlement.lua"]="65aa923135386a239f4a991e7f883adb72947d330fb8089686fda56d2d88987d"
end

-- AuctionDeposits.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='AuctionDeposits';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local D,S,Q,F={},E.Store,E.Query,E.Economy;E.AuctionDeposits=D
local function integer(v,min)return type(v)=='number'and v==v and v%1==0 and v>=(min or 0)and v<=9007199254740991 end
local function canonical(c,r,kind)return type(r)=='table'and c.records[r.id]==r and r.character==c.id and r.kind==kind end
local function posting(c,r)
 if not canonical(c,r,'auction')or r.source~='post'or r.rejectAuctionDeposit then return end
 local d,a=r.auctionData,r.walletAnchor
 if type(d)~='table'or d.coverage~='request arguments observed'or not integer(d.depositQuote,1)or d.depositQuoteAt~=r.ts
  or not integer(d.duration,1)or not integer(d.quantity,1)or not integer(r.itemID,1)or d.itemID~=r.itemID
  or not integer(r.ts)or type(r.session)~='string'or r.session==''then return end
 local method=d.requestMethod=='PostItem'and'CalculateItemDeposit'or d.requestMethod=='PostCommodity'and'CalculateCommodityDeposit'
 if not method or d.depositQuoteMethod~=method then return end
 if type(a)~='table'or a.session~=r.session or not integer(a.amount)or not integer(a.ts)or a.ts>r.ts or r.ts-a.ts>15
  or not integer(a.sequence)or a.sequence>=S.Sequence(r)then return end
 local window=c.records[a.window]
 if not canonical(c,window,'wallet_window')or window.session~=r.session or not integer(window.ts)or not integer(window.ended)
  or window.ts>a.ts then return end
 local plan=E.AuctionCosts.Resolve(c,r);if not plan then return end
 if not canonical(c,plan.created,'auction')or not canonical(c,plan.listing,'auction')
  or not integer(plan.created.auctionID,1)or plan.listing.auctionID~=plan.created.auctionID
  or plan.itemID~=r.itemID or plan.quantity~=d.quantity or not plan.listing.auctionData
  or plan.listing.auctionData.itemID~=r.itemID then return end
 for _,id in ipairs(plan.refs)do _auctionTick(); local source=c.records[id];if not source or source.character~=c.id then return end end
 return plan,window
end
-- This is only the rival census. A debit that precedes the request can
-- prevent a unique match even though it cannot itself establish a deposit.
function D.CandidateDebit(post,wallet)
 local quote=type(post.auctionData)=='table'and post.auctionData.depositQuote
 local anchor=post.walletAnchor
 return wallet.kind=='gold'and integer(quote,1)and type(anchor)=='table'and anchor.window~=nil
  and type(post.session)=='string'and wallet.session==post.session and wallet.window==anchor.window
  and wallet.amount==-quote and integer(post.ts)and type(wallet.ts)=='number'and math.abs(wallet.ts-post.ts)<=2
end
function D.ValidProof(c,p)
 if not canonical(c,p,'money_evidence')or p.source~='auctionDeposit'or p.auctionDepositVersion~=1
  or p.observationType~='auction_posting_deposit'or p.withdrawnReason then return false end
 local r=c.records[p.posting];local plan,window=posting(c,r);if not plan then return false end
 local d,a=r.auctionData,r.walletAnchor
 if p.ts~=r.ts or p.session~=r.session or p.amount~=-d.depositQuote or p.quotedDeposit~=d.depositQuote
  or p.quoteMethod~=d.depositQuoteMethod or p.itemID~=r.itemID or p.quantity~=d.quantity or p.duration~=d.duration
  or p.created~=plan.created.id or p.listing~=plan.listing.id or p.auctionID~=plan.created.auctionID
  or p.walletWindow~=window.id or p.requestSequence~=S.Sequence(r)then return false end
 local found,count=nil,0
 for _,w in ipairs(Q.Range(c,r.ts-2,r.ts+3,'gold'))do _auctionTick();
  if D.CandidateDebit(r,w)then found=w;count=count+1 end
 end
 -- A post-hook quote cannot establish an earlier debit. Earlier callbacks stay
 -- unknown until an independently captured pre-request quote is available.
 return count==1 and canonical(c,found,'gold')and found.ts>=r.ts and S.Sequence(found)>S.Sequence(r)
  and S.Sequence(found)>a.sequence and found.before==a.amount and integer(found.after)
  and found.after-found.before==p.amount and window.ended>=found.ts
end
function D.Reject(c,r,rejected)
 if not canonical(c,r,'auction')or r.source~='post'then return false end
 r.rejectAuctionDeposit=rejected and true or nil;S.Changed(c,r);return true
end
local busy=false
local function capture(c,r)
 if busy or E.db.characters[c.id]~=c then return end
 local key='auction-deposit:'..r.id
 if c.dedup and c.dedup['money_evidence:'..key]then return end
 local plan,window=posting(c,r);if not plan then return end
 busy=true
 local d=r.auctionData
 local ok,why=pcall(F.Evidence,c,r.ts,{title='Posting deposit / inferred',source='auctionDeposit',amount=-d.depositQuote,session=r.session,
  auctionDepositVersion=1,observationType='auction_posting_deposit',posting=r.id,created=plan.created.id,listing=plan.listing.id,
  auctionID=plan.created.auctionID,itemID=r.itemID,quantity=d.quantity,duration=d.duration,quotedDeposit=d.depositQuote,
  quoteMethod=d.depositQuoteMethod,requestSequence=S.Sequence(r),walletWindow=window.id,
  refs={r.id,plan.created.id,plan.listing.id,window.id},
  evidenceNote='Inferred posting-deposit cash outflow. Recoverable deposit; refund, forfeiture and complete profit are unresolved.'},key)
 busy=false
 if not ok then error(why,0)end
end
local relevant={auction=true,inventory=true,inventory_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,
 mail=true,mail_scan=true,mail_collection=true,mail_request=true,mail_notice=true,mail_draft=true,bank=true,bank_gap=true,
 craft_request=true,craft_begin=true,craft_result=true,crafted=true,loot=true,gathered=true}
local stamps=setmetatable({},{__mode='k'});local changes=setmetatable({},{__mode='k'})
local function stamp(r)
 local out={kind=r.kind,ts=r.ts}
 if r.kind=='auction'then out.source=r.source;out.character=r.character;out.session=r.session;out.auctionID=r.auctionID;out.itemID=r.itemID
  out.data=_auctionCopy(r.auctionData);out.anchor=_auctionCopy(r.walletAnchor);out.inventory=_auctionCopy(r.inventoryAnchor)
  out.rejectDeposit=r.rejectAuctionDeposit;out.rejectPosting=r.rejectPostingCosts end
 return out
end
E.On('HISTORY_TOUCHED',function(c,receipt)
 local d=receipt and receipt.detail;local r=type(d)=='table'and d.record
 if receipt and receipt.reason=='record'and type(r)=='table'then
  local oldKind=d.operation=='change'and Q.RecordedKind(c,r.id)
  if relevant[r.kind]or relevant[oldKind]or stamps[r]then
   if d.operation=='change'then changes[receipt]={record=r,prior=stamps[r],oldKind=oldKind,unanchoredOffer=Q.RecordedUnanchoredOffer(c,r.id)};stamps[r]=stamp(r)
   elseif d.operation=='add'then stamps[r]=stamp(r)end
  end
 end
end)
local function reviewAt(c,ts)
 for _,r in ipairs(Q.Range(c,ts-20,ts+21,'auction'))do _auctionTick(); if r.source=='post'then capture(c,r)end end
 for _,proof in ipairs(Q.Range(c,ts-22,ts+23,'money_evidence'))do _auctionTick();
  if proof.source=='auctionDeposit'then E.GoldChecks.RequestDepositHistory(c,proof.id)end
 end
end
-- A cold receipt only schedules its timestamp. The financial worker checks
-- the original time window after Query finishes its cooperative preparation.
function D.Defer(c,ts,linkCosts)
 local pending=c.state.auctionDepositTimes
 if not pending then
  pending={first=1,last=0,times={}}
  c.state.auctionDepositTimes=pending
 end
 if pending.times[pending.last]~=ts then
  pending.last=pending.last+1
  pending.times[pending.last]=ts
 end
 if linkCosts then
  pending.linkCosts=pending.linkCosts or{}
  pending.linkCosts[pending.last]=true
 end
 E.GoldChecks.RequestDepositReview(c)
end
local function near(c,ts)
 if E.db.characters[c.id]~=c then return end
 if not integer(ts)then E.GoldChecks.RequestDepositHistory(c);return end
 if Q.EnsureWarm(c)=='ready'then reviewAt(c,ts)
 else D.Defer(c,ts)end
end
function D.ProcessDeferred(c)
 local pending=c.state.auctionDepositTimes
 if not pending then return false end
 local first=pending.first
 if pending.linkCosts and pending.linkCosts[first]then E.AuctionCosts.LinkAt(c,pending.times[first])end
 reviewAt(c,pending.times[first])
 if pending.linkCosts then pending.linkCosts[first]=nil end
 pending.times[first]=nil
 if first==pending.last then c.state.auctionDepositTimes=nil
 else pending.first=first+1 end
 return true
end
E.On('RECORD_ADDED',function(c,r,_,receipt)
 local d=receipt and receipt.detail
 if type(d)=='table'and d.previousKind and(relevant[d.previousKind]or relevant[r.kind])then E.GoldChecks.RequestDepositHistory(c)end
 if relevant[r.kind]then near(c,r.ts)end
 if r.kind=='auction'and r.source=='owned'and integer(r.auctionID,1)then E.GoldChecks.RequestDepositHistory(c,r.auctionID)end
end)
E.On('RECORD_CHANGED',function(c,r,_,receipt)
 local entry=receipt and changes[receipt];if receipt then changes[receipt]=nil end
 -- TradeCosts.Plan requires the accepted offer's inventory anchor. When
 -- neither observation can claim items, Trades owns the wallet correction.
 if entry and entry.record==r and entry.unanchoredOffer and c.records[r.id]==r
  and r.kind=='trade_offer'and r.inventoryAnchor==nil then return end
 if E.AuctionPreparation and E.AuctionPreparation.ReturnReviewReceipt(c,r,receipt)then return end
 local prior=entry and entry.record==r and entry.prior
 local oldKind=entry and entry.oldKind or Q.PreviousKind(c,r.id)
 if not relevant[r.kind]and not(prior and relevant[prior.kind])and not relevant[oldKind]then return end
 local fresh=stamps[r]or stamp(r)
 -- Repeated owned-list observations change lastObservedAt only. They are not
 -- corrections and must not trigger archive-wide review during normal polling.
 if prior and prior.kind=='auction'and r.kind=='auction'and _auctionSame(prior,fresh)then return end
 near(c,r.ts)
 if prior then near(c,prior.ts)end
 -- A corrected earlier owned listing can contradict first-use of its ID far
 -- outside the local posting window. Unknown prior membership is conservative.
 -- Inventory dependencies are canonical IDs, not a time radius: an unchanged
 -- poll can retain a very old baseline beneath a fresh posting anchor. Every
 -- correction is conservative, including refs and intermediate claim fields.
 -- Only Inventory's exact in-flight bookkeeping receipt avoids a full review.
 local inventory= r.kind=='inventory'or oldKind=='inventory'or prior and prior.kind=='inventory'
 local bookkeeping=inventory and E.Inventory and E.Inventory.AccountingReceipt(c,r,receipt)
 if not prior or inventory and not bookkeeping then
  E.GoldChecks.RequestDepositHistory(c)
 else
  if prior.kind=='auction'and prior.source=='owned'and integer(prior.auctionID,1)then E.GoldChecks.RequestDepositHistory(c,prior.auctionID)end
  if r.kind=='auction'and r.source=='owned'and integer(r.auctionID,1)then E.GoldChecks.RequestDepositHistory(c,r.auctionID)end
 end
end)

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="AuctionDeposits",create=create}
E.AuctionReaderSources["AuctionDeposits.lua"]="208c9549586a59e8cce5883e8319eae4efb2ecd0835a86013b26a0c5942de8ac"
end

-- AuctionReturns.lua
do
local function create(E)
local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='AuctionReturns';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
local R,S,Q={},E.Store,E.Query;E.AuctionReturns=R
local function int(n,min)return type(n)=='number'and n==n and n%1==0 and n>=(min or 0)and n<=67108864 end
local function own(c,r,kind)return E.db.characters[c.id]==c and r and c.records[r.id]==r and r.character==c.id and r.kind==kind end
local caches=setmetatable({},{__mode='k'})
local tickets=setmetatable({},{__mode='k'})
local function invalidate(c)caches[c]=nil end
E.On('RECORD_ADDED',invalidate);E.On('RECORD_CHANGED',invalidate);E.On('RECORDS_REMOVED',invalidate)
-- Mail has no authored returned-auction identity. These are proposals only;
-- the user must confirm the exact parcel's origin before any cost projection.
local ownedSources={owned=true,created=true,cancelled=true,expired=true,sale_notice=true}
local function timeKnown(ts)return type(ts)=='number'and ts==ts and ts>-math.huge and ts<math.huge end
local function order(c,r)
 -- Do not infer historical observation order from an ID suffix or a missing
 -- counter. Both creation and any explicitly reserved observation must fit
 -- this character's monotonic recorded counter.
 local seq=r and r.sequence;local n=seq;if r and r.observationSequence~=nil then n=r.observationSequence end
 local function valid(v)return type(v)=='number'and v==v and v%1==0 and v>=1 and v<=9007199254740991 end
 if not valid(seq)or not valid(n)or not valid(c.seq)or n>seq or seq>c.seq then return end
 return n
end
local function groups(c)
 local out={};for _,r in ipairs(Q.Kind(c,'auction'))do _auctionTick(); if r.character==c.id and ownedSources[r.source]then
  local key=r.auctionID or('unknown:'..r.id);local g=out[key]
  if not g then g={id=r.auctionID,rows={},created={},notices={}};out[key]=g end
  if r.source=='sale_notice'then g.notices[#g.notices+1]=r else g.rows[#g.rows+1]=r end
  local d=r.auctionData or{}
  if r.source=='owned'then
   if not int(r.itemID,1)or d.itemID~=r.itemID or not int(d.quantity,1)or d.auctionID~=r.auctionID or d.coverage~='observed'then g.bad=true end
   if g.itemID and g.itemID~=r.itemID then g.bad=true end
   if g.quantity and g.quantity~=d.quantity then g.varied=true end
   g.itemID,g.quantity=r.itemID,d.quantity
   if d.statusLabel~='Active'then g.bad=true end
   local sequence=order(c,r)
   if not sequence or not timeKnown(r.ts)then g.unknownStart=true
   else g.firstOrder=math.min(g.firstOrder or sequence,sequence);g.firstTime=math.min(g.firstTime or r.ts,r.ts)end
   if not g.active or S.Before(r,g.active)then g.active=r end
  elseif r.source=='created'then g.created[#g.created+1]=r
  elseif r.source=='cancelled'or r.source=='expired'then
   if g.closed then g.bad=true end;g.closed=r
   if d.event~=(r.source=='cancelled'and'AUCTION_CANCELED'or'AUCTION_HOUSE_AUCTIONS_EXPIRED')or d.auctionID~=r.auctionID then g.bad=true end
  end
 end end
 for _,g in pairs(out)do _auctionTick();
  if not g.active or not g.closed or not g.id or not S.Before(g.active,g.closed)then g.bad=true end
  if g.closed then for _,r in ipairs(g.rows)do _auctionTick();
   if r.source=='owned'and(r.lastObservedAt or r.ts)>g.closed.ts then g.bad=true end
  end end
 end;return out
end
local function dense(rows,count,limit,work)
 if type(rows)~='table'or not int(count)or count>limit or #rows~=count then return false end
 local n=0;for key in pairs(rows)do _auctionTick(); if work then work()end
  if not int(key,1)or key>count then return false end;n=n+1
 end;return n==count
end
-- Shared by matching and protection: observed attachments are exhaustive only
-- with a complete, dense header/slot census. Losing identity adds a wildcard;
-- it can never make a competing collection disappear.
local function mailCandidates(c,row,emit,work)
 if not own(c,row,'mail')or type(row.mailData)~='table'then emit(nil);return end
 local d=row.mailData;local complete=d.complete==true and dense(d.items,d.itemCount,16,work)
 local slots={};local ids={}
 if type(d.items)=='table'then for _,item in pairs(d.items)do _auctionTick(); if work then work()end
  if type(item)~='table'then complete=false
  else
   local identified=item.isCurrency==true and int(item.currencyID,1)and item.itemID==nil
    or item.isCurrency~=true and int(item.itemID,1)and item.currencyID==nil
   if not item.complete or not identified or not int(item.quantity,1)or not int(item.slot,1)or item.slot>16 or slots[item.slot]then complete=false end
   if item.slot then slots[item.slot]=true end
   if int(item.itemID,1)then ids[item.itemID]=true end
  end
 end end
 if not complete then emit(nil);return end
 -- Only a fully readable purchase parcel can be positively excluded.
 if type(d.invoice)=='table'and d.invoice.type=='buyer'then return end
 for id in pairs(ids)do _auctionTick(); if work then work()end;emit(id,row.ts,row)end
end
local function collectionCandidates(c,b,emit,work)
 local scan=c.records[b.beforeScan]
 if not own(c,scan,'mail_scan')or scan.complete~=true or scan.session~=b.session or scan.visit~=b.visit
  or not int(scan.loaded)or scan.loaded~=scan.total or not dense(scan.entries,scan.loaded,100,work)then emit(nil)end
 if not scan or type(scan.entries)~='table'then return end
 local seen={};for _,id in pairs(scan.entries)do _auctionTick(); if work then work()end
  local row=c.records[id]
  if seen[id]or not own(c,row,'mail')or row.scan~=scan.id or row.session~=b.session or row.visit~=b.visit then emit(nil)
  else mailCandidates(c,row,emit,work)end
  seen[id]=true
 end
end
local function coverage(c,b)
 local out={items={}}
 collectionCandidates(c,b,function(id,ts,row)
  if not id then out.unknown=true
  else
   local item=out.items[id]or{};out.items[id]=item;local sequence=order(c,row)
   if not sequence or not timeKnown(ts)then item.unknownOrder=true
   else item.lastOrder=math.max(item.lastOrder or sequence,sequence);item.lastTime=math.max(item.lastTime or ts,ts)end
  end
 end)
 return out
end
local function possible(observed,g)
 if observed.unknown then return true end
 if g.itemID then local item=observed.items[g.itemID];if not item then return false end
  -- Exclusion needs both explicit earlier observation order and compatible
  -- wall time. A later observation with a rolled-back clock stays a rival;
  -- missing order and contradictory clocks never increase certainty.
  return item.unknownOrder or g.unknownStart or not item.lastOrder or not g.firstOrder
   or item.lastOrder>=g.firstOrder or item.lastTime>g.firstTime
 end
 return next(observed.items)~=nil
end
local function itemPayload(link,id)
 if type(link)~='string'then return end
 local payload=link:match('^|H(item:[^|]+)|h%[[^|]*%]|h$')
  or link:match('^|c%x%x%x%x%x%x%x%x|H(item:[^|]+)|h%[[^|]*%]|h|r$')
 if payload and tonumber(payload:match('^item:(%d+):')or payload:match('^item:(%d+)$'))==id then return payload end
end
local function parcel(c,b)
 if not own(c,b,'mail_collection')then return end
 for _,key in ipairs({'beforeScan','afterScan'})do _auctionTick(); local scan=c.records[b[key]]
  if not own(c,scan,'mail_scan')then return end
  for _,id in ipairs(scan.entries or{})do _auctionTick(); if not own(c,c.records[id],'mail')then return end end
 end
 for _,key in ipairs({'requests','notices'})do _auctionTick(); local kind=key=='requests'and'mail_request'or'mail_notice'
  for _,id in ipairs(b[key]or{})do _auctionTick(); if not own(c,c.records[id],kind)then return end end
 end
 local p=E.MailCosts.Plan(c,b)
 if not p or #p.components~=1 or p.gold~=0 then return end
 local part=p.components[1];local e=c.records[part.record];local d=e and e.mailData
 if not own(c,e,'mail')or not d or d.invoice or not dense(d.items,d.itemCount,16)
  or d.money~=0 or d.cod~=0 or part.money~=0 or part.cod~=0 then return end
 local itemID,quantity;for id,n in pairs(part.beforeItems)do _auctionTick(); if itemID then return end;itemID,quantity=id,n end
 if not int(itemID,1)or not int(quantity,1)or part.items[itemID]~=quantity then return end
 local stacked
 if #d.items~=1 then
  -- Multiple attachment slots can be one returned commodity. Require one
  -- complete auto-loot of the whole envelope and an identical item payload.
  local request=#b.requests==1 and c.records[b.requests[1]]
  if not request or request.method~='AutoLootMailItem'
   or #d.items<2 or #part.removed~=#d.items or d.invoiceUnavailable then return end
  for _,item in ipairs(d.items)do _auctionTick();
   local key=itemPayload(item.itemLink,itemID)
   if item.itemID~=itemID or not key or stacked and key~=stacked then return end
   stacked=key
  end
 end
 if E.MailCosts.Resolve(c,p.records[1])~=b then return end
 return {collection=b.id,envelope=e.id,itemID=itemID,quantity=quantity,plan=p,parcel=e,stackedPayload=stacked}
end
-- A smaller parcel alone cannot identify the unsold tail of a posting.
-- Follow the collector's actual previous-observation chain through every
-- owned row to the closure, checking both order and wall time at each edge.
-- A notice proves some stock was reported sold but contains no quantity.
-- Each notice must fit a later observed decrease from its exact active row.
-- Without that witness the remaining parcel could overlap sold stock.
local function noticesFit(c,g,request)
 if #g.notices==0 then return true end
 local nextOwned={}
 for _,row in ipairs(g.rows)do _auctionTick();
  if row.source=='owned'and row.previousObservation then nextOwned[row.previousObservation]=row end
 end
 local used={}
 for _,notice in ipairs(g.notices)do _auctionTick();
  local prior=c.records[notice.previousObservation];local later=prior and nextOwned[prior.id]
  local d=notice.auctionData or{}
  if not later or prior.source~='owned'or prior.auctionID~=g.id or notice.session~=request.session
   or d.auctionID~=g.id or d.event~='AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION'or d.notification~='AuctionSold'
   or not order(c,prior)or not order(c,notice)or not order(c,later)or order(c,prior)>=order(c,notice)or order(c,notice)>=order(c,later)
   or not timeKnown(notice.ts)or not timeKnown(prior.ts)or not timeKnown(prior.lastObservedAt or prior.ts)or not timeKnown(later.ts)
   or math.max(prior.ts,prior.lastObservedAt or prior.ts)>notice.ts or notice.ts>later.ts then return false end
  local count=(used[prior.id]or 0)+1;used[prior.id]=count
  if not int(prior.auctionData.quantity,1)or not int(later.auctionData.quantity,1)
   or prior.auctionData.quantity-later.auctionData.quantity<count then return false end
 end
 return true
end
local function remainingOffset(c,g,p,request,plan)
 if not noticesFit(c,g,request)then return end
 if not g.varied then
  if plan.quantity==p.quantity and g.quantity==p.quantity then return 0 end
  return
 end
 if request.auctionData.requestMethod~='PostCommodity' or plan.quantity<=p.quantity
  or #g.created~=1 or plan.created~=g.created[1] or plan.created.previousObservation~=nil
  or plan.created.auctionData.auctionID~=g.id or not timeKnown(p.parcel.ts)then return end
 local function precedes(a,b)
  local first,last=order(c,a),order(c,b)
  local through=a.lastObservedAt or a.ts
  return first and last and first<last and timeKnown(a.ts)and timeKnown(through)and timeKnown(b.ts)
   and a.ts<=through and through<=b.ts
 end
 if not precedes(request,plan.created)or not precedes(g.closed,p.parcel)then return end
 local nextRow=g.closed
 local expected=p.quantity
 local count=0
 while nextRow.previousObservation~=plan.created.id do _auctionTick();
  local row=c.records[nextRow.previousObservation]
  if not own(c,row,'auction')or row.source~='owned'or row.auctionID~=g.id or row.session~=request.session
   or nextRow.session~=request.session or not precedes(row,nextRow) then return end
  local data=row.auctionData
  if type(data.itemKey)~='table' or data.itemKey.itemID~=p.itemID then return end
  local quantity=data.quantity
  if count==0 and quantity~=expected or quantity<expected then return end
  expected=quantity
  count=count+1
  nextRow=row
 end
 if count+2~=#g.rows or nextRow~=plan.listing or expected~=plan.quantity
  or not precedes(plan.created,nextRow)then return end
 return plan.quantity-p.quantity
end
local function posting(c,g,p)
 local candidates={};for _,r in ipairs(Q.Kind(c,'auction'))do _auctionTick(); if r.source=='post'and r.character==c.id then
  local plan=E.AuctionCosts.Plan(c,r);local may=plan and plan.created.auctionID==g.id
  if not plan and(not r.itemID or r.itemID==p.itemID)then
   for _,made in ipairs(g.created)do _auctionTick(); if r.session==made.session and r.ts<=made.ts and made.ts<=r.ts+6 then may=true end end
  end
  if may then candidates[#candidates+1]={record=r,plan=plan}end
 end end
 if #candidates~=1 then return end
 local r,plan=candidates[1].record,candidates[1].plan
 if not plan or plan.itemID~=p.itemID or not S.Before(r,g.closed)then return end
 if not own(c,plan.created,'auction')or not own(c,plan.listing,'auction')then return end
 if p.stackedPayload and (r.auctionData.requestMethod~='PostCommodity'
  or itemPayload(r.auctionData.itemLink,p.itemID)~=p.stackedPayload
  or itemPayload(plan.listing.auctionData.itemLink,p.itemID)~=p.stackedPayload)then return end
 if E.AuctionCosts.Resolve(c,r)~=plan then return end
 local offset=remainingOffset(c,g,p,r,plan)
 if offset==nil then return end
 local movements,total={},0
 for _,inv in ipairs(plan.records)do _auctionTick(); local raw
  for _,id in ipairs(inv.refs or{})do _auctionTick(); local v=c.records[id]
   if own(c,v,'stock_move')and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==p.itemID and v.quantity==plan.rows[inv.id].quantity then
    if raw then return end;raw=v
   end
  end
  if not raw or not S.Before(raw,p.parcel)then return end
  movements[#movements+1]=raw;total=total+raw.quantity
 end
 if total~=plan.quantity then return end
 return r,plan,movements,offset
end
local function index(c)
 local old=caches[c];if old and old.revision==c.revision then return old end
 local out={revision=c.revision,byBatch={},byEnvelope={}};local gs=groups(c);local batches=Q.Kind(c,'mail_collection')
 local claims={};for _,b in ipairs(batches)do _auctionTick(); local pool={};local observed=coverage(c,b)
  for key,g in pairs(gs)do _auctionTick(); if possible(observed,g)then pool[#pool+1]=g;claims[key]=(claims[key]or 0)+1 end end
  out.byBatch[b.id]={pool=pool}
 end
 for _,b in ipairs(batches)do _auctionTick(); local entry=out.byBatch[b.id];local p=parcel(c,b);local g=#entry.pool==1 and entry.pool[1]
  if p then out.byEnvelope[p.envelope]=entry;entry.proposal=p end
  if p and g and claims[g.id]==1 and not g.bad and g.itemID==p.itemID and S.Before(g.closed,p.parcel)then
   local post,plan,movements,offset=posting(c,g,p)
   if post then p.posting,p.auctionID,p.closure,p.movements,p.postPlan=post.id,g.id,g.closed.id,movements,plan
    p.postedQuantity,p.unresolvedQuantity=plan.quantity,offset
    p.quality='inferred';p.originQuality='requires user confirmation';entry.valid=true
   end
  end
 end
 caches[c]=out;return out
end
function R.Proposal(c,envelope)
 if not own(c,envelope,'mail')then return nil,'Select a retained parcel belonging to this character.'end
 local entry=index(c).byEnvelope[envelope.id]
 if not entry or not entry.valid then return nil,'No unique matching posting, closure and collected parcel are available.'end
 local p=entry.proposal
 local proposal={envelope=p.envelope,collection=p.collection,posting=p.posting,auctionID=p.auctionID,closure=p.closure,itemID=p.itemID,quantity=p.quantity,
  postedQuantity=p.postedQuantity,unresolvedQuantity=p.unresolvedQuantity,
  quality='inferred',originQuality='requires user confirmation',warning='The client does not identify auction return mail. Confirm only if this parcel is the returned stock from this listing.'}
 tickets[proposal]={owner=c,envelope=envelope,posting=p.posting,revision=c.revision};return proposal
end
-- Version 1 confirms a full posting. Partial returns bind the reviewed
-- quantity and closure so corrections cannot silently change the FIFO tail.
function R.ReviewBasis(p)
 if p.unresolvedQuantity>0 then
  return {version=2,posting=p.posting,postedQuantity=p.postedQuantity,quantity=p.quantity,closure=p.closure,collection=p.collection}
 end
 return {version=1,posting=p.posting}
end
function R.MatchesBasis(review,p)
 if type(review)~='table'then return false end
 for key,value in pairs(R.ReviewBasis(p))do _auctionTick(); if review[key]~=value then return false end end
 return true
end
function R.Confirm(c,envelope,proposal)
 if type(proposal)~='table'then return false,'Inspect a fresh proposal before confirming.'end
 local ticket=tickets[proposal];tickets[proposal]=nil
 if not ticket or ticket.owner~=c or ticket.envelope~=envelope or ticket.revision~=c.revision then return false,'The review changed; inspect a fresh proposal.'end
 local p,why=R.Proposal(c,envelope);if not p or p.posting~=ticket.posting then return false,why or'The proposed posting changed.'end
 local review=R.ReviewBasis(p)
 review.contents=_auctionCopy(envelope.mailData)
 envelope.auctionReturnReview=review
 S.Changed(c,envelope);return true
end
function R.Clear(c,envelope)
 if not own(c,envelope,'mail')then return false end
 if envelope.auctionReturnReview~=nil then envelope.auctionReturnReview=nil;S.Changed(c,envelope)end;return true
end
function R.Project(c,r)
 if not own(c,r,'cost_lot')or r.source~='inventory observation'then return end
 local inv=c.records[r.evidence];local batch=E.MailCosts.Resolve(c,inv);if not batch then return end
 local entry=index(c).byBatch[batch.id];if not entry or not entry.valid then return end
 local p=entry.proposal;local review=p.parcel.auctionReturnReview
 if not R.MatchesBasis(review,p)or not _auctionSame(review.contents,p.parcel.mailData)then return end
 local part=p.plan.rows[inv.id][r.itemID]
 if r.itemID~=p.itemID or not part or part.quantity~=r.quantity then return end
 -- One accounting receipt per inventory/item; duplicate raw rows never create
 -- a second restoration or consume a second interval.
 local found;for _,id in ipairs(inv.refs or{})do _auctionTick(); local v=c.records[id]
  if v and v.kind=='cost_lot'and v.source=='inventory observation'and v.evidence==inv.id and v.itemID==r.itemID then if found then return end;found=v end
 end
 if found~=r then return end
 local copy=_auctionCopy(r);copy.kind='stock_return';copy.returnParts={};copy.auctionReturn=p.envelope;copy.quality='inferred';copy.title='Returned auction stock (origin confirmed; cost inferred)'
 local start=p.unresolvedQuantity+part.offset
 local offset=0;for _,move in ipairs(p.movements)do _auctionTick();
  local first,last=math.max(start,offset),math.min(start+part.quantity,offset+move.quantity)
  if last>first then copy.returnParts[#copy.returnParts+1]={sale=move.id,offset=first-offset,quantity=last-first}end;offset=offset+move.quantity
 end
 return {copy}
end
-- Item-connected candidates survive together. Unreadable identity is a wildcard,
-- not permission to remove a rival and manufacture uniqueness after cleanup.
local evidenceKinds={auction=true,mail=true,mail_collection=true,mail_scan=true,mail_request=true,mail_notice=true,
 inventory=true,inventory_gap=true,bank=true,bank_gap=true,merchant=true,trade=true,trade_offer=true,trade_notice=true,
 craft_request=true,craft_begin=true,craft_result=true,crafted=true,mail_draft=true,stock_move=true,cost_lot=true}
function R.Retention(c,r,add,state)
 if r.kind~='auction'and r.kind~='mail'and r.kind~='mail_collection'then return end
 local function tick()if state.work then state.work()end end
 local wildcard='unknown';local ix=state.auctionReturnRetention
 if not ix then
  ix={items={},members={},auctions={},seen={},intervals={},rows={}};state.auctionReturnRetention=ix
  local function join(id,key)
   key=key or wildcard;ix.items[key]=ix.items[key]or{};ix.items[key][id]=true
   ix.members[id]=ix.members[id]or{};ix.members[id][key]=true
  end
  for id,row in pairs(c.records)do _auctionTick(); tick()
   if evidenceKinds[row.kind]then ix.rows[#ix.rows+1]=row end
   if row.kind=='auction'and(row.source=='owned'or row.source=='post')then
    local key=int(row.itemID,1)and row.itemID or wildcard;join(id,key)
    if row.auctionID then local a=ix.auctions[row.auctionID]or{};ix.auctions[row.auctionID]=a;a[key]=true end
   elseif row.kind=='mail'then mailCandidates(c,row,function(key)join(id,key)end,tick)
   end
  end
  for id,row in pairs(c.records)do _auctionTick(); tick()
   if row.kind=='auction'and ownedSources[row.source]then
    local keys=ix.auctions[row.auctionID];if keys then for key in pairs(keys)do _auctionTick(); tick();join(id,key)end else join(id,wildcard)end
   elseif row.kind=='mail_collection'then collectionCandidates(c,row,function(key)join(id,key)end,tick)
   end
  end
  if state.work then E.RetentionWork.Sort(ix.rows,S.Before,state.work)else _auctionSort(ix.rows,S.Before)end
 end
 local function expand(key)
  tick();if ix.seen[key]then return end;ix.seen[key]=true
  for id in pairs(ix.items[key]or{})do _auctionTick(); tick();if id~=r.id then add(id,{kind='linked',source=r.id})end end
 end
 local keys=ix.members[r.id]
 if keys then
  for key in pairs(keys)do _auctionTick(); expand(key)end;expand(wildcard)
  if keys[wildcard]then for key in pairs(ix.items)do _auctionTick(); expand(key)end end
 end
 if r.kind=='mail_collection'and not ix.intervals[r.id]then
  ix.intervals[r.id]=true
  -- These fields are source ownership even if an incomplete collector record
  -- has not yet appended its ordinary refs. Keep the scan and observed rows.
  for _,key in ipairs({'beforeScan','afterScan'})do _auctionTick(); tick();local scan=c.records[r[key]]
   if scan then add(scan.id,{kind='linked',source=r.id})
    if type(scan.entries)=='table'then for _,id in pairs(scan.entries)do _auctionTick(); tick();if c.records[id]then add(id,{kind='linked',source=r.id})end end end
   end
  end
  for _,key in ipairs({'requests','notices'})do _auctionTick(); for _,id in ipairs(r[key]or{})do _auctionTick(); tick();if c.records[id]then add(id,{kind='linked',source=r.id})end end end
  local first=r.inventoryAnchor and r.inventoryAnchor.ts or r.ts-15
  if type(first)~='number'or first>r.ts or first<r.ts-15 then first=r.ts-15 end
  local through=type(r.settledAt)=='number'and r.settledAt+1 or(r.lastRequestAt or r.ts)+6
  local lo,hi=1,#ix.rows+1
  while lo<hi do _auctionTick(); tick();local mid=math.floor((lo+hi)/2);if ix.rows[mid].ts<first then lo=mid+1 else hi=mid end end
  while ix.rows[lo]and ix.rows[lo].ts<through do _auctionTick(); tick();local row=ix.rows[lo];if row.id~=r.id then add(row.id,{kind='linked',source=r.id})end;lo=lo+1 end
 end
end

end
E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="AuctionReturns",create=create}
E.AuctionReaderSources["AuctionReturns.lua"]="b4651b194f6522ab4dd0b7f34b6734c9f18a296e96b4f2559ab7876b75d21b6a"
end
