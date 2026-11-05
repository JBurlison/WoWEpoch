local A,S,D,J=E.API,E.Store,E.Diary,E.JournalJobs
local t=assert(A.ParseDay('2026-12-28'))
local now=CASE=='record'and t+23*3600 or(CASE=='day'or CASE=='repeat')and t+26*3600 or CASE=='dayfinish'and t+50*3600 or assert(A.ParseDay('2027-02-03'))+3600
TEST_NOW(now)
local f=E.frame
local function fire(n,...)return f.scripts.OnEvent(f,n,...)end
fire('ADDON_LOADED','MyEpoch');fire('PLAYER_LOGIN')
local c=E.current
local function drain(at)
 TEST_NOW(at)
 if NORMAL_FRAMES then for i=1,4000 do f.scripts.OnUpdate(f,.1)end;return end
 for i=1,10000 do
  J.Step(c,at,500);J.Process(c,at+60,1,true);J.StepWriter(c,at,500)
  if not J.seeds[c]and not J.boundaries[c]and not J.corrections[c]and not J.spans[c]and not J.dailyWriters[c]and not next(J.pending[c]or{})then return end
 end
 error('scheduler did not drain: '..tostring(A.status.journalWritingError))
end
local function saved(kind,day)return c.records[(c.state.recaps or{})[kind..':'..day]]end
if CASE=='record'then
 local fall=A.ParseDay('2026-11-01');local spring=A.ParseDay('2026-03-08')
 local fallHours=(A.ShiftDay(fall,1)-fall)/3600;local springHours=(A.ShiftDay(spring,1)-spring)/3600
 assert(A.Day(A.ShiftDay(fall,1))=='2026-11-02'and A.Day(A.ShiftDay(spring,1))=='2026-03-09')
 print('Local DST boundaries',fallHours,springHours)
 S.Add(c,'play',t+23*3600,{ended=t+25*3600,status='active',session='midnight'})
 S.Add(c,'play',t+24*3600+900,{ended=t+24*3600+1800,status='afk',session='midnight'})
 S.Add(c,'milestone',t+23*3600+1,{subject=c.id,milestoneType='skill',skillID=43,skillName='Swords',before=24,after=25,title='Swords 25',major=true})
 S.Add(c,'milestone',t+24*3600+1,{subject=c.id,milestoneType='skill',skillID=43,skillName='Swords',before=25,after=26,title='Swords 26'})
 S.Add(c,'auction',t+23*3600+5,{auctionID=77,source='owned',auctionData={statusLabel='Reported sold'},title='First sale observation'})
 S.Add(c,'crafted',t+23*3600+10,{recipient=c.id,itemID=123,quantity=2,title='Thing'})
 S.Add(c,'crafted',t+24*3600+10,{recipient=c.id,itemID=123,quantity=3,title='Thing'})
 drain(t+26*3600)
 assert(not saved('daily','2026-12-28')and not saved('weekly','2026-12-22'))
 assert(D.Generate(c,'daily:2026-12-29',t+86400,t+172800,'Current',{periodKind='daily'})==nil)
 local majors=0;for _,r in pairs(c.records)do if r.kind=='recap'and r.periodKind=='milestone'then majors=majors+1 end end
 assert(majors==1,'closed milestone remains immediate')
 local first,last=A.Period(t,'monthly')
 local legacy=S.Add(c,'recap',t,{key='monthly:2026-12-01',periodKind='monthly',from=first,through=last,
  inProgress=true,generation=0,read=true,starred=true,title='Legacy unfinished month',text='Old unfinished text',facts={}})
 c.state.recaps[legacy.key]=legacy.id;S.Note(c,'record:'..legacy.id,'Old private note',A.Now())
 local hidden,why=E.JournalViews.Get(c,{kind='monthly',key=legacy.key,from=first,through=t-1},A.Now())
 assert(not hidden and why=='pending-login','saved actual boundary wins over stale requested dates')
 assert(not D.Visible(c,legacy)and legacy.text=='Old unfinished text')
 local interrupted=S.Add(c,'recap',t,{key='daily:2026-12-28',periodKind='daily',from=t,through=A.ShiftDay(t,1),generation=0,title='Interrupted daily',read=true,starred=true})
 c.state.recaps[interrupted.key]=interrupted.id
 assert(not D.Completed(interrupted))


elseif CASE=='day'or CASE=='repeat'then
 drain(now)
 local first=assert(saved('daily','2026-12-28'))
 assert(not saved('daily','2026-12-29')and first.generation==1)
 assert(first.title=='Interrupted daily'and first.read and first.starred and D.Completed(first),'interrupted recap rebuilt on its existing identity')
 if CASE=='day'then
  S.Note(c,'recap:daily:2026-12-28','my own words',A.Now())
  local removed={}
  for id,r in pairs(c.records)do if r.kind=='auction'and r.auctionID==77 then removed[id]=r;c.records[id]=nil end end
  E.Emit('RECORDS_REMOVED',c,removed)
  S.Add(c,'auction',t+26*3600,{auctionID=77,source='owned',auctionData={statusLabel='Reported sold'},title='Later refresh after source expiry'})
 end
 assert(c.notes['recap:daily:2026-12-28'].text=='my own words')
elseif CASE=='dayfinish'then
 drain(now)
 assert(saved('daily','2026-12-29')and saved('monthly','2026-12-01').inProgress)
 local from,through=A.Period(t,'monthly')
 local raw=D.Facts(c,from,through)
 local merged=D.PeriodFacts(c,c,from,through)
 for k,n in pairs(raw.counts)do assert(merged.counts[k]==n,k)end
 assert(merged.activeSeconds==raw.activeSeconds and merged.longestSessionSeconds==raw.longestSessionSeconds)
 local removed={}
 for id,r in pairs(c.records)do
  if r.kind=='play'and r.session=='midnight'or r.kind=='crafted'and r.itemID==123 or r.kind=='milestone'and r.skillID==43 then
   removed[id]=r;c.records[id]=nil
  end
 end
 E.Emit('RECORDS_REMOVED',c,removed)
else
 drain(now)
 local first=assert(saved('daily','2026-12-28'))
 local second=assert(saved('daily','2026-12-29'))
 local month=assert(saved('monthly','2026-12-01'))
 local year=assert(saved('yearly','2026-01-01'))
 assert(month.read and month.starred and c.notes['recap:'..month.key].text=='Old private note')
 assert(not month.inProgress and month.text~='Old unfinished text')
 assert(month.facts.counts.crafted==5 and year.facts.counts.crafted==5)
 assert(month.facts.counts.auctionsSold==1 and year.facts.counts.auctionsSold==1,'saved auction identities deduplicate across daily facts after raw expiry')
 assert(month.facts.activeSeconds==6300 and month.facts.longestSessionSeconds==6300)
 assert(month.facts.skills[1]=='Swords: 24 -> 26 (2 recorded changes)')
 assert(second.facts.activeSeconds==2700 and first.facts.activeSeconds==3600)
 assert(not saved('monthly','2027-02-01')and not saved('yearly','2027-01-01'))
 assert(c.notes['recap:daily:2026-12-28'].text=='my own words')
 if CASE=='late'then assert(D.Facts(c,month.from,month.through).counts.crafted==0,'raw observations expired before this larger recap')end
 local merged=D.PeriodFacts(c,c,month.from,month.through)
 assert(merged.counts.crafted==5 and merged.longestSessionSeconds==6300)
 assert(month.generation==1 and first.generation==1)
end
fire('PLAYER_LOGOUT')
print('PASS completed recap phase '..CASE)
