local S,B,R,D,V=E.Store,E.Book,E.Artwork,E.ArtDialog,E.ArtView
local c=S.Character("art-alias-owner",{name="Tern"});E.current=c;B.Open();B.ChangeCharacter(c.id)
local savedMap,savedZone,savedSub=C_Map,GetZoneText,GetSubZoneText
local label;C_Map={GetBestMapForUnit=function()return nil end};GetZoneText=function()return label end
GetSubZoneText=function()return "Excavation Site: Wetlands"end
label="The Hall of Thanes"
local record=E.Collectors.Milestone("achievement","Sight from the hall",time(),{},"alias-hall")
assert(record.zone==label and record.mapID==nil)
local key='dungeon:hall-of-thanes'
local known=R.byLocation[key][3];assert(known.texture and R.Select(c,key,known.id))
if BASELINE then
    assert(R.ForRecord(c,record).type=='Anywhere')
    assert(#R.Locations('Dungeon',label)==0)
    C_Map,GetZoneText,GetSubZoneText=savedMap,savedZone,savedSub
    return
end
local old=E.Copy(record)
local automatic=R.ForRecord(c,record);assert(automatic.location==key)
B.SetChapter("Chronicle");B.selected=record.id;B.Render(true)
B.Clear(B.right);V.Record(B.right,c,record)
local found=false
for _,f in ipairs(B.right.pool.label or{})do if (f:GetText() or ''):find(automatic.title,1,true)then found=true end end
assert(found and E.Same(record,old))
for _,names in ipairs({
 {"Hall of Thanes","The Hall of Thanes",key},
 {"The Deadmines","Deadmines","dungeon:the-deadmines"},
 {"The Stockade","Stormwind Stockade","dungeon:the-stockade"},
 {"Temple of Atal'Hakkar","Sunken Temple","dungeon:temple-of-atal-hakkar"},
 {"Excavation Site","Excavation Site: Wetlands","dungeon:excavation-site"},
})do
 local previous={}
 for index=1,2 do
    local query=names[index];D.OpenLocation(nil);assert(D.IsOpen())
    local f=D.left.pool.edit[1];f:SetText(query);f.scripts.OnEnterPressed(f)
    assert(#V.lastLocations==1 and V.lastLocations[1].key==names[3],query)
    D.left.pool.artLocationRow[1]:Click()
    local button
    for _,b in ipairs(D.left.pool.artControl or{})do if b.text:GetText()=="This location's nine"then button=b end end
    assert(button):Click();assert(#V.lastChoices==9 and D.left.used.artTile==9,query)
    for i,r in ipairs(V.lastChoices)do
        assert(r.location==names[3] and D.left.pool.artTile[i].artID==r.id and r.texture)
        if index==1 then previous[i]=r.id else assert(previous[i]==r.id)end
    end
    D.cancel:Click();assert(not D.IsOpen()and B.selected==record.id)
 end
 local tags=R.FilterTags('locations',names[2]);assert(#tags==2 and tags[2].name==names[1])
 assert(#R.MemoryChoices(names[2],'locations','location:'..names[3])==9)
end
local function observed(zone,ui,sub)
    return S.Add(c,"milestone",time(),{major=true,subject=c.id,milestoneType="discovery",zone=zone,mapID=ui,subzone=sub})
end
for _,entry in ipairs({
 {'Sunken Temple','dungeon:temple-of-atal-hakkar'},
 {'Stormwind Stockade','dungeon:the-stockade'},
 {'Deadmines','dungeon:the-deadmines'},
})do assert(R.ForRecord(c,observed(entry[1])).location==entry[2])end
assert(R.ForRecord(c,observed('Excavation Site: Wetlands')).type=='Anywhere')
assert(R.ForRecord(c,observed('Stormwind Stockades')).type=='Anywhere')
assert(R.ForRecord(c,observed('Blackrock Spire')).type=='Anywhere')
assert(R.ForRecord(c,observed('The Hall of Thanes',3065)).type=='Anywhere')
assert(R.ForRecord(c,observed('Wetlands',1437,'Excavation Site: Wetlands')).location=='zone:wetlands')
assert(R.ForRecord(c,observed('An unrecognized zone',nil,'Sunken Temple')).type=='Anywhere')
assert(R.SelectRecord(c,record.id,'none')and not R.ForRecord(c,record))
assert(R.SelectRecord(c,record.id,'fixed','anywhere-09')and R.ForRecord(c,record).id=='anywhere-09')
assert(R.SelectRecord(c,record.id,'location')and R.ForRecord(c,record)==known)
local other=S.Character("art-alias-other",{name="Alt"});assert(not R.ForRecord(other,record))
C_Map,GetZoneText,GetSubZoneText=savedMap,savedZone,savedSub
