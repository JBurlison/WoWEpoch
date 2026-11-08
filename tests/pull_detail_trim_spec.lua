local B,S,V,A,P=E.Book,E.Store,E.PullView,E.API,E.Pulls
local c=S.Character('pull-detail-trim',{name='Trim'});local base=A.Now()-100000
local function fight(i,data)
 local spells={{spellID=686,totalAmount=300,target={name='Defias Thug',isMob=true,amount=300}}}
 local snapshot={totalAmount=420,durationSeconds=20,observedAt=base+i*60,sources={
  {name='Warlock',sourceGUID='Player-1',totalAmount=420,detail={totalAmount=420,coverage='observed',spells=spells}},
  {name='Rogue',totalAmount=0}}}
 local enemy={totalAmount=420,observedAt=base+i*60,sources={{name='Defias Thug',sourceCreatureID=95,totalAmount=420,detail={spells=E.Copy(spells)}}}}
 local r=S.Add(c,'pull',base+i*60,{title='Fight '..i,observedThrough=base+i*60+20,snapshots={DamageDone={snapshot},EnemyDamageTaken={enemy}},contexts={},gaps={},refs={}})
 for k,v in pairs(data or{})do r[k]=v end
 return r
end
local pulls={}
for i=1,60 do pulls[i]=fight(i)end
-- Protected older fights: starred, noted, memory-linked and a boss encounter.
pulls[2].starred=true
S.Note(c,pulls[3].id,'A fight worth remembering',base)
S.Add(c,'memory',base+200,{title='That fight',text='',tags={},refs={pulls[4].id}})
S.Add(c,'encounter',base+5*60+10,{encounterID=1,encounterName='Boss',phase='start',title='Encounter started: Boss'})
local revision=c.revision
local touches=0;E.On('HISTORY_TOUCHED',function(owner,receipt)if owner==c and receipt.reason=='pullDetailTrim'then touches=touches+1 end end)
P.StartTrim()
local steps=0;while not P.TrimStep(50)do steps=steps+1;assert(steps<20000)end
assert(steps>1,'trimming is spread across frames')
local function spellsOf(r)return r.snapshots.DamageDone[1].sources[1].detail.spells end
local function trimmed(r)return r.snapshots.DamageDone[1].sources[1].detail.spellsTrimmed end
-- The ten oldest fights are outside the newest 50; four of them are protected.
for _,i in ipairs({1,6,7,8,9,10})do
 local r=pulls[i];assert(spellsOf(r)==nil and trimmed(r),'old ordinary fight '..i..' trimmed')
 assert(r.snapshots.EnemyDamageTaken[1].sources[1].detail.spells==nil)
 local source=r.snapshots.DamageDone[1].sources[1]
 assert(source.totalAmount==420 and source.detail.totalAmount==420 and source.sourceGUID=='Player-1','totals and identities stay')
end
for _,i in ipairs({2,3,4,5})do assert(spellsOf(pulls[i])and not trimmed(pulls[i]),'protected fight '..i..' keeps detail')end
for i=11,60 do assert(spellsOf(pulls[i]),'recent fight '..i..' keeps detail')end
assert(touches==1 and c.revision==revision+1,'one history notice for the batch')
-- A second pass finds nothing new to trim.
P.StartTrim();while not P.TrimStep(1000)do end;assert(touches==1)
-- The fight page explains trimmed detail instead of claiming none was recorded.
B.ChangeCharacter(c.id);B.chapter='Company';B.companyMode='pulls';B.selected=pulls[1].id;B.pullRecord=nil
TEST_PREPARE_BOOK();B.Clear(B.right);V.Record(B.right,c,pulls[1])
B.pullSource=1;B.Clear(B.right);V.Record(B.right,c,pulls[1])
local text='';for i=1,B.right.used.label do text=text..B.right.pool.label[i]:GetText()end
assert(text:find(E.L['Spell details are kept for boss encounters, starred or noted fights and the 50 most recent fights.'],1,true))
assert(not text:find(E.L['No spell details were recorded.'],1,true))
print('PASS fight detail trimming: old ordinary fights keep totals without spell rows; starred, noted, memory-linked, boss and newest 50 fights keep detail; one notice; trimmed message')
