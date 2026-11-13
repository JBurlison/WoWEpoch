local F, S, H, B = E.CompanyFavorites, E.Store, E.History, E.Book
local c = S.Character("favorites-owner", {name="Owner",realm="Dawn"})
local other = S.Character("favorites-other", {name="Other",realm="Dawn"})
local owner = {id=c.id,name="Owner",realm="Dawn"}
local dawn = {id="favorites-dawn",name="Bob",realm="Dawn"}
local dusk = {id="favorites-dusk",name="Bob",realm="Dusk"}
local ts = E.API.Now()
H.Group(c, ts, {owner,dawn,dusk}, "session", "party")
H.Group(c, ts+1, {}, "session", "party")
S.Note(c,"companion:"..dawn.id,"Brings spare potions",ts)

B.ChangeCharacter(c.id); B.SetChapter("Company"); TEST_PREPARE_BOOK()
TEST_UI_CLICK("Companions"); TEST_UI_CLICK("Bob - Dawn"); TEST_UI_CLICK("Add to favorites")
local bob = assert(F.Get(c,dawn.id))
assert(B.companyMode=="favorites" and B.right.pool.edit[3]:GetText()=="Brings spare potions")
local function submit(page,index,value)
    local f=page.pool.edit[index]; f:SetText(value); f.scripts.OnEnterPressed(f)
end
submit(B.right,1,"Raid, Healing, raid"); submit(B.right,2,"Raid 1")
assert(bob.tags.raid=="Raid" and bob.tags.healing=="Healing" and bob.rosters["raid 1"])
local alt=assert(F.Add(c,dusk.id))
F.SetLabels(c,alt,"tags","raid"); F.SetLabels(c,alt,"rosters","Raid 2")
assert(#F.List(c,nil,"raid")==2 and #F.List(c,"raid 1","raid")==1 and #F.List(c,"raid 2","healing")==0)
assert(F.List(c,"raid 2","raid")[1]==alt)
assert(F.Get(other,dawn.id)==nil and #F.List(other)==0)

TEST_UI_CLICK("New roster"); submit(B.left,1,"Raid 3")
assert(F.RosterNames(c)["raid 3"]=="Raid 3" and #F.List(c,"raid 3")==0)
TEST_UI_CLICK("Edit roster"); submit(B.left,1,"Raid 2")
assert(F.RosterNames(c)["raid 3"]=="Raid 3")
TEST_UI_CLICK("Delete roster"); assert(not F.RosterNames(c)["raid 3"] and F.RosterNames(c)["raid 2"])
assert(F.SaveRoster(c,"raid 1","Sunday raid")=="sunday raid")
assert(F.List(c,"sunday raid","raid")[1]==bob and not bob.rosters["raid 1"])

local player,ready,party,friends,lookup=E.current,E.RecorderReady,C_PartyInfo,C_FriendList,GetPlayerInfoByGUID
E.current=c; E.RecorderReady=function()return true end
local invites={}
C_PartyInfo={CanInvite=function()return true end,IsGUIDInGroup=function()return false end,
    InviteUnit=function(address)invites[#invites+1]=address end}
C_FriendList={GetNumFriends=function()return 0 end}
TEST_UI_CLICK("Sunday raid")
local invite=TEST_UI_FIND("Invite Bob").scripts.OnClick
invite(); assert(#invites==1 and invites[1]=="Bob-Dawn")
TEST_UI_CLICK("Raid 2"); invite(); assert(#invites==1,"A roster switch invalidates the captured invite")
TEST_UI_CLICK("Invite Bob"); assert(#invites==2 and invites[2]=="Bob-Dusk")
C_FriendList.GetFriendInfo=function()return {guid="different-player"}end
TEST_UI_CLICK("Invite Bob"); assert(#invites==2)
C_FriendList.GetFriendInfo=nil; C_PartyInfo.CanInvite=function()return false end
TEST_UI_CLICK("Invite Bob"); assert(#invites==2)
C_PartyInfo.CanInvite=function()return true end; C_PartyInfo.IsGUIDInGroup=function(id)return id==dusk.id end
TEST_UI_CLICK("Invite Bob"); assert(#invites==2)
C_PartyInfo.IsGUIDInGroup=function()return false end
GetPlayerInfoByGUID=function(id)
    assert(id==dusk.id); return nil,nil,nil,nil,nil,"Renamed","Dusk"
end
TEST_UI_CLICK("Invite Bob"); assert(#invites==3 and invites[3]=="Renamed-Dusk")
local staleInvite=TEST_UI_FIND("Invite Bob").scripts.OnClick
B.ChangeCharacter(other.id); staleInvite(); assert(#invites==3)
assert(not F.Invite(other,alt) and #invites==3)
E.current,E.RecorderReady,C_PartyInfo,C_FriendList,GetPlayerInfoByGUID=player,ready,party,friends,lookup

local copy=E.Copy(E.db)
E.Store.Open(copy); c=E.db.characters[c.id]
assert(F.List(c,"sunday raid","healing")[1].name=="Bob")
assert(c.notes["companion:"..dawn.id].text=="Brings spare potions")
c.retention.groups=1
S.ApplyExpiry(c,S.PreviewExpiry(c,ts+86400*3))
assert(#E.Query.Kind(c,"group")==0)
local kept=F.List(c,"sunday raid","raid")[1]
assert(kept and kept.id==dawn.id)
F.Remove(c,kept)
assert(not F.Get(c,dawn.id) and c.notes["companion:"..dawn.id].text=="Brings spare potions")
assert(F.Get(c,dusk.id) and F.RosterNames(c)["sunday raid"])
print("PASS Company favorites: profile shortcut, shared notes, roster editing, tag filters, individual invites, stale controls, character isolation, reload and group retention")
