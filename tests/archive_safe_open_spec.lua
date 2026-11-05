local S,I,B,A=E.Store,E.Inventory,E.Book,E.API
local function ev(n,...)return E.frame.scripts.OnEvent(E.frame,n,...)end
local function tick()E.frame.scripts.OnUpdate(E.frame,.2)end
local function character(id)
 return {id=id,identity={id=id,name='Adventurer'},seq=2,revision=0,state={},records={
   [id..':1']={id=id..':1',character=id,kind='memory',sequence=1,title='Old undated memory',refs={}},
   [id..':2']={id=id..':2',character=id,kind='craft_request',sequence=2,ts=123,refs={}}},
   order={id..':1',id..':2'},notes={['day:old']={text='Saved note',updated=123}},dedup={},art={},retention={}}
end
local a=character('actual-player');local b=character('other')
local db={schema=E.schema,settings={},characters={[a.id]=a,[b.id]=b},bankOrder=2}
local oldID,oldOther=a.id,b.id
local legacy={'uncertified prototype queue'}
local function open()MyEpochDB=db;ev('ADDON_LOADED','MyEpoch')end
local function lock()
 local function clone(t)
  if type(t)~='table' then return t end
  local out={};for k,v in pairs(t)do out[k]=clone(v) end;return out
 end
 local original=clone(db);local messages={}
 DEFAULT_CHAT_FRAME.AddMessage=function(_,msg)messages[#messages+1]=msg end
 open();assert(E.failure and not E.db and MyEpochDB==db and E.Same(original,db))
 ev('PLAYER_LOGIN');ev('PLAYER_ENTERING_WORLD');ev('CHAT_MSG_PARTY','A line','Someone');ev('PLAYER_MONEY');tick()
 ev('PLAYER_LOGOUT');ev('ADDON_LOADED','MyEpoch');assert(not E.current and not E.db)
 assert(SLASH_MYEPOCH1=='/myepoch' and SLASH_MYEPOCH2=='/epoch')
 local n=#messages;SlashCmdList.MYEPOCH('status');SlashCmdList.MYEPOCH('capture');MyEpoch_Capture()
 assert(#messages==n+3)
 for i=n+1,#messages do assert(messages[i]:find('Recording is stopped',1,true))end
 ev('SAVED_VARIABLES_TOO_LARGE','OtherAddon');assert(#messages==n+3)
 ev('SAVED_VARIABLES_TOO_LARGE','MyEpoch');ev('SAVED_VARIABLES_TOO_LARGE','MyEpoch')
 assert(#messages==n+4 and not messages[#messages]:find('Open Archive',1,true))
 assert(E.Same(original,db) and MyEpochDB==db and not S.CraftSeed(a) and not S.CraftSeed(b))
end
if MODE=='fresh' then
 MyEpochDB=nil;ev('ADDON_LOADED','MyEpoch');ev('PLAYER_LOGIN');tick()
 assert(E.db==MyEpochDB and E.current.id=='actual-player' and E.current.state.wallet)
elseif MODE=='sparse' or MODE=='benign-queue' then
 a.id=nil;a.retention=nil;a.art=nil
 local record=a.records[oldID..':1'];local note=a.notes['day:old']
 a.state.inventoryCostLinks=MODE=='sparse' and legacy or {epochs={},ids={},jobs={},first=1,last=0}
 local bank=b.records[oldOther..':1'];bank.kind='bank';bank.bankOrder=9
 open();assert(E.db==db and a.id==oldID and db.bankOrder==9 and not next(a.retention) and a.art==nil)
 assert(a.state.inventoryCostLinks==nil and a.records[record.id]==record and a.notes['day:old']==note and S.Timestamp(record)==nil)
 assert(S.CraftSeed(a).slots[oldID..':2'])
 ev('PLAYER_LOGIN');tick();assert(E.current==a and a.state.wallet and a.state.sessionSequence==1)
 B.Open();B.SetChapter('Archive');B.archiveTab='accountStorage';B.Render(true)
 for i=1,10000 do tick();if E.Archive.results[E.db] then break end end
 assert(E.Archive.results[E.db].complete and E.Archive.results[E.db].characters==2)
 E.Archive.Configure(a,'chat',7);assert(a.retention.chat==7);E.Archive.Configure(a,'chat',nil)
 assert(not a.retention.chat and not a.retention.memories and S.PreviewExpiry(a,A.Now()))
 B.SetChapter('Chronicle');B.Render(true);assert(B.Character()==a and a.records[record.id]==record and a.notes['day:old']==note)
elseif MODE=='queue-tombstone' then
 local id=oldID..':1'
 a.state.inventoryCostLinks={first=1,last=1,ids={id},epochs={[id]=2},jobs={}}
 open();assert(E.db==db);I.ProcessCostLinks(a);assert(a.state.inventoryCostLinks==nil)
elseif MODE=='live-reopen' then
 open();local saved=assert(S.CraftSeed(a));local prior=E.db
 a.retention=nil;a.state.inventoryCostLinks=legacy;a.records[oldID..':2'].kind='chat'
 b.records.invalid=true;assert(not pcall(S.Open,db))
 assert(E.db==prior and S.CraftSeed(a)==saved and saved.slots[oldID..':2'] and a.retention==nil and a.state.inventoryCostLinks==legacy)
 b.records.invalid=nil;assert(S.Open(db)==db and a.state.inventoryCostLinks==nil and not next(a.retention) and not S.CraftSeed(a))
elseif MODE=='legacy-identity' then
 open();assert(E.db==db)
else
 a.id=nil;a.retention=nil;a.state.inventoryCostLinks=legacy
 if MODE=='corrupt-record' then b.records.bad=true
 elseif MODE=='owner-conflict' then a.identity.id='other'
 elseif MODE=='foreign-record' then a.records[oldID..':1'].character='other'
 elseif MODE=='record-key' then a.records[oldID..':1'].id='another:1'
 elseif MODE=='wrong-id' then b.id='other-account'
 elseif MODE=='aliased-owner' then db.characters.other=a
 elseif MODE=='queue-no-index' or MODE=='queue-hole' then
  local id=oldOther..':1';b.state.inventoryCostLinks={first=1,last=1,epochs={[id]=1},jobs={[id]={index=1,modules={TradeCosts={}}}}}
  if MODE=='queue-hole' then local q=b.state.inventoryCostLinks;q.last=3;q.ids={[1]=id,[3]=id}end
 elseif MODE:match('^job%-') then
  local id=oldOther..':1';local q={first=1,last=1,epochs={[id]=1},ids={id},jobs={[id]={index=1,modules={TradeCosts={}}}}}
  b.state.inventoryCostLinks=q
  if MODE=='job-epoch' then q.epochs[id]=nil
  elseif MODE=='job-missing' then q.jobs[id]=nil
  elseif MODE=='job-scalar' then q.jobs[id]=true
  elseif MODE=='job-index' then q.jobs[id].index=2
  elseif MODE=='job-modules' then q.jobs[id].modules=nil
  elseif MODE=='job-context' then q.jobs[id].modules.TradeCosts=true
  elseif MODE=='job-counterpart' then q.jobs[id].modules.TradeCosts.other=1 end
 elseif MODE=='nonfinite-counter' then b.seq=math.huge
 else b[MODE]=nil end
 lock();assert(a.id==nil and a.retention==nil and a.state.inventoryCostLinks==legacy)
end
