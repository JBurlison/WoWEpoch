local B,S,H,A=E.Book,E.Store,E.History,E.API
local c=S.Character('company-localization-contract',{name='Company',realm='Realm'})
local t=A.ParseDay('2026-11-04')+3600
local owner={id=c.id,name='Company',realm='Realm'}
local buddy={id='company-localization-buddy',name='Companions',realm='Realm'}
local group=H.Group(c,t,{owner,buddy},'localization-session','localization-party')
group.title='Good company' -- a title recorded verbatim, not a UI message
local quest=S.Add(c,'quest',t+1,{title='Captured quest',questID=990095,group=group.id,refs={group.id},status='completed'})
local item=S.Add(c,'loot',t+2,{title='Captured item',itemID=990096,group=group.id,refs={group.id},quantity=1})
local chat=S.Add(c,'chat',t+3,{text='Keep these exact words',author='Unknown speaker',group=group.id,refs={group.id},channel='CHAT_MSG_PARTY'})
local oldQuest,oldItem=E.Display.Quest,E.Display.Item
E.Display.Quest=function(id,fallback)return id==990095 and 'Client quest title' or oldQuest(id,fallback)end
E.Display.Item=function(id,fallback)return id==990096 and 'Client item title' or oldItem(id,fallback)end
H.Group(c,t+10,{owner,buddy},'localization-session','localization-party')
B.ChangeCharacter(c.id);B.companyMode='sessions';B.SetChapter('Company');B.selected=group.id;B.groupTab='events';B.Render(true);TEST_PREPARE_BOOK()
local function has(page,value)
    for _,pool in pairs(page.pool)do for _,f in ipairs(pool)do
        if f.GetText and f:GetText()==value or f.text and f.text:GetText()==value then return true end
    end end
    return false
end
assert(has(B.left,E.L['Good company']))
assert(has(B.right,'Good company'),'record title is not mistaken for a translation key')
assert(has(B.right,'Client quest title') and has(B.right,'Client item title'))
TEST_UI_CLICK(E.L.Quests);assert(B.groupTab=='quests','localized tab preserves its internal key')
TEST_UI_CLICK(E.L.Chat);TEST_PREPARE_BOOK();assert(B.groupTab=='chat')
assert(has(B.right,'Keep these exact words'),'chat content stays verbatim')
TEST_UI_CLICK(E.L.Coverage);assert(B.groupTab=='coverage')
assert(has(B.right,E.L['Observed leadership']))
assert(group.title=='Good company'and quest.title=='Captured quest'and item.title=='Captured item')
assert(chat.text=='Keep these exact words'and chat.author=='Unknown speaker')
E.Display.Quest,E.Display.Item=oldQuest,oldItem
print('PASS localized company: translated tabs, stable keys, original names/chat, current-client record titles and coverage')
