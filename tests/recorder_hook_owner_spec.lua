-- Fresh Lua VM for each case. No frame event or OnUpdate is delivered after the GUID changes.
local action,reading=...
local S,C=E.Store,E.Collectors
local c=S.Character("hook-owner",{name="Recorder"});E.current=c;C.session="hook-owner:1";E.recordingGUID=c.id
local token={};issecretvalue=function(value)return value==token end
local guid=c.id
UnitGUID=function(unit)if unit=="player" then return guid end end
local registered,entered={},{}
hooksecurefunc=function(container,name,fn)
    if type(container)=="table"then registered[name]=fn else registered[container]=name end
end
local function noop()end
for _,name in ipairs({"SetSendMailMoney","SetSendMailCOD","TakeInboxMoney","TakeInboxItem","AutoLootMailItem","SendMail","DeleteInboxItem","ReturnInboxItem",
        "BuyMerchantItem","BuybackItem","RepairAllItems","TakeTaxiNode","BuyTrainerService"})do _G[name]=noop end
C_Container={UseContainerItem=noop}
C_AuctionHouse={PostItem=noop,PostCommodity=noop}
C_TradeSkillUI={CraftRecipe=noop,CraftEnchant=noop,CraftSalvage=noop}
local function spy(object,key,category)
    local original=object[key]
    object[key]=function(...) entered[category]=(entered[category]or 0)+1; return original(...)end
end
spy(E.Mail,"Request","mail");spy(E.Auctions,"PostRequest","auction");spy(E.Production,"Request","craft")
spy(E.Merchant,"Attempt","merchant");spy(E.TravelMoney,"Attempt","flight");spy(E.TrainingMoney,"Attempt","trainer")
E.Mail.Start(c,C.session);E.Mail.Open();E.Auctions.Start(c,C.session);E.Production.InstallHooks()
E.Merchant.InstallHooks();E.TravelMoney.InstallHooks();E.TrainingMoney.InstallHooks()
local category={
 TakeInboxMoney="mail",TakeInboxItem="mail",AutoLootMailItem="mail",SendMail="mail",DeleteInboxItem="mail",ReturnInboxItem="mail",
 PostItem="auction",PostCommodity="auction",CraftRecipe="craft",CraftEnchant="craft",CraftSalvage="craft",
 BuyMerchantItem="merchant",BuybackItem="merchant",RepairAllItems="merchant",UseContainerItem="merchant",
 TakeTaxiNode="flight",BuyTrainerService="trainer"}
for name in pairs(category)do assert(registered[name],name)end
assert(registered.SetSendMailMoney and registered.SetSendMailCOD)
local shots,tells,adds=0,0,0
Screenshot=function()shots=shots+1 end
ChatFrameUtil={GetActiveWindow=function()end,SendTell=function(to)assert(to=="Partner-Realm");tells=tells+1 end}
C_FriendList={GetNumFriends=function()return 0 end,AddFriend=function(to)assert(to=="Partner-Realm");adds=adds+1 end}
local initial=c.seq
if reading=="other"then guid="other-guid" elseif reading=="missing"then guid=nil elseif reading=="secret"then guid=token end
local person={id="friend-guid",name="Partner",realm="Realm"}
local message
if action=="Whisper" then message=E.Social.Whisper(person)
elseif action=="AddFriend"then message=E.Social.AddFriend(person)
elseif action=="Capture"then local _,err=E.Capture.Request();message=err
else
    local fn=assert(registered[action],action)
    if category[action]=="auction"then fn({},1,1,300)
    elseif action=="SendMail"then fn("Partner-Realm","Book")
    else fn(11,1)end
end
if reading=="owner"then
    if category[action] then assert(entered[category[action]]==1,action)
    elseif action=="SetSendMailMoney" then assert(E.Mail.sendIntent.money==11)
    elseif action=="SetSendMailCOD" then assert(E.Mail.sendIntent.cod==11)
    elseif action=="Capture"then assert(not message and shots==1 and c.seq>initial)
    elseif action=="Whisper" then assert(tells==1)
    else assert(adds==1) end
    if category[action]=="craft" or category[action]=="auction" or category[action]=="mail" then assert(c.seq>initial,action)end
else
    assert(next(entered)==nil and not E.Mail.sendIntent.money and not E.Mail.sendIntent.cod,action)
    assert(shots==0 and tells==0 and adds==0 and c.seq==initial,action)
    if action=="Whisper" or action=="AddFriend" or action=="Capture" then
        assert(message=="Recording is waiting for a verified player. Use /myepoch status for details.",action)
    end
end
return true
