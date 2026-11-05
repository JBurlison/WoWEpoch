local function event(name,...) E.frame.scripts.OnEvent(E.frame,name,...) end
event("ADDON_LOADED","Unrelated"); assert(not MyEpochDB)
event("ADDON_LOADED","MyEpoch"); assert(MyEpochDB)
local originalCombatQuery=UnitAffectingCombat
UnitAffectingCombat=function(unit)assert(unit=='player');return true end
event("PLAYER_LOGIN"); assert(E.current and E.current.identity.build=="70707")
assert(E.Book.inCombat==true,'Login seeds combat state even before a combat event')
UnitAffectingCombat=originalCombatQuery
local c=E.current; assert(c.state.activeQuests[100]); assert(c.state.wallet.amount==12345)
SlashCmdList.MYEPOCH(""); assert(E.Book.frame:IsShown())
local tabs={"Chronicle","Calendar","Recaps","Quests","Company","Loot","Gold","Memories","Journey","Search","Archive"}
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}}) do
    UIParent:SetSize(unpack(size)); E.Book.Fit()
    local expected=E.Book.frame:GetScale()
    assert(1760*expected<=size[1] and 940*expected<=size[2])
    for _,name in ipairs(tabs) do E.Book.SetChapter(name); assert(E.Book.frame:GetWidth()==1760 and E.Book.frame:GetHeight()==940); assert(E.Book.frame:GetScale()==expected) end
end
E.db.settings.combatClose=false; event("PLAYER_REGEN_DISABLED"); assert(E.Book.frame:IsShown())
E.db.settings.combatClose=true; event("PLAYER_REGEN_DISABLED"); assert(not E.Book.frame:IsShown())
SlashCmdList.MYEPOCH("");assert(not E.Book.frame:IsShown()and E.Book.reopen,"Blocked slash opening preserves combat restoration")
assert(E.Book.Open()==false and not E.Book.frame:IsShown()and E.Book.reopen,"Direct opening respects the same setting")
event("PLAYER_REGEN_ENABLED"); assert(E.Book.frame:IsShown())
event("PLAYER_REGEN_DISABLED"); SlashCmdList.MYEPOCH("close")
SlashCmdList.MYEPOCH("");assert(not E.Book.frame:IsShown()and not E.Book.reopen,"Blocked opening never undoes a manual close")
event("PLAYER_REGEN_ENABLED"); assert(not E.Book.frame:IsShown())
event("PLAYER_REGEN_DISABLED");E.db.settings.combatClose=false;SlashCmdList.MYEPOCH("");assert(E.Book.frame:IsShown(),"Default setting allows opening during combat")
event("PLAYER_REGEN_ENABLED");E.Book.Close(true)
TEST_NOW(2000000005); E.frame.scripts.OnUpdate(E.frame,5)
event("PLAYER_LEVEL_UP",13)
assert(#E.Query.Major(c)==2) -- first recorded zone and personal level
local rank=74
GetProfessions=function()return 1 end
GetProfessionInfo=function()return "Mining",0,rank,300,0,0,186 end
C_SkillInfo={GetNumSkillLines=function()return 2 end,GetSkillLineInfo=function(i)
    return {isHeader=false,skillID=i==1 and 186 or 43,name=i==1 and "Mining" or "Swords",rank=rank}
end}
event("SKILL_LINES_CHANGED"); rank=75; event("SKILL_LINES_CHANGED")
local majors=E.Query.Major(c); assert(#majors==4)
local foundProfession,foundWeapon=false,false
for _,r in ipairs(majors) do if r.skillID==186 then assert(r.milestoneType=="profession" and r.thresholds[1]==75); foundProfession=true
elseif r.skillID==43 then assert(r.milestoneType=="skill" and r.thresholds[1]==75); foundWeapon=true end end
assert(foundProfession and foundWeapon)
event("CHAT_MSG_PARTY","Good job!","Friend",nil,nil,nil,nil,nil,nil,nil,nil,101,"friend-guid")
event("CHAT_MSG_PARTY","Good job!","Friend",nil,nil,nil,nil,nil,nil,nil,nil,101,"friend-guid")
assert(E.Query.Search(c,"Good job!").total==1)
event("CHAT_MSG_LOOT","You create: |cffaaaaaa|Hitem:2840:0|h[Copper Bar]|hx3.",nil,nil,nil,nil,nil,nil,nil,nil,nil,102)
assert(E.Query.Search(c,"Copper Bar","crafted").total==1)
event("QUEST_REMOVED",100); event("QUEST_TURNED_IN",100,500,100); E.frame.scripts.OnUpdate(E.frame,0.1)
assert(not c.state.activeQuests[100]); assert(#E.Store.List(c,function(r)return r.kind=="quest"end)==1)
local screenshot=E.Collectors.Screenshot(); assert(screenshot.status=="unconfirmed" and screenshot.image=="unavailable")
E.Book.Open()
for _,r in ipairs(E.Store.List(c)) do E.Book.selected=r.id; E.Book.Render() end
event("PLAYER_LOGOUT"); assert(not c.state.play)
print("PASS integration: bootstrap, build record, observed quests/items/chat, static book across 33 chapter/resolution combinations, combat close/reopen/manual close, turn-in ordering, screenshot honesty")
