local R,V,B,S=E.Artwork,E.ArtView,E.Book,E.Store
assert(#E.ArtCatalog.weapons==16)
for _,weapon in ipairs(E.ArtCatalog.weapons)do
 local row=assert(R.byWeapon[weapon.skillLineID][25])
 assert(row.weapon==weapon.key and row.milestone==25 and row.location==nil and row.profession==nil)
 for points=25,300,25 do
  local tier=assert(R.byWeapon[weapon.skillLineID][points])
  assert(tier.id==weapon.key..'-'..string.format('%03d',points) and tier.slot==points/25)
 end
 assert(not R.byWeapon[weapon.skillLineID][325],"no illustration beyond the curated range")
end
local c=S.Character('weapon-art-owner',{name='Apprentice'});local other=S.Character('weapon-art-other',{name='Other'})
local record=S.Add(c,'milestone',time(),{title='Swords: 20 -> 55',skillID=43,skillName='Swords',subject=c.id,milestoneType='skill',major=true,before=20,after=55,thresholds={50,25,25},zone='Westfall'})
local original=E.Copy(record);local orderCount=#c.order
local original25,original50=R.byWeapon[43][25],R.byWeapon[43][50]
-- Preserve the missing-exact-tier regression when this tier ships artwork.
local missing50=E.Copy(original50);missing50.texture=nil;missing50.thumbnail=nil
R.byWeapon[43][50]=missing50;R.rows[missing50.id]=missing50
local art25=E.Copy(original25);art25.texture=R.rows['anywhere-07'].texture;art25.thumbnail=R.rows['anywhere-07'].thumbnail
R.byWeapon[43][25]=art25;R.rows[art25.id]=art25
local choices=R.MilestoneChoices(c,record)
assert(#choices==2 and choices[1].milestone==25 and choices[1].art==art25 and choices[2].milestone==50 and not choices[2].art)
assert(#R.MilestoneChoices(other,record)==0,"another character's milestones never receive these decorations")
local before=E.Copy(record);before.thresholds=nil;assert(#R.MilestoneChoices(c,before)==0,"rank alone is not milestone evidence")
before=E.Copy(record);before.major=false;assert(#R.MilestoneChoices(c,before)==0)
before=E.Copy(record);before.milestoneType='profession';assert(#R.MilestoneChoices(c,before)==0)
before=E.Copy(record);before.skillID=9999;assert(#R.MilestoneChoices(c,before)==0)
before=E.Copy(record);before.thresholds={0,-25,26,'25',math.huge,25};assert(#R.MilestoneChoices(c,before)==1)
assert(R.Select(c,'zone:westfall','anywhere-07'));assert(not R.ForRecord(c,record),"missing highest tier cannot become lower-tier or location art")
before=E.Copy(record);before.thresholds={25};assert(not R.ForRecord(c,before),'detached milestones cannot receive character artwork')
local thresholds=record.thresholds;record.thresholds={25};local resolved,warning=R.ForRecord(c,record);assert(resolved==art25 and warning==nil);record.thresholds=thresholds
assert(R.Select(c,'zone:westfall',art25.id),"weapon artwork can decorate a location without awarding a milestone")
local memory=assert(E.Memories.Create(c,time()));assert(R.SelectMemory(c,memory.id,'fixed',art25.id))
assert(R.ForRecord(c,memory)==art25 and #R.MemoryChoices('Swords 25')>=1)
assert(not R.SelectMemory(other,memory.id,'fixed',art25.id))
B.ChangeCharacter(c.id);B.SetChapter('Chronicle');B.selected=record.id;B.Render(true)
TEST_PREPARE_BOOK()
assert(V.weaponSelection.threshold==50 and B.right.used.artImage==1,'a separate decorative fallback does not fill the missing exact tier')
local missingLabel=false
for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find('Decorative artwork · 50-point illustration pending',1,true)then missingLabel=true end end
assert(missingLabel,'missing exact tier remains explicitly labeled beside decorative fallback')
local function click(label)
 for i=1,B.right.used.artControl or 0 do local f=B.right.pool.artControl[i];if f.text:GetText()==label then f:Click();return end end
 error('Missing weapon milestone control: '..label)
end
click('Previous milestone');assert(V.weaponSelection.threshold==25)
assert(B.right.pool.artImage[1].image.texture==art25.texture)
local allocated=#B.right.pool.artImage
for i=1,12 do click('Next milestone');click('Previous milestone')end
assert(#B.right.pool.artImage==allocated and B.right.used.artImage==1,"milestone switches reuse one image frame")
local art50=E.Copy(art25);art50.id='weapon-skill-43-050';art50.milestone=50;art50.texture=R.rows['anywhere-08'].texture
R.byWeapon[43][50]=art50;R.rows[art50.id]=art50
click('Next milestone');assert(B.right.pool.artImage[1].image.texture==art50.texture,"exact upper-tier art, never a lower-tier substitute")
local otherRecord=S.Add(other,'milestone',time(),{title='Other swords',skillID=43,subject=other.id,milestoneType='skill',major=true,thresholds={25}})
B.ChangeCharacter(other.id);B.SetChapter('Chronicle');B.selected=otherRecord.id;B.Render(true)
TEST_PREPARE_BOOK()
assert(V.weaponSelection.character==other.id and V.weaponSelection.threshold==25)
B.ChangeCharacter(c.id);B.selected=record.id;B.Render(true);assert(V.weaponSelection.threshold==50)
record.thresholds={25};S.Changed(c,record);B.Render();assert(V.weaponSelection.threshold==25,"removed selection resolves only to a currently recorded threshold")
record.thresholds=E.Copy(original.thresholds);S.Changed(c,record)
assert(#c.order==orderCount+1 and E.Same(record,original),"decoration does not create milestones or rewrite their facts")
R.byWeapon[43][25]=original25;R.rows[art25.id]=original25;R.byWeapon[43][50]=original50;R.rows[art50.id]=original50
V.weaponSelection=nil;B.SetChapter('Memories')
print('PASS weapon artwork: explicit tiers, own recorded thresholds, exact/missing artwork, bounded switches, character isolation and unchanged facts')
