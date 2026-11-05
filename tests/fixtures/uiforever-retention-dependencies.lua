-- Synthetic saved-state fixture. No gameplay data is pruned.
do
local id='myepoch-ui-fixture-069'
if not MyEpochDB.characters[id]then
 local now=time();local d=date('*t',now-45*86400);d.hour=0;d.min=0;d.sec=0;d.isdst=nil
 local day=time(d);d.day=d.day+1;d.isdst=nil;local finish=time(d)
 d=date('*t',day);d.day=d.day-(d.wday+4)%7;d.isdst=nil;local week=time(d)
 d.day=d.day+7;d.isdst=nil;local weekEnd=time(d)
 local key='weekly:'..date('%Y-%m-%d',week);local dayKey=date('%Y-%m-%d',day)
 local c={id=id,identity={name='Mira',realm='TEST: Expired summaries',level=21},state={firstObserved=day},seq=0,records={},order={},dedup={},notes={},retention={diaries=7,recaps=7,questKills=7},art={},revision=1}
 local function add(kind,category,ts,r)
  c.seq=c.seq+1;r.id=id..':'..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.category=category;r.ts=ts;r.refs=r.refs or{}
  c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local level=add('milestone','milestones',day+100,{title='Character level 20 -> 21',subject=id,milestoneType='level',major=true,before=20,after=21})
 local q=add('quest_attempt','quests',day,{title='A quest whose kill history stays',ended=finish,intervals={{from=day,through=day+300}}})
 local kill=add('kill','questKills',day+200,{title='Synthetic wolf',npcID=1})
 c.state.diaries={};c.state.recaps={}
 c.state.expiredSummaries={diaries={[dayKey]={expiredAt=now,from=day,through=finish}},recaps={
  [key]={expiredAt=now,from=week,through=weekEnd},['milestone:'..level.id]={expiredAt=now,from=day,through=day+100}}}
 c.notes['day:'..dayKey]={text='The generated page expired. These are still my own words.',updated=now}
 c.notes['recap:'..key]={text='I kept my note from that week.',updated=now}
 c.notes['recap:milestone:'..level.id]={text='A small note about a big level.',updated=now}
 c.state.expiryFixture={day=day,key=key,level=level.id,kill=kill.id,quest=q.id}
 MyEpochDB.characters[id]=c
end
print('RETENTION069 synthetic Mira / TEST: Expired summaries ready. Calendar date: '..date('%Y-%m-%d',MyEpochDB.characters[id].state.expiryFixture.day)..'. No gameplay character was pruned.')
end
