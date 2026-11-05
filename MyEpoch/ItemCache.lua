local _,E=...
local K={};E.ItemCache=K
local kinds={loot=true,crafted=true,gathered=true,drop=true}
local state
local function valid(s)
    return state==s and E.current==s.owner and E.db and E.db.characters[s.owner.id]==s.owner
end
local function new(c)
    state={owner=c,records=c.records,order=c.order,scan=c.order,cursor=1,last=#c.order,
        heads={},nodes={},version=0,itemVersion={},complete={},waiting={},jobs={},first=1,lastJob=0}
    return state
end
local function unlink(s,node)
    if node.prev then node.prev.next=node.next else s.heads[node.key]=node.next end
    if node.next then node.next.prev=node.prev end
    s.nodes[node.row.id]=nil
    if not s.heads[node.key] then s.complete[node.key]=nil;s.itemVersion[node.key]=nil end
    -- A paused job may still hold this node. Its forward link leads to the
    -- original remaining suffix; it must never walk into later arrivals.
    node.prev=nil
end
-- Changed is a post-write notification. Keep the last observed metadata
-- inputs on indexed receipts so a delayed cache event cannot reverse a later
-- correction. Only a conflicting field is fenced; the other facts still fill.
local inputs={"title","itemLink","rarity","texture","vendorUnitValue","vendorValuation"}
local function witness(node,r,version)
    local touched=false
    for _,key in ipairs(inputs)do
        if version and node[key]~=r[key] then
            local field=key=="itemLink" and "title" or key=="vendorValuation" and "vendorUnitValue" or key
            node.edits=node.edits or {};node.edits[field]=version;touched=true
        end
        node[key]=r[key]
    end
    return touched
end
local function track(s,r,live)
    local old=s.nodes[r.id]
    local key=kinds[r.kind] and type(r.itemID)=="number" and r.itemID>0 and r.itemID or nil
    -- Exact receipt names and drop titles survive enrichment. Once all three
    -- fill-only fields are present, such a record cannot benefit from a retry.
    if key and r.rarity~=nil and r.texture~=nil and r.vendorUnitValue~=nil and
        (r.kind=="drop" or type(r.itemLink)=="string" and r.itemLink:find("|h[",1,true))then key=nil end
    if old and old.row==r and old.key==key then
        if live and witness(old,r,s.version+1)then
            s.version=s.version+1;s.itemVersion[key]=s.version;s.complete[key]=nil
        end
        return
    end
    if old then unlink(s,old)end
    if key then
        if live then s.version=s.version+1;s.itemVersion[key]=s.version;s.complete[key]=nil end
        local head=s.heads[key]
        local node={row=r,key=key,born=live and s.version or 0,next=head}
        witness(node,r)
        if head then head.prev=node end
        s.heads[key]=node;s.nodes[r.id]=node
    end
end
local function changed(c,r)
    local s=state
    if not s or s.owner~=c or not valid(s) or s.records~=c.records or c.records[r.id]~=r then return end
    if kinds[r.kind] or s.nodes[r.id]then track(s,r,true)end
end
E.On("RECORD_ADDED",changed);E.On("RECORD_CHANGED",changed)
E.On("HISTORY_TOUCHED",function(c,receipt)
    local s=state
    if s and s.owner==c and receipt and receipt.reason=="retention" and s.records~=c.records then
        -- Store retains the actual survivor objects and their IDs. An in-flight
        -- legacy scan can finish its original order; new records arrive by hook.
        s.records=c.records;s.order=c.order
        s.removals={ids=receipt.detail.ids,next=s.removals}
    end
end)
local function scan(s,budget)
    if not s.scan then return end
    local stop=math.min(s.last,s.cursor+budget-1)
    for i=s.cursor,stop do
        local r=s.records[s.scan[i]]
        if r then track(s,r,false)end
    end
    s.cursor=stop+1
    if s.cursor>s.last then s.scan=nil end
end
local function pop(s,j)
    -- A complete no-change sweep proves another identical observation cannot
    -- fill anything. Changed, moved or appended rows invalidate only their item.
    if j.itemVersion==s.itemVersion[j.id] and not j.failed and s.heads[j.id] then s.complete[j.id]=j.meta end
    if s.waiting[j.id]==j then s.waiting[j.id]=nil end
    s.jobs[s.first]=nil;s.first=s.first+1
    if s.first>s.lastJob then s.first=1;s.lastJob=0 end
end
local function step(s,limit)
    for _=1,limit do
        if not valid(s) or s.records~=s.owner.records or s.order~=s.owner.order then return end
        local j=s.jobs[s.first];if not j then return end
        if not j.started then
            if s.heads[j.id] and E.Query.EnsureWarm(s.owner)=="preparing" then return end
            j.started=true;j.cursor=s.heads[j.id]
        end
        local node=j.cursor
        if node then
            j.cursor=node.next
            local r=node.row
            if node.born<=j.version and s.nodes[r.id]==node and s.records[r.id]==r and r.itemID==j.id and kinds[r.kind]then
                local meta=j.meta
                for field,version in pairs(node.edits or {})do
                    if version>j.version and meta[field]~=nil then
                        if meta==j.meta then meta=E.Copy(meta)end
                        meta[field]=nil
                    end
                end
                if E.Items.ApplyMetadata(r,meta)then
                    -- Record our own assignments before notifying ordinary
                    -- listeners; nested user corrections still get a new stamp.
                    witness(node,r)
                    E.Store.Changed(s.owner,r)
                end
            end
        end
        if valid(s) and not j.cursor then pop(s,j)end
    end
end
local function process(s,budget)
    if s.busy then return end
    s.busy=true;local ok,why=pcall(step,s,budget);s.busy=nil
    if not ok then
        local j=s.jobs[s.first];if j then j.failed=true end
        error(why,0)
    end
end
local function same(a,b)
    return a.title==b.title and a.rarity==b.rarity and a.texture==b.texture and a.vendorUnitValue==b.vendorUnitValue
end
function K.Received(id,success)
    local A,c=E.API,E.current
    if A.Secret(id) or A.Secret(success) or not success or type(id)~="number" or id<1 or id>2147483647 or id%1~=0
        or not c or not E.db or E.db.characters[c.id]~=c then return end
    local s=state
    if not s or not valid(s) or s.records~=c.records or s.order~=c.order then s=new(c)end
    scan(s,32)
    if not s.scan and not s.heads[id] then return end
    local version,itemVersion=s.version,s.itemVersion[id]
    local meta=A.Item(id)
    if not meta or not valid(s) or s.records~=c.records or s.order~=c.order then return end
    local prior=s.waiting[id]
    if not prior and s.complete[id] and same(s.complete[id],meta)then return end
    if prior and not prior.failed and prior.itemVersion==itemVersion and same(prior.meta,meta)then return end
    local job={id=id,meta=meta,version=version,itemVersion=itemVersion}
    s.lastJob=s.lastJob+1;s.jobs[s.lastJob]=job;s.waiting[id]=job
    -- Deliver changes during the frame service. A burst of cache callbacks
    -- shares the same per-frame fanout limit as a single popular item.
end
function K.Tick()
    local s=state;if not s then return end
    if not valid(s) or s.records~=s.owner.records or s.order~=s.owner.order then state=nil;return end
    if s.removals then
        for _=1,64 do
            local batch=s.removals;if not batch then break end
            local id=next(batch.ids,batch.id);batch.id=id
            if not id then s.removals=batch.next
            else
                local n=s.nodes[id];if n and s.records[id]~=n.row then unlink(s,n)end
            end
        end
    end
    scan(s,256)
    if s.scan or s.first>s.lastJob then return end
    process(s,8)
end
