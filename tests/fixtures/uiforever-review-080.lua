-- Synthetic presentation review only. Never included in the production package.
local _,E=...
local function review(mode)
 local c=E.Store.Character('myepoch-ui-fixture-080',{name='Mira',realm='TEST: Crafting context',level=22})
 local r=c.state.craftContext and c.records[c.state.craftContext]
 if not r then
  local now=time();local session='craft-context-review'
  local base=E.Store.Add(c,'inventory',now-3,{title='TEST workshop inventory',scope='bags and equipment',session=session,
   baseline=true,carried={[2835]=12},equipment={},items={{itemID=2835,before=0,after=12,delta=12}}})
  r=E.Store.Add(c,'craft_request',now,{title='Crafting request: TEST workshop batch',recipeID=900,subject=c.id,profession='Engineering',requestMethod='CraftRecipe',
   session=session,requestCasts=4,reagentCoverage='observed argument list',requestedReagents={{inputIndex=1,slot=1,itemID=2835,quantity=1}},
   status='request observed; acceptance, completion and consumption unknown',source='TEST presentation fixture',
   outputPreview={itemID=4357,hyperlink='|Hitem:4357::::::::|h[Rough Blasting Powder]|h',source='TEST presentation fixture',context='synthetic preview'},
   outputPreviewCoverage='recipe preview observed; actual output, quantity and recipient unconfirmed',
   inventoryAnchor={record=base.id,ts=now-1,sequence=c.seq,scope=base.scope,session=session},refs={base.id}})
  c.state.craftContext=r.id
  local missing=E.Store.Add(c,'craft_request',now+1,{title='Crafting request: TEST unavailable preview',recipeID=901,subject=c.id,requestMethod='CraftRecipe',requestCasts=1,
   reagentCoverage='not supplied',requestedReagents={},outputPreviewCoverage='selected reagent list incomplete',status='request observed; outcome unknown'})
  c.state.craftContextMissing=missing.id
 end
 E.Book.Open();E.Book.ChangeCharacter(c.id)
 E.SearchView.Open({character=c.id,record=mode=='missing'and c.state.craftContextMissing or r.id})
 if mode=='inventory' then
  for i=1,E.Book.right.used.button or 0 do local f=E.Book.right.pool.button[i];if f.text:GetText()=='Open inventory starting point'then f:Click();break end end
 end
 print('CRAFT080',E.version,mode or 'preview',E.Book.chapter,E.Book.selected,E.Book.frame:GetWidth(),E.Book.frame:GetHeight())
end
MyEpochCraftContextReview=review
local f=CreateFrame('Frame');f:RegisterEvent('PLAYER_LOGIN');f:SetScript('OnEvent',function()C_Timer.After(1,function()review('preview')end)end)

-- Synthetic journey; map/art identifiers were inspected in UIForever.
-- Coordinates and events are illustrative, never production fallback data.
local function seedJourney()
do
local id="myepoch-ui-fixture-032"
if not MyEpochDB.characters[id]then
 local base=time({year=2026,month=10,day=31,hour=18,min=0,sec=0})
 local c={id=id,identity={name="Mira",realm="TEST: Journey",level=60},state={level=60,firstObserved=base},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function position(x,y,art)return{mapID=1454,artID=art or 2176,x=x,y=y,observedAt=base,space="uiMap",unit="player",source="C_Map.GetPlayerMapPosition"}end
 local function add(kind,r)
  c.seq=c.seq+1;r.id=id..":"..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.ts=base+c.seq*300;r.refs=r.refs or{};c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local function located(kind,title,r)
  r=r or{};r.title=title;r.mapID=1454;r.zone="Orgrimmar";r.position=r.position or position(.48,.57);return add(kind,r)
 end
 located("milestone","First recorded visit: Orgrimmar",{subject=id,milestoneType="discovery",major=true,position=position(.45,.61)})
 local quest=located("quest","A small errand, a warm welcome",{status="completed",questID=990032,position=position(.46,.62)})
 located("gathered","A handful of herbs for the road",{recipient=id,itemID=2447,quantity=4,position=position(.51,.58)})
 located("loot","A companion's lucky find",{recipient="synthetic-companion",itemID=2589,quantity=3,position=position(.51,.58)})
 located("spell","A new trick to practice",{subject=id,position=position(.55,.42)})
 add("memory",{title="The directions were excellent. My listening was not.",text="We found the meeting place eventually. I kept the directions as a souvenir.",mapID=1454,zone="Orgrimmar",tags={"detour"},createdAt=base+1800,refs={quest.id}})
 located("death","An unexpected tumble",{subject=id,groupState="party",membershipObserved=true,membersAtDeath={{id=id,name="Mira",nameKnown=true},{id="synthetic-companion",name="Bramble",realm="TEST",nameKnown=true}},position=position(.57,.47)})
 located("milestone","Mining reached 75",{subject=id,milestoneType="profession",skill="Mining",from=74,to=75,major=true,position=position(.55,.42)})
 located("loot","A keepsake from an older map",{recipient=id,itemID=2589,quantity=1,position=position(.61,.53,2175)})
 add("memory",{title="An afternoon without a place name",text="The story survived; the location was not recorded.",createdAt=base+3000})
 c.notes[quest.id]={text="Bramble knew a shorter way back.",updatedAt=base+3000}
 MyEpochDB.characters[id]=c
end
print("Synthetic Mira / TEST: Journey added. Events and positions are illustrative; map 1454 / art 2176.")
end
end


MyEpochJourneyReview=function(mode)
 seedJourney()
 E.Book.Open();E.Book.ChangeCharacter('myepoch-ui-fixture-032');E.Book.SetChapter('Journey')
 E.Book.journeyMap='map:1454';E.Book.journeyFilter='all';E.Book.journeyChooser=false;E.Book.journeyFiltersOpen=false;E.Book.journeyMapInfo=false;E.Book.selected=nil;E.Book.Render(true)
 if mode=='details' then for i=1,E.Book.left.used.journeyControl or 0 do local f=E.Book.left.pool.journeyControl[i];if f.text:GetText()=='Map details'then f:Click();break end end end
 local f=E.Book.left.pool.journeyMap[1];local g=f.geometry
 if mode=='pin'and f.pins[1]then f.pins[1]:Click()end
 print('JOURNEY080',E.version,f:GetWidth(),f:GetHeight(),g and g.width,g and g.height,f.ready,E.Book.left.y,E.Book.left.scroll:GetHeight(),E.Book.frame:GetWidth(),E.Book.frame:GetHeight(),E.Book.journeyBucket or 'all')
end
