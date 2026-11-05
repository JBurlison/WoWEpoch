local R,V,B,S=E.Artwork,E.ArtView,E.Book,E.Store
local c=S.Character('default-art-owner',{name='Keeper'});local other=S.Character('default-art-other',{name='Other'})
local function milestone(fields)
 fields=fields or{};fields.subject=fields.subject or c.id;fields.title=fields.title or'Default artwork';fields.major=fields.major~=false
 return S.Add(c,'milestone',time(),fields)
end
local first=milestone({milestoneType='discovery',zone='Westfall'})
local original=E.Copy(first);local artBefore=E.Copy(c.art);local revision=c.revision
local art=assert(R.ForRecord(c,first));assert(art.location=='zone:westfall')
for i=1,20 do assert(R.ForRecord(c,first)==art)end
assert(E.Same(first,original)and E.Same(c.art,artBefore)and c.revision==revision,'resolving defaults never writes saved history or chosen art')
local pool=R.byLocation['zone:westfall'];local reverse={};for i=#pool,1,-1 do reverse[#reverse+1]=pool[i]end
R.byLocation['zone:westfall']=reverse;assert(R.ForRecord(c,first)==art,'iteration order cannot reroll a saved record');R.byLocation['zone:westfall']=pool
local seen={}
for i=1,32 do local r=milestone({milestoneType='level',after=i+1,zone='Westfall'});seen[R.ForRecord(c,r).id]=true end
local n=0;for _ in pairs(seen)do n=n+1 end;assert(n>3,'different records draw more than one repeated default')
assert(not R.ForRecord(other,first)and not R.ForRecord(c,E.Copy(first))and not R.ForRecord({id=c.id,records=c.records},first))
assert(not R.ForRecord(c,milestone({subject=other.id,zone='Westfall'})),'foreign subject cannot acquire owner decoration')
local replaced=E.Copy(first);c.records[first.id]=replaced
assert(not R.ForRecord(c,first)and R.ForRecord(c,replaced)==art,'same-ID replacement must use the canonical object')
c.records[first.id]=first
local badOwner=milestone({zone='Westfall'});badOwner.character=other.id;assert(not R.ForRecord(c,badOwner))
assert(R.Select(c,'zone:westfall','anywhere-07'));assert(R.ForRecord(c,first)==art)
assert(R.Select(other,'zone:westfall','anywhere-08'));assert(R.ForRecord(c,first)==art,'other characters choices remain isolated')
assert(R.Select(c,'zone:westfall','wf-bread'));assert(R.ForRecord(c,first)==art,'location choices cannot override automatic milestone art')
assert(R.SelectRecord(c,first.id,'fixed','wetlands-03'));assert(R.ForRecord(c,first).id=='wetlands-03')
assert(R.SelectRecord(c,first.id,'none')and not R.ForRecord(c,first)and not R.MilestoneFallback(c,first))
assert(R.SelectRecord(c,first.id,'location'));assert(R.ForRecord(c,first).id=='wf-bread'and not R.MilestoneFallback(c,first))
R.Clear(c,'zone:westfall');assert(not R.ForRecord(c,first),'explicit follow-location keeps its existing no-choice semantics')
assert(R.SelectRecord(c,first.id,'default')and R.ForRecord(c,first)==art)
local savedMissing='missing-location-choice';c.art['zone:westfall']=savedMissing
assert(R.ForRecord(c,first).location=='zone:westfall'and c.art['zone:westfall']==savedMissing,'unavailable location preference preserved while default uses available decoration')
R.Clear(c,'zone:westfall')
local profession=milestone({milestoneType='profession',skillName='Engineering',skillID=202,zone='Uncatalogued place'})
assert(R.ForRecord(c,profession).profession=='profession-engineering')
profession.zone='Westfall';assert(R.ForRecord(c,profession).profession=='profession-engineering','profession illustration is relevant even with a recorded zone')
assert(R.Select(c,'zone:westfall','wf-bread'));assert(R.ForRecord(c,profession).profession=='profession-engineering','default profession art precedes chosen zone decoration')
assert(R.SelectRecord(c,profession.id,'location')and R.ForRecord(c,profession).id=='wf-bread','explicit location overrides profession default')
assert(R.SelectRecord(c,profession.id,'default'));R.Clear(c,'zone:westfall')
profession.zone=nil;profession.skillName='engineering';assert(R.ForRecord(c,profession).type=='Anywhere','no guessed case or localization matches')
profession.skillName='Engineering';R.professions['duplicate-test']={key='duplicate-test',name='Engineering'}
assert(R.ForRecord(c,profession).type=='Anywhere','ambiguous profession identity cannot select a pool');R.professions['duplicate-test']=nil
for _,kind in ipairs({'level','achievement','discovery','completion','death','spell','skill'})do
 local r=milestone({milestoneType=kind,major=false,zone='Unknown'});assert(R.ForRecord(c,r).type=='Anywhere','personal milestone fallback: '..kind)
end
local ambiguous=milestone({zone='Westfall'});R.locations['duplicate-test']={key='duplicate-test',name='Westfall'}
assert(R.ForRecord(c,ambiguous).type=='Anywhere','duplicate location names are not resolved arbitrarily');R.locations['duplicate-test']=nil
local keep=R.rows[art.id];R.rows[art.id]=nil
assert(R.ForRecord(c,first)~=art,'stale pool rows are excluded');R.rows[art.id]=keep
local texture=art.texture;art.texture=nil;assert(R.ForRecord(c,first)~=art);art.texture=texture
local localPool=R.byLocation['zone:westfall'];R.byLocation['zone:westfall']={}
profession.zone='Westfall';assert(R.ForRecord(c,profession).profession=='profession-engineering','empty location pool falls back to matching profession')
assert(R.ForRecord(c,first).type=='Anywhere');R.byLocation['zone:westfall']=localPool
local anywhere=R.anywhere;R.anywhere={};local noArt=milestone({zone='Unknown'});assert(not R.ForRecord(c,noArt));R.anywhere=anywhere
-- Exercise a missing Swords 50 image independently of the shipped art inventory.
local installedTier=R.byWeapon[43][50]
local missingTier=E.Copy(installedTier);missingTier.texture=nil;missingTier.thumbnail=nil
R.byWeapon[43][50]=missingTier;R.rows[missingTier.id]=missingTier
local weapon=milestone({milestoneType='skill',skillID=43,skillName='Swords',thresholds={25,50},zone='Westfall'})
assert(not R.ForRecord(c,weapon)and not R.MilestoneChoices(c,weapon)[2].art)
local generic=assert(R.MilestoneFallback(c,weapon));assert(generic.location=='zone:westfall'and not generic.weapon)
local weaponFacts=E.Copy(weapon);local artChoices=E.Copy(c.art)
B.ChangeCharacter(c.id);B.SetChapter('Chronicle');B.selected=weapon.id;B.Render(true)
TEST_PREPARE_BOOK()
assert(V.weaponSelection.threshold==50 and B.right.used.artImage==1)
assert(B.right.pool.artImage[1].image.texture==generic.texture)
local function label(text)
 for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find(text,1,true)then return true end end
end
assert(label('Decorative artwork · 50-point illustration pending'),'fallback remains visually separate from the exact missing tier')
local function click(text)
 for i=1,B.right.used.artControl or 0 do local f=B.right.pool.artControl[i];if f.text:GetText()==text then f:Click();return end end
 error('Missing control '..text)
end
click('Previous milestone');assert(V.weaponSelection.threshold==25 and B.right.pool.artImage[1].image.texture==R.byWeapon[43][25].texture)
click('Next milestone');assert(V.weaponSelection.threshold==50 and B.right.pool.artImage[1].image.texture==generic.texture)
assert(E.Same(weapon,weaponFacts)and E.Same(c.art,artChoices),'actual painting and selector clicks do not alter source facts or preferences')
assert(R.SelectRecord(c,weapon.id,'none'));B.Render();assert((B.right.used.artImage or 0)==0,'pooled decoration hides after None')
assert(R.SelectRecord(c,weapon.id,'default'));B.Render();assert(B.right.used.artImage==1)
local images=B.right.used.artImage;B.Clear(B.right);V.Record(B.right,other,weapon);assert((B.right.used.artImage or 0)==0,'foreign direct view has no selector or image')
B.Clear(B.right);V.Record(B.right,c,E.Copy(weapon));assert((B.right.used.artImage or 0)==0,'detached direct view has no selector or image')
-- The actual picker can preview restoring a default while an override is saved.
local D=E.ArtDialog
B.selected=weapon.id;assert(R.SelectRecord(c,weapon.id,'fixed','wetlands-03'));B.Render()
D.OpenRecord(weapon);local fixed=E.Copy(weapon)
local function dialogClick(text)
 for i=1,D.right.used.artControl or 0 do local f=D.right.pool.artControl[i];if f.text:GetText()==text then f:Click();return end end
 error('Missing dialog control '..text)
end
dialogClick('Use default');assert(D.IsOpen()and E.Same(weapon,fixed),'preview must not clear the saved override')
assert(V.lastMemoryPreview==generic and D.right.pool.artImage[1].image.texture==generic.texture,'picker uses the same decorative fallback as the milestone')
local pending=false
for i=1,D.right.used.label or 0 do if D.right.pool.label[i]:GetText():find('Decorative artwork · 50-point illustration pending',1,true)then pending=true end end
assert(pending,'default preview does not present fallback as exact weapon artwork')
D.cancel:Click();assert(E.Same(weapon,fixed))
D.OpenRecord(weapon);dialogClick('Use default');D.apply:Click()
assert(not D.IsOpen()and weapon.artMode==nil and not R.ForRecord(c,weapon)and B.right.pool.artImage[1].image.texture==generic.texture)
assert(not R.DefaultMilestone(other,weapon)and not R.DefaultMilestone(c,E.Copy(weapon)))
profession.skillName='Engineering';profession.zone='Westfall'
B.selected=profession.id;assert(R.SelectRecord(c,profession.id,'none'));B.Render();D.OpenRecord(profession);dialogClick('Use default')
assert(V.lastMemoryPreview.profession=='profession-engineering'and profession.artMode=='none');D.cancel:Click()
assert(R.SelectRecord(c,profession.id,'default'))
local root=E.db;local reopened=E.Copy(c);local saved={schema=E.schema,characters={[c.id]=reopened},settings=E.Copy(root.settings),bankOrder=root.bankOrder}
local expected=R.ForRecord(c,first).id;S.Open(saved)
assert(R.ForRecord(reopened,reopened.records[first.id]).id==expected,'reload preserves the automatic draw without new saved fields')
assert(not R.ForRecord(c,first),'stale pre-reload owner rejected');E.db=root
local memory=assert(E.Memories.Create(c,time()));memory.zone='Westfall';assert(not R.ForRecord(c,memory),'new milestone defaults do not silently change memory modes')
assert(not R.ForRecord(c,{zone='Westfall'}),'ordinary location pages retain existing chosen-only behavior')
B.SetChapter('Memories');V.weaponSelection=nil
print('PASS milestone defaults: canonical ownership, stable draws/no writes, explicit modes, exact location/profession/anywhere fallback, missing-tier label/selector, pooled hides and reload')


R.byWeapon[43][50]=installedTier;R.rows[installedTier.id]=installedTier
