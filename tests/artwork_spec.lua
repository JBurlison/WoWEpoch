local R,V,B,S,A=E.Artwork,E.ArtView,E.Book,E.Store,E.API
local function eq(a,b,label)assert(a==b,(label or "Artwork mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local c=S.Character("art-owner",{name="Painter"}); local other=S.Character("art-other",{name="Other"})
local location="zone:westfall"; local second="zone:elwynn-forest"; local art="anywhere-07"
eq(#E.ArtCatalog.locations,84); eq(#E.ArtCatalog.rows,1309); eq(#R.anywhere,27)
eq(#E.ArtCatalog.professions,12)
for _,profession in ipairs(E.ArtCatalog.professions)do eq(#R.byProfession[profession.key],18)end
for _,row in ipairs(R.anywhere)do assert(row.texture and row.thumbnail,"all anywhere scenes have development exports")end
for _,row in ipairs(E.ArtCatalog.locations)do eq(#R.byLocation[row.key],9)end
eq(#R.Choices(location,"local"),9); eq(#R.Choices(location,"anywhere"),27); eq(#R.Choices(location),36)
eq(#R.Locations("Zone","Westfall"),1); eq(#R.Locations("Raid","Westfall"),0)
eq(R.Resolve(c,location),nil); assert(R.Select(c,location,art)); eq(R.Resolve(c,location).id,art)
eq(R.Resolve(other,location),nil); eq(R.Resolve(c,second),nil)
assert(R.Select(c,second,art)); local revision=c.revision; R.Select(c,location,art); eq(c.revision,revision,"saving the same choice is idempotent")
for _,row in ipairs(R.Choices(location,"local"))do assert(row.texture and row.thumbnail,"all nine Westfall scenes have development exports")end
for _,row in ipairs(R.Choices(second,"local"))do assert(row.texture and row.thumbnail,"all nine Elwynn scenes have development exports")end
for _,row in ipairs(R.Choices("dungeon:the-deadmines","local"))do assert(row.texture and row.thumbnail,"all nine Deadmines scenes have development exports")end
local redridge=R.Choices("zone:redridge-mountains","local");assert(#redridge==9)
for i,row in ipairs(redridge)do assert(row.id=="redridge-mountains-"..string.format("%02d",i) and row.texture and row.thumbnail,"Redridge stable slots, textures and thumbnails")end
-- Force an unavailable export in the fixture; new artwork must not invalidate this guard.
local pending="raid:molten-core";local pendingRow=R.Choices(pending,"local")[1]
local unexported=pendingRow.id;local pendingTexture,pendingThumbnail=pendingRow.texture,pendingRow.thumbnail
pendingRow.texture,pendingRow.thumbnail=nil,nil
local ironforge=R.Choices('zone:ironforge','local');eq(#ironforge,9)
for i,row in ipairs(ironforge)do
 eq(row.id,'ironforge-'..string.format('%02d',i));assert(row.texture and row.thumbnail)
 assert(R.Select(c,'zone:ironforge',row.id));eq(R.Resolve(c,'zone:ironforge').id,row.id)
 eq(R.Resolve(other,'zone:ironforge'),nil,'Ironforge choice stays character-specific')
 assert(R.Select(c,location,row.id));eq(R.Resolve(c,location).id,row.id,'Foreign artwork can decorate Westfall')
end
R.Clear(c,'zone:ironforge')
local stormwind=R.Choices('zone:stormwind-city','local');eq(#stormwind,9)
for i,row in ipairs(stormwind)do
 eq(row.id,'stormwind-city-'..string.format('%02d',i));assert(row.texture and row.thumbnail)
 assert(R.Select(c,'zone:stormwind-city',row.id));eq(R.Resolve(c,'zone:stormwind-city').id,row.id)
 eq(R.Resolve(other,'zone:stormwind-city'),nil,'Stormwind choice stays character-specific')
 assert(R.Select(c,location,row.id));eq(R.Resolve(c,location).id,row.id,'Foreign artwork remains resolvable')
end
R.Clear(c,'zone:stormwind-city')
assert(not R.Select(c,pending,unexported),"unexported concepts cannot be selected")
assert(R.Select(c,location,"wf-bread")); eq(R.Resolve(c,location).id,"wf-bread"); R.Select(c,location,art)
local temporary={id="test-local",location=second,type="Zone",texture="test"}; R.rows[temporary.id]=temporary
assert(R.Select(c,location,temporary.id),"a chosen catalog illustration can decorate any location"); R.rows[temporary.id]=nil
c.art[location]="removed-illustration"; local _,message=R.Resolve(c,location); assert(message:find("preserved",1,true)); eq(c.art[location],"removed-illustration")
c.art["legacy-location-key"]="keep-me"; R.Clear(c,location); eq(c.art["legacy-location-key"],"keep-me"); eq(c.art[second],art)
local screenshot=S.Add(c,"screenshot",A.Now(),{title="Original screenshot",status="unconfirmed",image="unavailable"})
local memory=S.Add(c,"memory",A.Now(),{title="Original memory",text="My words",refs={screenshot.id}})
local savedMemory,savedScreenshot=E.Copy(memory),E.Copy(screenshot)
B.ChangeCharacter(c.id); B.SetChapter("Memories"); B.memoryMode="illustrations"; B.artLocation=location; B.artPreview=art; B.Render(true)
eq(c.art[location],nil,"default preview does not save a choice")
local function click(text,page)
    page=page or B.right
    for _,kind in ipairs({"button","artControl"})do for i=1,page.used[kind]or 0 do local f=page.pool[kind][i];if f.text:GetText()==text then f:Click();return end end end
    error("Artwork button missing: "..text)
end
assert(B.right.used.artImage==1 and B.left.used.artImage==6,"six left thumbnails plus one right preview")
click("Use for Westfall"); eq(c.art[location],art)
assert(E.Same(memory,savedMemory) and E.Same(screenshot,savedScreenshot),"art selection cannot rewrite prior memories or screenshot metadata")
local oldPage={zone="Westfall",ts=1,text="Unchanged history"}; local original=E.Copy(oldPage)
eq(R.ForRecord(c,oldPage).id,art); eq(R.ForRecord(other,oldPage),nil)
R.Select(c,location,"gen-camp"); eq(R.ForRecord(c,oldPage).id,"gen-camp","older pages resolve the new choice")
assert(E.Same(oldPage,original),"decoration must not alter recorded facts")
eq(R.ForRecord(c,{zone="Unknown place"}),nil); eq(R.ForRecord(c,{zone="westfall"}),nil,"no inferred alias mapping")
B.Clear(B.right); V.Record(B.right,c,oldPage); eq(B.right.used.artImage,1); eq(B.right.pool.artImage[1].image.texture,R.rows['gen-camp'].texture)
R.Clear(c,location); eq(R.ForRecord(c,oldPage),nil); R.Select(c,location,art)
B.artLocation=pending; B.artPreview=unexported; B.Render(); eq(c.art[location],art)
for i=1,B.right.used.artControl or 0 do assert(not B.right.pool.artControl[i].text:GetText():find("^Use for "),"missing texture has no apply action")end
pendingRow.texture,pendingRow.thumbnail=pendingTexture,pendingThumbnail
B.artLocation=location
B.artCollection="local"; B.artPreview=nil; B.Render(); local slots=#B.left.pool.artImage
B.artPage=2; B.Render(); eq(#B.left.pool.artImage,slots,"paging reuses bounded texture frames")
B.artCollection="anywhere"; B.artPreview=art; B.Render()
local frame=B.right.pool.artImage[1]; assert(frame.image:IsShown()); assert(not frame.message:IsShown())
-- A previously selected but missing texture is visible as an unavailable state; the ID survives.
local texture=R.rows[art].texture; R.rows[art].texture=nil; B.Render(); eq(c.art[location],art); assert(frame.message:IsShown()); assert(not frame.image:IsShown())
R.rows[art].texture=texture; B.Render()
frame.image.loaded=false; B.Render(); assert(not frame.image:IsShown()); assert(frame.scripts.OnUpdate)
frame.scripts.OnUpdate(frame,6); eq(frame.scripts.OnUpdate,nil); assert(frame.message:GetText():find("unavailable",1,true))
frame.image.loaded=true; B.Render(); assert(frame.image:IsShown())
local setTexture=frame.image.SetTexture; frame.image.SetTexture=function()return false end; B.Render(); assert(frame.message:GetText():find("could not",1,true)); assert(not frame.image:IsShown())
frame.image.SetTexture=setTexture; B.Render()
-- Loose file lookup distinguishes real assets from a ready missing-file texture.
-- A false setter is accepted only with both independent recognition and the
-- exact selected path; this exercises the native UIForever counterexample.
local oldFileAsset=C_UIFileAsset
C_UIFileAsset={IsKnownFile=function(path)return path==texture end}
frame.image.SetTexture=function(self,path)self.texture=path;return false end
B.Render();assert(frame.image:IsShown()and not frame.message:IsShown(),"recognized selected loose file renders")
frame.image.loaded=false;B.Render();assert(not frame.image:IsShown()and frame.scripts.OnUpdate)
frame.image.loaded=true;frame.scripts.OnUpdate(frame,.1);assert(frame.image:IsShown()and not frame.scripts.OnUpdate,"recognized file still waits for readiness")
C_UIFileAsset.IsKnownFile=function()return false end
B.Render();assert(not frame.image:IsShown()and not frame.scripts.OnUpdate,"ready missing file rejected")
frame.image.SetTexture=setTexture;B.Render();assert(not frame.image:IsShown(),"known missing file overrides successful setter")
C_UIFileAsset.IsKnownFile=function()return true end
frame.image.SetTexture=function()return false end
frame.image.texture="different-file";B.Render();assert(not frame.image:IsShown(),"stale path rejected")
frame.image.SetTexture=function()error('setter unavailable')end
B.Render();assert(not frame.image:IsShown(),"file recognition cannot hide a failed call")
frame.image.SetTexture=function(self,path)self.texture=path;return false end
for _,lookup in ipairs({function()return nil end,function()error('lookup unavailable')end})do
    C_UIFileAsset.IsKnownFile=lookup;B.Render();assert(not frame.image:IsShown(),"unknown recognition cannot rescue a false setter")
end
C_UIFileAsset.IsKnownFile=function()return true end
frame.image.loaded=false;B.Render();frame.scripts.OnUpdate(frame,5);assert(not frame.image:IsShown()and not frame.scripts.OnUpdate,"recognized file can still time out")
frame.image.loaded=true;frame.image.SetTexture=setTexture;C_UIFileAsset=oldFileAsset;B.Render()
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]); B.Fit(); B.Render(); eq(B.frame:GetWidth(),1760); eq(B.frame:GetHeight(),940)end
UIParent:SetSize(1920,1080); B.Fit()
B.ChangeCharacter(other.id); eq(B.artLocation,nil); eq(R.Resolve(other,location),nil); B.ChangeCharacter(c.id); eq(B.artLocation,location)
B.memoryMode="illustrations"; B.Render(); click("Clear this location's choice"); eq(c.art[location],nil); eq(c.art[second],art)
B.SetChapter("Chronicle"); eq(frame.image.texture,nil,"hidden gallery releases its image reference"); eq(frame.scripts.OnUpdate,nil)
print("PASS artwork: registry, per-character/location choices, preview versus apply, dynamic older pages, known/unknown/missing loose files, stale/error/timeout guards, release, bounded thumbnails and fixed sizing")
