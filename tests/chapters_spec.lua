local S,C,K,P,A=E.Store,E.Chapters,E.Keepsakes,E.MemoryPrompts,E.API
local c=S.Character('chapter-owner',{name='Scribe'});local other=S.Character('chapter-other',{})
E.current=c
local day=assert(A.ParseDay('2026-11-04'));TEST_NOW(day+3600)
local function flush()
    for i=1,10000 do if not K.Pending(c)and not K.Pending(other)then return end;K.Process(100)end
    error('chapter jobs failed to settle')
end
local group=S.Add(c,'group',day,{title='An outing'})
local quest=S.Add(c,'quest',day+5,{title='A little errand',status='completed',questID=123,mapID=1429,group=group.id})
local loot=S.Add(c,'loot',day+10,{title='One apple',itemID=453,quantity=1,mapID=1429,group=group.id,recipient=c.id})
local elsewhere=S.Add(c,'loot',day+20,{title='Elsewhere',itemID=453,quantity=1,mapID=1431,recipient=c.id})
local foreign=S.Add(other,'loot',day+10,{title='Not my story',itemID=453,quantity=1})
local movement=S.Add(c,'travel',day+15,{title='Walked'})
local active=S.Add(c,'play',day,{status='active',ended=day+120,session='one'})
S.Add(c,'play',day+30,{status='afk',ended=day+50,session='one'})
S.Add(c,'play',day+80,{status='unknown',ended=day+90,session='one'})
S.Add(c,'play',day+10,{status='active',ended=day+60,session='one'})
local diary=S.Add(c,'diary',day,{title='The day, in words',text='A small adventure'})
local entry=assert(C.Create(c,{title='A day in Elwynn',mode='range',fromDay='2026-11-04',throughDay='2026-11-04',
    kinds={quest=true,loot=true},mapIDs={[1429]=true},groupIDs={[group.id]=true}}))
C.Projection(c,entry.id)
flush()
local result=assert(C.Projection(c,entry.id))
assert(#result.rows==2 and #result.diaries==1 and result.diaries[1]==diary)
assert(result.activeSeconds==90 and result.knownSeconds==110,'Overlaps, AFK and unknown play must not inflate time')
assert(result.timeScope=='chapter dates'and #entry.members==2)
assert(K.Note(c,entry,'My own words'))
assert(not C.Include(c,entry.id,foreign.id)and not C.Include(c,entry.id,movement.id))
assert(C.Include(c,entry.id,elsewhere.id));flush();assert(#C.Projection(c,entry.id).rows==3)
assert(C.Exclude(c,entry.id,quest.id));flush();assert(#C.Projection(c,entry.id).rows==2)
assert(C.Seal(c,entry.id));flush();assert(entry.sealed and not entry.sealRequested)
local late=S.Add(c,'loot',day+30,{title='A late apple',itemID=453,quantity=1,mapID=1429,group=group.id,recipient=c.id})
flush();assert(#C.Projection(c,entry.id).rows==2,'A sealed chapter cannot collect arrivals')
assert(C.Include(c,entry.id,late.id));flush();assert(#C.Projection(c,entry.id).rows==3,'Deliberate additions still work when sealed')
assert(C.Reopen(c,entry.id));flush();assert(not entry.sealed and #C.Projection(c,entry.id).rows==3)
local later=S.Add(c,'loot',day+40,{title='Another apple',itemID=453,quantity=1,mapID=1429,group=group.id,recipient=c.id})
flush();assert(#C.Projection(c,entry.id).rows==4)
later.mapID=1431;S.Changed(c,later);flush();assert(#C.Projection(c,entry.id).rows==3,'Corrections update live selection')
assert(K.Notes(c,entry)=='My own words')
assert(C.Seal(c,entry.id));flush()
c.records[loot.id]=nil;S.Touch(c,'test removal');E.Emit('RECORDS_REMOVED',c,{loot.id});flush()
assert(C.Projection(c,entry.id).missingCount==1 and #entry.members==3,'Frozen membership keeps a missing source reference')
for _,id in ipairs(entry.refs)do assert(c.records[id]and id~=foreign.id)end
assert(c.retention.chapters==nil,'A sealed chapter does not change retention')
local picked=assert(C.Create(c,{title='Two dates',mode='picked',included={quest.id,elsewhere.id}}));C.Projection(c,picked.id);flush()
assert(#C.Projection(c,picked.id).rows==2 and C.Projection(c,picked.id).activeSeconds==90)
assert(not C.Create(c,{title='Bad',mode='range',fromDay='2026-11-05',throughDay='2026-11-04'}))
assert(not C.Create(c,{title='Bad',included={foreign.id}}))
local empty=assert(C.Create(c,{title='Empty',mode='picked'}));C.Projection(c,empty.id);flush()
assert(C.Projection(c,empty.id).activeSeconds==nil)
local before=K.Notes(c,entry)
local prompt,key=P.Get(c,'group',entry.id);assert(type(prompt)=='string'and key==P.lines.group[1])
local nextPrompt,nextKey=P.Another(c,'group',entry.id);assert(nextKey==P.lines.group[2]and nextPrompt~=prompt)
P.Hide(c,true);assert(P.Get(c,'group',entry.id)==nil and P.Hidden(c)and not P.Hidden(other))
P.Hide(c,false);assert(P.Get(c,'goal','goal')and K.Notes(c,entry)==before)
-- Loading persisted chapters rebuilds only derived projections; writing and
-- sealed membership remain canonical, and preparation yields for large books.
local reloaded=E.Copy(c);E.db.characters[c.id]=reloaded
C.Ensure(reloaded);K.Process(1);assert(K.Pending(reloaded))
c=reloaded;C.Projection(c,entry.id);flush();assert(#C.List(c)==3 and K.Notes(c,c.records[entry.id])=='My own words')
assert(C.Projection(c,entry.id).missingCount==1)
-- Typing notes and extending a normal heartbeat must not restart every chunk
-- of a long chapter scan. Appended sources are collected by a follow-up pass.
local busy=S.Character('busy-chapter-owner',{})
for i=1,300 do S.Add(busy,'memory',day+i,{title='Moment '..i})end
local play=S.Add(busy,'play',day,{status='active',ended=day+300,session='busy'})
local wallet=S.Add(busy,'wallet_window',day,{ended=day,opening=0,closing=0,session='busy'})
local busyChapter=assert(C.Create(busy,{title='A busy day',mode='range',fromDay='2026-11-04',throughDay='2026-11-04'}))
local publications=0
E.On('CHAPTER_READY',function(owner,r)if owner==busy and r==busyChapter then publications=publications+1 end end)
for i=1,600 do
    S.Note(busy,'draft','Still writing '..i,day+i)
    play.ended=day+300+i;S.Changed(busy,play)
    wallet.ended=day+i;S.Changed(busy,wallet)
    K.Process(50)
end
assert(publications>0,'Ordinary play and typing must not starve background chapter publication')
print('PASS live/sealed chapter selection, source removal, local-day time, reload and independent prompts')
