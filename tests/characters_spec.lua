local C,V,B,S,A=E.Characters,E.CharacterView,E.Book,E.Store,E.API
local oldCurrent=E.current;local oldClass,oldName,oldRealm,oldSecret=UnitClass,UnitFullName,GetRealmName,issecretvalue
UnitClass=function()return 'Warrior','WARRIOR',1 end;UnitFullName=function()return 'Aldren',''end;GetRealmName=function()return 'Home realm'end
local identity=A.Identity('player');assert(identity.classID==1 and identity.className=='Warrior'and identity.realm=='Home realm')
local refresh=S.Character(identity.id);E.current=refresh;E.Collectors.RefreshIdentity();assert(refresh.identity.className=='Warrior');E.current=oldCurrent
local unrelated=S.Character('identity-unrelated',{name='Unrelated'});E.current=unrelated;E.Collectors.RefreshIdentity();assert(unrelated.identity.className==nil and unrelated.identity.name=='Unrelated');E.current=oldCurrent
local secret={};issecretvalue=function(v)return v==secret end;UnitClass=function()return secret,'WARRIOR',1 end
assert(A.Identity('player').className==nil,'restricted class names omitted');UnitClass,UnitFullName,GetRealmName,issecretvalue=oldClass,oldName,oldRealm,oldSecret
local a=S.Character('picker-a',{name='Picker Aldren',realm='Amber',className='Warrior',level=22,nameKnown=true})
local b=S.Character('picker-b',{name='Picker Aldren',realm='Bronze',className='Mage',level=12})
local r=S.Add(a,'loot',100,{title='Old loot'});assert(C.Latest(a)==100)
local late=S.Add(a,'loot',90,{title='Late-arriving old record'});assert(C.Latest(a)==100)
local active=S.Add(a,'play',110,{ended=180,status='active'});assert(C.Latest(a)==180)
S.Add(a,'recap',900,{title='A generated summary'});assert(C.Latest(a)==180)
active.ended=200;S.Changed(a,active);assert(C.Latest(a)==200)
a.records[active.id]=nil;E.Emit('RECORDS_REMOVED',a,{[active.id]=true});assert(C.Latest(a)==100)
S.Character(a.id,{name='Unknown',nameKnown=false});assert(a.identity.name=='Picker Aldren'and not a.identityHistory)
S.Character(a.id,{name='Picker Renamed',realm='Amber',nameKnown=true});assert(a.identityHistory[1].name=='Picker Aldren')
assert(#C.Rows('Picker Aldren')==2 and C.Rows('Picker Renamed')[1]==a,'old name remains searchable, stable identity preserved')
local rev=a.revision;S.Character(a.id,{name='Picker Renamed',realm='Amber',nameKnown=true});assert(a.revision==rev and #a.identityHistory==1)
assert(#C.Rows('[nonpattern')==0)
for i=1,13 do S.Character('picker-extra-'..i,{name='Picker Extra '..i,realm='A very long realm '..string.rep('x',100)})end
B.ChangeCharacter(a.id);B.Open();B.SetChapter('Memories');B.memoryMode='saved';B.Render();S.Note(a,'day:2026-11-01','Unchanged note',200)
B.characterButton:Click();assert(V.frame:IsShown()and B.Character()==a,'opening does not switch character')
V.input:SetText('Picker');V.input.scripts.OnTextChanged(V.input,true);assert(#V.rows==15 and #V.cards==6)
V.next:Click();assert(V.page==2);V.next:Click();assert(V.page==3);assert(V.cards[3]:IsShown()and not V.cards[4]:IsShown())
V.input:SetText('Bronze');V.input.scripts.OnTextChanged(V.input,true);assert(#V.rows==1 and V.cards[1].characterID==b.id)
V.cards[1]:Click();assert(B.Character()==b and not V.frame:IsShown());B.SetChapter('Calendar')
B.ChangeCharacter(a.id);assert(B.chapter=='Memories'and a.notes['day:2026-11-01'].text=='Unchanged note')
local dated=S.Add(b,'milestone',300,{datePrecision='day'});V.Toggle();V.input:SetText('Bronze');V.input.scripts.OnTextChanged(V.input,true);assert(V.cards[1].activity:GetText():find('(date only)',1,true));V.Hide()
V.Toggle();V.input:SetText('[nonpattern');V.input.scripts.OnTextChanged(V.input,true);assert(V.count:GetText()=='No matching characters')
V.input.scripts.OnEscapePressed();assert(not V.frame:IsShown()and V.query=='[nonpattern','dismiss preserves search')
V.Toggle();E.db.settings.combatClose=true;B.Combat(true);assert(not V.frame:IsShown());B.Combat(false);assert(B.frame:IsShown());E.db.settings.combatClose=false
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();V.Toggle();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940 and V.panel:GetHeight()==750);V.Hide()end
UIParent:SetSize(1920,1080);B.Fit();E.current=oldCurrent
for i=1,10 do S.Add(a,'milestone',500+i,{subject=a.id,major=true,milestoneType='level',title='A recorded level-up '..i})end
B.ChangeCharacter(a.id);B.SetChapter('Chronicle');B.left.scroll:SetVerticalScroll(60)
B.ChangeCharacter(b.id);B.SetChapter('Calendar');B.ChangeCharacter(a.id)
assert(B.chapter=='Chronicle'and B.left.scroll:GetVerticalScroll()==60,'character switch restores page scroll')
print('PASS characters: guarded identity, rename aliases, activity chronology/invalidation, duplicate names, literal search, bounded paging, separate views/notes, dismissal, combat and fixed sizing')
