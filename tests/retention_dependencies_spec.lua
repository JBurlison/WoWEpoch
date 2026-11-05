local S,D,J,A,B,Q=E.Store,E.Diary,E.JournalJobs,E.API,E.Book,E.Query
local now=A.ParseDay('2026-11-01')+36000;TEST_NOW(now)
local old=now-20*86400
local c=S.Character('retention-dependencies',{name='Keeper'})
local q=S.Add(c,'quest_attempt',old,{title='A retained quest',ended=old+100,intervals={{from=old+10,through=old+40},{from=old+80,through=old+100}}})
local inside=S.Add(c,'kill',old+20,{title='Wolf',npcID=1})
local gap=S.Add(c,'kill',old+60,{title='Gap kill',npcID=2})
local outside=S.Add(c,'kill',old-5,{title='Confirmed outside contextual interval',npcID=3})
local boundary=S.Add(c,'kill',old+100,{title='At quest end',npcID=4})
local objective=S.Add(c,'objective',old+30,{attempt=q.id,refs={q.id},title='Objective increased'})
local credit=S.Add(c,'credit',old+31,{attempt=q.id,kill=outside.id,refs={q.id,outside.id,objective.id}})
c.retention.questKills=1
local p=S.PreviewExpiry(c,now)
assert(not p.ids[inside.id] and not p.ids[credit.id] and not p.ids[objective.id] and not p.ids[outside.id])
assert(p.ids[gap.id] and p.ids[boundary.id],'contextual gaps and exclusive quest-end boundary are not invented links')
assert(p.reasons[inside.id].source==q.id and p.reasons[credit.id].source==q.id)
-- A previously eligible quest rescued by a surviving record also rescues implicit children.
c.retention.quests=1
local memory=S.Add(c,'memory',old,{refs={q.id}})
p=S.PreviewExpiry(c,now);assert(not p.ids[q.id] and not p.ids[inside.id] and not p.ids[credit.id])
c.retention.memories=1
p=S.PreviewExpiry(c,now);assert(p.ids[q.id] and p.ids[inside.id] and p.ids[credit.id] and p.ids[objective.id],'expired cycles do not protect themselves')
q.starred=true
local protected=S.Protected(c);assert(protected[inside.id] and protected[credit.id] and protected[outside.id] and protected[objective.id])
q.starred=nil
-- A retained result preserves the complete reported operation, including expired siblings.
local one=S.Add(c,'craft_result',old,{operationKey='op',result={itemID=4}})
local two=S.Add(c,'craft_result',now,{operationKey='op',result={itemID=5}})
c.retention.production=1
p=S.PreviewExpiry(c,now);assert(not p.ids[one.id] and p.reasons[one.id].kind=='operation')
-- Deep reverse-reference chains finish without repeated whole-store passes or Lua recursion.
local chain=S.Character('retention-long-chain',{name='Chain'})
local tail
for i=1,5000 do tail=S.Add(chain,'chat',old,{refs=tail and{tail.id}or{}})end
S.Add(chain,'memory',now,{refs={tail.id}});chain.retention.chat=1
local start=os.clock();p=S.PreviewExpiry(chain,now);assert(p.count==0)
local elapsed=(os.clock()-start)*1000
-- Expired summaries stay expired across worker seeding, direct views, late facts and reloads.
local summaries=S.Character('retention-summaries',{name='Summaries'});summaries.state.recapLoginThrough=A.DayStart(now)
local day=A.DayStart(old);local finish=A.ShiftDay(day,1)
local level=S.Add(summaries,'milestone',day+100,{title='Level 21',major=true,milestoneType='level',subject=summaries.id,before=20,after=21})
local diary=D.SaveDaily(summaries,day,finish,now)
local from,through=A.Period(day,'weekly');local key='weekly:'..A.Day(from)
local recap=D.Generate(summaries,key,from,through,'Old week',{periodKind='weekly',now=old+8*86400})
local milestoneKey='milestone:'..level.id
local milestone=D.Generate(summaries,milestoneKey,day,day+101,'Level journey',{milestone=true,periodKind='milestone',partialBoundary=true,now=old+8*86400})
S.Note(summaries,'day:'..A.Day(day),'Keep the daily note',now)
S.Note(summaries,'recap:'..key,'Keep the weekly note',now)
-- Old note-key migrations also survive expiry without making an inaccessible orphan.
S.Note(summaries,'record:'..milestone.id,'Keep the milestone note',now)
summaries.retention.diaries=1;summaries.retention.recaps=1
p=S.PreviewExpiry(summaries,now);assert(p.ids[diary.id] and p.ids[recap.id] and p.ids[milestone.id])
S.ApplyExpiry(summaries,p)
assert(not summaries.records[diary.id] and not summaries.state.diaries[A.Day(day)])
assert(D.Expired(summaries,'diaries',A.Day(day)).expiredAt==now and D.Expired(summaries,'recaps',key))
assert(summaries.notes['recap:'..milestoneKey].text=='Keep the milestone note')
assert(not D.SaveDaily(summaries,day,finish,now) and not D.RetellDaily(summaries,day,finish,now))
assert(not D.Generate(summaries,key,from,through,'Do not recreate',{now=now}))
J.Seed(summaries,now);while J.seeds[summaries]or J.boundaries[summaries]do J.Step(summaries,now,500)end;J.Process(summaries,now,1000)
assert(not summaries.state.diaries[A.Day(day)] and not summaries.state.recaps[key] and not summaries.state.recaps[milestoneKey])
S.Add(summaries,'crafted',day+200,{recipient=summaries.id,itemID=1,quantity=1})
while J.corrections[summaries]do J.Step(summaries,now+5,500)end;J.Process(summaries,now+5,1000)
assert(not summaries.state.diaries[A.Day(day)] and not summaries.state.recaps[key])
summaries.retention={};S.Touch(summaries)
assert(not D.Generate(summaries,key,from,through,'Forever cannot restore deleted writing',{now=now}))
-- The saved marker contains identity/boundaries only, not retained summary text or facts.
local copy=E.Copy(summaries);assert(D.Expired(copy,'recaps',key) and not D.SaveDaily(copy,day,finish,now))
assert(D.Expired(copy,'recaps',key).text==nil and D.Expired(copy,'recaps',key).facts==nil)
local other=S.Character('retention-summary-other',{name='Other'});other.state.recapLoginThrough=A.DayStart(now)
assert(D.SaveDaily(other,day,finish,now) and D.Generate(other,key,from,through,'Independent',{now=now}))
-- In-progress summaries cannot disappear halfway through their period.
local live=S.Add(summaries,'recap',old,{key='in-progress',inProgress=true,refs={level.id}})
summaries.retention.recaps=1;assert(not S.PreviewExpiry(summaries,now).ids[live.id])
-- Native empty states keep notes editable; opening them does not resurrect records.
local function has(page,text)for i=1,page.used.label or 0 do if page.pool.label[i]:GetText():find(text,1,true)then return true end end end
B.ChangeCharacter(summaries.id);B.day=day;B.calendarDiaryOpen=true;B.SetChapter('Calendar')
assert(has(B.right,'generated diary expired') and B.right.pool.edit[1]:GetText()=='Keep the daily note')
B.recapKind='weekly';B.recapDate=day;B.SetChapter('Recaps')
assert(has(B.right,'This recap has expired') and B.right.pool.edit[1]:GetText()=='Keep the weekly note')
B.right.pool.edit[1]:SetText('Edited after expiry');B.right.pool.edit[1].scripts.OnTextChanged(B.right.pool.edit[1],true)
assert(summaries.notes['recap:'..key].text=='Edited after expiry' and not summaries.state.recaps[key])
B.recapKind='milestone';E.RecapView.SelectMilestone(summaries,level)
assert(has(B.right,'This recap has expired') and B.right.pool.edit[1]:GetText()=='Keep the milestone note')
B.ChangeCharacter(other.id);assert(not B.recapExpiredKey)
B.ChangeCharacter(summaries.id);assert(B.recapExpiredKey==milestoneKey and has(B.right,'This recap has expired'))
print(string.format('PASS retention dependencies: contextual/credited quest sources, rescued chains/cycles, complete operations, expired summaries stay absent through jobs/views/reload copies, separate editable notes; 5,000-link host walk %.1f ms',elapsed))
