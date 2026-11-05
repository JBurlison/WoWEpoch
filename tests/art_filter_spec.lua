local R,D,B,V,S=E.Artwork,E.ArtDialog,E.Book,E.ArtView,E.Store
local total=0
for _,category in ipairs(R.FilterCategories)do if category.key~='all'then
 local rows=R.MemoryChoices('',category.key);assert(#rows>0,category.name..' has bundled choices')
 total=total+#rows
 for _,row in ipairs(rows)do assert(R.FilterIdentity(row)==category.key and row.texture)end
end end
assert(total==#R.MemoryChoices(),'Categories partition the available catalog')
local c=S.Character('art-filter-owner',{name='Filter Test'})
local record=S.Add(c,'milestone',time(),{subject=c.id,major=true,milestoneType='level',after=2,zone='Westfall'})
B.Open();B.ChangeCharacter(c.id);B.SetChapter('Chronicle');B.selected=record.id;B.Render(true)
local before=E.Copy(record);local revision=c.revision
local context=D.OpenRecord(record)
local function choose(label)
 for _,f in ipairs(D.filterButtons)do
  local value=f.text:GetText():gsub('^%s+','')
  if f:IsShown()and(value==label or value:sub(1,#label+2)==label..' ('or value:sub(1,#label+3)==label..'  [')then f:Click();return end
 end
 error('Missing filter: '..label)
end
local function category(label)
 D.category:Click();choose(label)
end
local function search(value)
 local input=D.filterInput;input:SetText(value);input.scripts.OnTextChanged(input,true)
end
D.left.pool.artTile[2]:Click()
local pending=context.pending;local preview=context.memoryArtPreview;local tile=D.left.pool.artTile[1].artID
local pageLabel=D.pageLabel:GetText();D.left.scroll:SetVerticalScroll(23);D.right.scroll:SetVerticalScroll(37)
D.category:Click();choose('Locations')
assert(D.filterOverlay:IsShown()and D.filterExpanded=='locations'and context.artCategory==nil)
assert(D.left.pool.artTile[1].artID==tile and context.memoryArtPreview==preview and context.pending==pending)
assert(D.pageLabel:GetText()==pageLabel and D.left.scroll:GetVerticalScroll()==23 and D.right.scroll:GetVerticalScroll()==37,'Dropdown preserves picker contents and scroll')
assert(#D.filterRows>10 and #D.filterButtons==10)
D.filterDown:Click();assert(D.filterOffset>0)
D.filterPanel.scripts.OnMouseWheel(D.filterPanel,3);assert(D.filterOffset==0)
choose('Locations');assert(D.filterExpanded==nil and #D.filterRows==#R.FilterCategories,'Locations collapse inline')
D.filterDismiss:Click();assert(not D.filterOverlay:IsShown()and D.IsOpen()and context.pending==pending)
D.category:Click();D.filterInput.scripts.OnEscapePressed(D.filterInput)
assert(not D.filterOverlay:IsShown()and D.IsOpen()and context.pending==pending,'Escape in dropdown preserves picker')
category('Generic');assert(context.artCategory=='generic'and context.memoryArtPage==1)
assert(#V.lastMemoryChoices==#R.MemoryChoices('','generic'))
D.next:Click();assert(context.memoryArtPage==2)
category('Character levels');assert(D.filterOverlay:IsShown()and D.filterExpanded=='levels')
local function children()
 local list={}
 for _,row in ipairs(D.filterRows)do if row.category=='levels'and row.child then list[#list+1]=row.tag end end
 return table.concat(list,',')
end
assert(children()=='all,faction:Horde,faction:Alliance','The level branch orders All, Horde and Alliance')
search('Character levels');assert(children()=='all,faction:Horde,faction:Alliance')
search('All character levels')
choose('All character levels');assert(context.memoryArtPage==1 and context.artTag=='all')
assert(D.category.text:GetText():find('Character levels / All character levels',1,true))
for _,row in ipairs(V.lastMemoryChoices)do assert(row.characterLevel)end
local allLevels=#V.lastMemoryChoices;local factionTotal=0
for _,faction in ipairs({'Horde','Alliance'})do
 D.category:Click();choose(faction)
 assert(context.artCategory=='levels'and context.artTag=='faction:'..faction and context.memoryArtPage==1)
 assert(D.category.text:GetText():find('Character levels / '..faction,1,true))
 assert(#V.lastMemoryChoices==59);factionTotal=factionTotal+#V.lastMemoryChoices
 local available={}
 for _,row in ipairs(V.lastMemoryChoices)do assert(row.faction==faction);available[row.characterLevel]=true end
 for level=2,60 do assert(available[level])end
 D.next:Click();assert(context.memoryArtPage==2)
 for i=1,D.left.used.artTile do assert(R.rows[D.left.pool.artTile[i].artID].faction==faction)end
end
assert(allLevels==118 and factionTotal==allLevels,'Both factions together cover levels 2 through 60')
D.category:Click();choose('Character levels');assert(D.filterExpanded==nil,'Level children collapse inline')
search('Alliance');choose('Alliance');assert(context.artTag=='faction:Alliance','Dropdown search finds faction children')
category('Professions & skills');assert(D.filterOverlay:IsShown()and context.artCategory=='levels')
search('Cooking');choose('Cooking')
assert(context.artTag=='profession:profession-cooking'and context.memoryArtPage==1)
for _,row in ipairs(V.lastMemoryChoices)do assert(row.profession=='profession-cooking')end
local input=D.left.pool.edit[1];input:SetText('no-such-scene');input.scripts.OnEnterPressed(input)
assert(#V.lastMemoryChoices==0 and not context.pending)
D.apply:Click();assert(D.IsOpen()and E.Same(record,before)and c.revision==revision)
D.cancel:Click();assert(E.Same(record,before))
context=D.OpenLocation('zone:westfall');category('Locations')
search('Westfall');choose('Westfall')
assert(context.artCollection=='catalog'and context.artTag=='location:zone:westfall')
for _,row in ipairs(V.lastChoices)do assert(row.location=='zone:westfall')end
assert(D.left.used.artTile<=9 and D.left.y<=D.left.scroll:GetHeight(),'Filters retain nine-tile layout')
D.category:Click();local stale=D.filterButtons[1].scripts.OnClick
D.cancel:Click();local fresh=D.OpenRecord(record);stale()
assert(D.context==fresh and fresh.artCategory==nil,'Old filter selection cannot change a new picker')
assert(not c.art or not next(c.art),'Filtering never saves a location choice')
D.cancel:Click()
c.identity.faction='Alliance';context=D.OpenRecord(record);category('Character levels');choose('Horde')
D.left.pool.artTile[1]:Click();local chosen=context.memoryArtPreview;assert(R.rows[chosen].faction=='Horde')
D.apply:Click();assert(not D.IsOpen()and record.artID==chosen,'An Alliance character can still apply Horde artwork')
local duel=assert(R.rows['weapon-skill-43-300'])
local function containsScene(rows)
 for _,row in ipairs(rows)do if row==duel then return true end end
end
for _,phrase in ipairs({duel.mob,duel.sceneZone,duel.combatAction})do
 assert(containsScene(R.Choices('zone:westfall','catalog',phrase:upper(),'skills','weapon:'..duel.weapon)))
 assert(not containsScene(R.MemoryChoices(phrase,'levels')))
end
context=D.OpenRecord(record)
local sceneSearch=D.left.pool.edit[1]
sceneSearch:SetText(duel.combatAction);sceneSearch.scripts.OnEnterPressed(sceneSearch)
assert(V.lastMemoryPreview==duel and record.artID==chosen,'Finding a fight only previews the painting')
local caption=R.CollectionName(duel).." · "..duel.mob.." · "..duel.sceneZone
local seenCaption=false
for i=1,D.right.used.label do
 if D.right.pool.label[i]:GetText()==caption then seenCaption=true end
end
assert(seenCaption,'The preview identifies the skill, opponent and setting')
D.cancel:Click()
print('PASS art filters: inline expansion/collapse, dropdown search/scroll/dismissal, preserved preview, category/tag/search intersection, page reset, nine tiles, empty Apply, cancel and stale context isolation')
