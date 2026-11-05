local B,V,S,H,C,A=E.Book,E.QuestView,E.Store,E.History,E.Collectors,E.API
local saved={owner=B.character,current=E.current,tip=GameTooltip,icon=C_Item.GetItemIconByID,
 questID=GetQuestID,count=GetNumQuestItems,item=GetQuestItemInfo,session=C.session}
local c=S.Character('quest-item-icons',{name='Quest items'});E.current=c;B.ChangeCharacter(c.id)
local q=H.BeginQuest(c,990002,'Item errand',100,true)
q.objectives={{type='item',itemID=2589,text=string.rep('Linen cloth ',12),numFulfilled=6,numRequired=10},
 {type='monster',itemID=123,text='A creature',numFulfilled=1,numRequired=5},
 {type='item',text='An unidentified item',numFulfilled=0,numRequired=1}}
C_Item.GetItemIconByID=function(id)return id==2589 and 132889 or nil end
GameTooltip={SetOwner=function(self,f)self.owner=f end,IsOwned=function(self,f)return self.owner==f end,
 SetHyperlink=function(self,link)self.link=link end,Show=function(self)self.shown=true end,Hide=function(self)self.shown=false end}
local function draw()B.Clear(B.right);V.Objectives(B.right,q)end
draw();local rows=B.right.pool.questObjective;local icon=rows[1].icon
assert(icon.itemID==2589 and icon.image:IsShown()and icon.mouseMotionEnabled)
assert(rows[1].title.point[2]==42 and rows[1]:GetHeight()>=65)
assert(not rows[2].icon:IsShown()and not rows[3].icon:IsShown(),'no guessed icons')
icon.scripts.OnEnter(icon);assert(GameTooltip.shown and GameTooltip.link=='item:2589')
icon.scripts.OnLeave(icon);assert(not GameTooltip.shown)
icon.scripts.OnEnter(icon);q.objectives={{type='item',text='No identity'}};draw()
assert(not GameTooltip.shown and not icon:IsShown()and icon.itemID==nil,'pool reuse clears icon and tooltip')
q.objectives={{type='item',text='|cffffffff|Hitem:2589:0|h[Linen Cloth]|h|r'}};draw();assert(icon.itemID==2589)
local currentID,count,unavailable=990002,1,false
GetQuestID=function()return currentID end;GetNumQuestItems=function()return count end
GetQuestItemInfo=function(kind,index)assert(kind=='required'and index==1);if not unavailable then return 'Linen Cloth',132889,10,1,true,2589 end end
C.session='quest-items-test';C.handlers.QUEST_PROGRESS()
assert(q.requiredItems[1].itemID==2589 and q.requiredItems[1].quantity==10)
unavailable=true;C.handlers.QUEST_ITEM_UPDATE();assert(#q.requiredItems==1,'missing cache does not erase observation')
unavailable=false;currentID=990003;count=0;C.handlers.QUEST_ITEM_UPDATE();assert(#q.requiredItems==1,'different dialog cannot overwrite')
currentID=990002;C.handlers.QUEST_FINISHED();C.handlers.QUEST_ITEM_UPDATE();assert(#q.requiredItems==1,'closed dialog cannot overwrite')
B.Clear(B.right);V.RequiredItems(B.right,q);assert(B.right.pool.ledgerItem[1].icon.itemID==2589)
E.current=saved.current;C.session=saved.session;GameTooltip=saved.tip;C_Item.GetItemIconByID=saved.icon
GetQuestID=saved.questID;GetNumQuestItems=saved.count;GetQuestItemInfo=saved.item;B.ChangeCharacter(saved.owner)
print('PASS quest items: objective identity, hover/leave, pooled reset, text fallback, required-item capture, incomplete loads and dialog isolation')
