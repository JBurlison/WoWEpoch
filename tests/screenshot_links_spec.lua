local S,M,C,B,V,A=E.Store,E.Memories,E.Capture,E.Book,E.MemoryView,E.API
local priorCurrent,priorScreenshot=E.current,Screenshot
local now=A.ParseDay('2026-11-03')+30000;TEST_NOW(now)
local c=S.Character('screenshot-links-owner',{name='Screenshot links'})
local other=S.Character('screenshot-links-other',{name='Other scrapbook'})
local milestone=S.Add(c,'milestone',now-86400,{title='Level twenty',subject=c.id,major=true,milestoneType='level',level=20})
local wrong=S.Add(c,'milestone',now,{subject=other.id,title='Other subject'})
local memory=assert(M.Create(c,now-3600))
local group=S.Add(c,'group',now-20,{title='Original company'})
local one=S.Add(c,'screenshot',now-100,{title='First shot',status='unconfirmed',image='unavailable',refs={group.id}})
local two=S.Add(c,'screenshot',now-50,{title='Second shot',status='failed',image='unavailable'})
local foreign=S.Add(other,'screenshot',now,{title='Foreign shot',status='unconfirmed'})
local baseline=E.Copy(one);local stamp=milestone.ts
assert(M.AttachScreenshot(c,milestone,one));assert(M.AttachScreenshot(c,milestone,two));assert(M.AttachScreenshot(c,milestone,one))
assert(#M.Screenshots(c,milestone)==2 and #milestone.refs==2,'many attachments deduplicate')
assert(E.Same(one,baseline) and milestone.ts==stamp,'links do not change capture facts or historic milestone dates')
assert(not M.AttachScreenshot(c,milestone,foreign));assert(not M.AttachScreenshot(other,milestone,foreign))
assert(not M.AttachScreenshot(c,wrong,one));assert(not M.AttachScreenshot(c,one,two))
assert(M.Link(c,memory.id,one.id));assert(#M.Screenshots(c,memory)==1,'legacy memory screenshot links appear')
assert(M.AttachScreenshot(c,memory,two));assert(#M.Screenshots(c,memory)==2)
milestone.starred=true;S.Changed(c,milestone)
local protected=S.Protected(c);assert(protected[one.id]and protected[two.id]and protected[group.id],'star closure protects all screenshots and their contextual sources')
assert(M.DetachScreenshot(c,milestone,two));assert(not M.DetachScreenshot(c,milestone,two));assert(c.records[two.id]==two)
assert(M.DetachScreenshot(c,memory,one));assert(one.refs[1]==group.id,'unlink never deletes screenshot or its group')
milestone.starred=false;S.Changed(c,milestone)

local function find(label)
 for _,page in ipairs({B.left,B.right,B.nav})do for i=1,page.used.button or 0 do local f=page.pool.button[i];if f.text:GetText()==label then return f end end end
end
local function click(label)local f=assert(find(label),'Missing action '..label);f:Click();return f end
local function labels(needle)local count=0;for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find(needle,1,true)then count=count+1 end end;return count end
local function detail(r,chapter)B.chapter=chapter or'Chronicle';B.selected=r.id;B.Render(true);TEST_PREPARE_BOOK()end
E.current=c;local calls=0;Screenshot=function()assert(not B.frame:IsShown());calls=calls+1 end
B.ChangeCharacter(c.id);B.Open();detail(milestone)
assert(labels('Screenshots')>0 and labels('cannot import or display')>0)
click('Link existing screenshots')
local picker=assert(find('Close screenshot picker'));local choice=assert(find('Link screenshot: '..A.RecordDate(two)..' - Second shot'))
local linked=assert(find('Open screenshot: First shot'))
assert(-picker.point[5]<-choice.point[5]and -choice.point[5]<-linked.point[5],'Screenshot choices belong immediately beneath their picker, before linked entries')
click('Link screenshot: '..A.RecordDate(two)..' - Second shot')
assert(#M.Screenshots(c,milestone)==2)
local selection=B.selected;click('Capture screenshot for this milestone');local pending=assert(C.pending);local shot=pending.record
assert(shot.ts==now and shot.status=='pending'and not B.frame:IsShown())
assert(#M.Screenshots(c,milestone)==2,'pending association waits for revalidation')
assert(C.Request(milestone,c)==nil,'concurrent captures refused')
C.Tick(.02);TEST_NOW(now+2);C.Tick(.02)
assert(calls==1 and shot.status=='unconfirmed'and shot.ts==now+2 and shot.requestedAt==now)
assert(shot.filename==nil and shot.image=='unavailable'and milestone.ts==stamp)
assert(#M.Screenshots(c,milestone)==3)
C.Tick(.6);C.Tick(.6);assert(B.frame:IsShown()and B.selected==selection and B.chapter=='Chronicle'and B.Character()==c)
assert(labels('Screenshots (3)')==1,'restored detail refreshes the linked count')
click('Unlink screenshot: '..shot.title);assert(#M.Screenshots(c,milestone)==2 and c.records[shot.id]==shot)

detail(memory,'Memories');B.memoryEditing=true;B.memoryEditID=memory.id;B.Render()
local edit=B.right.pool.edit[1];edit:SetText('Unsaved title survives capture')
click('Capture screenshot for this memory');C.Tick(.02);C.Tick(.02);C.Tick(.6);C.Tick(.6)
assert(B.right.pool.edit[1]:GetText()=='Unsaved title survives capture'and memory.title=='A memory of my own','capture refresh preserves unsubmitted draft without saving it')
assert(#M.Screenshots(c,memory)==2)
B.memoryEditing=false;detail(milestone)
click('Capture screenshot for this milestone');local cancelled=C.pending.record;local oldCalls=calls
local replacement=E.Copy(milestone);replacement.refs={};replacement.userRefs={};c.records[milestone.id]=replacement;S.Changed(c,replacement)
C.Tick(.02);C.Tick(.02)
assert(cancelled.status=='cancelled'and not C.pending and calls==oldCalls and B.frame:IsShown())
assert(#replacement.refs==0,'same-ID replacement cannot receive queued attachment')
assert(not M.AttachScreenshot(c,milestone,one),'stale object refused')
milestone=replacement
detail(milestone);click('Capture screenshot for this milestone');local changed=C.pending.record
milestone.subject=other.id;S.Changed(c,milestone);C.Tick(.02);C.Tick(.02)
assert(changed.status=='cancelled'and calls==oldCalls and #milestone.refs==0)
milestone.subject=c.id;S.Changed(c,milestone)

local altMemory=M.Create(other,now);B.ChangeCharacter(other.id);detail(altMemory,'Memories')
assert(not find('Capture screenshot for this memory'),'alt view cannot capture for wrong owner')
local before=c.seq;assert(C.Request(altMemory,other)==nil and c.seq==before)
click('Link existing screenshots');click('Link screenshot: '..A.RecordDate(foreign)..' - Foreign shot');assert(#M.Screenshots(other,altMemory)==1)
assert(#M.Screenshots(c,milestone)==0)
B.ChangeCharacter(c.id);detail(memory,'Memories');click('Link existing screenshots')
local staleButton=find('Link screenshot: '..A.RecordDate(one)..' - First shot');assert(staleButton)
local staleCallback=staleButton.scripts.OnClick;B.ChangeCharacter(other.id);staleCallback();assert(#M.Screenshots(c,memory)==2,'old-owner callback cannot link')

B.ChangeCharacter(c.id);detail(milestone)
for i=1,14 do local r=S.Add(c,'screenshot',now+i,{title='Extra '..i,status='unconfirmed',image='unavailable'});assert(M.AttachScreenshot(c,milestone,r))end
B.Render();assert(find('More screenshots'));local openCount=0
for i=1,B.right.used.button or 0 do if B.right.pool.button[i].text:GetText():find('Open screenshot:',1,true)==1 then openCount=openCount+1 end end
assert(openCount==6,'linked image controls stay paginated')
click('More screenshots');assert(find('Previous screenshots'))

-- Immediate unavailable/failed calls remain honest references; no filename or success is invented.
B.Close(true);Screenshot=nil;local unavailable=C.Request(memory,c);assert(unavailable.status=='unavailable')
Screenshot=function()error('Screenshot rejected')end;local failed=C.Request(memory,c);assert(failed.status=='failed'and failed.filename==nil)
assert(#M.Screenshots(c,memory)==4)
-- Persistence uses ordinary record refs; no new schema, filesystem path or image payload.
local saved=E.Copy(c);assert(saved.records[memory.id].refs[#memory.refs]==failed.id)
assert(saved.records[one.id].refs[1]==group.id)
E.current,Screenshot=priorCurrent,priorScreenshot;B.Close(true)
print('PASS screenshot links: multiple attachments, legacy refs, retention closure, independent unlink, owner/object guards, async replacement/subject validation, actual capture dates, visible capture/link UI, draft preservation, pagination and honest failures')
