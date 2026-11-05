local _,E=...
local P={};E.SavedPages=P
local S,M,W=E.Store,E.Memories,E.RetentionWork
local active,frame,scheduled

-- S.List delegates to Lua 5.1 table.sort. Its equal-key partitioning changes
-- the visible IDs. Mirror it with checkpoints rather than imposing a new order.
-- The partition routine is adapted from Lua 5.1 ltablib.c. Its license follows.
--[[
Lua 5.1
Copyright (C) 1994-2006 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]
local function nativeSort(a,less,work)
    local function sort(lo,hi)
        while lo<hi do
            work()
            if less(a[hi],a[lo])then a[lo],a[hi]=a[hi],a[lo]end
            if hi-lo==1 then return end
            local mid=math.floor((lo+hi)/2)
            if less(a[mid],a[lo])then a[mid],a[lo]=a[lo],a[mid]
            elseif less(a[hi],a[mid])then a[mid],a[hi]=a[hi],a[mid]end
            if hi-lo==2 then return end
            local pivot=a[mid];a[mid],a[hi-1]=a[hi-1],a[mid]
            local i,j=lo,hi-1
            while true do
                repeat i=i+1;work() until not less(a[i],pivot)
                repeat j=j-1;work() until not less(pivot,a[j])
                if j<i then break end
                a[i],a[j]=a[j],a[i]
            end
            a[i],a[hi-1]=a[hi-1],a[i]
            if i-lo<hi-i then sort(lo,i-1);lo=i+1 else sort(i+1,hi);hi=i-1 end
        end
    end
    sort(1,#a)
end
local function wake()
    scheduled=true
    if not frame then frame=CreateFrame("Frame");frame:SetScript("OnUpdate",function()P.Tick()end)end
    frame:Show()
end
local function identity(s)return E.db.characters[s.owner.id]==s.owner and s.order==s.owner.order and s.records==s.owner.records end
local function remember(s,i)
    local id=s.order[i];if not id then return end
    local prior=s.positions[id]
    if not prior then s.positions[id]=i
    elseif type(prior)=="number" then if prior~=i then s.positions[id]={prior,i}end
    elseif prior[#prior]~=i then prior[#prior+1]=i end
    local r=s.records[id]
    if M.SavedMember(s.owner,r) and not s.known[i] then
        s.known[i]=true
        if s.later and i>s.seedLast then s.later[#s.later+1]=i;return end
        s.slots[#s.slots+1]=i
        if #s.slots>1 and s.slots[#s.slots-1]>i then s.unordered=true end
    end
end
local function source(c)
    local s={owner=c,records=c.records,order=c.order,positions={},known={},slots={},generation=0}
    local last=#c.order
    s.seedLast=last;s.later={}
    s.seed=W.Start(function(work)
        for i=1,last do work();remember(s,i)end
        local i=1
        while i<=#s.later do work();s.slots[#s.slots+1]=s.later[i];i=i+1 end
        s.later=nil;s.seedLast=nil
    end)
    return s
end
local function visible(s)
    local B=E.Book
    return B.frame and B.frame:IsShown() and B.chapter=="Memories" and B.memoryMode=="saved" and B.Character()==s.owner
end
local function invalidate(s,keepCut)
    if not keepCut then s.published=nil;s.lastRows=nil end
    s.rescan=nil
    s.generation=s.generation+1;s.clearVisible=s.clearVisible or s.result~=nil;s.result=nil;s.excerpts=nil;s.preview=nil;s.suffix={};s.flush=nil;s.keys=nil
end
local function changed(c,receipt)
    local s=active
    if not s or s.owner~=c or not identity(s) then return end
    local d=receipt and receipt.reason=="record" and receipt.detail
    if type(d)~="table" or type(d.record)~="table" then return end
    local r=d.record
    local i=s.positions[r.id]
    if d.operation=="add" and s.order[#s.order]==r.id then
        i=#s.order;remember(s,i)
    end
    if not i then return end -- The initial ordered pass still owns this slot.
    -- Common live additions are strictly later than every result. With no
    -- ambiguous native ties this is exactly the sorted result after insertion.
    if d.operation=="add" and s.result and not s.flush and #s.suffix==0 and not s.ties and type(i)=="number" and M.SavedMember(c,r) and s.query=="" then
        local last=s.result[#s.result]
        if not last or S.Before(last,r) then
            s.result[#s.result+1]=r;s.bindings[r]=s.order[i];s.keys[i]={r=r,time=S.Timestamp(r),seq=S.Sequence(r)};s.cache[i]=true
            s.preview=nil;s.excerpts=nil
            if visible(s)then wake()end
            return
        end
    end
    if d.operation=="add" and (s.build or s.result) and type(i)=="number" and M.SavedMember(c,r) then
        s.suffix[#s.suffix+1]=i
        if not s.rescan then s.excerpts=nil;s.preview=nil end
        if visible(s)then wake()end
        return
    end
    local old=type(i)=="number" and s.keys and s.keys[i]
    if old and not s.published and s.result and s.query=="" and old.r==r and s.records[s.order[i]]==r and M.SavedMember(c,r) and old.time==S.Timestamp(r) and old.seq==S.Sequence(r)then
        s.excerpts=nil;s.preview=nil
        if visible(s)then wake()end
        return
    end
    local changedAny=false
    local function dirty(slot)
        local member=M.SavedMember(c,s.records[s.order[slot]])
        if member or s.known[slot] then
            if member and not s.known[slot]then s.known[slot]=true;s.slots[#s.slots+1]=slot;s.unordered=true end
            if s.cache then s.cache[slot]=nil end;changedAny=true
        end
    end
    if type(i)=="table" then for _,slot in ipairs(i)do dirty(slot)end else dirty(i)end
    if changedAny then invalidate(s);if visible(s) then wake()end end
end
E.On("HISTORY_TOUCHED",changed)
E.On("RECORDS_REMOVED",function(c)
    if active and active.owner==c then active=nil;if frame then frame:Hide()end
        if E.Book.frame and E.Book.frame:IsShown() and E.Book.chapter=="Memories" and E.Book.Character()==c then wake()end
    end
end)
local function build(s)
    local gen,query,cache=s.generation,s.query,s.cache
    s.suffix={}
    return W.Start(function(work)
        local slots,last=s.slots,#s.slots
        if s.unordered then
            local ordered={}
            for i=1,last do work();ordered[i]=slots[i]end
            W.Sort(ordered,function(a,b)return a<b end,work)
            if #slots==last then s.slots=ordered;s.unordered=false end
            slots=ordered
        end
        local sortable,keys,bindings={},{},{}
        local strictlyAscending=true
        local function less(a,b)
            if a.time~=b.time then return a.time~=nil and (b.time==nil or a.time<b.time)end
            return a.seq<b.seq
        end
        for i=1,last do
            work();local slot=slots[i]
            local r=s.records[s.order[slot]]
            if M.SavedMember(s.owner,r)then
                local matches=cache[slot]
                if matches==nil then
                    matches=E.Search.SavedMatch(r,query,work)
                    if gen==s.generation then cache[slot]=matches end
                end
                if matches then
                    local item={r=r,time=S.Timestamp(r),seq=S.Sequence(r)}
                    if strictlyAscending and #sortable>0 and not less(sortable[#sortable],item)then strictlyAscending=false end
                    sortable[#sortable+1]=item;keys[slot]=item;bindings[r]=s.order[slot]
                end
            end
        end
        if not strictlyAscending then nativeSort(sortable,less,work)end
        local out,ties={},false
        for i,v in ipairs(sortable)do
            work();out[i]=v.r
            local prev=sortable[i-1]
            if prev and v.time==prev.time and v.seq==prev.seq then ties=true end
        end
        if gen==s.generation then s.result=out;s.keys=keys;s.bindings=bindings;s.ties=ties end
    end)
end
local function appendChanges(s)
    local rows,pending=s.result,s.suffix
    return W.Start(function(work)
        local n=1
        while n<=#pending do
            work();local slot=pending[n];local r=s.records[s.order[slot]];n=n+1
            if M.SavedMember(s.owner,r) and E.Search.SavedMatch(r,s.query,work)then
                if s.ties then s.rescan=true;s.suffix={};return end
                local lo,hi=1,#rows+1
                while lo<hi do
                    work();local mid=math.floor((lo+hi)/2)
                    if S.Before(rows[mid],r) then lo=mid+1 else hi=mid end
                end
                if rows[lo] and not S.Before(r,rows[lo])then s.rescan=true;s.suffix={};return end
                for i=#rows,lo,-1 do work();rows[i+1]=rows[i]end
                rows[lo]=r;s.bindings[r]=s.order[slot];s.keys[slot]={r=r,time=S.Timestamp(r),seq=S.Sequence(r)};s.cache[slot]=true
            end
        end
        s.suffix={}
    end)
end
local function excerpts(s,page)
    local rows=s.result;s.excerpts=nil;s.previewPage=page
    return W.Start(function(work)
        local text={}
        for i=#rows-(page-1)*8,math.max(1,#rows-page*8+1),-1 do
            work();local r=rows[i];text[r]=E.Search.SavedExcerpt(r.caption or r.text or "",s.query,160,work)
        end
        if s.result==rows then s.excerpts=text end
    end)
end
local function step(job,budget)
    local state,err=W.Step(job,budget)
    if state=="failed"then error(err,0)end
    return state=="done"
end
local function advance(s,page,budget)
    if s.seed then if not step(s.seed,budget)then return end;s.seed=nil end
    if s.fold then if not step(s.fold,budget)then return end;s.fold=nil end
    if not s.result then
        s.build=s.build or build(s)
        if not step(s.build,budget)then return end;s.build=nil
        if not s.result then return end
    end
    if #s.suffix>0 and not s.rescan then
        s.flush=s.flush or appendChanges(s)
        if not step(s.flush,budget)then return end;s.flush=nil
        if not s.result then return end
    end
    page=math.max(1,math.min(page,math.max(1,math.ceil(#s.result/8))))
    if s.previewPage~=page or not s.preview and not s.excerpts then s.preview=excerpts(s,page)end
    if s.preview then if not step(s.preview,budget)then return end;s.preview=nil end
    return s.result,s.excerpts,page
end
local function validPage(s,rows,page,bindings)
    local function valid(r)
        if not r then return true end
        local key=bindings[r]
        if s.records[key]==r and M.SavedMember(s.owner,r) then return true end
        local i=s.positions[key]
        if type(i)=="number"then s.cache[i]=nil
        elseif type(i)=="table"then for _,slot in ipairs(i)do s.cache[slot]=nil end end
        return false
    end
    if not valid(rows[#rows])then return false end
    for i=#rows-(page-1)*8,math.max(1,#rows-page*8+1),-1 do if not valid(rows[i])then return false end end
    return true
end
function P.Page(c,query,page)
    if not active or active.owner~=c or not identity(active)then active=source(c)end
    local s=active;query=query or ""
    if s.rawQuery~=query then
        s.rawQuery=query;s.cache={};s.build=nil;s.query=nil;invalidate(s)
        s.fold=W.Start(function(work)s.query=E.Search.FoldSavedQuery(query,work)end)
    end
    s.clearVisible=nil;s.page=page or 1
    local rows,excerpts,number=advance(s,s.page,100)
    if rows and not validPage(s,rows,number,s.bindings)then invalidate(s);rows=nil end
    if rows then
        s.lastRows=rows;s.lastPage=number
        if s.rescan then
            -- Native table.sort may permute all equal keys when even one row is
            -- appended. Show this completed cut while preparing the newer set.
            s.published={rows=rows,excerpts=excerpts,page=number,bindings=s.bindings}
            invalidate(s,true);wake()
            return rows,excerpts,number,true
        end
        s.published=nil
        if frame then scheduled=nil;frame:Hide()end
        return rows,excerpts,number
    end
    wake()
    local cut=s.published
    if cut and cut.page==s.page and not validPage(s,cut.rows,cut.page,cut.bindings)then invalidate(s);cut=nil end
    if cut and cut.page==s.page then s.lastRows=cut.rows;s.lastPage=cut.page;return cut.rows,cut.excerpts,cut.page,true end
end
function P.SamePage(c,query,page)
    local s=active
    return s and s.owner==c and identity(s) and visible(s) and s.lastRows and s.rawQuery==(query or "")
        and s.lastPage==page and (E.Book.memoryQuery or "")==s.rawQuery and E.Book.memoryPage==page
end
function P.Shows(c,r,index,query,page)
    local s=active
    return P.SamePage(c,query,page) and s.lastRows[index]==r
        and M.SavedMember(c,r) and c.records[r.id]==r
end
function P.Tick()
    if not scheduled then return end
    local s=active
    if not s then
        scheduled=nil
        if frame then frame:Hide()end
        local B=E.Book;if B.frame and B.frame:IsShown()and B.chapter=="Memories"and B.memoryMode=="saved"then B.Navigation.KeepDrafts();B.Render()end
        return
    end
    if not visible(s)then scheduled=nil;if frame then frame:Hide()end;return end
    if not identity(s)then active=nil;return end
    if s.clearVisible then
        s.clearVisible=nil;E.Book.Navigation.KeepDrafts();E.Book.Render();return
    end
    if advance(s,s.page or 1,900)then
        scheduled=nil;if frame then frame:Hide()end;E.Book.Navigation.KeepDrafts();E.Book.Render()
    end
end
