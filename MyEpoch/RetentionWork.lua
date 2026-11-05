local _,E=...
local W={};E.RetentionWork=W
-- Cooperative read-only scans and cleanup validation. The deletion commit and
-- downstream notifications remain atomic and do not use checkpoints.
function W.Sort(rows,less,work)
    if not work then table.sort(rows,less);return end
    local n=#rows;local source,target=rows,{};local width=1
    while width<n do
        for first=1,n,width*2 do
            local middle=math.min(first+width,n+1);local last=math.min(first+width*2-1,n)
            local a,b=first,middle
            for index=first,last do
                work()
                if a<middle and (b>last or not less(source[b],source[a]))then target[index]=source[a];a=a+1
                else target[index]=source[b];b=b+1 end
            end
        end
        source,target=target,source;width=width*2
    end
    if source~=rows then for i=1,n do work();rows[i]=source[i]end end
end
function W.Copy(value,work)
    if not work then return E.Copy(value)end
    if type(value)~='table'then return E.Copy(value)end
    local out={};local active={[value]=true};local stack={{input=value,output=out}}
    while #stack>0 do
        work();local frame=stack[#stack];local key,item=next(frame.input,frame.key);frame.key=key
        if key==nil then active[frame.input]=nil;stack[#stack]=nil
        else
            assert(type(key)=='string'or type(key)=='number','Invalid data key')
            if type(item)=='table'then
                assert(not active[item],'Cyclic data');active[item]=true
                local copy={};frame.output[key]=copy;stack[#stack+1]={input=item,output=copy}
            else frame.output[key]=E.Copy(item)end
        end
    end
    return out
end
function W.Start(callback)
    -- Capability gate: never fall back to an unbounded UI scan on an unknown client.
    if type(coroutine)~='table'or type(coroutine.create)~='function'or type(coroutine.resume)~='function'
        or type(coroutine.yield)~='function'or type(coroutine.status)~='function'then return nil end
    local job={operations=0}
    job.thread=coroutine.create(function()
        local function checkpoint()
            if job.remaining<=0 then coroutine.yield()end
            job.remaining=job.remaining-1;job.operations=job.operations+1
        end
        return callback(checkpoint)
    end)
    return job
end
function W.Same(a,b,work)
    if not work then return E.Same(a,b)end
    local stack={{a=a,b=b}}
    while #stack>0 do
        work();local f=stack[#stack]
        if type(f.a)~=type(f.b)then return false end
        if type(f.a)~='table'then
            if f.a~=f.b then return false end
            stack[#stack]=nil
        elseif not f.second then
            local key,value=next(f.a,f.key);f.key=key
            if key==nil then f.second=true
            else stack[#stack+1]={a=value,b=f.b[key]}end
        else
            local key=next(f.b,f.key);f.key=key
            if key==nil then stack[#stack]=nil
            elseif f.a[key]==nil then return false end
        end
    end
    return true
end
function W.Step(job,budget)
    job.remaining=type(budget)=='number'and budget==budget and math.min(1000,math.max(0,math.floor(budget)))or 1000
    if job.remaining==0 then return end
    local ok,value=coroutine.resume(job.thread)
    if not ok then return 'failed',value end
    if coroutine.status(job.thread)=='dead'then return 'done',value end
end
