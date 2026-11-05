local _,E=...
local V,B,A,W={},E.Book,E.API,E.RetentionWork;E.MobDropView=V
local epochs=setmetatable({},{__mode='k'})
local relevant={kill=true,kill_observation=true,drop=true,loot_window=true}
local function changed(c,r)if r and relevant[r.kind]then epochs[c]=(epochs[c]or 0)+1 end end
E.On('RECORD_ADDED',changed);E.On('RECORD_CHANGED',changed)
E.On('RECORDS_REMOVED',function(c)epochs[c]=(epochs[c]or 0)+1 end)
local function context()return table.concat({tostring(B.character),B.chapter or'',B.lootMode or'receipts',tostring(B.selected),tostring(B.mobDropNPC),tostring(B.lootBucket),tostring(B.dropBucket)},'|')end
function V.Request(c,options)
    if options.allHistory then options.from=nil end
    local key=table.concat({context(),tostring(options.npcID),tostring(options.from),tostring(options.through),options.query or'',options.mobQuery or''},'|')
    local j=V.job
    if not j or j.key~=key or j.owner~=c or j.records~=c.records or j.epoch~=(epochs[c]or 0)then
        j={key=key,owner=c,records=c.records,epoch=epochs[c]or 0,context=context()};V.job=j
        j.work=W.Start(function(work)
            local rows=E.MobDrops.List(c,options,work)
            return {mobs=rows,report=options.npcID and E.MobDrops.Report(c,options,work)or nil}
        end)
        if not j.work then j.error='Drop-rate preparation is unavailable.'end
    end
    return j.model,j.error
end
function V.Tick()
    local j=V.job;if not j then return end
    if B.chapter~='Loot' or context()~=j.context or B.Character()~=j.owner or j.owner.records~=j.records or (epochs[j.owner]or 0)~=j.epoch then V.job=nil;if B.chapter=='Loot'then B.Render()end;return end
    if B.frame and not B.frame:IsShown()then return end
    if not j.work or j.model or j.error then return end
    local status,result=W.Step(j.work,600)
    if status=='done'then j.model=result elseif status=='failed'then j.error='Could not prepare drop rates.';V.lastError=result else return end
    B.Navigation.KeepDrafts();B.Render()
end
local function pages(page,key,count,size)
    local last=math.max(1,math.ceil(count/size));B[key]=math.min(last,math.max(1,B[key]or 1))
    if last>1 then
        B.Text(page,'Page '..B[key]..' of '..last,12)
        if B[key]>1 then B.Action(page,'Previous',function()B[key]=B[key]-1;B.Render()end)end
        if B[key]<last then B.Action(page,'Next',function()B[key]=B[key]+1;B.Render()end)end
    end
    return (B[key]-1)*size+1,math.min(count,B[key]*size)
end
function V.Panel(page,c,npcID,name,range)
    B.Text(page,name or ('Creature '..npcID),26)
    local model,err=V.Request(c,{npcID=npcID,from=range.from,through=range.through,allHistory=range.preset=='all',query=B.mobDropItemQuery})
    if not model then B.Text(page,err or 'Counting recorded kills and matching observed drops...',14);return end
    local report=model.report;V.lastReport=report
    E.LootLayout.Stats(page,{{report.killCount,'Recorded kills'}})
    B.Text(page,'Observed drops / recorded kills · includes group loot',13)
    B.Text(page,'Kills without observed loot remain in the count. This is your recorded sample, not a guaranteed drop chance.',12)
    B.Text(page,'Find an item; Enter to apply',12)
    B.Input(page,B.mobDropItemQuery or'',function(value)B.mobDropItemQuery=value;B.mobDropItemPage=1;B.Render()end)
    local first,last=pages(page,'mobDropItemPage',#report.items,6)
    for i=first,last do local row=report.items[i]
        local rate=row.ratePercent and string.format('%.1f%%',row.ratePercent)or 'Unlinked'
        local caption=row.ratePercent and (row.killsWithItem..' of '..report.killCount..' recorded kills · '..(row.observedUnits or ('at least '..(row.knownObservedUnits or 0)))..' items observed')or 'No matching recorded kill'
        E.LootLayout.Bar(page,row.name or ('Item '..row.itemID),rate,caption,row.ratePercent or 0,100,nil,row.itemID)
    end
    if #report.unmatched>0 then B.Text(page,#report.unmatched..' observations could not be linked to a recorded kill and are excluded from rates.',12)end
    if #report.items==0 then B.Text(page,'No matching item drops linked to this mob’s recorded kills.',14)end
end
function V.Render(left,right)
    local c=B.Character();local range=E.LootLayout.Range(c,'mobDrop',{'kill','drop'})
    B.Navigation.Controls(function(page)
        E.LootLayout.Period(page,'mobDrop',range)
        B.Text(page,'Find a mob; Enter to apply',12)
        B.Input(page,B.mobDropQuery or'',function(value)B.mobDropQuery=value;B.mobDropPage=1;B.Render()end)
    end)
    local model,err=V.Request(c,{npcID=B.mobDropNPC,from=range.from,through=range.through,allHistory=range.preset=='all',query=B.mobDropItemQuery})
    if not model then B.Text(left,err or 'Preparing mob history...',14);return end
    local rows={};local query=string.lower(B.mobDropQuery or'')
    for _,row in ipairs(model.mobs)do if query==''or string.find(string.lower(row.name or tostring(row.npcID)),query,1,true)then rows[#rows+1]=row end end
    local first,last=pages(left,'mobDropPage',#rows,8);local name
    for i=first,last do local row=rows[i]
        E.LootLayout.Bar(left,row.name or ('Creature '..row.npcID),tostring(row.killCount),'Recorded kills',row.killCount,math.max(1,row.killCount),function()B.mobDropNPC=row.npcID;B.mobDropItemPage=1;B.Render()end)
    end
    for _,row in ipairs(model.mobs)do if row.npcID==B.mobDropNPC then name=row.name end end
    if #rows==0 then B.Text(left,'No recorded mobs in this period.',14)end
    if B.mobDropNPC then V.Panel(right,c,B.mobDropNPC,name,range)else B.Text(right,'Choose a mob',29);B.Text(right,'See how often each item appeared across your recorded kills, including observed group drops.',15)end
end
