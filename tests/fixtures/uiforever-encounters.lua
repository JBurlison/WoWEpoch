-- Synthetic encounter history for native layout review. Not shipped or observed gameplay.
do
local id='myepoch-ui-fixture-039'
if not MyEpochDB.characters[id]then
 local base=time()-7200
 local c={id=id,identity={name='Aldren',realm='TEST: Encounters',level=22},state={level=22,firstObserved=base},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,title,offset,data)
  c.seq=c.seq+1;local r=data or {};r.id=id..':'..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.title=title;r.ts=base+offset;r.refs=r.refs or {}
  r.category=({group='groups',encounter='groups',milestone='milestones',chat='chat'})[kind]
  c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local function member(name)return {name=name,realm='Sample realm',nameKnown=true,intervals={{from=base,through=base+4200,firstSequence=1,lastSequence=99999,ended=base+4200}}}end
 local g=add('group','A patient crew — synthetic encounter review',0,{zone='The Deadmines',mapID=291,ended=base+4200,observedThrough=base+4200,
  memberships={[id]=member('Aldren'),['Player-Test-Rook']=member('Rook'),['Player-Test-Merrin']=member('Merrin')},gaps={}})
 local first
 local function observation(phase,offset,success)
  local data={group=g.id,refs={g.id},subject=id,encounterID=990039,encounterName='Captain Copperkettle',phase=phase,session='synthetic-039',zone='The Deadmines',mapID=291,
   coverage='Synthetic example; not observed gameplay.',source=phase=='boss' and 'BOSS_KILL' or phase=='start' and 'ENCOUNTER_START' or 'ENCOUNTER_END'}
  if phase~='boss' then data.difficultyID=1;data.reportedGroupSize=3 end
  data.success=success;data.outcome=phase=='start' and 'start observed' or phase=='boss' and 'boss defeat reported' or success==1 and 'success reported' or 'no success reported'
  return add('encounter',(phase=='start' and 'Encounter started: ' or phase=='boss' and 'Boss defeat reported: ' or success==1 and 'Encounter victory: ' or 'Encounter ended: ')..data.encounterName,offset,data)
 end
 for i=1,4 do
  local start=observation('start',i*500);local finish=observation('end',i*500+120,i==1 and 0 or 1)
  start.endObservation=finish.id;start.refs[#start.refs+1]=finish.id;finish.startObservation=start.id;finish.refs[#finish.refs+1]=start.id
  finish.pairing='Inferred from the current session, matching encounter/difficulty IDs and event order; no unique attempt ID is supplied.';start.pairing=finish.pairing
  if i>1 then observation('boss',i*500+121);first=first or finish end
 end
 local lost=observation('start',3200);lost.title='Encounter started: The unfinished lookout';lost.encounterName='The unfinished lookout';lost.encounterID=990040
 lost.continuity='Recording resumed after an observation gap; the encounter outcome is unknown.';lost.observationStoppedAt=base+3300
 local m=add('milestone','First recorded victory: Captain Copperkettle',1120,{group=g.id,refs={g.id,first.id},subject=id,major=true,milestoneType='encounter',encounterID=990039,
  encounterName='Captain Copperkettle',difficultyID=1,sourceRecord=first.id,zone='The Deadmines',mapID=291,observationSequence=first.sequence,
  coverage='First victory notification recorded for this encounter ID, across difficulties. Earlier history and individual contribution are unknown.'})
 c.state.encounterVictories={[990039]={ts=first.ts,source=first.id,milestone=m.id}}
 add('chat','Rook',1122,{group=g.id,refs={g.id},author='Rook',authorGUID='Player-Test-Rook',channel='PARTY',text='That was worth the practice. Nice teamwork!'} )
 add('chat','Merrin',1124,{group=g.id,refs={g.id},author='Merrin',authorGUID='Player-Test-Merrin',channel='PARTY',text='Celebration biscuits for everyone.'})
 c.notes['record:'..first.id]={text='We stayed patient and found our rhythm.',updatedAt=base+1200}
 MyEpochDB.characters[id]=c
end
print('Synthetic Aldren / TEST: Encounters added. Boss, outcome and chat records are illustrative, not observed gameplay.')
end
