-- Synthetic data only. Cleanup controls affect this clearly labeled test character.
do
local id='myepoch-ui-fixture-074'
if not MyEpochDB.characters[id]then
 local now=time();local old=now-100*86400
 local c={id=id,identity={name='Mira',realm='TEST: Retention controls',level=21},seq=0,records={},order={},dedup={},notes={},art={},state={},retention={chat=30,otherNotes=30},revision=1}
 local function add(kind,category,r)
  c.seq=c.seq+1;r.id=id..':'..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.category=category;r.ts=old;r.refs=r.refs or{}
  c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local loose=add('chat','chat',{title='Old unlinked chat',text='Synthetic disposable review example'})
 local linked=add('chat','chat',{title='A remembered conversation',text='This remains protected'})
 add('memory','memories',{title='A starred memory',starred=true,refs={linked.id}})
 c.notes['record:'..loose.id]={text='An old test note eligible under its own policy',updated=old}
 c.notes['record:'..linked.id]={text='Protected supporting note',updated=old}
 c.notes['day:'..date('%Y-%m-%d',old)]={text='Daily notes are still Forever',updated=old}
 MyEpochDB.characters[id]=c
end
print('RETENTION074 synthetic Mira / TEST: Retention controls ready. Automatic cleanup is off. Open Archive to review the test character.')
end
