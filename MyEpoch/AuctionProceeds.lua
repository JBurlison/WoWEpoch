local _,E=...
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
    for _,key in ipairs({'gross','cut','deposit','received'})do
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
    for _,component in ipairs(plan.components)do
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
    for _,w in ipairs(plan.wallets)do
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
    for _,r in ipairs(Q.Kind(c,'mail_collection'))do
        local row=candidate(c,r)
        if row then
            out.rows[#out.rows+1]=row;out.byID[r.id]=row
            -- An original source can explain only one collection.
            for _,ids in ipairs({row.wallets,row.envelopes})do for _,id in ipairs(ids)do
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
    for _,r in ipairs(Q.Kind(c,'mail_collection'))do if r.character==c.id and not r.sendRequest then
        local batch=validated[r.id];local supported={}
        for _,row in ipairs(batch and batch.rows or{})do supported[row.envelope]=row end
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
            for _,component in ipairs(plan.components)do reserve(component.record)end
        elseif not plan then
            -- A partial/invalid collection cannot prove which positive-money
            -- seller envelopes were collected. Preserve its plausible sources.
            local scan=c.records[r.beforeScan]
            if scan and scan.kind=='mail_scan'and scan.character==c.id then
                for _,id in ipairs(scan.entries or{})do reserve(id)end
            end
        end
    end end
    return out
end
-- Wallet timestamps define the interval. Never apportion an indivisible batch
-- across a reporting boundary without evidence identifying each sale's cash.
function P.Report(c,from,through,query)
    local out=empty();out.boundary=0;out.excluded=0;out.collections=0;query=(query or''):lower()
    for _,batch in ipairs(index(c).rows)do
        if batch.through>=from and batch.from<through then
            if batch.from<from or batch.through>=through then out.boundary=out.boundary+1
            elseif batch.reason then out.excluded=out.excluded+1
            else
                out.unresolved=out.unresolved+batch.unresolved;local included=false
                for _,row in ipairs(batch.rows)do
                    local words=((row.itemName or'')..' '..(row.buyer or'')):lower()
                    if words:find(query,1,true)then
                        local copy=E.Copy(row);copy.observedAt=batch.through;out.rows[#out.rows+1]=copy;add(out,row);included=true
                    end
                end
                if included then out.collections=out.collections+1 end
            end
        end
    end
    table.sort(out.rows,function(a,b)if a.observedAt~=b.observedAt then return a.observedAt>b.observedAt end;return a.envelope<b.envelope end)
    return finish(out)
end
