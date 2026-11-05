local S,M,A,Q,B,V=E.Store,E.Memories,E.API,E.Query,E.Book,E.MemoryView
local function eq(a,b,label)assert(a==b,(label or "Memory mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local function day(s)return assert(A.ParseDay(s))end
local now=day("2026-10-31")+40000; TEST_NOW(now)
local c=S.Character("memory-owner",{name="Rememberer"})
local other=S.Character("memory-other",{name="Other"})
local quest=S.Add(c,"quest",day("2026-10-24")+60,{title="A daring rescue",status="completed"})
local foreign=S.Add(other,"quest",quest.ts,{title="Other rescue",status="completed"})
local milestone=S.Add(c,"milestone",quest.ts,{title="Character level 20",subject=c.id,major=true})
S.Add(c,"milestone",quest.ts,{title="Another character's level",subject=other.id,major=true,starred=true})
S.Add(c,"crafted",quest.ts,{title="Another character's craft",recipient=other.id,quantity=2})
local memory=assert(M.Create(c,now,quest.id)); eq(memory.refs[1],quest.id)
eq(M.Create(c,now,foreign.id),nil); eq(#Q.Kind(other,"memory"),0)
Q.Range(c,now-10,now+10); E.Search.Find(c,"memory") -- prime both date and search indexes
assert(M.Edit(c,memory.id,"title","Our rescue story"))
assert(M.Edit(c,memory.id,"text","A very stubborn chicken."))
assert(M.Edit(c,memory.id,"tags","Rescue, funny, rescue,  chickens  ,")); eq(#memory.tags,3)
assert(M.Edit(c,memory.id,"day","2026-10-24")); eq(memory.ts,day("2026-10-24")); eq(memory.createdAt,now)
eq(#Q.Range(c,now-10,now+10,"memory"),0,"old date index no longer contains moved memory")
eq(#Q.Range(c,day("2026-10-24"),day("2026-10-25"),"memory"),1)
eq(E.Search.Find(c,"stubborn chicken").hits[1].record,memory.id)
eq(E.Search.Find(c,"chickens").hits[1].ts,memory.ts)
eq(A.RecordDate(E.Search.Find(c,"chickens").hits[1]),"2026-10-24 (date only)","a supplied date never invents an exact event time")
eq(#M.Saved(c,"FUNNY"),1); assert(not M.Edit(c,memory.id,"day","2026-02-30")); eq(memory.ts,day("2026-10-24"))
assert(not M.Edit(c,quest.id,"title","Changed source")); eq(quest.title,"A daring rescue")
assert(not M.Link(c,memory.id,foreign.id)); assert(M.Link(c,memory.id,quest.id)); eq(#memory.refs,1)
assert(M.Link(c,memory.id,milestone.id)); memory.starred=true; S.Changed(c,memory)
assert(S.Protected(c)[quest.id]); assert(M.Unlink(c,memory.id,milestone.id)); eq(#memory.refs,1); assert(c.records[milestone.id])
local seq=c.seq
local report=M.Rediscover(c,now,"week","all")
eq(#report.rows,3,"only personal eligible records on the target day")
eq(report.rows[1].id,memory.id); eq(c.seq,seq,"rediscovery never copies source records")
eq(#M.Rediscover(c,now,"week","keepsakes").rows,1)
eq(#M.Rediscover(c,now,"week","milestones").rows,1)
eq(#M.Rediscover(c,now,"week","adventures").rows,1)
local from,through,adjusted,message,choice=M.Anniversary(now,"month")
eq(A.Day(from),"2026-09-30"); eq(adjusted,true,"approved default uses the last valid day and labels the adjustment")
from,through,adjusted=M.Anniversary(now,"month","last-day"); eq(A.Day(from),"2026-09-30"); eq(adjusted,true)
eq(M.Anniversary(now,"month","skip"),nil)
from=M.Anniversary(day("2026-01-31"),"month","skip"); eq(A.Day(from),"2025-12-31")
from,through,adjusted=M.Anniversary(day("2024-02-29"),"year","last-day"); eq(A.Day(from),"2023-02-28"); eq(adjusted,true)
eq(M.Anniversary(day("2024-02-29"),"year","skip"),nil)
from,through=M.Anniversary(day("2026-11-08"),"week"); eq(A.Day(from),"2026-11-01"); eq(A.Day(through),"2026-11-02")

local function click(text)
    for _,page in ipairs({B.left,B.right}) do for _,kind in ipairs({"button","memoryControl","memoryCard"})do for i=1,page.used[kind] or 0 do local f=page.pool[kind][i]
        if f.text:GetText()==text then f:Click(); return end
    end end end
    return TEST_UI_CLICK(text,prefix)
end
B.ChangeCharacter(c.id); B.SetChapter("Memories"); click("On This Day")
eq(#V.lastReport.rows,3); eq(c.seq,seq)
click("One month earlier"); eq(B.otdPolicy,"last-day"); assert(V.lastReport.adjusted)
click("One week earlier"); click(quest.title); eq(B.selected,quest.id)
click("Write a memory about this"); local newMemory=c.records[B.selected]; eq(newMemory.refs[1],quest.id)
eq(B.memoryMode,"saved")
local title=B.right.pool.edit[1]; title:SetText("A linked memory"); title.scripts.OnEnterPressed(title); eq(newMemory.title,"A linked memory")
local story=B.right.pool.edit[4]; story:SetText("My own account of the day"); story.scripts.OnTextChanged(story,true)
eq(newMemory.text,"My own account of the day"); eq(quest.title,"A daring rescue")
click("Link a recorded moment"); click(A.Date(milestone.ts).." - "..milestone.title); eq(#newMemory.refs,2)
click("Remove memory link: "..milestone.title); eq(#newMemory.refs,1)
B.ChangeCharacter(other.id); eq(B.otdPolicy,nil); B.ChangeCharacter(c.id); eq(B.otdPolicy,"last-day")

local originalCurrent,originalScreenshot=E.current,Screenshot
E.current=c; E.Collectors.rosterObserved=false
local calls=0; Screenshot=function()calls=calls+1 end
B.Close(true)
local shot=MyEpoch_Capture(); eq(calls,1); eq(shot.status,"unconfirmed"); eq(shot.character,c.id); eq(shot.filename,nil)
assert(M.Edit(c,shot.id,"title","A souvenir")); assert(M.Edit(c,shot.id,"text","The screenshot might be on disk."))
assert(not M.Edit(c,shot.id,"day","2000-01-01")); eq(shot.ts,now,"capture timestamp is immutable")
assert(M.Link(c,shot.id,quest.id)); assert(M.Unlink(c,shot.id,quest.id)); eq(shot.status,"unconfirmed")
shot.refs={quest.id}; shot.userRefs={}; assert(not M.Unlink(c,shot.id,quest.id),"capture's original context is immutable")
Screenshot=nil; local unavailable=E.Collectors.Screenshot(); eq(unavailable.status,"unavailable")
Screenshot=function()error("Capture rejected")end; local failed=E.Collectors.Screenshot(); eq(failed.status,"failed"); assert(failed.failure:find("Capture rejected",1,true))
eq(E.Search.Find(c,"Capture rejected").total,0,"raw error is not fabricated as an adventure")
eq(E.Search.Find(c,"failed","memories").total,1,"post-call status invalidates search index")
Screenshot=function()calls=calls+1 end
B.ChangeCharacter(other.id); B.SetChapter("Journey"); B.Open(); B.captureButton:Click()
eq(B.Character().id,other.id); eq(B.chapter,"Journey"); assert(not B.frame:IsShown())
local pending=E.Capture.pending; eq(pending.character,c); eq(pending.record.status,"pending")
local priorCalls=calls; eq(MyEpoch_Capture(),nil); eq(calls,priorCalls,"repeated input does not issue concurrent captures")
E.Capture.Tick(.02); eq(calls,priorCalls); assert(not B.frame:IsShown())
Screenshot=function()assert(not B.frame:IsShown(),"only book is hidden when calling Screenshot"); calls=calls+1 end
TEST_NOW(now+2); E.Capture.Tick(.02); eq(calls,priorCalls+1); eq(pending.record.ts,now+2); eq(pending.record.requestedAt,now)
eq(pending.record.status,"unconfirmed"); E.Capture.Tick(.6); assert(not B.frame:IsShown()); E.Capture.Tick(.6)
assert(B.frame:IsShown()); eq(B.chapter,"Journey"); eq(B.Character().id,other.id,"capture restores the viewed alt without switching the scrapbook")
eq(pending.record.status,"unconfirmed","restoration delay is not completion evidence")
local manual=MyEpoch_Capture(); B.Close(true); E.Capture.Tick(.02); E.Capture.Tick(.02); E.Capture.Tick(.6); E.Capture.Tick(.6)
assert(not B.frame:IsShown(),"manual closing cancels restoration"); eq(manual.status,"unconfirmed")
B.Open(); local interrupted=MyEpoch_Capture(); local beforeInterrupt=calls; B.Open(); eq(interrupted.status,"cancelled"); E.Capture.Tick(2); eq(calls,beforeInterrupt)
E.db.settings.combatClose=true; B.Open(); local combatShot=MyEpoch_Capture(); B.Combat(true)
local combatPending=E.Capture.pending
assert(B.Open()==false and E.Capture.pending==combatPending and combatShot.status=="pending","Blocked opening preserves the queued photograph")
E.Capture.Tick(.02); E.Capture.Tick(.02)
SlashCmdList.MYEPOCH("");assert(E.Capture.pending==combatPending and combatPending.restore,"Blocked slash opening preserves the capture restoration delay")
E.Capture.Tick(.6); E.Capture.Tick(.6)
assert(not B.frame:IsShown()); assert(B.reopen); B.Combat(false); assert(B.frame:IsShown()); eq(combatShot.status,"unconfirmed")
local logoutShot=MyEpoch_Capture(); E.Capture.Interrupt("Logging out before capture."); eq(logoutShot.status,"cancelled"); eq(E.Capture.pending,nil)
local stale=S.Add(c,"screenshot",now,{title="Interrupted capture",status="pending",image="unavailable"})
E.Capture.Recover(c); eq(stale.status,"pending","startup only schedules interrupted-capture recovery")
for i=1,1000 do E.Query.ProcessPreparation(500);E.Capture.Tick(.01);if stale.status~="pending"then break end end
eq(stale.status,"unconfirmed");assert(stale.captureNote)
E.db.settings.combatClose=false; B.Close(true)
E.current,Screenshot=originalCurrent,originalScreenshot
local dense=S.Character("memory-dense",{name="Many keepsakes"})
for i=1,1800 do S.Add(dense,"memory",quest.ts,{title="Keepsake "..i,text="A recorded memory"}) end
B.ChangeCharacter(dense.id)
assert(B.preparingCharacter==dense,'a cold large scrapbook prepares before showing results')
TEST_PREPARE_BOOK();B.SetChapter("Memories"); click("On This Day")
eq(#V.lastReport.rows,1800); assert((B.right.used.memoryCard or 0)<=8,"anniversary result controls stay bounded")
local denseSeq=dense.seq; click("Older entries"); eq(B.memoryPage,2); eq(dense.seq,denseSeq)
print("PASS memories: editable authorship, immutable sources/capture dates, local redating indexes, tags, link retention, character isolation, anniversary/leap/DST boundaries, source navigation, capture failures and optional binding")

-- Blank filters and eight short card previews should not fold entire narratives.
do
    local owner=S.Character("memory-preview-budget",{name="Preview budget"})
    local r=M.Create(owner,now)
    local story=string.rep("campfire ",8192).."after the march"
    assert(M.Edit(owner,r.id,"text",story))
    local normal=string.lower
    local large=0
    string.lower=function(value)if #value>65536 then large=large+1 end;return normal(value)end
    local ok,err=pcall(function()
        assert(M.Saved(owner,"")[1]==r)
        assert(E.Search.Excerpt(story,nil,8)=="campfire ...")
        assert(E.Search.Excerpt(string.rep(" ",8192).."ééé","",1)==" é...")
    end)
    string.lower=normal
    assert(ok,err);assert(large==0)
    assert(M.Saved(owner,"AFTER THE MARCH")[1]==r)
end
