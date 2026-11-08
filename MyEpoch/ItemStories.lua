local _,E=...
local I,K,S,W={},E.Keepsakes,E.Store,E.RetentionWork;E.ItemStories=I
local caches=setmetatable({},{__mode='k'});local epoch=0
local requested=setmetatable({},{__mode='k'})
function I.ReleaseView()
    for c in pairs(requested)do K.Cancel(c,'item-stories')end
    requested=setmetatable({},{__mode='k'});caches=setmetatable({},{__mode='k'})
end
-- Financial custody can cross characters. A correction to either side also
-- invalidates an already prepared story; narrative entries remain owner-local.
local ignored={play=true,travel=true,quest=true,quest_attempt=true,objective=true,credit=true,kill=true,kill_observation=true,
    group=true,chat=true,pull=true,death=true,spell=true,memory=true,screenshot=true,diary=true,recap=true,chapter=true,goal=true,personal_record=true}
E.On('HISTORY_TOUCHED',function(c,receipt)
    if receipt and(receipt.reason=='walletUnchanged'or receipt.reason=='walletExtension'or receipt.reason=='notes')then return end
    local r=receipt and type(receipt.detail)=='table'and receipt.detail.record
    if not r or not ignored[r.kind]or receipt.detail.operation~='add'then epoch=epoch+1 end
end)
local receiptKinds={loot='Acquired',crafted='Crafted',gathered='Gathered'}
local function personal(c,r)return r.recipient==c.id or (r.kind=='crafted'or r.kind=='gathered')and r.subject==c.id end
local function equipped(row)return row and row.status=='equipped'and K.ID(row.itemID)end
local function variant(row)
    return E.SnapshotComparison.ItemVariant(row)
end
local function movementRow(rows,itemID,delta,work)
    local found
    for _,row in ipairs(rows or{})do work();if row.itemID==itemID then
        if found or not K.Number(row.before,0)or not K.Number(row.after,0)or row.after-row.before~=delta or row.delta~=delta then return end
        found=row
    end end
    return found
end
function I.Build(c,work)
    work=work or function()end
    if not K.Owned(c)then return end
    local out={items={},rows={},owner=c.id};local records={};local hasEconomy=false
    local function add(itemID,r,kind,extra)
        work();if not K.ID(itemID)or not K.Record(c,r)then return end
        local item=out.items[itemID]
        if not item then item={itemID=itemID,events={},name=r.itemName or r.title,seen={}};out.items[itemID]=item;out.rows[#out.rows+1]=item end
        local key=r.id..':'..kind..':'..tostring(extra and extra.slot or'')
        if item.seen[key]then return end;item.seen[key]=true
        local entry={record=r.id,character=c.id,kind=r.kind,storyKind=kind,ts=r.ts,sequence=S.Sequence(r),itemID=itemID,link=r.itemLink,quantity=r.quantity}
        for k,v in pairs(extra or{})do work();entry[k]=v end
        item.events[#item.events+1]=entry;return entry,item
    end
    for _,id in ipairs(c.order)do work();local r=c.records[id]
        if K.Record(c,r)then records[#records+1]=r;if r.kind=='cost_lot'or r.kind=='stock_move'or r.kind=='item_sale'or r.kind=='sale_return'then hasEconomy=true end end
    end
    W.Sort(records,S.Before,work)
    local previous
    for _,r in ipairs(records)do
        work()
        if receiptKinds[r.kind]and personal(c,r)then
            local entry,item=add(r.itemID,r,receiptKinds[r.kind],{inferred=E.Gathering and E.Gathering.Inferred(r)or false})
            if item then item.name=r.itemName or r.title or item.name end
        end
        local snapshot=E.SnapshotComparison.Snapshot(c,r)
        if snapshot then
            local slots,seen={},{};for _,row in ipairs(snapshot.equipment or{})do work();if type(row)=='table'and K.Number(row.slot,1,19)and row.slot%1==0 then
                if seen[row.slot]then slots[row.slot]=false else slots[row.slot]=row;seen[row.slot]=true end
            end end
            for slot=1,19 do
                work();local row=slots[slot];local prior=previous and previous.slots[slot]
                if equipped(row)then local _,item=add(row.itemID,r,'Worn at this milestone',{slot=slot,link=row.link,quantity=nil});if item then item.name=row.name or item.name end end
                if equipped(prior)and row and(row.status=='empty'or equipped(row))then
                    if prior.itemID~=row.itemID then
                        add(prior.itemID,r,'Replaced between snapshots',{slot=slot,link=prior.link,previous=previous.record.id,replacementItemID=row.itemID})
                    elseif variant(prior)and variant(row)and variant(prior)~=variant(row)then
                        add(prior.itemID,r,'Equipment variant changed',{slot=slot,link=row.link,previous=previous.record.id,previousLink=prior.link})
                    end
                end
            end
            previous={record=r,slots=slots}
        end
    end
    if hasEconomy then
        -- The shared reader owns its own FIFO/projection caches and yields in
        -- nested matching loops. It must never mutate the live cost ledger.
        assert(E.PersonalRecords and E.PersonalRecords.ReadEngine,'Bounded accounting reader is unavailable')
        local engine=E.PersonalRecords.ReadEngine(work,c);local owner=engine.db.characters[c.id]
        out.financialValid=engine.PreparationValid
        local replay=engine.Economy.Replay(owner,math.huge)
        for _,info in ipairs(replay.order or{})do work();local projected=info.record;local r=c.records[projected.id]
            if r and projected.kind=='item_sale'and K.Record(c,c.records[projected.evidence])then
                add(projected.itemID,r,'Sale recorded',{quantity=projected.quantity,link=projected.itemLink,inferred=info.inferred or projected.quality=='inferred',evidence=projected.merchantReceipt or projected.tradeReceipt or projected.evidence})
            elseif r and projected.kind=='sale_return'and K.Record(c,c.records[projected.evidence])then
                add(projected.itemID,r,'Sale returned',{quantity=projected.quantity,link=projected.itemLink,inferred=projected.quality=='inferred',evidence=projected.evidence})
            end
        end
        for _,info in pairs(replay.movements or{})do work();local projected=info.record;local r=c.records[projected.id]
            if r and projected.sentMail and K.Record(c,c.records[projected.sentMail])then
                add(projected.itemID,r,'Mailed out',{quantity=projected.quantity,inferred=true,evidence=projected.sentMail})
            elseif r and projected.reason=='transfer'and K.Record(c,c.records[projected.evidence])then
                add(projected.itemID,r,'Transfer recorded',{quantity=projected.quantity,inferred=projected.quality=='inferred',evidence=projected.evidence})
            end
        end
        for _,r in ipairs(records)do work()
            if r.kind=='bank'then
                local inv=owner.records[r.inventoryRecord]
                local previous=owner.records[r.previousRecord]
                if inv and inv.kind=='inventory'and not inv.baseline and inv.ts==r.ts and owner.records[inv.previousRecord]
                    and previous and previous.kind=='bank'and previous.bankType==r.bankType and S.Sequence(inv)<S.Sequence(r)then
                    for _,transfer in ipairs(r.transfers or{})do work()
                        if transfer.direction=='deposit'or transfer.direction=='withdrawal'then
                            local n=K.Number(transfer.quantity,1);local delta=n and(transfer.direction=='deposit'and n or-n)
                            local item=delta and movementRow(r.items,transfer.itemID,delta,work)
                            local carried=delta and movementRow(inv.items,transfer.itemID,-delta,work)
                            local balanced=item and carried and type(r.counts)=='table'and type(previous.counts)=='table'
                                and(r.counts[transfer.itemID]or 0)==item.after and(previous.counts[transfer.itemID]or 0)==item.before
                            local raw
                            for _,id in ipairs(balanced and inv.refs or{})do work();local candidate=owner.records[id]
                                if candidate and candidate.itemID==transfer.itemID and candidate.quantity==transfer.quantity and candidate.evidence==inv.id
                                    and candidate.source=='inventory observation'and S.Sequence(candidate)<S.Sequence(r)
                                    and candidate.kind==(transfer.direction=='deposit'and'stock_move'or'cost_lot')then if raw then raw=false;break else raw=candidate end end
                            end
                            if raw then
                                local conflict=engine.CostMatch.Resolve(owner,inv)or engine.TradeCosts.Resolve(owner,inv)or engine.MailCosts.Resolve(owner,inv)
                                    or engine.SentMailCosts.Claim(owner,inv)or engine.CraftCosts.Claim(owner,inv)or engine.AuctionCosts.Claim(owner,inv)
                                if not conflict then add(transfer.itemID,r,transfer.direction=='deposit'and'Placed in bank'or'Taken from bank',{quantity=transfer.quantity,inferred=true,evidence=raw.id})end
                            end
                        end
                    end
                end
            end
        end
    end
    for _,item in ipairs(out.rows)do
        work();W.Sort(item.events,function(a,b)if S.Before(a,b)then return true elseif S.Before(b,a)then return false end;return a.storyKind<b.storyKind end,work)
        item.seen=nil;item.last=item.events[#item.events]and item.events[#item.events].ts
    end
    W.Sort(out.rows,function(a,b)if a.last~=b.last then return(a.last or 0)>(b.last or 0)end;return a.itemID<b.itemID end,work)
    return out
end
function I.Request(c)
    if not K.Owned(c)then return end
    requested[c]=true
    local saved=caches[c]
    if saved and saved.epoch==epoch then return saved.model end
    if not K.Pending(c,'item-stories')then
        K.Queue(c,'item-stories',function(work)local version=epoch;return{version=version,model=I.Build(c,work)}end,function(result)
            if result.version~=epoch or result.model.financialValid and not result.model.financialValid()then I.Request(c);return end
            result.model.financialValid=nil
            caches[c]={epoch=epoch,revision=c.revision,model=result.model};E.Emit('ITEM_STORIES_READY',c)
        end,function()return epoch end)
    end
end
function I.Get(c,itemID)
    local model=I.Request(c);if not model then return end
    if itemID~=nil then return model.items[itemID]end;return model
end
function I.NoteKey(itemID)if K.ID(itemID)then return'itemstory:'..itemID end end
