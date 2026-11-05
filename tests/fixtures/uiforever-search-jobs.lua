-- Synthetic retained history for native search responsiveness review only.
do
 local id='myepoch-ui-fixture-045'
 if not MyEpochDB.characters[id]then
  local base=time({year=2026,month=10,day=31,hour=18,min=0,sec=0})
  local c={id=id,identity={name='Mira',realm='TEST: Long Search',className='Mage',level=22},seq=6001,records={},order={},dedup={},notes={},retention={},art={},state={},revision=1}
  local group=id..':1';c.order[1]=group
  c.records[group]={id=group,character=id,sequence=1,kind='group',category='groups',ts=base,title='An evening of campfire stories',ended=base+6000,refs={},memberships={}}
  for i=1,6000 do
   local key=id..':'..(i+1);c.order[i+1]=key
   c.records[key]={id=key,character=id,sequence=i+1,kind='chat',category='chat',ts=base+i,title='Bramble',author='Bramble',authorGUID='Player-Test-Bramble',
    text=i%250==0 and 'Campfire memory '..i..': The chicken had the right of way. We saluted and waited.'or'Campfire story '..i..': Another tale for the journey.',
    group=group,zone='Westfall',refs={group}}
  end
  MyEpochDB.characters[id]=c
 end
 print('Synthetic Mira / TEST: Long Search ready: 6,000 illustrative chat messages.')
end
