local _,E=...
local V,B,C,A,S={},E.Book,E.Company,E.API,E.Store; E.CompanyView=V
local function name(person)
    return (person.name or "Unnamed companion")..(person.realm and " - "..person.realm or " (realm unknown)")
end
function V.Open(id)
    local _,people=C.List(B.Character())
    if not people[id] then B.companyMessage="This companion's group history is no longer available."; B.Render(); return false end
    B.chapter="Company"; B.companyMode="companions"; B.companionID=id; B.selected=nil
    B.companySection="sessions"; B.companyDetailPage=1; B.companyMessage=nil; B.socialMessage=nil; B.Render(); B.right.scroll:SetVerticalScroll(0); E.BookTheme.Scroll(B.right)
    return true
end
function V.Leadership(page,group)
    B.Text(page,'Observed leadership',20)
    local rows=group.leadership or{}
    if #rows==0 then B.Text(page,'Leadership was not recorded for this session.',14);return end
    B.Text(page,'These are observation times, not exact promotion times. A recording gap ends an observation interval.',13)
    local pages=math.max(1,math.ceil(#rows/6));B.groupLeaderPage=math.max(1,math.min(B.groupLeaderPage or 1,pages))
    B.Text(page,'Leadership page '..B.groupLeaderPage..' of '..pages,12)
    for i=(B.groupLeaderPage-1)*6+1,math.min(#rows,B.groupLeaderPage*6)do local row=rows[i]
        if row.leaderID then
            local title=(row.changeObserved and'Leader change observed: 'or'Leader observed: ')..name(row)
            if row.leaderID==B.Character().id then B.Text(page,title..' (you)',16)
            else local id=row.leaderID;B.Action(page,title,function()V.Open(id)end)end
        else B.Text(page,'Leader unavailable',16);B.Text(page,row.reason or'Leadership could not be established.',13)
            if #(row.candidates or{})>0 then
                local people={};for _,person in ipairs(row.candidates)do people[#people+1]=name(person)end
                B.Text(page,'Reported candidates: '..table.concat(people,'; '),13)
            end
        end
        B.Text(page,'First / last observed: '..A.Date(row.from)..' / '..A.Date(row.through),12)
        if row.closedReason then B.Text(page,row.closedReason,12)end
    end
    if B.groupLeaderPage>1 then B.Action(page,'Earlier leadership observations',function()B.groupLeaderPage=B.groupLeaderPage-1;B.Render()end)end
    if B.groupLeaderPage<pages then B.Action(page,'More leadership observations',function()B.groupLeaderPage=B.groupLeaderPage+1;B.Render()end)end
end
function V.Members(page,group)
    local c=B.Character(); local ids={}
    B.Text(page,group.ended and "Session ended: "..A.Date(group.ended) or "Last observed: "..A.Date(group.observedThrough or group.ts),13)
    if group.continuity then B.Text(page,"The connection to the previous recording session could not be verified.",14) end
    local gaps=group.gaps or {}; local gapPages=math.max(1,math.ceil(#gaps/6)); B.groupGapPage=math.max(1,math.min(B.groupGapPage or 1,gapPages))
    if #gaps>0 then B.Text(page,"Unobserved intervals",18) end
    for i=(B.groupGapPage-1)*6+1,math.min(#gaps,B.groupGapPage*6) do local gap=gaps[i]
        B.Text(page,A.Date(gap.from).." - "..(gap.through and A.Date(gap.through) or "observation not resumed").." | "..(gap.reason or "recording interrupted"),13)
    end
    if B.groupGapPage>1 then B.Action(page,"Earlier observation gaps",function()B.groupGapPage=B.groupGapPage-1; B.Render()end) end
    if B.groupGapPage<gapPages then B.Action(page,"More observation gaps",function()B.groupGapPage=B.groupGapPage+1; B.Render()end) end
    V.Leadership(page,group)
    for _,id in ipairs(E.SortedKeys(group.memberships or {})) do if id~=c.id then ids[#ids+1]=id end end
    B.Text(page,"Recorded companions",20)
    local pages=math.max(1,math.ceil(#ids/12)); B.companyCoverageMemberPage=math.max(1,math.min(B.companyCoverageMemberPage or 1,pages))
    for i=(B.companyCoverageMemberPage-1)*12+1,math.min(#ids,B.companyCoverageMemberPage*12) do local id=ids[i]
        local member=group.memberships[id]; B.Action(page,name(member),function()V.Open(id)end)
        local intervals=member.intervals or {}; local first,last=intervals[1],intervals[#intervals]
        if first then B.Text(page,"First / last observed: "..A.Date(first.from).." / "..A.Date(last.through or last.from).." | "..#intervals.." membership intervals",12) end
    end
    if B.companyCoverageMemberPage>1 then B.Action(page,"Previous companions",function()B.companyCoverageMemberPage=B.companyCoverageMemberPage-1; B.Render()end) end
    if B.companyCoverageMemberPage<pages then B.Action(page,"More companions",function()B.companyCoverageMemberPage=B.companyCoverageMemberPage+1; B.Render()end) end
    if #ids==0 then B.Text(page,"No other player identities were recorded for this session.",14) end
end
