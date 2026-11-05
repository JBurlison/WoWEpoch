local R,S=E.Artwork,E.Store
local c=S.Character('level-art-owner',{name='Apprentice',class='MAGE',level=60,faction='Alliance'})
local other=S.Character('level-art-other',{name='Warrior',class='WARRIOR',level=30,faction='Alliance'})
local function milestone(owner,fields)
 fields=fields or{};fields.subject=fields.subject or owner.id;fields.milestoneType=fields.milestoneType or'level'
 fields.title='Character level 2';fields.major=true
 return S.Add(owner,'milestone',time(),fields)
end
local level=assert(R.byCharacterLevel.Alliance[2]);assert(level.texture and level.thumbnail)
assert(R.CollectionName(level)=='Alliance character level 2')
local first=milestone(c,{before=1,after=2,zone='Westfall'})
local original,revision=E.Copy(first),c.revision
assert(R.ForRecord(c,first)==level and R.DefaultMilestone(c,first)==level)
assert(R.ForRecord(other,milestone(other,{after=2}))==level,'shared across classes')
assert(R.Select(c,'zone:westfall','wf-bread'))
assert(R.ForRecord(c,first)==level,'exact level artwork is the level-up default')
assert(R.SelectRecord(c,first.id,'location')and R.ForRecord(c,first).location=='zone:westfall')
assert(R.DefaultMilestone(c,first)==level,'Use default previews without changing override')
assert(first.artMode=='location')
assert(R.SelectRecord(c,first.id,'fixed','anywhere-07')and R.ForRecord(c,first).id=='anywhere-07')
assert(R.SelectRecord(c,first.id,'none')and not R.ForRecord(c,first))
assert(R.SelectRecord(c,first.id,'default')and R.ForRecord(c,first)==level)
local current,artPrefs,rev=E.Copy(first),E.Copy(c.art),c.revision
for i=1,20 do assert(R.ForRecord(c,first)==level and R.DefaultMilestone(c,first)==level)end
assert(E.Same(first,current)and E.Same(c.art,artPrefs)and c.revision==rev,'rendering defaults is read-only')
for _,after in ipairs({1,61,2.5,'2'})do
 local r=milestone(c,{after=after,zone='Westfall'})
 assert(R.ForRecord(c,r).location=='zone:westfall'and R.DefaultMilestone(c,r)==R.ForRecord(c,r),'missing or invalid exact level uses ordinary decoration, never another tier')
end
for _,faction in ipairs({'Alliance','Horde'})do
 local seen={}
 for attained=2,5 do
  local art=assert(R.byCharacterLevel[faction][attained]);assert(art.texture and art.thumbnail,'Generated faction-level artwork must be exported')
  local record=milestone(c,{before=attained-1,after=attained,faction=faction,zone='Westfall'})
  assert(R.ForRecord(c,record)==art and R.DefaultMilestone(c,record)==art,'Exact recorded faction/attained-level default')
  assert(not seen[art.texture],'Each attained level has its own image');seen[art.texture]=true
  local opposite=faction=='Alliance'and'Horde'or'Alliance'
  assert(art.texture~=R.byCharacterLevel[opposite][attained].texture,'Factions have distinct scenes at each level')
 end
end
assert(R.ForRecord(c,milestone(c,{zone='Westfall'})).location=='zone:westfall','title and current character level do not infer historical level')
assert(R.ForRecord(c,milestone(c,{after=2,milestoneType='discovery',zone='Westfall'})).location=='zone:westfall')
assert(not R.ForRecord(other,first)and not R.DefaultMilestone(other,first))
assert(not R.ForRecord(c,E.Copy(first))and not R.DefaultMilestone(c,E.Copy(first)))
local texture=level.texture;level.texture=nil
assert(R.ForRecord(c,first).location=='zone:westfall'and R.DefaultMilestone(c,first)==R.ForRecord(c,first));level.texture=texture
local row=R.rows[level.id];R.rows[level.id]=nil
assert(R.ForRecord(c,first).location=='zone:westfall');R.rows[level.id]=row
local found=false;for _,r in ipairs(R.MemoryChoices('Alliance character level 2'))do if r==level then found=true end end
assert(found,'All artwork picker includes level art with searchable level labels')
local horde=milestone(c,{after=2,faction='Horde',zone='Westfall'})
local hordeArt=assert(R.byCharacterLevel.Horde[2]);local hordeTexture=hordeArt.texture
hordeArt.texture='TEST-horde-level-2'
assert(R.ForRecord(c,horde)==hordeArt and R.DefaultMilestone(c,horde)==hordeArt,'recorded Horde faction precedes current Alliance identity')
hordeArt.texture=nil
assert(R.ForRecord(c,horde).location=='zone:westfall','a recorded faction takes priority; missing Horde artwork never defaults to Alliance')
hordeArt.texture=hordeTexture
assert(R.SelectRecord(c,horde.id,'fixed',level.id)and R.ForRecord(c,horde)==level,'manual overrides may use either faction')
local unknown=S.Character('level-art-unknown',{name='Unknown faction'})
assert(R.ForRecord(unknown,milestone(unknown,{after=2})).type=='Anywhere','unknown faction is never guessed')
local factionFn=UnitFactionGroup
UnitFactionGroup=function(unit)assert(unit=='player');return 'Alliance','Localized Alliance'end
assert(E.API.Faction('player')=='Alliance')
local oldCurrent,oldMilestone=E.current,E.Collectors.Milestone
E.current=c;c.state.level=1;local captured
E.Collectors.Milestone=function(kind,title,ts,data,key)captured=data;assert(kind=='level'and key=='level:2')end
E.Collectors.handlers.PLAYER_LEVEL_UP(2)
assert(captured.after==2 and captured.before==1 and captured.faction=='Alliance','actual event handler records observed faction with the attained level')
E.Collectors.Milestone=oldMilestone;E.current=oldCurrent
UnitFactionGroup=function()return 'Horde'end;assert(E.API.Faction('player')=='Horde')
UnitFactionGroup=function()return 'Neutral'end;assert(E.API.Faction('player')==nil)
UnitFactionGroup=function()error('unavailable')end;assert(E.API.Faction('player')==nil)
UnitFactionGroup=nil;assert(E.API.Faction('player')==nil);UnitFactionGroup=factionFn
print('character_level_art_spec: passed')
