local R,S,B=E.Artwork,E.Store,E.Book
local c=S.Character('memory-art-owner',{name='Illustrator'});local other=S.Character('memory-art-other',{name='Other'})
local source=S.Add(c,'loot',time(),{zone='Westfall',itemID=2589,quantity=1})
local memory=assert(E.Memories.Create(c,time(),source.id));memory.text='My unchanged words';memory.tags={'A day to remember'}
local before=E.Copy(memory);local original=E.Copy(source)
assert(memory.artMode=='none' and not R.ForRecord(c,memory))
assert(R.SelectMemory(c,memory.id,'fixed','wetlands-03'))
assert(R.ForRecord(c,memory).id=='wetlands-03','memory art can come from another collection')
R.Select(c,'zone:westfall','wf-bread');assert(R.ForRecord(c,memory).id=='wetlands-03','fixed art ignores location changes')
assert(not R.SelectMemory(other,memory.id,'fixed','anywhere-07'),'cannot edit another character memory')
assert(not R.SelectMemory(c,source.id,'fixed','anywhere-07'),'cannot edit historical loot')
assert(not R.SelectMemory(c,memory.id,'fixed','missing-art'),'cannot choose missing art')
assert(not R.SelectMemory(c,memory.id,'invented-mode'))
local revision=c.revision;assert(R.SelectMemory(c,memory.id,'fixed','wetlands-03'));assert(c.revision==revision)
local texture=R.rows['wetlands-03'].texture;R.rows['wetlands-03'].texture=nil
local row,message=R.ForRecord(c,memory);assert(not row and message:find('preserved') and memory.artID=='wetlands-03')
R.rows['wetlands-03'].texture=texture;assert(R.ForRecord(c,memory).id=='wetlands-03')
assert(R.SelectMemory(c,memory.id,'location'));assert(R.ForRecord(c,memory).id=='wf-bread')
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,memory).id=='anywhere-07')
assert(R.SelectMemory(c,memory.id,'none'));assert(not R.ForRecord(c,memory))
assert(E.Same(source,original) and memory.text==before.text and E.Same(memory.refs,before.refs) and memory.ts==before.ts and E.Same(memory.tags,before.tags))
local standalone=assert(E.Memories.Create(c,time()));assert(R.SelectMemory(c,standalone.id,'fixed','anywhere-07'));assert(R.ForRecord(c,standalone).id=='anywhere-07')
assert(R.SelectMemory(c,standalone.id,'location'));assert(not R.ForRecord(c,standalone),'missing location is not invented')
local wetlands=R.MemoryChoices('Wetlands');local locationCount=0
for _,row in ipairs(wetlands)do if row.location=='zone:wetlands'then locationCount=locationCount+1 end end
assert(locationCount==9 and #R.MemoryChoices('no-such-art')==0,'all nine dedicated Wetlands scenes remain searchable')
for _,r in ipairs(R.MemoryChoices())do assert(r.texture)end
B.ChangeCharacter(c.id);B.SetChapter('Memories');E.ArtView.OpenMemoryInline(memory)
assert(B.memoryMode=='memory-art' and B.left.used.artImage==6 and B.right.used.artImage==1)
local function click(page,label)
 for i=1,page.used.artControl or 0 do local f=page.pool.artControl[i];if f.text:GetText()==label then f:Click();return end end
 return TEST_UI_CLICK(label)
end
B.memoryArtQuery='Wetlands';B.Render(true);assert(#E.ArtView.lastMemoryChoices==#wetlands)
local preview=E.ArtView.lastMemoryPreview.id;assert(memory.artMode=='none','preview does not save')
click(B.right,'Use for this memory');assert(memory.artMode=='fixed' and memory.artID==preview)
click(B.left,'Next page');assert(B.memoryArtPage==2 and B.left.used.artImage==math.min(6,#wetlands-6))
click(B.right,'Follow location');assert(memory.artMode=='location')
click(B.right,'No illustration');assert(memory.artMode=='none')
click(B.right,'Use for this memory');assert(memory.artMode=='fixed')
click(B.left,'Back to this memory');assert(B.selected==memory.id and B.memoryMode=='saved' and B.right.used.artImage==1)
E.ArtView.OpenMemoryInline(memory);B.ChangeCharacter(other.id);assert(B.artMemoryID==nil and B.artMemoryCharacter==nil)
assert(memory.text=='My unchanged words' and E.Same(source,original))
B.ChangeCharacter(c.id)
local cookingSearch=R.MemoryChoices('Cooking');local cooking={}
for _,row in ipairs(cookingSearch)do if row.profession=='profession-cooking'then cooking[#cooking+1]=row end end
assert(#cooking==18,'all eighteen Cooking scenes remain selectable alongside matching location callbacks')
assert(not R.SelectMemory(c,standalone.id,'fixed','profession-tailoring-19'),'out-of-range profession slots stay unavailable')
for _,row in ipairs(cooking)do
 assert(row.profession=='profession-cooking' and row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Cooking' and R.Select(c,'zone:westfall',row.id),'profession art can be chosen as a location default')
end
assert(R.SelectMemory(c,standalone.id,'fixed',cooking[1].id));R.Select(c,'zone:westfall','anywhere-07')
assert(R.ForRecord(c,standalone).id==cooking[1].id,'fixed profession artwork survives location choices without requiring a zone')
assert(not R.SelectMemory(other,standalone.id,'fixed',cooking[2].id),'another character cannot change this memory')
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Cooking';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#cookingSearch and B.left.used.artImage==6)
click(B.left,'Next page');click(B.left,'Next page');assert(B.memoryArtPage==3 and B.left.used.artImage==6)
local chosen=E.ArtView.lastMemoryPreview.id;click(B.right,'Use for this memory');assert(standalone.artID==chosen)
click(B.left,'Back to this memory');assert(B.selected==standalone.id and B.right.used.artImage==1)
local fishing=R.MemoryChoices('Fishing');local count=0
for _,row in ipairs(fishing)do
 if row.profession=='profession-fishing'then
  count=count+1;assert(row.location==nil and row.texture and row.thumbnail)
  assert(R.CollectionName(row)=='Fishing' and R.Select(c,'zone:westfall',row.id))
 end
end
assert(count==18,'all eighteen Fishing scenes are selectable')
for n=1,18 do
 local id=string.format('profession-fishing-%02d',n);assert(R.rows[id].texture)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','wf-bread');assert(standalone.artID=='profession-fishing-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-fishing-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Fishing';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#fishing and B.left.used.artImage==6)
for page=2,math.ceil(#fishing/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='The long-jawed yawn';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-fishing-18')
local firstAid=R.MemoryChoices('First Aid');local firstAidCount=0
for _,row in ipairs(firstAid)do if row.profession=='profession-first-aid'then
 firstAidCount=firstAidCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='First Aid' and R.Select(c,'zone:westfall',row.id))
end end
assert(firstAidCount==18,'all eighteen First Aid scenes are selectable')
for n=1,18 do
 local id=string.format('profession-first-aid-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-first-aid-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-first-aid-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='First Aid';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#firstAid and B.left.used.artImage==6)
for page=2,math.ceil(#firstAid/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='The honorary patient';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-first-aid-10')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local alchemy=R.MemoryChoices('Alchemy');local alchemyCount=0
for _,row in ipairs(alchemy)do if row.profession=='profession-alchemy'then
 alchemyCount=alchemyCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Alchemy' and R.Select(c,'zone:westfall',row.id))
end end
assert(alchemyCount==18,'all eighteen Alchemy scenes are selectable')
for n=1,18 do
 local id=string.format('profession-alchemy-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-alchemy-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-alchemy-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Alchemy';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#alchemy and B.left.used.artImage==6)
for page=2,math.ceil(#alchemy/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='The crystal has an audience';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-alchemy-11')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local smith=R.MemoryChoices('Blacksmithing');local smithCount=0
for _,row in ipairs(smith)do if row.profession=='profession-blacksmithing'then
 smithCount=smithCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Blacksmithing' and R.Select(c,'zone:westfall',row.id))
end end
assert(smithCount==18,'all eighteen Blacksmithing scenes are selectable')
for n=1,18 do
 local id=string.format('profession-blacksmithing-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-blacksmithing-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-blacksmithing-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Blacksmithing';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#smith and B.left.used.artImage==6)
for page=2,math.ceil(#smith/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='The anvil gets the last flower';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-blacksmithing-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local enchanting=R.MemoryChoices('Enchanting');local enchantingCount=0
for _,row in ipairs(enchanting)do if row.profession=='profession-enchanting'then
 enchantingCount=enchantingCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Enchanting' and R.Select(c,'zone:westfall',row.id))
end end
assert(enchantingCount==18,'all eighteen Enchanting scenes are selectable')
for n=1,18 do
 local id=string.format('profession-enchanting-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-enchanting-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-enchanting-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Enchanting';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#enchanting and B.left.used.artImage==6)
for page=2,math.ceil(#enchanting/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='A constellation for the workshop';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-enchanting-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local engineering=R.MemoryChoices('Engineering');local engineeringCount=0
for _,row in ipairs(engineering)do if row.profession=='profession-engineering'then
 engineeringCount=engineeringCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Engineering' and R.Select(c,'zone:westfall',row.id))
end end
assert(engineeringCount==18,'all eighteen Engineering scenes are selectable')
for n=1,18 do
 local id=string.format('profession-engineering-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-engineering-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-engineering-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Engineering';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#engineering and B.left.used.artImage==6)
for page=2,math.ceil(#engineering/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='The exhibition of useful things';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-engineering-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local herbalism=R.MemoryChoices('Herbalism');local herbalismCount=0
for _,row in ipairs(herbalism)do if row.profession=='profession-herbalism'then
 herbalismCount=herbalismCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Herbalism' and R.Select(c,'zone:westfall',row.id))
end end
assert(herbalismCount==18,'all eighteen Herbalism scenes are selectable')
for n=1,18 do
 local id=string.format('profession-herbalism-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-herbalism-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-herbalism-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Herbalism';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#herbalism and B.left.used.artImage==6)
for page=2,math.ceil(#herbalism/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='The smallest garden assistant';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-herbalism-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local leatherworking=R.MemoryChoices('Leatherworking');local leatherworkingCount=0
for _,row in ipairs(leatherworking)do if row.profession=='profession-leatherworking'then
 leatherworkingCount=leatherworkingCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Leatherworking' and R.Select(c,'zone:westfall',row.id))
end end
assert(leatherworkingCount==18,'all eighteen Leatherworking scenes are selectable')
for n=1,18 do
 local id=string.format('profession-leatherworking-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-leatherworking-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-leatherworking-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Leatherworking';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#leatherworking and B.left.used.artImage==6)
for page=2,math.ceil(#leatherworking/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery='One more cushion';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-leatherworking-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local mining=R.MemoryChoices('Mining');local miningCount=0
for _,row in ipairs(mining)do if row.profession=='profession-mining'then
 miningCount=miningCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Mining' and R.Select(c,'zone:westfall',row.id))
end end
assert(miningCount==18,'all eighteen Mining scenes are selectable')
for n=1,18 do
 local id=string.format('profession-mining-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-mining-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-mining-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Mining';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#mining and B.left.used.artImage==6)
for page=2,math.ceil(#mining/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery="The apprentice's first pebble";B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-mining-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local skinning=R.MemoryChoices('Skinning');local skinningCount=0
for _,row in ipairs(skinning)do if row.profession=='profession-skinning'then
 skinningCount=skinningCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Skinning' and R.Select(c,'zone:westfall',row.id))
end end
assert(skinningCount==18,'all eighteen Skinning scenes are selectable')
for n=1,18 do
 local id=string.format('profession-skinning-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-skinning-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-skinning-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Skinning';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#skinning and B.left.used.artImage==6)
for page=2,math.ceil(#skinning/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery="The first tidy bundle";B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-skinning-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
local tailoring=R.MemoryChoices('Tailoring');local tailoringCount=0
for _,row in ipairs(tailoring)do if row.profession=='profession-tailoring'then
 tailoringCount=tailoringCount+1;assert(row.location==nil and row.texture and row.thumbnail)
 assert(R.CollectionName(row)=='Tailoring' and R.Select(c,'zone:westfall',row.id))
end end
assert(tailoringCount==18,'all eighteen Tailoring scenes are selectable')
for n=1,18 do
 local id=string.format('profession-tailoring-%02d',n)
 assert(R.SelectMemory(c,standalone.id,'fixed',id));assert(R.ForRecord(c,standalone).id==id)
end
R.Select(c,'zone:westfall','anywhere-07');assert(R.ForRecord(c,standalone).id=='profession-tailoring-18')
assert(not R.SelectMemory(other,standalone.id,'fixed','profession-tailoring-01'))
E.ArtView.OpenMemoryInline(standalone);B.memoryArtQuery='Tailoring';B.Render(true)
assert(#E.ArtView.lastMemoryChoices==#tailoring and B.left.used.artImage==6)
for page=2,math.ceil(#tailoring/6)do click(B.left,'Next page');assert(B.memoryArtPage==page and B.left.used.artImage<=6)end
B.memoryArtQuery="The last stitch celebration";B.Render(true)
assert(#E.ArtView.lastMemoryChoices==1 and B.left.used.artImage==1)
click(B.right,'Use for this memory');assert(standalone.artID=='profession-tailoring-18')
assert(memory.text=='My unchanged words' and E.Same(source,original))
B.memoryMode='saved';B.SetChapter('Chronicle')
print('PASS memory artwork: fixed/follow/none, missing assets, no-location memories, character isolation, source preservation, search, paging and native view controls')
