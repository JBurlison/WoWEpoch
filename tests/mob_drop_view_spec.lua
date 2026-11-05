local B,S,A,V=E.Book,E.Store,E.API,E.MobDropView
local c=S.Character('mob-drop-view-fixture',{name='Mob observer'})
local ts=A.Now()-60
c.state.firstObserved=ts
for i=1,4 do
 local guid='Creature-0-1-2-3-524-000'..i
 local k=S.Add(c,'kill',ts+i,{source='PARTY_KILL',npcID=524,npcName='Rockhide Boar',victimGUID=guid,session='view-test'})
 if i<3 then
  local w=S.Add(c,'loot_window',ts+i,{session='view-test',fromItem=false,fishing=false})
  local r=S.Add(c,'drop',ts+i,{source='loot_window',session='view-test',window=w.id,slot=1,itemID=117,title='Tough Jerky',snapshots={}})
  r.lastSlotSourceIndex=1
  r.snapshots[1]={ts=ts+i,sequence=S.ReserveObservation(c),data={itemID=117,name='Tough Jerky',visibleQuantity=3,slotSources={{guid=guid,npcID=524,name='Rockhide Boar',kind='Creature',quantity=3}}}}
 end
end
local function drain()
 for i=1,1000 do V.Tick();if V.job and V.job.model then return end end
 error('Mob report did not finish: '..tostring(V.lastError))
end
B.ChangeCharacter(c.id);B.SetChapter('Loot');B.lootMode='mob_rates';B.mobDropNPC=524;B.Render();drain()
assert(V.lastReport.killCount==4 and V.lastReport.items[1].ratePercent==50)
assert(B.right.pool.lootBar[1].value:GetText()=='50.0%')
assert(B.right.pool.lootBar[1].meta:GetText():find('2 of 4 recorded kills',1,true))
assert(B.right.pool.lootBar[1].meta:GetText():find('6 items observed',1,true))
B.mobDropItemQuery='nothing';B.Render();drain();assert(V.lastReport.killCount==4 and #V.lastReport.items==0)
B.mobDropItemQuery=nil;B.Render();drain()
local previous=V.job
S.Add(c,'kill',ts+10,{source='PARTY_KILL',npcID=524,npcName='Rockhide Boar',victimGUID='Creature-0-1-2-3-524-0005',session='view-test'})
drain();assert(V.job~=previous and V.lastReport.killCount==5 and V.lastReport.items[1].ratePercent==40)
B.lootMode='drops';B.dropDimension='mob';B.dropBucket='npc:524';B.Render();drain();assert(V.lastReport.killCount==5)
assert(B.right.pool.lootBar[1].value:GetText()=='40.0%')
assert(E.DropView.lastReport.groups['npc:524'].label=='Rockhide Boar')
B.mobDropPreset='today';B.lootMode='mob_rates';B.Render();drain()
local other=S.Character('mob-drop-other',{name='Other'})
B.ChangeCharacter(other.id);B.SetChapter('Loot');B.lootMode='mob_rates';B.Render();drain()
assert(not B.mobDropNPC and #V.job.model.mobs==0,'Character state isolation')
print('PASS mob-drop UI: empirical percentages and quantities, item search preserves denominator, source invalidation, existing mob drill-down, character isolation')
