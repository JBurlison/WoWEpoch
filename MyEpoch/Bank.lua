local _,E=...
local B,A,S={},E.API,E.Store; E.Bank=B
local success="call succeeded; client behavior still needs validation"
local function integer(v,min,max)return type(v)=="number" and v==v and v%1==0 and v>=min and v<=max end
local function call(label,fn,...)
    local value=A.Call(label,fn,...)
    return value,A.status[label]==success
end
local function slot(counts,bag,index)
    local id,ok=call("bankItemID",C_Container and C_Container.GetContainerItemID,bag,index)
    local info,infoOK=call("bankItem",C_Container and C_Container.GetContainerItemInfo,bag,index)
    local again,againOK=call("bankItemIDCheck",C_Container and C_Container.GetContainerItemID,bag,index)
    if not ok or not infoOK or not againOK or id~=again then return nil,"Bank item identity unavailable or changing" end
    if id==nil then
        if info~=nil then return nil,"Empty bank-slot observations disagree" end
        return true,0
    end
    if type(info)=="table" and info.isLocked==true then return nil,"Bank item movement is locked",true end
    if not integer(id,1,9007199254740991) or type(info)~="table" or info.itemID~=id or info.isLocked~=false
        or not integer(info.stackCount,1,67108864) then return nil,"Bank item count unavailable or inconsistent" end
    counts[id]=(counts[id] or 0)+info.stackCount
    if counts[id]>67108864 then return nil,"Bank item total exceeds accounting bounds" end
    return true,info.stackCount
end
local function layout(bankType,carriedSizes)
    local n,nOK=call("bankTabCount",C_Bank.FetchNumPurchasedBankTabs,bankType)
    local rows,ok=call("bankTabs",C_Bank.FetchPurchasedBankTabData,bankType)
    if not nOK or not integer(n,0,32) or not ok or type(rows)~="table" then return nil,"Bank tab list unavailable" end
    local count=0; for key in pairs(rows)do
        if not integer(key,1,n) then return nil,"Bank tab list is not a complete sequence" end
        count=count+1
    end
    if count~=n then return nil,"Purchased bank tab count disagrees with tab list" end
    local ids,seen={},{}
    for i=1,n do local row=rows[i]
        if type(row)~="table" or not integer(row.ID,-100,1000) or row.bankType~=bankType
            or seen[row.ID] or carriedSizes[row.ID]~=nil then return nil,"Bank tab identity is inconsistent" end
        seen[row.ID]=true; ids[i]=row.ID
    end
    return ids
end
local function snapshot(key,bankType,carriedSizes)
    local visible,ok=call("bankView:"..key,C_Bank.CanViewBank,bankType)
    if not ok or type(visible)~="boolean" then return {status="unavailable",reason="Bank access could not be read"} end
    if not visible then return {status="closed"} end
    local usable,useOK=call("bankUse:"..key,C_Bank.CanUseBank,bankType)
    local usesBags,bagsOK=call("bankUsesBags",C_Bank.ShouldUsePlayerBagsInBank)
    if not useOK or type(usable)~="boolean" or not bagsOK or type(usesBags)~="boolean" then return nil,"Bank mode unavailable" end
    local ids,reason=layout(bankType,carriedSizes); if not ids then return nil,reason end
    local out={status="available",usable=usable,usesBags=usesBags,counts={},contents={},bagObjects={},tabs={}}
    local bagContainer
    if usesBags then
        bagContainer=A.Plain(Enum and Enum.BagIndex and Enum.BagIndex[key=="character" and "Characterbanktab" or "Accountbanktab"])
        if not integer(bagContainer,-100,1000) or carriedSizes[bagContainer]~=nil then return nil,"Bank bag-object container unavailable" end
        for _,id in ipairs(ids)do if id==bagContainer then return nil,"Bank tab aliases its bag-object container" end end
        out.bagContainer=bagContainer
    end
    for index,id in ipairs(ids)do
        local n,nOK=call("bankSlots",C_Container and C_Container.GetContainerNumSlots,id)
        if not nOK or not integer(n,(index==1 or not usesBags) and 1 or 0,1000) then return nil,"Bank tab capacity not ready" end
        out.tabs[index]={id=id,slots=n}
        for position=1,n do
            local read,err,transient=slot(out.contents,id,position)
            if not read then return nil,err,transient end
        end
        -- Camelot's first tab is built in; subsequent purchased tabs can hold bag objects.
        if usesBags and index>1 then
            local read,quantity,transient=slot(out.bagObjects,bagContainer,index)
            if not read then return nil,quantity,transient end
            if quantity>1 or (quantity==0)~=(n==0) then return nil,"Bank bag object and capacity disagree" end
        end
    end
    for _,counts in ipairs({out.contents,out.bagObjects})do for id,n in pairs(counts)do
        out.counts[id]=(out.counts[id] or 0)+n
        if out.counts[id]>67108864 then return nil,"Combined bank count exceeds accounting bounds" end
    end end
    local check,err=layout(bankType,carriedSizes)
    local stillVisible,viewOK=call("bankViewCheck:"..key,C_Bank.CanViewBank,bankType)
    local stillUsable,useCheckOK=call("bankUseCheck:"..key,C_Bank.CanUseBank,bankType)
    local stillUsesBags,modeOK=call("bankModeCheck",C_Bank.ShouldUsePlayerBagsInBank)
    if not check or not E.Same(ids,check) or not viewOK or stillVisible~=true or not useCheckOK or stillUsable~=usable
        or not modeOK or stillUsesBags~=usesBags then return nil,err or "Bank access or layout changed during the scan" end
    return out
end
function B.Snapshot(carriedSizes)
    local result={}
    local types=A.Plain(Enum and Enum.BankType)
    if type(C_Bank)~="table" or type(types)~="table" or not integer(types.Character,0,20) or not integer(types.Account,0,20)
        or types.Character==types.Account then
        return {character={status="unavailable",reason="Forever bank API unavailable"},account={status="unavailable",reason="Forever bank API unavailable"}}
    end
    for _,key in ipairs({"character","account"})do
        local row,reason,transient=snapshot(key,types[key=="character" and "Character" or "Account"],carriedSizes)
        if transient then return nil,reason,true end
        result[key]=row or {status="unavailable",reason=reason}
    end
    -- Distinct bank types must not claim the same physical tab or bag object.
    local seen={}
    for _,key in ipairs({"character","account"})do local row=result[key]
        if row.status=="available" then
            if row.bagContainer then
                if seen[row.bagContainer] then return {character={status="unavailable",reason="Bank container ownership overlaps"},account={status="unavailable",reason="Bank container ownership overlaps"}} end
                seen[row.bagContainer]=true
            end
            for _,tab in ipairs(row.tabs)do
            if seen[tab.id] then return {character={status="unavailable",reason="Bank tab ownership overlaps"},account={status="unavailable",reason="Bank tab ownership overlaps"}} end
            seen[tab.id]=true
        end end
    end
    return result
end
local function endScope(w,key,reason,now)
    local state=w.c.state.banks and w.c.state.banks[key]
    if state and state.record and not state.gap then
        local r=S.Add(w.c,"bank_gap",now,{title=(key=="account" and "Account" or "Character").." bank observation ended",
            bankType=key,reason=reason,from=state.lastSeen,refs={state.record},session=w.session})
        state.gap=r.id; state.status="unavailable"; S.Touch(w.c)
    end
end
function B.End(w,reason)
    if not w then return end
    for _,key in ipairs({"character","account"})do endScope(w,key,reason,A.Now())end
    w.bankPrior=nil
end
local function differences(before,after)
    local ids,rows={},{}
    for id in pairs(before or {})do ids[id]=true end; for id in pairs(after)do ids[id]=true end
    for _,id in ipairs(E.SortedKeys(ids))do local a,b=before and (before[id] or 0),after[id] or 0
        if not before or a~=b then rows[#rows+1]={itemID=id,before=a,after=b,delta=before and b-a} end
    end
    return rows
end
function B.Accept(w,snapshot,previous,inventoryRecord,baseline,now)
    if not snapshot.banks then return end
    local c=w.c; c.state.banks=c.state.banks or {}
    local prior=not baseline and w.bankPrior or nil
    local personal=E.Copy(snapshot.counts); local inventoryID=inventoryRecord and inventoryRecord.id or previous and previous.record
    local allReadable=true
    for _,key in ipairs({"character","account"})do
        local current=snapshot.banks[key]; local old=prior and prior.banks[key]
        if current.status=="unavailable" or not old or old.status=="unavailable" or current.status~=old.status then allReadable=false end
    end
    for _,key in ipairs({"character","account"})do local current=snapshot.banks[key]
        A.status["bank:"..key]=current.status=="available" and "Bank counts observed; matching transfers use inferred FIFO custody"
            or current.reason or "Bank not viewable; retained history is not a live count"
        if current.status~="available" then
            endScope(w,key,current.reason or "Bank is no longer viewable",now)
            local state=c.state.banks[key] or {}; c.state.banks[key]=state
            state.status=current.status; state.reason=current.reason
        else
            local old=prior and prior.banks[key]
            local continuous=old and old.status=="available" and old.usesBags==current.usesBags and E.Same(old.tabs,current.tabs)
            local state=c.state.banks[key] or {}; c.state.banks[key]=state
            if not continuous and state.record then endScope(w,key,"Bank coverage or layout changed",now)end
            local rows=differences(continuous and old.counts or nil,current.counts)
            local bagObjectsChanged=continuous and not E.Same(old.bagObjects,current.bagObjects)
            local changed=not continuous or #rows>0 or bagObjectsChanged or old.usable~=current.usable
            if changed then
                local refs={}; for _,id in ipairs({state.record or false,state.gap or false,inventoryID or false,prior and prior.inventoryID or false})do if id then refs[#refs+1]=id end end
                local transfers={}
                if continuous and allReadable and current.usable and old.usable and not bagObjectsChanged then
                    local other=key=="account" and "character" or "account"
                    for _,row in ipairs(rows)do
                        local personalBefore,personalAfter=prior.personal[row.itemID] or 0,personal[row.itemID] or 0
                        local otherOld,otherNew=prior.banks[other],snapshot.banks[other]
                        local otherUnchanged=otherOld.status=="closed" and otherNew.status=="closed"
                            or otherOld.status=="available" and otherNew.status=="available" and E.Same(otherOld.tabs,otherNew.tabs)
                            and (otherOld.counts[row.itemID] or 0)==(otherNew.counts[row.itemID] or 0)
                        if otherUnchanged and personalAfter-personalBefore==-row.delta then
                            transfers[#transfers+1]={itemID=row.itemID,quantity=math.abs(row.delta),direction=row.delta>0 and "deposit" or "withdrawal",quality="inferred"}
                        end
                    end
                end
                local r=S.Add(c,"bank",now,{title=(key=="account" and "Account" or "Character")..(continuous and " bank observation" or " bank baseline"),
                    bankType=key,baseline=not continuous,items=rows,counts=E.Copy(current.counts),tabs=E.Copy(current.tabs),bagObjects=E.Copy(current.bagObjects),
                    usesBags=current.usesBags,usable=current.usable,personalBefore=prior and E.Copy(prior.personal),personalAfter=personal,
                    observedFrom=continuous and prior.ts,inventoryRecord=inventoryID,previousRecord=continuous and state.record,
                    transfers=transfers,refs=refs,session=w.session,
                    coverage="Two matching readable bank and personal snapshots. Balanced net changes suggest transfers; hidden or canceling movements remain unknown."})
                state.record=r.id; state.gap=nil
            end
            state.lastSeen=now; state.status="available"; state.reason=nil; S.Touch(c,not changed and'bankUnchanged'or nil)
        end
    end
    w.bankPrior={banks=E.Copy(snapshot.banks),personal=personal,inventoryID=inventoryID,ts=now}
end
