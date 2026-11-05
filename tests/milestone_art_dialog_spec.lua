local B,D,V,R,S=E.Book,E.ArtDialog,E.ArtView,E.Artwork,E.Store
local c=S.Character('milestone-dialog-owner',{name='Keeper'});local other=S.Character('milestone-dialog-other',{name='Other'})
local milestone=S.Add(c,'milestone',time(),{title='A level to remember',subject=c.id,milestoneType='level',major=true,before=21,after=22,zone='Westfall'})
local sibling=S.Add(c,'milestone',time()+1,{title='Another Westfall milestone',subject=c.id,milestoneType='achievement',major=true,zone='Westfall'})
local weapon=S.Add(c,'milestone',time()+2,{title='Swords: 20 to 55',subject=c.id,milestoneType='skill',major=true,skillID=43,skillName='Swords',thresholds={25,50},before=20,after=55,zone='Westfall'})
local memory=assert(E.Memories.Create(c,time(),milestone.id))
assert(R.Select(c,'zone:westfall','anywhere-07'))
local locationBefore=E.Copy(c.art);local siblingBefore=E.Copy(sibling);local facts=E.Copy(milestone);local count=#c.order
local function find(page,label,optional)
 for _,kind in ipairs({'artControl','button','memoryControl'})do for i=1,page.used[kind]or 0 do
  local f=page.pool[kind][i];if f.text and f.text:GetText()==label then return f end
 end end
 assert(optional,'Missing entry illustration control: '..label)
end
local function click(label)find(D.right,label):Click()end
local function search(value)local f=D.left.pool.edit[1];f:SetText(value);f.scripts.OnEnterPressed(f)end
local function isolate()
 assert(E.Same(c.art,locationBefore)and E.Same(sibling,siblingBefore),'Entry artwork cannot change the zone default or its sibling')
 assert(#c.order==count,'Decorating an entry cannot create historical records')
 local current=E.Copy(milestone);current.artMode=nil;current.artID=nil
 assert(E.Same(current,facts),'Artwork cannot rewrite milestone facts')
end
local function open(record)
 B.SetChapter('Chronicle');B.selected=record.id;B.Render(true)
 B.left.scroll:SetVerticalScroll(29);B.right.scroll:SetVerticalScroll(43)
end
local function origin(record)
 assert(B.chapter=='Chronicle'and B.selected==record.id,'Picker must return to the originating entry')
 assert(B.left.scroll:GetVerticalScroll()==29 and B.right.scroll:GetVerticalScroll()==43,'Picker must preserve the originating scroll positions')
end
B.Open();B.ChangeCharacter(c.id);open(milestone)
-- The actual header opens the selected milestone, not its shared zone preference.
B.illustrations:Click();assert(D.IsOpen()and D.context.record==milestone)
assert((D.left.used.artTile or 0)==9 and D.left.used.artImage==9)
search('Cooking');assert(D.left.used.artTile==math.min(9,#V.lastMemoryChoices))
local selected=D.left.pool.artTile[2].artID;D.left.pool.artTile[2]:Click()
assert(not milestone.artMode and not milestone.artID and D.IsOpen());isolate()
D.cancel:Click();assert(not D.IsOpen()and not milestone.artMode);origin(milestone);isolate()
-- The real detail button uses the same staged picker and applies only this entry.
find(B.right,'Choose milestone illustration'):Click();assert(D.context.record==milestone)
search('Cooking');selected=D.left.pool.artTile[2].artID;D.left.pool.artTile[2]:Click()
assert(not milestone.artMode);D.apply:Click()
assert(not D.IsOpen()and milestone.artMode=='fixed'and milestone.artID==selected and R.ForRecord(c,milestone)==R.rows[selected])
origin(milestone);isolate()
for _,label in ipairs({'Use default','Follow location','No illustration'})do
 local before=E.Copy(milestone);D.OpenRecord(milestone);click(label)
 assert(E.Same(milestone,before)and D.IsOpen(),'Alternate modes are staged until Apply')
 if label=='Follow location'then assert(V.lastMemoryPreview==R.rows['anywhere-07'])end
 if label=='No illustration'then assert(not V.lastMemoryPreview and (D.right.used.artImage or 0)==0)end
 D.cancel:Click();assert(E.Same(milestone,before));origin(milestone);isolate()
end
D.OpenRecord(milestone);click('Follow location');D.apply:Click()
assert(milestone.artMode=='location'and not milestone.artID and R.ForRecord(c,milestone)==R.rows['anywhere-07']);isolate();origin(milestone)
D.OpenRecord(milestone);click('No illustration');D.apply:Click()
assert(milestone.artMode=='none'and not R.ForRecord(c,milestone));isolate();origin(milestone)
D.OpenRecord(milestone);click('Use default');assert(milestone.artMode=='none');D.apply:Click()
assert(not milestone.artMode and not milestone.artID and R.ForRecord(c,milestone)==R.DefaultMilestone(c,milestone));isolate();origin(milestone)
-- Captured Apply callbacks cannot change another selected entry, a deleted row, or another character.
D.OpenRecord(milestone);local apply=D.apply.scripts.OnClick;B.selected=sibling.id;apply()
assert(not D.IsOpen()and not milestone.artMode);isolate();open(milestone)
D.OpenRecord(milestone);apply=D.apply.scripts.OnClick;c.records[milestone.id]=nil;apply()
assert(not D.IsOpen()and not milestone.artMode and not c.records[milestone.id]);c.records[milestone.id]=milestone;B.Render(true)
D.OpenRecord(milestone);apply=D.apply.scripts.OnClick;B.ChangeCharacter(other.id);apply()
assert(not D.IsOpen()and not milestone.artMode and not next(other.art or{}))
B.ChangeCharacter(c.id);open(milestone);local fresh=D.OpenRecord(milestone);apply()
assert(D.IsOpen()and D.context==fresh and not milestone.artMode);D.cancel:Click();isolate()
-- Restoring automatic art restores the recorded crossed-tier navigator.
open(weapon);V.weaponSelection=nil;B.Render(true)
assert(find(B.right,'Previous milestone',true)or find(B.right,'Next milestone',true),'Automatic weapon artwork exposes recorded thresholds')
find(B.right,'Choose milestone illustration'):Click();search('Cooking');D.apply:Click()
assert(weapon.artMode=='fixed'and not find(B.right,'Previous milestone',true)and not find(B.right,'Next milestone',true),'An explicit override replaces automatic tier artwork')
D.OpenRecord(weapon);click('Use default');assert(weapon.artMode=='fixed');D.apply:Click()
assert(not weapon.artMode and not weapon.artID)
assert(find(B.right,'Previous milestone',true)or find(B.right,'Next milestone',true),'Default restores the crossed-tier navigator')
assert(E.Same(weapon.thresholds,{25,50})and weapon.before==20 and weapon.after==55)
-- The generalized record entry point continues to accept canonical personal memories.
B.SetChapter('Memories');B.memoryMode='saved';B.selected=memory.id;B.Render(true)
assert(D.OpenRecord(memory)and D.context.record==memory);D.cancel:Click()
assert(not D.OpenRecord(sibling and E.Copy(sibling)),'Detached rows cannot be customized')
assert(not D.OpenRecord(S.Add(c,'loot',time(),{zone='Westfall'})),'Ordinary records retain location-based decoration')
-- A source can retain the outdoor zone label while its physical instance selects dungeon art.
local dungeonMemory=S.Add(c,'memory',time(),{title='At the gangplank',zone='Westfall',instanceType='party',instanceMapID=36,artMode='none'})
assert(R.Select(c,'dungeon:the-deadmines','anywhere-08'))
open(dungeonMemory);D.OpenRecord(dungeonMemory);click('Follow location')
assert(V.lastMemoryPreview==R.rows['anywhere-08'] and dungeonMemory.artMode=='none')
local function hasCaption(text)
 for i=1,D.right.used.label or 0 do if D.right.pool.label[i]:GetText()==text then return true end end
end
assert(hasCaption('Location preview · The Deadmines'))
D.apply:Click();D.OpenRecord(dungeonMemory)
assert(V.lastMemoryPreview==R.rows['anywhere-08'] and hasCaption('Following location: The Deadmines'))
click('No illustration');assert(not V.lastMemoryPreview);D.cancel:Click()
assert(dungeonMemory.artMode=='location' and R.ForRecord(c,dungeonMemory)==R.rows['anywhere-08'])
local unplaced=S.Add(c,'memory',time(),{title='An uncertain place',zone='Westfall',instanceLocationUncertain=true,artMode='none'})
open(unplaced);D.OpenRecord(unplaced);click('Follow location')
assert(not V.lastMemoryPreview and hasCaption('No matching location was recorded.'))
D.cancel:Click()
print('PASS milestone illustration dialog: header/detail entry points, nine-tile search staging, Apply/Cancel/default/follow/none, per-entry isolation, stale selection/deletion/character guards, preserved origin and restored weapon tiers')
