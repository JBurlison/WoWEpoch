local B=E.Book
local oldQuery,oldSecret=UnitAffectingCombat,issecretvalue
local oldSetting=E.db.settings.combatClose
B.Close(true);B.Combat(false);B.SetCombatClose(false);B.Open()
assert(B.frame:IsShown())
UnitAffectingCombat=function(unit)assert(unit=='player');return true end
B.SetCombatClose(true)
assert(B.inCombat and B.reopen and not B.frame:IsShown(),'Enabling during combat closes the already-visible book')
assert(B.Open()==false and B.reopen,'Blocked open preserves combat reopen intent')
UnitAffectingCombat=function()return false end;B.SyncCombat()
assert(not B.inCombat and not B.reopen and B.frame:IsShown(),'Readable combat end restores a combat-hidden book')
B.Combat(true);B.Close(true)
UnitAffectingCombat=function()return false end;B.SyncCombat()
assert(not B.frame:IsShown()and not B.reopen,'Sync cannot undo a manual close')
B.SetCombatClose(false);B.Open();B.Combat(true)
for _,query in ipairs({function()return nil end,function()return 'false'end,function()error('restricted')end})do
 UnitAffectingCombat=query;B.SyncCombat();assert(B.inCombat==true)
end
UnitAffectingCombat=nil;B.SyncCombat();assert(B.inCombat==true)
B.SetCombatClose(true);assert(not B.frame:IsShown()and B.reopen,'Known event state applies if the direct query is missing')
local opaque={};UnitAffectingCombat=function()return opaque end;issecretvalue=function(v)return v==opaque end
B.SyncCombat();assert(B.inCombat==true,'Opaque state never becomes a false result')
issecretvalue=oldSecret
UnitAffectingCombat=function()return false end;B.SyncCombat()
assert(B.frame:IsShown())
B.Close(true);B.inCombat=nil;UnitAffectingCombat=function()return true end;B.SyncCombat()
assert(B.inCombat and not B.reopen and B.Open()==false,'Reload-style initialization blocks opening without inventing restore intent')
B.Combat(false);assert(not B.frame:IsShown())
B.SetCombatClose(false);B.Combat(true);B.Open();assert(B.frame:IsShown(),'Default-off behavior remains unchanged')
B.Combat(false);B.Close(true);E.db.settings.combatClose=oldSetting;UnitAffectingCombat=oldQuery
print('PASS combat state: login seeding, immediate setting, readable/missing/error/opaque queries, reopen and manual-close intent')
