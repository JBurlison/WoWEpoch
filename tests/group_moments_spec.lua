local B,A,C,S,L=E.Book,E.API,E.Collectors,E.Store,E.CompanyLayout
local saved={current=E.current,character=B.character,now=A.Now(),roster=A.Roster,shown=B.frame and B.frame:IsShown()}
local collectorKeys={"session","partyGUID","partyCategory","rosterAt","rosterObserved","rosterSize","lastRoster","chatGap"}
for _,k in ipairs(collectorKeys)do saved[k]=C[k]end
local function restore()
 E.current=saved.current;A.Roster=saved.roster;TEST_NOW(saved.now)
 for _,k in ipairs(collectorKeys)do C[k]=saved[k]end
 if saved.character then B.ChangeCharacter(saved.character)end
 if not saved.shown then B.Close()end
end
local function emit(event,...)E.frame.scripts.OnEvent(E.frame,event,...)end
local c=S.Character("group-moments-review",{name="Journal owner"})
E.current=c;C.session="group-moments-review";C.partyGUID="party-unique"
local people={{id=c.id,name="Journal owner",isLeader=true},{id="friend-guid",name="Rook",realm="Review",isLeader=false}}
A.Roster=function()return people end
local day=A.ParseDay("2026-11-01");TEST_NOW(day+3600);emit("GROUP_ROSTER_UPDATE")
local g=assert(c.records[c.state.group]);local quote
for i=1,32 do
 TEST_NOW(day+3600+i)
 emit("CHAT_MSG_PARTY",i==24 and "Thanks everyone! Beautiful teamwork." or ("Message "..i),"Rook-Review",nil,nil,nil,nil,nil,nil,nil,nil,14000+i,"friend-guid")
 if i==24 then quote=c.records[c.order[#c.order]]end
end
TEST_NOW(day+3700);emit("BOSS_KILL",60123,"Review boss")
local boss
for _,r in ipairs(E.Query.Kind(c,"encounter"))do if r.phase=="boss"then boss=r end end
assert(boss and E.Highlights.Reason(c,boss) and E.Highlights.Reason(c,quote))
local words,author,ts=quote.text,quote.author,quote.ts
assert(quote.channel=="CHAT_MSG_PARTY" and quote.authorGUID=="friend-guid" and quote.group==g.id)
local function waitHistory()
 for i=1,10000 do if B.HistoryReadiness(c)=="ready"then return end
  E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()
 end;error("history did not settle")
end
waitHistory();B.Open();B.ChangeCharacter(c.id);B.SetChapter("Company");B.companyMode="sessions";B.Render(true)
local function find(page,label)
 for _,kind in ipairs({"companyControl","companyRow","button","calendarControl"})do
  for i=1,page.used[kind] or 0 do local f=page.pool[kind][i]
   if f.text:GetText()==label then return f end
  end
 end
end
local function click(page,text)local f=assert(find(page,text),text);f:Click();return f end
click(B.left,g.title);click(B.right,"Highlights")
assert(#L.lastHighlights==2)
click(B.right,"Chat"); click(B.right,"Later messages")
local f=B.right.pool.companyChat[12];assert(f.text:GetText()==words)
f.keep:Click();assert(quote.starred)
f=B.right.pool.companyChat[12];assert(f.keep.text:GetText()=="Kept");f:Click();assert(B.selected==quote.id)
local note=B.right.pool.edit[B.right.used.edit];note:SetText("My caption");note.scripts.OnTextChanged(note,true)
assert(c.notes["record:"..quote.id].text=="My caption" and quote.text==words and quote.author==author)
-- Physically position the viewport so the source action itself is visible before clicking it.
local sourceButton=assert(find(B.right,"Open this group's transcript"))
local scroll=B.right.scroll
local sourceTop=-sourceButton.point[5]
scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),sourceTop-scroll:GetHeight()+sourceButton:GetHeight())))
sourceButton:Click();assert(B.selected==g.id and B.transcriptPage==2 and B.transcriptHighlight==quote.id)
f=B.right.pool.companyChat[12];assert(f.text:GetText()==words and f.meta:GetText():find(author,1,true))
local top=-f.point[5];local y=scroll:GetVerticalScroll();local bottom=y+scroll:GetHeight()
print("VIEWPORT",BEFORE and "installed" or "candidate",y,bottom,"QUOTE",top,top+f:GetHeight())
if BEFORE then assert(top>=bottom or top+f:GetHeight()<=y,"original source quote was visible");restore();return end
assert(top>=y and top+f:GetHeight()<=bottom,"source target must be visible after the jump")
-- Rendering again should respect a reader who has scrolled away from the quote.
scroll:SetVerticalScroll(0);B.Render();assert(scroll:GetVerticalScroll()==0)
local function sourceAction(r)
 B.selected=r.id;B.Render(true)
 local action=assert(find(B.right,"Open this group's transcript"))
 return action.scripts.OnClick
end
local function visibleTarget(r)
 local records=E.Search.Transcript(c,g.id,"");local pos
 for i,message in ipairs(records)do if message==r then pos=i;break end end
 assert(pos and B.transcriptPage==math.ceil(pos/12) and B.transcriptHighlight==r.id)
 local row=B.right.pool.companyChat[(pos-1)%12+1]
 assert(row.text:GetText()==r.text)
 local top=-row.point[5];local sy=scroll:GetVerticalScroll()
 assert(top>=sy and top+math.min(row:GetHeight(),scroll:GetHeight())<=sy+scroll:GetHeight())
end
local action=sourceAction(quote)
quote.ts=day+3615.5;quote.author="Updated speaker";quote.text="Corrected observed text";S.Changed(c,quote)
action();visibleTarget(quote)
quote.ts=ts;quote.author=author;quote.text=words;S.Changed(c,quote)
local rows=E.Search.Transcript(c,g.id,"")
local last=rows[#rows];sourceAction(last)();visibleTarget(last)
-- Model the preparation gate returning before the transcript is painted.
-- A real later Book.Render performs the owner/selection/identity checks.
local function delayJump(r)
 local go=sourceAction(r);local render=B.Render
 B.Render=function()end;go();B.Render=render
 assert(B.selected==g.id and B.transcriptHighlight==nil)
end
delayJump(quote);B.transcriptSearch="query that excludes these messages";B.Render()
assert(B.transcriptSearch~="" and #L.lastMessages==0 and not B.transcriptHighlight)
delayJump(quote)
local other=S.Character("group-moments-other",{name="Other"});B.ChangeCharacter(other.id)
assert(B.character==other.id and B.selected~=g.id)
B.ChangeCharacter(c.id);B.Render()
assert(B.selected==g.id and not B.transcriptHighlight)
local disposable=S.Add(c,"chat",day-10*86400,{author="Earlier",text="Discard this only",group=g.id,refs={g.id}})
delayJump(disposable);c.retention.chat=2;local preview=S.PreviewExpiry(c,day+1)
assert(preview.ids[disposable.id] and not preview.ids[quote.id])
S.ApplyExpiry(c,preview);B.Render()
assert(not c.records[disposable.id] and not B.transcriptHighlight)
-- Stale callbacks must not open a replacement source with the same ID.
local stale=sourceAction(last);local copy=E.Copy(last)
c.records[last.id]=copy;S.Changed(c,copy);local selected=B.selected
stale();assert(B.selected==selected and B.selected~=g.id)
local superseded=sourceAction(quote);B.selected=last.id;B.Render(true)
superseded();assert(B.selected==last.id)
sourceAction(quote)();visibleTarget(quote)
click(B.right,"Highlights");click(B.right,"Kept");assert(#L.lastHighlights==1 and L.lastHighlights[1]==quote)
click(B.right,words);assert(B.selected==quote.id)
assert(quote.author==author and quote.text==words and quote.ts==ts)
click(B.right,"Back to highlights");click(B.right,"Suggested");click(B.right,boss.title)
click(B.right,"Star and protect this memory");assert(boss.starred and B.selected==boss.id)
B.SetChapter("Calendar");B.calendarFilter="all";E.CalendarView.SelectDay(day)
-- Selecting a day opens its diary; use the visible tab before following events.
assert(B.calendarDiaryOpen~=false)
click(B.right,"Events");assert(B.calendarDiaryOpen==false)
local function followDayRecord(target)
 local pos
 for i,r in ipairs(E.CalendarView.lastReport.records)do if r==target then pos=i;break end end
 assert(pos)
 while B.calendarPage<math.ceil(pos/12)do click(B.right,"Later events")end
 while B.calendarPage>math.ceil(pos/12)do click(B.right,"Earlier events")end
 local eventRow=B.right.pool.calendarEvent[(pos-1)%12+1];eventRow:Click()
 assert(B.selected==target.id);click(B.right,"Back to this day");assert(B.day==day)
end
followDayRecord(quote);followDayRecord(boss)
people={};emit("GROUP_ROSTER_UPDATE")
c.retention.chat=1;c.retention.groups=1;c.retention.otherNotes=1
local horizon=A.ShiftDay(day,4)
local prev=S.PreviewExpiry(c,horizon)
assert(not prev.ids[quote.id] and not prev.ids[boss.id] and not prev.ids[g.id] and not prev.noteIDs["record:"..quote.id]);S.ApplyExpiry(c,prev)
assert(c.records[quote.id]==quote and c.records[boss.id]==boss and c.records[g.id]==g and c.notes["record:"..quote.id].text=="My caption")
local messages=E.Search.Transcript(c,g.id,"");assert(#messages==1 and messages[1]==quote)
restore()
print("PASS frame chat/boss highlights, transcript Keep, unchanged speaker/text, separate caption, canonical Calendar record, one-shot visible jump and protected quote/group")
