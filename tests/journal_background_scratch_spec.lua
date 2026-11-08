local C,D,P,K,S,W,A,B=E.Chapters,E.Diary,E.DiaryPresentation,E.Keepsakes,E.Store,E.RetentionWork,E.API,E.Book
local previous={current=E.current,character=B.character,locale=E.locale}
local c=S.Character('background-scratch',{name='Background writer'})
local day=assert(A.ParseDay('2026-11-04'));local through=A.ShiftDay(day,1);TEST_NOW(through+3600)
E.current=c;B.character=c.id;B.Build();B.frame:Hide()
for i=1,800 do
    c.seq=c.seq+1;local id='scratch-loot:'..i
    c.records[id]={id=id,character=c.id,kind='loot',sequence=c.seq,ts=day+i,title='A remembered apple',recipient=c.id,itemID=453,quantity=1}
    c.order[#c.order+1]=id
end
local weak=setmetatable({},{__mode='v'})
local prepare=C.Prepare;local prepared=0
C.Prepare=function(...)
    local result=prepare(...)
    if result then prepared=prepared+1;weak.chapter=result;weak.rows=result.rows;weak.diaries=result.diaries end
    return result
end
local function flush()
    for _=1,20000 do if not K.Pending(c)then return end;K.Process(250)end
    error('Background chapter did not finish')
end
local chapter=assert(C.Create(c,{title='While the book was closed',mode='range',fromDay=A.Day(day),throughDay=A.Day(day),kinds={loot=true}}))
assert(C.Seal(c,chapter.id));K.Process(1)
E.ReleaseJournalViewCaches()
assert(K.Pending(c,'chapter:'..chapter.id),'Closing the book cannot cancel canonical chapter compilation')
flush()
assert(prepared>0 and chapter.sealed and not chapter.sealRequested and #chapter.members==800 and #chapter.refs==800,
    'A real closed-book compilation must commit membership, references and the requested seal')
collectgarbage('collect');collectgarbage('collect')
assert(not weak.chapter and not weak.rows and not weak.diaries,'Completed background display projections must be collectible')
assert(C.Projection(c,chapter.id)==nil,'A first read requests the discarded display projection')
flush()
do local result=assert(C.Projection(c,chapter.id));assert(#result.rows==800 and weak.chapter==result)end
E.ReleaseJournalViewCaches();collectgarbage('collect');collectgarbage('collect')
assert(not weak.chapter and not weak.rows,'A requested chapter projection is released by close')
local added=S.Add(c,'loot',day+900,{title='A deliberate addition',recipient=c.id,itemID=453,quantity=1})
assert(C.Include(c,chapter.id,added.id));flush()
assert(#chapter.members==801 and chapter.sealed,'Closed compilation still honors edits to a sealed chapter')
collectgarbage('collect');collectgarbage('collect')
assert(not weak.chapter and not weak.rows,'Later background publication cannot recreate a closed view cache')
C.Prepare=prepare

-- Generate a real diary, then compile its read-time translation. The finished
-- localized text is reusable while reading; its completed coroutine is not.
local writer=assert(D.StartDaily(c,day,through,A.Now()))
for _=1,20000 do local status=TEST_HISTORY_CALL(W.Step,writer.worker,250);if status then assert(status=='done');break end end
assert(writer.phase=='ready','The real diary writer must complete its bounded capture and text compilation')
local diary=D.FinishDaily(writer);assert(diary,'The completed diary must be published');writer=nil
local savedText,savedRefs=diary.text,diary.refs
S.Note(c,'record:'..diary.id,'The player keeps these exact words.',A.Now())
E.locale='ruRU'
local _,entry=P.Daily(c,diary);assert(entry and entry.job)
weak.translationJob=entry.job
P.Tick();assert(not entry.ready,'Large linked-source translation must yield')
for _=1,2000 do P.Tick();if entry.ready then break end end
assert(entry.ready and type(entry.text)=='string'and not entry.job,'Completed translation drops its worker immediately')
collectgarbage('collect');collectgarbage('collect')
assert(not weak.translationJob,'Completed translation scratch must collect while its text remains cached')
assert(P.Daily(c,diary)==entry.text and diary.text==savedText and diary.refs==savedRefs)

-- A suspended read-time translation is also disposable on close. It is
-- separate from the automatic diary/recap writer and never changes saved text.
P.ReleaseView()
local _,pending=P.Daily(c,diary);P.Tick();assert(pending and not pending.ready and pending.job)
weak.suspendedJob=pending.job
E.ReleaseJournalViewCaches();collectgarbage('collect');collectgarbage('collect')
assert(not pending.job and not weak.suspendedJob and not P.Pending(pending),'Close cancels only the translated view worker')
for _=1,5 do P.Tick()end
assert(diary.text==savedText and diary.refs==savedRefs and E.Keepsakes.Notes(c,diary)=='The player keeps these exact words.')
flush()
E.current=previous.current;B.character=previous.character;E.locale=previous.locale
print('PASS real background chapter publication, display-only scratch disposal and localized diary worker cleanup')
