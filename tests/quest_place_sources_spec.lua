local restoreSourceReview=TEST_QUEST_SOURCE_REVIEW()
local S,H,T,V,B,A=E.Store,E.History,E.QuestAtlas,E.QuestView,E.Book,E.API
local c=S.Character("quest-place-sources",{name="Map reader",faction="Alliance"})
local ts=A.ParseDay("2026-11-02")+600
local id,title=373,"The Unsent Letter"
local function west()return {mapID=1436,zone="Westfall",subzone="Sentinel Hill"}end
local function offer(at,name)
    local data=west();data.questID=id;data.title=title;data.giverName=name
    return S.Add(c,"quest_offer",at,data)
end
local first=H.BeginQuest(c,id,title,ts,false,west())
H.EndQuest(c,id,ts+1,"abandoned")
local oldest=offer(ts+60,"Archivist")
for n=2,6 do offer(ts+n*60,"Archivist")end
local latest=offer(ts+420,"Archivist")
local accepted=H.BeginQuest(c,id,title,ts+480,true,west())
H.CompleteQuest(c,id,ts+600,{},"map-session",title,{mapID=1453,zone="Stormwind City"})
B.Open();B.ChangeCharacter(c.id);B.SetChapter("Quests")
B.questZone="all";B.questFilter="all";B.questQuery=title;V.Select(id);TEST_PREPARE_BOOK()
local function button(label)
    for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()==label then return f end end
end
local function click(label)assert(button(label),label):Click()end
local mapRow=assert(V.lastReport.all[id] or T.Row(c,id))
assert(mapRow.maps[291] and not mapRow.observedMaps[291] and not button("Show observations in Deadmines"))
click("Show observations in Westfall")
assert(button("Accepted · "..A.RecordDate(accepted)) and not button("Turned in · "..A.Date(ts+600)))
local visit="Offered by Archivist · "..A.RecordDate(latest)
click(visit);assert(B.selected==latest.id)
local found=false
for i=1,B.right.used.questDetailField or 0 do
    local f=B.right.pool.questDetailField[i]
    if f.label:GetText()=="Quest giver" and f.value:GetText()=="Archivist" then found=true end
end
assert(found); click("Back to quest overview");click("Older observations")
assert(button("Observed in quest log · "..A.RecordDate(first)) and not button("Accepted · "..A.RecordDate(first)))
local oldOpen=assert(button("Offered by Archivist · "..A.RecordDate(oldest))).scripts.OnClick
oldest.mapID=1453;oldest.zone="Stormwind City";S.Changed(c,oldest);oldOpen();assert(B.selected==nil)
B.Render();click("Show observations in Stormwind City")
assert(button("Turned in · "..A.Date(ts+600)) and button("Offered by Archivist · "..A.RecordDate(oldest)))
local off=button("Offered by Archivist · "..A.RecordDate(oldest)).scripts.OnClick
local foreign=S.Character("other-map-reader",{})
B.ChangeCharacter(foreign.id);off();assert(B.Character()==foreign and B.selected~=oldest.id)
accepted.kind="memory";S.Changed(c,accepted);assert(T.History(c)[id].latest~=accepted)
local current=T.History(c)[id];for _,r in ipairs(current.attempts)do assert(r~=accepted)end
print("PASS quest map sources: catalog-only area, two observed zones, initial log versus acceptance, grouped offers, exact original, paging and correction/owner guards")

restoreSourceReview()
