local B,S,V,A=E.Book,E.Store,E.PullView,E.API
local c=S.Character('pull-detail-review',{name='Review'});local ts=A.Now()
local spells={{spellID=686,totalAmount=300,target={name='Hogger',isMob=true,amount=300}},{spellID=6603,totalAmount=120,target={name='Hogger',amount=120}}}
local snapshot={totalAmount=606,durationSeconds=47,observedAt=ts,coverage='partial',sources={
 {name='A very patient warlock',totalAmount=420,classFilename='WARLOCK',detail={spells=spells}},
 {name='A helpful rogue',totalAmount=120},{name='A cheerful mage',totalAmount=66},{name='No damage',totalAmount=0}}}
local r=S.Add(c,'pull',ts,{title='Hogger',snapshots={DamageDone={snapshot,E.Copy(snapshot)}},contexts={},gaps={}})
B.ChangeCharacter(c.id);B.chapter='Company';B.companyMode='pulls';B.selected=r.id;B.pullRecord=nil
TEST_PREPARE_BOOK();B.Clear(B.right);V.Record(B.right,c,r)
assert(B.right.used.pullRow==3 and B.right.used.pullStat==3,'compact metrics and ranked rows')
assert(B.right.pool.pullRow[1].text:GetText()=='A very patient warlock')
assert(B.right.pool.pullRow[1].status:GetText()=='420')
assert(B.right.pool.pullRow[1].meta:GetText():find('69.3%%'))
assert(B.right.pool.pullRow[1].open:IsShown())
local function button(text)
 for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()==E.L[text]then return f end end
 error('Missing button: '..text)
end
assert(button('Earlier snapshot'):IsEnabled() and not button('Later snapshot'):IsEnabled())
B.right.pool.pullRow[1].open:Click();assert(B.pullSource==1)
B.Clear(B.right);V.Record(B.right,c,r);assert(B.right.used.pullRow==2 and B.right.pool.pullRow[1].icon:IsShown(),'spells use rows and icons')
assert(B.right.pool.pullRow[1].meta:GetText():find('Hogger',1,true))
button('Back to recorded sources'):Click();button('Earlier snapshot'):Click();assert(B.pullSnapshot==1)
button('Enemy damage taken'):Click();assert(B.pullMeter=='EnemyDamageTaken')
r.snapshots.EnemyDamageTaken={snapshot};B.pullSource=1;B.Clear(B.right);V.Record(B.right,c,r)
local enemyText='';for i=1,B.right.used.label do enemyText=enemyText..B.right.pool.label[i]:GetText()end
assert(enemyText:find('420 '..E.L['Enemy damage taken'],1,true),'Enemy drilldown must label the selected measure')
button('Damage done'):Click();assert(B.pullMeter=='DamageDone')
local labels='';for i=1,B.right.used.label do labels=labels..B.right.pool.label[i]:GetText()end
assert(not labels:find('Fight start',1,true),'technical evidence stays collapsed')
print('PASS combat details: totals, ranked rows, drilldown, icons, compact tabs and stable paging')
