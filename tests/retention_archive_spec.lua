local R,S,A,F,B=E.Archive,E.Store,E.API,E.Economy,E.Book
local function eq(a,b,label)assert(a==b,(label or "Archive mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local now=A.ParseDay("2026-10-31")+74000; TEST_NOW(now)
local c=S.Character("archive-reviewer",{name="Archivist"}); local other=S.Character("archive-isolated",{name="Other"})
local old=now-10*86400
local chat=S.Add(c,"chat",old,{title="Remembered words",text="A friendly message"})
local disposable=S.Add(c,"chat",old+2,{title="Older chat",text="Unlinked words"})
local memory=S.Add(c,"memory",old+4,{title="A memory",starred=true,refs={chat.id}})
local incoming=S.Add(c,"gold",old,{title="Acquisition evidence",amount=-100,source="vendorPurchase"})
local unrelated=S.Add(c,"gold",old+1,{title="Unrelated old spending",amount=-20,source="unknown"})
local lot=F.Lot(c,old+2,{itemID=9,quantity=5,cost=100,evidence=incoming.id},"retention-lot")
local sale=F.Sale(c,old+3,{itemID=9,quantity=2,gross=80,fees=0,evidence="sale observed"},"retention-sale")
local profit=F.Profit(c,0,now).profit; eq(profit,40)
S.Note(c,"day:2026-10-20","My independent note",now)
S.Note(c,"recap:weekly:2026-10-20","Recap note",now)
S.Note(c,"record:"..disposable.id,"Preserve my words even after source expiry",now)
eq(S.PreviewExpiry(c,now).count,0,"all categories default to forever")
c.retention.chat=1; c.retention.memories=1; c.retention.gold=1; S.Touch(c)
local review=R.Review(c,now); eq(#review.groups.chat.eligible,1); eq(#review.groups.chat.protected,1)
eq(review.preview.reasons[chat.id].source,memory.id); eq(review.preview.reasons[memory.id].kind,"starred")
assert(review.preview.ids[unrelated.id]); assert(not review.preview.ids[lot.id] and not review.preview.ids[sale.id] and not review.preview.ids[incoming.id])
eq(review.preview.reasons[lot.id].kind,"accounting")
eq(R.Reason(c,review.preview.reasons[chat.id]),"Linked source: A memory")
-- Policy changes, protection changes and character mistakes reject the entire deletion transaction.
local before=#c.order; local tampered=E.Copy(review.preview); tampered.ids[memory.id]=true
assert(not pcall(S.ApplyExpiry,c,tampered)); eq(#c.order,before); assert(c.records[disposable.id] and c.records[unrelated.id])
c.retention.chat=2 -- deliberately bypass Touch to verify the policy snapshot itself is checked
assert(not pcall(S.ApplyExpiry,c,review.preview)); assert(c.records[disposable.id] and c.records[unrelated.id]); c.retention.chat=1
assert(not pcall(S.ApplyExpiry,other,review.preview)); eq(#other.order,0)
disposable.starred=true; assert(not pcall(S.ApplyExpiry,c,review.preview)); assert(c.records[unrelated.id]); disposable.starred=nil
-- Review timestamps and removal timestamps stay distinct, with source-date coverage retained.
TEST_NOW(now+100); local removed=S.ApplyExpiry(c,review.preview)
eq(removed.chat,1); eq(removed.gold,1); eq(c.records[disposable.id],nil); assert(c.records[chat.id] and c.records[memory.id])
eq(F.Profit(c,0,now+101).profit,profit,"cleanup cannot change FIFO profit")
eq(c.notes["record:"..disposable.id].text,"Preserve my words even after source expiry")
local gap=E.Query.Kind(c,"gap")[1]; eq(gap.ts,now+100); eq(gap.reviewedAt,now); eq(gap.removedRanges.chat.from,old+2)
eq(gap.removedRanges.gold.through,old+1)
-- Another starred reference continues protection after the first star is removed.
local memory2=S.Add(c,"memory",old+6,{title="Another memory",starred=true,refs={chat.id}})
memory.starred=false; S.Changed(c,memory); assert(S.Protected(c)[chat.id]); memory2.starred=false; S.Changed(c,memory2)
assert(S.PreviewExpiry(c,now+100).ids[chat.id])
-- The estimator matches its documented compact Lua representation, not engine memory/file sizes.
local function size(v)
    local kind=type(v)
    if kind=="string" then return #string.format("%q",v)elseif kind=="number" then return #tostring(v)
    elseif kind=="boolean" then return v and 4 or 5 elseif kind=="nil" then return 3 end
    local n=2; for k,value in pairs(v)do n=n+size(k)+4+size(value)end; return n
end
local function measure(character,budget)
    R.Start(character); local out; local steps=0
    repeat steps=steps+1; out=R.Step(budget or 100); assert(steps<100000,"measurement terminates")until out
    return out,steps
end
c.state.measurementFixture={quote='a"b',slash="a\\b",newline="a\nb",unicode="café",zero=0,no=false,empty={}}
local out,steps=measure(c,2); assert(steps>1); eq(out.bytes,size(c)); eq(out.records,#c.order); eq(out.notes,3); eq(out.unavailable,0)
eq(out.categories.dailyNotes.notes,1); eq(out.categories.recapNotes.notes,1); eq(out.categories.otherNotes.notes,1)
local sum=0; for _,row in pairs(out.categories)do sum=sum+row.bytes end; eq(sum,out.bytes); eq(R.results[other],nil)
local countBefore=#c.order; R.Start(c); R.Step(1); S.Note(c,"day:2026-10-21","Changed during measurement",now+100)
repeat out=R.Step(100)until out; eq(out.changed,true); eq(#c.order,countBefore,"measurement does not add or remove records")
-- Unexpected cyclic/unsupported fields are reported as incomplete; the scan neither executes nor loops on them.
c.state.bad={callback=function()error("must not execute")end}; c.state.bad.self=c.state.bad
out=measure(c); assert(out.unavailable>=2); c.state.bad=nil
-- Native category/status rows remain paginated and isolated; cleanup controls are tested separately.
B.ChangeCharacter(c.id); B.SetChapter("Archive"); B.archiveTab="storage"; B.Render(true)
assert((B.right.used.label or 0)<35)
B.archiveTab="retention"; B.archiveCategory="gold"; B.archiveProtected=true; B.Render(true)
while R.reviewWorker do R.StepReview(1000)end;B.Render()
assert(E.ArchiveView.lastReview.preview.character==c.id)
for i=1,B.left.used.button or 0 do local text=B.left.pool.button[i].text:GetText(); assert(not text:find("Apply cleanup",1,true) and not text:find("Delete",1,true))end
B.selected=lot.id; B.Render(); B.selected=nil
local width,height=B.frame:GetWidth(),B.frame:GetHeight()
for _,resolution in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(resolution[1],resolution[2]); B.Fit(); B.Render(); eq(B.frame:GetWidth(),width); eq(B.frame:GetHeight(),height)end
UIParent:SetSize(1920,1080); B.Fit()
B.ChangeCharacter(other.id); eq(B.archiveCategory,nil); B.ChangeCharacter(c.id); eq(B.archiveCategory,"gold")
-- Large histories are measured incrementally without truncating their original messages.
local archive=S.Character("archive-measurement-dense",{name="Collector"})
for i=1,10000 do S.Add(archive,"chat",old+i,{title="Friend",text=string.rep("Remember this. ",12)})end
local started=os.clock(); out,steps=measure(archive,1000); eq(out.records,10000); assert(steps>100); eq(#archive.order,10000)
print(string.format("PASS archive measurement: 10,000 retained records, %d bounded scan steps, %.1f ms total host time",steps,(os.clock()-started)*1000))
print("PASS retention review: atomic validation, policy/character/protection changes, FIFO roots, linked stars, independent notes, dated coverage gaps, byte estimates, malformed data, isolated navigation and fixed sizing")
