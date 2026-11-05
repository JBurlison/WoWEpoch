local _,E=...
local X,A={},E.API;E.MilestoneSnapshot=X
local function pack(...)return {n=select('#',...),...}end
local function number(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge and v or nil end
local function integer(v,min)return number(v)and v%1==0 and v>=min and v<=2147483647 and v or nil end
local function text(v,max)return type(v)=='string'and #v>0 and #v<=(max or 256)and v or nil end
local function call(name,fn,...)
 local key='milestoneSnapshot.'..name
 local values=pack(A.Call(key,fn,...))
 return values,A.status[key]=='call succeeded; client behavior still needs validation'
end
local slots={'Head','Neck','Shoulders','Shirt','Chest','Waist','Legs','Feet','Wrists','Hands','Finger 1','Finger 2','Trinket 1','Trinket 2','Back','Main hand','Off hand','Ranged','Tabard'}
local professions={[171]=true,[164]=true,[333]=true,[202]=true,[182]=true,[165]=true,[186]=true,[393]=true,[197]=true,[185]=true,[129]=true,[356]=true}
local function equipment(out)
 local observed=0
 for slot,label in ipairs(slots)do
  local row={slot=slot,slotName=label,status='unavailable'};out.equipment[#out.equipment+1]=row
  local before,ok=call('equipmentID',GetInventoryItemID,'player',slot)
  local link,linkOK=call('equipmentLink',GetInventoryItemLink,'player',slot)
  local icon=call('equipmentIcon',GetInventoryItemTexture,'player',slot)
  local quality=call('equipmentQuality',GetInventoryItemQuality,'player',slot)
  local durability=call('equipmentDurability',GetInventoryItemDurability,slot)
  local after,afterOK=call('equipmentID',GetInventoryItemID,'player',slot)
  local again,againOK=call('equipmentLink',GetInventoryItemLink,'player',slot)
  local id=integer(before[1],1)
  if ok and afterOK and before[1]==after[1]then
   if before[1]==nil and (not linkOK or link[1]==nil)then row.status='empty';observed=observed+1
   elseif id then
    local saved=text(link[1],4096);local linkedID=saved and tonumber(saved:match('|Hitem:(%d+)')or saved:match('^item:(%d+)'))
    local stable=not linkOK or not againOK or link[1]==again[1]
    if stable and (not saved or linkedID==id)then
     row.status='equipped';row.itemID=id;observed=observed+1
     if linkOK and againOK and saved and linkedID==id then row.link=saved;row.name=text(saved:match('|h%[(.-)%]|h'))end
     row.icon=integer(icon[1],1)or text(icon[1],512);row.quality=integer(quality[1],0)
     row.durability=number(durability[1]);row.maxDurability=number(durability[2])
    end
   end
  end
 end
 out.coverage.equipment=observed..' of 19 equipment slots observed. Missing item links cannot reproduce instance-specific details.'
end
local function stats(out)
 local known=0
 local function add(key,label,value,unit)
  value=number(value);out.stats[#out.stats+1]={key=key,label=label,value=value,unit=unit}
  if value~=nil then known=known+1 end
 end
 local function one(name,label,fn,unit,...)
  local v=call(name,fn,...);add(name,label,v[1],unit);return v
 end
 one('health','Health',UnitHealth,nil,'player');one('maxHealth','Maximum health',UnitHealthMax,nil,'player')
 local power=call('powerType',UnitPowerType,'player');out.powerType=integer(power[1],0);out.powerToken=text(power[2],64)
 one('power','Current '..(out.powerToken or 'power'),UnitPower,nil,'player')
 one('maxPower','Maximum '..(out.powerToken or 'power'),UnitPowerMax,nil,'player')
 for index,label in ipairs({'Strength','Agility','Stamina','Intellect','Spirit'})do
  local v=call('attribute',UnitStat,'player',index)
  add('attribute'..index,label,v[2]);add('attributeBase'..index,label..' (base)',v[1])
  add('attributePositive'..index,label..' (positive modifier)',v[3]);add('attributeNegative'..index,label..' (negative modifier)',v[4])
 end
 local armor=call('armor',UnitArmor,'player');add('armor','Armor',armor[2]);add('armorBase','Armor (base)',armor[1]);add('armorBonus','Armor (bonus)',armor[4])
 -- Use the same client enum as the loaded paper-doll resistance rows.
 for school,label in ipairs({'Physical','Holy','Fire','Nature','Frost','Shadow','Arcane'})do
  local id=A.Plain(Enum and Enum.Damageclass and Enum.Damageclass[label])
  local v=integer(id,0)and call('resistance',UnitResistance,'player',id)or{}
  add('resistance'..school,label..' resistance',v[3]);add('resistanceBase'..school,label..' resistance (base)',v[1])
 end
 for _,entry in ipairs({{'attackPower','Attack power',UnitAttackPower},{'rangedAttackPower','Ranged attack power',UnitRangedAttackPower}})do
  local v=call(entry[1],entry[3],'player');local total
  if number(v[1])and number(v[2])and number(v[3])then total=v[1]+v[2]+v[3]end
  add(entry[1],entry[2],total);add(entry[1]..'Base',entry[2]..' (base)',v[1])
 end
 local damage=call('damage',UnitDamage,'player')
 for i,label in ipairs({'Main-hand minimum damage','Main-hand maximum damage','Off-hand minimum damage','Off-hand maximum damage'})do add('damage'..i,label,damage[i])end
 local speed=call('attackSpeed',UnitAttackSpeed,'player');add('mainSpeed','Main-hand speed',speed[1],'seconds');add('offSpeed','Off-hand speed',speed[2],'seconds')
 local ranged=call('rangedDamage',UnitRangedDamage,'player');add('rangedSpeed','Ranged speed',ranged[1],'seconds');add('rangedMin','Ranged minimum damage',ranged[2]);add('rangedMax','Ranged maximum damage',ranged[3])
 for _,v in ipairs({{'crit','Melee critical strike',GetCritChance},{'rangedCrit','Ranged critical strike',GetRangedCritChance},{'spellCrit','Spell critical strike',GetSpellCritChance},{'dodge','Dodge',GetDodgeChance},{'parry','Parry',GetParryChance},{'block','Block',GetBlockChance},{'meleeHaste','Melee haste',GetMeleeHaste},{'armorPenetration','Armor penetration',GetArmorPenetration}})do one(v[1],v[2],v[3],'%')end
 one('spellHaste','Spell haste',UnitSpellHaste,'%','player')
 local rangedHaste=call('rangedHaste',GetRangedHaste)
 add('rangedHaste','Ranged haste',number(rangedHaste[1])and number(rangedHaste[2])and rangedHaste[1]+rangedHaste[2]or nil,'%')
 local expertise=call('expertise',GetExpertise)
 for i,label in ipairs({'Main-hand expertise','Off-hand expertise','Ranged expertise'})do add('expertise'..i,label,expertise[i],'%')end
 local defense=call('defense',UnitDefenseSkill,'player')
 add('defense','Defense skill',number(defense[1])and number(defense[2])and math.max(0,defense[1]+defense[2])or nil)
 add('defenseBase','Defense skill (base)',defense[1]);add('defenseModifier','Defense skill (modifier)',defense[2])
 one('shieldBlock','Shield block value',GetShieldBlock);one('spellPenetration','Spell penetration',GetSpellPenetration)
 local movement=call('movement',GetUnitSpeed,'player')
 for i,label in ipairs({'Current movement speed','Run speed','Flight speed','Swim speed'})do add('movement'..i,label,movement[i],'yards per second')end
 for _,v in ipairs({{'meleeHit','Melee hit','CR_HIT_MELEE',GetHitModifier},{'offhandHit','Off-hand hit','CR_HIT_MELEE',GetOffhandHitModifier},{'rangedHit','Ranged hit','CR_HIT_RANGED',GetRangedHitModifier},{'spellHit','Spell hit','CR_HIT_SPELL',GetSpellHitModifier}})do
  local modifier=call(v[1],v[4]);local id=A.Plain(_G[v[3]]);local rating=integer(id,1)and call(v[1]..'Rating',GetCombatRatingBonus,id)or{}
  add(v[1],v[2],number(modifier[1])and number(rating[1])and modifier[1]+rating[1]or nil,'%')
 end
 for school,label in ipairs({'Physical','Holy','Fire','Nature','Frost','Shadow','Arcane'})do
  if school>1 then one('spellDamage'..school,label..' spell bonus damage',GetSpellBonusDamage,nil,school)end
 end
 one('healing','Spell bonus healing',GetSpellBonusHealing)
 local regen=call('manaRegen',GetManaRegen);add('manaRegen','Mana regeneration',regen[1],'per second');add('castingRegen','Mana regeneration while casting',regen[2],'per second')
 -- Resolve named constants from this client instead of assuming Retail rating IDs.
 local seen={}
 for _,v in ipairs({{'CR_DEFENSE_SKILL','Defense'},{'CR_DODGE','Dodge'},{'CR_PARRY','Parry'},{'CR_BLOCK','Block'},{'CR_HIT_MELEE','Melee hit'},{'CR_HIT_RANGED','Ranged hit'},{'CR_HIT_SPELL','Spell hit'},{'CR_CRIT_MELEE','Melee critical strike'},{'CR_CRIT_RANGED','Ranged critical strike'},{'CR_CRIT_SPELL','Spell critical strike'},{'CR_HASTE_MELEE','Melee haste'},{'CR_HASTE_RANGED','Ranged haste'},{'CR_HASTE_SPELL','Spell haste'},{'CR_EXPERTISE','Expertise'},{'CR_ARMOR_PENETRATION','Armor penetration'},{'CR_MASTERY','Mastery'},{'COMBAT_RATING_RESILIENCE_PLAYER_DAMAGE_TAKEN','Resilience'}})do
  local id=A.Plain(_G[v[1]])
  if integer(id,1)and not seen[id]then seen[id]=true;one('rating'..id,v[2]..' rating',GetCombatRating,nil,id);one('ratingBonus'..id,v[2]..' rating bonus',GetCombatRatingBonus,nil,id)end
 end
 out.coverage.stats=known..' of '..#out.stats..' requested values observed. Values include modifiers active when captured; unavailable fields stay unrecorded.'
end
local function skills(out)
 local api=C_SkillInfo;local count,ok=call('skillCount',api and api.GetNumSkillLines)
 local seen,partial={},not ok
 local function add(info,requested)
  if type(info)~='table'then partial=true;return end
  if info.isHeader==true then if info.isCollapsed then partial=true end;return end
  local id=integer(info.skillID,1);local rank=integer(info.rank,0)
  if info.isHeader~=false or not id or not rank or (requested and id~=requested) then partial=true;return end
  if seen[id]then return end;seen[id]=true
  out.skills[#out.skills+1]={id=id,name=text(info.name)or('Skill '..id),rank=rank,maxRank=integer(info.maxRank,0),modifier=number(info.modifier),tempPoints=number(info.tempPoints),category=professions[id]and'profession'or A.weaponSkills[id]and'weapon'or'other'}
 end
 if integer(count[1],0)and count[1]<=512 then
  for i=1,count[1]do local v,readable=call('skill',api and api.GetSkillLineInfo,i);if not readable then partial=true end;add(v[1])end
 else partial=true end
 local wanted={};for id in pairs(professions)do wanted[id]=true end;for id in pairs(A.weaponSkills)do wanted[id]=true end
 for _,id in ipairs(E.SortedKeys(wanted))do if not seen[id]then local v=call('skillByID',api and api.GetSkillLineInfoByID,id);if v[1]then add(v[1],id)end end end
 table.sort(out.skills,function(a,b)return a.id<b.id end)
 out.coverage.skills=partial and 'Available skill rows recorded; collapsed or unavailable rows may be missing.'or 'Visible skills and known profession/weapon skill IDs checked. Unavailable ranks are not inferred.'
end
function X.Capture(c)
 if not c or c~=E.current or not E.db or E.db.characters[c.id]~=c then return nil end
 local identity,ok=call('identity',UnitGUID,'player')
 if not ok or identity[1]~=c.id then return nil end
 local out={version=1,character=c.id,capturedAt=A.Now(),equipment={},stats={},skills={},coverage={}}
 local level=call('level',UnitLevel,'player');out.level=integer(level[1],1)
 local race=call('race',UnitRace,'player');out.raceID=integer(race[3],1)
 local sex=call('sex',UnitSex,'player');out.sex=integer(sex[1],1)
 equipment(out);stats(out);skills(out)
 local after,readable=call('identity',UnitGUID,'player')
 if c~=E.current or not readable or after[1]~=c.id then return nil end
 out.completedAt=A.Now()
 return out
end
