local name,mode=...
local B=E.Book
local c=E.Store.Character('refresh-owner',{name='Keeper'})
E.current=c;E.recordingGUID=c.id;E.Collectors.session='refresh:1'
local guid=c.id; UnitGUID=function(u)if u=='player'then return guid end end
B.Build();B.character=c.id;B.questTools=true;B.questZone='recorded'
B.Navigation.Begin();B.Navigation.Controls=function(draw)draw(B.nav)end
local reads,blocked=0,0
DEFAULT_CHAT_FRAME={AddMessage=function(_,text)if text:find('Recording is waiting for a verified player. Use /myepoch status for details.',1,true)then blocked=blocked+1 end end}
local function entered()reads=reads+1 end
if name=='Refresh saved sessions'then E.PullView.List(B.left,B.right,c);E.Pulls.Refresh=entered
elseif name=='Refresh available roll history'then E.LootLayout.Drops(B.left,B.right);E.Drops.Refresh=entered
else E.QuestView.Render(B.left,B.right);if name=='Refresh character checks'then E.QuestAtlas.Refresh=entered else E.QuestieBridge.Start=entered end end
local button
for _,page in ipairs({B.nav,B.left,B.right})do
 for kind,count in pairs(page.used)do for i=1,count do
  local f=page.pool[kind][i];if f.text and f.text.GetText and f.text:GetText()==name and f.scripts.OnClick then button=f end
 end end
end
assert(button,'Missing rendered refresh control: '..name)
if mode=='changed'then guid='different-player'
elseif mode=='secret'then local value={};guid=value;issecretvalue=function(x)return x==value end
elseif mode=='stale'then E.current=E.Store.Character('already-rebound',{name='New'})
end
B.Render=function()end
button:Click()
if mode=='owner'then assert(reads==1 and blocked==0,name)else assert(reads==0 and blocked==1,name)end
return true
