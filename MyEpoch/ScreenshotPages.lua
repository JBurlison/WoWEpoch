local _,E=...
local P={};E.ScreenshotPages=P
local S=E.Store
-- Two ranked AVL trees keep the six visible choices seekable even when most
-- screenshots are already linked. Keys are snapshots: corrections may mutate
-- the same record in place before RECORD_CHANGED is delivered.
local function count(n)return n and n.size or 0 end
local function height(n)return n and n.height or 0 end
local function refresh(n)
    n.height=1+math.max(height(n.left),height(n.right));n.size=1+count(n.left)+count(n.right)
    return n
end
local function rotate(n,side,opposite)
    local top=n[opposite];n[opposite]=top[side];top[side]=refresh(n)
    return refresh(top)
end
local function balance(n)
    local d=height(n.left)-height(n.right)
    if d>1 then
        if height(n.left.right)>height(n.left.left)then n.left=rotate(n.left,"left","right")end
        return rotate(n,"right","left")
    elseif d< -1 then
        if height(n.right.left)>height(n.right.right)then n.right=rotate(n.right,"right","left")end
        return rotate(n,"left","right")
    end
    return refresh(n)
end
local function before(a,b)
    if a.position then return a.position<b.position or a.position==b.position and a.id<b.id end
    if a.time~=b.time then return a.time==nil or b.time~=nil and a.time>b.time end
    if a.sequence~=b.sequence then return a.sequence>b.sequence end
    if a.created~=b.created then return a.created>b.created end
    return a.id>b.id
end
local function edit(node,key,insert)
    if not node then
        if insert then return {key=key,height=1,size=1}end
        return
    end
    if node.key==key then
        if insert then return node end
        if not node.left then return node.right end
        if not node.right then return node.left end
        local nextNode=node.right
        while nextNode.left do nextNode=nextNode.left end
        node.key=nextNode.key;node.right=edit(node.right,node.key,false)
    else
        local side=before(key,node.key) and "left" or "right"
        node[side]=edit(node[side],key,insert)
    end
    return balance(node)
end
local function at(node,i)
    while node do
        local left=count(node.left)
        if i==left+1 then return node.key.record end
        if i<=left then node=node.left else i=i-left-1;node=node.right end
    end
end
local current
local function update(s,id)
    local old=s.keys[id];local r=s.owner.records[id]
    local slot=s.positions[id]
    local tree=slot and "linked" or "available"
    local valid=r and r.id==id and r.character==s.owner.id and r.kind=="screenshot"
    local time,sequence,created
    if valid and not slot then time=S.Timestamp(r);sequence=S.Sequence(r);created=r.sequence or 0 end
    if old then
        if valid and old.record==r and old.position==slot and old.time==time and old.sequence==sequence and old.created==created then return end
        local which=old.position and "linked" or "available"
        s[which]=edit(s[which],old,false);s.keys[id]=nil
    end
    if valid and (slot or s.started)then
        local key={record=r,id=id,position=slot,time=time,sequence=sequence,created=created}
        s[tree]=edit(s[tree],key,true);s.keys[id]=key
    end
end
local function links(s)
    local refs=s.target.refs or {}
    local positions={}
    for i=1,#refs do
        coroutine.yield()
        local id=refs[i]
        if type(id)=="string" and not positions[id]then positions[id]=i end
    end
    -- Swap membership one key at a time so a second correction can restart
    -- from precisely the memberships already installed.
    for id in pairs(s.positions)do
        coroutine.yield()
        if not positions[id]then s.positions[id]=nil;update(s,id)end
    end
    for id,i in pairs(positions)do
        coroutine.yield()
        s.positions[id]=i;update(s,id)
    end
end
local function directory(s,ids)
    if ids then
        for i=1,#ids do coroutine.yield();update(s,ids[i])end
        return
    end
    -- The authoritative dictionary also includes old rows absent from order.
    local records=s.owner.records
    for id in pairs(records)do
        coroutine.yield()
        update(s,id)
    end
end
local function startScan(s)
    local ids=E.Query.WarmScreenshotIDs(s.owner)
    s.fromQuery=ids~=nil
    s.scan=coroutine.create(function()directory(s,ids)end)
end
local function work(s,budget)
    if s.scan and not s.fromQuery and E.Query.WarmScreenshotIDs(s.owner) then startScan(s)end
    local pending=s.linkJob~=nil or s.removals~=nil or (s.open and s.scan~=nil)
    for i=1,budget do
        if s.linkJob then
            local ok,err=coroutine.resume(s.linkJob);if not ok then error(err)end
            if coroutine.status(s.linkJob)=="dead" then s.linkJob=nil end
        elseif s.removals then
            local first=s.removals;local id=next(first.ids,first.last)
            if id then first.last=id;update(s,id)else s.removals=first.next end
        elseif s.open and s.scan then
            local ok,err=coroutine.resume(s.scan);if not ok then error(err)end
            if coroutine.status(s.scan)=="dead"then s.scan=nil end
        else return pending end
    end
    return pending and not(s.linkJob or s.removals or s.open and s.scan)
end
local frame
local function schedule(s)
    if s.repaint or s.linkJob or s.removals or s.open and s.scan then
        if not frame then frame=CreateFrame("Frame");frame:SetScript("OnUpdate",P.Tick)end
        frame:Show()
    elseif frame then frame:Hide()end
end
function P.View(c,r,open)
    local s=current
    if not s or s.owner~=c or s.target~=r or s.records~=c.records then
        s={owner=c,target=r,records=c.records,keys={},positions={}};current=s
        s.linkJob=coroutine.create(function()links(s)end)
    end
    s.open=open;s.repaint=nil
    if open and not s.started then s.started=true;startScan(s)end
    work(s,40);schedule(s)
    return s
end
function P.Page(s,which,page)
    if s.linkJob or s.removals or which=="available" and s.scan then return end
    local size=count(s[which]);local pages=math.max(1,math.ceil(size/6));page=math.min(page,pages)
    local out={};for i=(page-1)*6+1,math.min(page*6,size)do out[#out+1]=at(s[which],i)end
    return out,size,page,pages
end
function P.Shows(s,which,page,slot,r)
    return s==current and not s.linkJob and not s.removals and (which=="linked" or s.open and not s.scan)
        and s.owner.records[r.id]==r and r.kind=="screenshot" and r.character==s.owner.id
        and at(s[which],(page-1)*6+slot)==r
end
function P.Tick()
    local s=current;local B=E.Book
    if not s or not B.frame or not B.frame:IsShown() or B.Character()~=s.owner or B.selected~=s.target.id or not E.Memories.ScreenshotTarget(s.owner,s.target)then
        current=nil;if frame then frame:Hide()end;return
    end
    local completed=work(s,120)
    if completed or s.repaint and not (s.linkJob or s.removals or s.open and s.scan)then
        s.repaint=nil;B.Navigation.KeepDrafts();B.Render()
    end
    schedule(s)
end
local function changed(c,r)
    local s=current;if not s or s.owner~=c then return end
    if r~=s.target and not s.keys[r.id] and r.kind~="screenshot" then return end
    local B=E.Book
    if not B.frame or not B.frame:IsShown() or B.Character()~=c or B.selected~=s.target.id then current=nil;if frame then frame:Hide()end;return end
    if r==s.target then
        s.linkJob=coroutine.create(function()links(s)end);schedule(s)
    else update(s,r.id);s.repaint=true;schedule(s)end
end
E.On("RECORD_CHANGED",changed)
E.On("RECORD_ADDED",function(c,r)
    local s=current
    if s and s.owner==c and s.scan and not s.fromQuery then
        -- Lua next does not guarantee complete traversal across hash resizes.
        startScan(s)
    end
    changed(c,r)
end)
E.On("RECORDS_REMOVED",function(c,ids)
    local s=current;if not s or s.owner~=c then return end
    if c.records[s.target.id]~=s.target then current=nil;if frame then frame:Hide()end;return end
    s.records=c.records;s.removals={ids=ids,next=s.removals}
    if s.scan then startScan(s)end
    schedule(s)
end)
