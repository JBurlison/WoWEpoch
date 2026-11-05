-- Current-client names are a presentation projection, never a saved-data rewrite.
local D=E.Display
local saved={C_Item,C_Map,C_SkillInfo,C_CreatureInfo,C_Spell,E.API.QuestTitle}
C_Item={GetItemInfo=function(id)if id==42 then return 'Localized item' end end}
C_Map={GetMapInfo=function(id)return {mapID=id==43 and 43 or 999,name='Localized zone'}end}
C_SkillInfo={GetSkillLineInfoByID=function(id)return {skillID=id==44 and 44 or 999,name='Localized skill'}end}
C_CreatureInfo={GetClassInfo=function(id)return {classID=id==45 and 45 or 999,className='Localized class'}end}
C_Spell={GetSpellInfo=function(id)return {spellID=id==46 and 46 or 999,name='Localized spell'}end}
E.API.QuestTitle=function(id)if id==47 then return 'Localized quest'end end
assert(D.Item(42,'Saved item')=='Localized item'and D.Item(1,'Saved item')=='Saved item')
assert(D.Item('42','Invalid ID')=='Invalid ID')
assert(D.Map(43,'Saved zone')=='Localized zone'and D.Map(1,'Saved zone')=='Saved zone')
assert(D.Zone({instanceMapID=43,zone='Physical map'})=='Physical map')
assert(D.Skill(44,'Saved skill')=='Localized skill'and D.Skill(1,'Saved skill')=='Saved skill')
assert(D.Class({classID=45,className='Saved class'})=='Localized class')
assert(D.Class({classID=1,className='Saved class'})=='Saved class')
assert(D.SpellName(46,'Saved spell')=='Localized spell'and D.SpellName(1,'Saved spell')=='Saved spell')
assert(D.Quest(47,'Saved quest')=='Localized quest'and D.Quest(1,'Saved quest')=='Saved quest')
local record={kind='loot',itemID=42,title='Saved item'}
assert(D.RecordTitle(record)=='Localized item'and record.title=='Saved item')
assert(D.RecordTitle({kind='memory',title='Wallet change'})=='Wallet change')
C_Item,C_Map,C_SkillInfo,C_CreatureInfo,C_Spell,E.API.QuestTitle=unpack(saved)
print('PASS current-client display names: verified IDs, fallbacks, physical-map isolation and unchanged records')
