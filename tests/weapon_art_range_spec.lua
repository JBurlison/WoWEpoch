local R,S,B,V=E.Artwork,E.Store,E.Book,E.ArtView
local function hasPainting(skill,points) return points>=25 and points<=300 end
local owner=S.Character("weapon-book-range-202",{name="Range reader"})
local planned,available=0,0
for _,weapon in ipairs(E.ArtCatalog.weapons)do
    local map=R.byWeapon[weapon.skillLineID]
    for points=25,300,25 do
        local row=assert(map[points])
        assert(row.id==weapon.key.."-"..string.format("%03d",points))
        planned=planned+1
        local bundled=hasPainting(weapon.skillLineID,points)
        assert((row.texture~=nil)==bundled and (row.thumbnail~=nil)==bundled)
        if bundled then
            available=available+1
            assert(row.combatReview=="Passed" and row.mob and row.combatAction and row.sceneZone)
            if points==25 then
                local priorID=weapon.key.."-025"
                local memory=S.Add(owner,"memory",time(),{artMode="fixed",artID=priorID,zone="Westfall"})
                local revision=owner.revision
                assert(R.ForRecord(owner,memory)==row and memory.artID==priorID and owner.revision==revision)
                local selected=R.Select(owner,"zone:westfall",priorID)
                assert(selected==row and R.Resolve(owner,"zone:westfall")==row)
            end
        else assert(row.combatReview=="Awaiting artwork")end
    end
end
assert(planned==192 and available==192)
local count=0
for _,row in ipairs(R.MemoryChoices("","skills","all"))do
    assert(row.texture and row.thumbnail)
    if row.weapon then count=count+1 end
end
assert(count==192,"Only generated weapon scenes can be chosen")
B.Open();B.ChangeCharacter(owner.id);B.SetChapter("Chronicle")
-- Open every available rank, including the exact choice at 200 and Swords 300.
for _,weapon in ipairs(E.ArtCatalog.weapons)do
    local skill=weapon.skillLineID
    for points=25,300,25 do if hasPainting(skill,points) then
        local r=S.Add(owner,"milestone",E.API.Now(),{subject=owner.id,skillID=skill,milestoneType="skill",
            major=true,before=points-1,after=points,thresholds={points},title="Recorded skill milestone"})
        local row=R.byWeapon[skill][points];B.selected=r.id;B.Render(true);TEST_PREPARE_BOOK()
        assert(R.ForRecord(owner,r)==row and V.weaponSelection.threshold==points)
        assert(B.right.pool.artImage[1].image.texture==row.texture)
    end end
end
local r=S.Add(owner,"milestone",E.API.Now(),{subject=owner.id,skillID=45,milestoneType="skill",major=true,before=299,after=325,thresholds={300,325}})
local choices=R.MilestoneChoices(owner,r)
assert(#choices==2 and choices[1].art==R.byWeapon[45][300] and choices[2].art==nil)
assert(not R.ForRecord(owner,r)and not R.SelectRecord(owner,r.id,"fixed",'weapon-skill-45-325'))
print("PASS curated 25-300 weapon art: 192 distinct slots, 192 available, every supported skill checked across twelve tiers, missing or out-of-plan art unavailable")
