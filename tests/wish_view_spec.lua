local S,V,W,B,K=E.Store,E.WishView,E.Wishes,E.Book,E.Keepsakes
assert(V and W and E.WishSharing,'Wish modules must be loaded by the release TOC')
local c=S.Character('wish-ui-owner',{name='Mira'});local friend=S.Character('wish-ui-friend',{name='Aldren'})
local oldRender=B.Render;local oldCharacter=B.character;local oldCurrent=E.current
E.current=c;B.character=c.id;B.chapter='Memories';B.memoryMode='wishes';TEST_NOW(1900000000)
B.Render=function()
    B.Clear(B.left);B.Clear(B.right);B.Navigation.Begin()
    V.Render(B.left,B.right,B.Character());B.Finish(B.left);B.Finish(B.right)
end
local function button(page,label)
    for i=1,page.used.button or 0 do local f=page.pool.button[i]
        if f.text:GetText()==E.Text(E.L[label])then return f end
    end
    error('Missing wish control: '..label)
end
local function click(page,label)button(page,label):Click()end
local function input(page,label,value)
    for i=1,page.used.edit or 0 do local f=page.pool.edit[i]
        if f.inputLabel==E.L[label]then f:SetText(value);f.scripts.OnTextChanged(f,true);return f end
    end
    error('Missing wish field: '..label)
end
local function settle()for i=1,300 do K.Process(500)end end
B.Render();click(B.left,'Write a new wish')
input(B.right,'Give your wish a name','A picnic beyond the city')
local draftEdit=input(B.right,'A few words for the journey','Bring bread, cheese, and a patient friend.')
-- Clicking Save must keep typed words without requiring Enter in either field.
click(B.right,'Keep this wish');settle()
local goal=W.List(c,'active')[1];assert(goal and goal.title=='A picnic beyond the city')
assert(K.Notes(c,goal)=='Bring bread, cheese, and a patient friend.')
B.Render()
local freeformHeadings=0
for i=1,B.right.used.label or 0 do local text=B.right.pool.label[i]:GetText()
    if text==E.L['A wish of my own']then freeformHeadings=freeformHeadings+1 end
    assert(not text:find('Recorded progress:',1,true),'Freeform wishes have no automatic progress meter')
end
assert(freeformHeadings==1,'Freeform goal details show the section label once')
click(B.right,'Mark this wish complete')
assert(goal.status=='completed'and goal.manualCompleted and c.records[goal.completionMemory])
local memory=goal.completionMemory;click(B.right,'Reopen this wish');click(B.right,'Mark this wish complete')
assert(goal.completionMemory==memory,'Repeated UI completion keeps one memory')
click(B.left,'Share a wish list')
click(B.left,'[ ] '..goal.title);click(B.right,'Prepare sharing text')
local state=V.State(c);local sharing=assert(state.shareText)
assert(state.includeNotes==true and E.WishSharing.Preview(sharing).goals[1].notes==K.Notes(c,goal))
click(B.right,'Leave notes out');click(B.right,'Prepare sharing text')
assert(E.WishSharing.Preview(state.shareText).goals[1].notes==nil)
-- Imports create the receiving character's own goals; they never carry source
-- references, completed status, sender baseline, or the sender's memory.
B.character=friend.id;V.Open();click(B.left,"Bring in a friend's wishes")
input(B.right,'Paste your friend’s sharing text',sharing)
click(B.right,'Review these wishes');assert(V.State(friend).preview)
assert(#W.List(friend,'all')==0,'Preview must not create goals')
click(B.right,'Bring these wishes into my book');settle()
local imported=W.List(friend,'all')[1]
assert(imported and imported.character==friend.id and not imported.includeHistory and imported.status=='active')
assert(imported.completionMemory==nil and #imported.refs==0 and K.Notes(friend,imported)==K.Notes(c,goal))
-- An input callback retained from the previous character cannot write through.
draftEdit:SetText('Cross-character write');draftEdit.scripts.OnTextChanged(draftEdit,true)
assert(K.Notes(c,goal)=='Bring bread, cheese, and a patient friend.')
assert(V.State(c)~=V.State(friend)and V.State(c).includeNotes==false and V.State(friend).includeNotes==true)
click(B.right,'Archive this wish');assert(imported.archived and #W.List(friend,'archived')==1)
click(B.right,'Return to active wishes');assert(not imported.archived)
-- A saved character can choose an ID even when it has not received that item.
click(B.left,'Write a new wish');input(B.right,'Give your wish a name','A little copper')
click(B.right,'Acquire an item')
local idInput=input(B.right,'Or enter an item, quest, skill or map ID','2840');idInput.scripts.OnEnterPressed(idInput)
input(B.right,'Quantity to collect','12');click(B.right,'Keep this wish');settle()
local itemGoal
for _,r in ipairs(W.List(friend,'all'))do if r.goalType=='acquire'then itemGoal=r end end
assert(itemGoal and itemGoal.target.itemID==2840 and itemGoal.target.quantity==12 and not itemGoal.includeHistory)
-- A callback held by a canceled form cannot submit that old draft after a new
-- editor is opened, even when the selected character has not changed.
click(B.left,'Write a new wish');input(B.right,'Give your wish a name','Canceled wish')
local oldSave=button(B.right,'Keep this wish').scripts.OnClick
click(B.right,'Cancel');click(B.left,'Write a new wish')
input(B.right,'Give your wish a name','The next wish')
local before=#W.List(friend,'all');oldSave()
assert(#W.List(friend,'all')==before and V.State(friend).draft.title=='The next wish')
click(B.right,'Cancel')
B.Render=oldRender;B.character=oldCharacter;E.current=oldCurrent
print('PASS wish UI drafts, status controls, safe preview/import, optional notes and character isolation')
