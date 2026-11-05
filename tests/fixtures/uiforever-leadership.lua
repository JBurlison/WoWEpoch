do
 local id='myepoch-ui-fixture-044'
 if not MyEpochDB.characters[id]then
  local ts=time({year=2026,month=10,day=31,hour=18,min=0,sec=0})
  local c={id=id,identity={name='Aldren',realm='TEST: Leadership',className='Warrior',level=22},seq=1,order={id..':1'},records={},dedup={},retention={},notes={},art={},state={},revision=1}
  local function person(name)return{name=name,realm='TEST: Leadership',intervals={{from=ts,through=ts+1800,ended=ts+1800,firstSequence=1,lastSequence=1}}}end
  local g={id=id..':1',character=id,sequence=1,kind='group',category='groups',ts=ts,title='A shared road through Westfall',zone='Westfall',mapID=52,
   ended=ts+1800,observedThrough=ts+1800,session='synthetic-044',memberships={[id]=person('Aldren'),['Player-Test-Mira']=person('Mira'),['Player-Test-Bram']=person('Bram')},leadership={},refs={}}
  local states={{id,'Aldren'},{'Player-Test-Mira','Mira'},{false},{'Player-Test-Bram','Bram'},{id,'Aldren'},{'Player-Test-Mira','Mira'},{'Player-Test-Bram','Bram'},{id,'Aldren'}}
  for i,p in ipairs(states)do
   local prior=states[i-1]
   g.leadership[i]={from=ts+(i-1)*180,through=ts+(i-1)*180+150,leaderID=p[1]or nil,name=p[2],realm=p[2]and'TEST: Leadership'or nil,
    state=p[1]and'observed'or'unknown',reason=not p[1]and'Some leadership flags were unavailable.'or nil,
    changeObserved=p[1]and prior and prior[1]and true or false,previousLeaderID=p[1]and prior and prior[1]or nil,
    closed=true,closedReason=i==#states and'The character left the group.'or'A different leadership observation followed.',candidates={}}
  end
  g.leadership[3].candidates={{id='Player-Test-Mira',name='Mira',realm='TEST: Leadership'}}
  c.records[g.id]=g;MyEpochDB.characters[id]=c
 end
 print('Synthetic leadership fixture ready; this is illustrative history only.')
end
