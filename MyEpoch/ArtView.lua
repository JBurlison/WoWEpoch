local _,E=...
local V,B,R,A={},E.Book,E.Artwork,E.API; E.ArtView=V
local T=E.BookTheme
local function width(page)return B.Width and B.Width(page)or 760 end
local function grid(page,context)
    local tile=(width(page)-40)/3;local image=context and tile-12 or tile;local imageHeight=image/2
    local titleY=imageHeight+(context and 2 or 4);local titleHeight=context and 30 or 34
    local height=context and(titleY+titleHeight+2)or(titleY+titleHeight+22)
    return {tile=tile,image=image,imageHeight=imageHeight,titleY=titleY,titleHeight=titleHeight,height=height,stride=height+(context and 0 or 8)}
end
local function sizeTile(tile,g,context)
    tile:SetSize(g.tile,g.height);tile.text:ClearAllPoints();tile.text:SetPoint('TOPLEFT',6,-g.titleY)
    tile.text:SetWidth(g.tile-12);tile.text:SetHeight(g.titleHeight);tile.text:SetFont(E.Font(),context and 12 or 13,'')
    tile.status:ClearAllPoints();tile.status:SetPoint('TOPLEFT',6,-g.titleY-g.titleHeight-4);tile.status:SetWidth(g.tile-12);tile.status:SetHeight(22);tile.status:SetMaxLines(2)
    if context then tile.status:Hide()else tile.status:Show()end
end
for _,pair in ipairs({{"artControl","calendarControl"},{"artLocationRow","questRow"}})do B.widgetFactories[pair[1]]=B.widgetFactories[pair[2]]end
B.widgetFactories.artTile=function(parent)
    local f=CreateFrame("Button",nil,parent)
    f.text=f:CreateFontString(nil,"OVERLAY");f.text:SetFont(E.Font(),13,"");f.text:SetTextColor(.29,.19,.11)
    f.text:SetWidth(228);f.text:SetHeight(34);f.text:SetMaxLines(2);f.text:SetJustifyH("LEFT");f.text:SetJustifyV("TOP");f.text:SetPoint("TOPLEFT",6,-124)
    f.status=f:CreateFontString(nil,"OVERLAY");f.status:SetFont(E.Font(),10,"");f.status:SetTextColor(.54,.40,.23)
    f.status:SetWidth(228);f.status:SetJustifyH("LEFT");f.status:SetPoint("TOPLEFT",6,-162)
    f.accent=f:CreateTexture(nil,"ARTWORK");f.accent:SetWidth(3);f.accent:SetPoint("TOPLEFT");f.accent:SetPoint("BOTTOMLEFT");f.accent:SetColorTexture(.52,.23,.12,1)
    f:SetHighlightTexture("Interface\\Buttons\\WHITE8X8");f:GetHighlightTexture():SetAlpha(.08);return f
end
local function controls(page,rows,columns)
    columns=columns or 3;local y=page.y;local w=(width(page)-(columns-1)*8)/columns
    for i,r in ipairs(rows)do local f=B.Acquire(page,"artControl")
        f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+((i-1)%columns)*(w+8),-y-math.floor((i-1)/columns)*38)
        f:SetSize(w,32);f.text:SetWidth(w-12);f.text:SetText(E.Text(r[1]));T.ButtonStyle(f,r[3]and"filter"or nil);f:SetScript("OnClick",r[2])
    end;page.y=y+math.ceil(#rows/columns)*38
end
local function bounds(rows,key,size,state)
    local B=state or B
    local count=math.max(1,math.ceil(#rows/size));B[key]=math.max(1,math.min(B[key]or 1,count))
    return (B[key]-1)*size+1,math.min(#rows,B[key]*size),count
end
local function navigation(page,rows,key,size,state,redraw)
    local B=state or B;redraw=redraw or E.Book.Render
    local _,_,count=bounds(rows,key,size,B);local buttons={}
    if B.navigation then B.navigation(B[key],count,function(delta)B[key]=B[key]+delta;redraw(true)end);return end
    if B[key]>1 then buttons[#buttons+1]={"Previous page",function()B[key]=B[key]-1;redraw(true)end}end
    if B[key]<count then buttons[#buttons+1]={"Next page",function()B[key]=B[key]+1;redraw(true)end}end
    if #buttons>0 then controls(page,buttons,2)end
end
local function title(row)return row.title=="Brief not written"and row.type.." illustration "..row.slot.." - planned"or row.title end
local function previewCaption(page,row,fontSize)
    B.Text(page,title(row),24)
    local collection=R.CollectionName(row)
    if row.mob and row.sceneZone and row.combatAction then
        B.Text(page,collection.." · "..row.mob.." · "..row.sceneZone,13)
        B.Text(page,row.combatAction.." "..(row.humor or ""),fontSize)
    else
        B.Text(page,collection,13)
        B.Text(page,row.alt,fontSize)
    end
end
local function assignImage(image,texture)
    -- A file setter's result alone does not establish file presence or readiness.
    -- In particular, loose addon images can be selected while the setter reports
    -- false. Require independent file recognition AND the selected path in that
    -- case; a missing file must never pass merely because IsObjectLoaded is true.
    A.Call("artRelease",image.SetTexture,image,nil)
    local assigned=A.Call("artTexture",image.SetTexture,image,texture)
    local known=A.Call("artFileKnown",C_UIFileAsset and C_UIFileAsset.IsKnownFile,texture)
    if known==false then return false end
    if assigned==true then return true end
    if assigned==false and known==true then
        return A.Call("artTexturePath",image.GetTexture,image)==texture
    end
    return false
end
function V.Image(page,row,width,height,thumbnail,framed)
    local limit=B.Width and B.Width(page)or 760
    if width>limit then height=height*limit/width;width=limit end
    if framed then height=(width-32)/2+32 end
    local frame=B.Acquire(page,"artImage"); frame:SetSize(width,height)
    if not frame.image then
        frame.image=frame:CreateTexture(nil,"ARTWORK"); frame.image:SetAllPoints()
        frame.message=frame:CreateFontString(nil,"OVERLAY"); frame.message:SetPoint("CENTER"); frame.message:SetFont(E.Font(),14,""); frame.message:SetTextColor(0.3,0.15,0.07)
        frame:SetScript("OnHide",function(self)self:SetScript("OnUpdate",nil); A.Call("artRelease",self.image.SetTexture,self.image,nil); self.image:Hide()end)
    end
    frame.image:ClearAllPoints()
    if framed then
        if not frame.photo then E.BookTheme.Photo(frame)end
        frame.photo:Show(); frame.image:SetPoint("TOPLEFT",16,-16); frame.image:SetPoint("BOTTOMRIGHT",-16,16)
    else
        if frame.photo then frame.photo:Hide()end
        frame.image:SetAllPoints()
    end
    frame.message:SetWidth(width-20); frame.image:Hide(); frame.message:Show(); frame:SetScript("OnUpdate",nil)
    local texture=row and (thumbnail and row.thumbnail or row.texture)
    if not texture then frame.message:SetText("Illustration not available yet")
    elseif not assignImage(frame.image,texture) then frame.message:SetText("Illustration could not be loaded")
    else
        frame.message:SetText("Loading illustration…"); frame.elapsed=0
        local function check(self,delta)
            self.elapsed=self.elapsed+(delta or 0)
            if A.Call("artTextureLoaded",self.image.IsObjectLoaded,self.image)==true then
                self.image:Show(); self.message:Hide(); self:SetScript("OnUpdate",nil)
            elseif self.elapsed>=5 then self.message:SetText("Illustration unavailable. Preview it again to retry."); self:SetScript("OnUpdate",nil)end
        end
        frame:SetScript("OnUpdate",check); check(frame,0)
    end
    page.y=page.y+height+12; return frame
end
function V.Render(left,right,context)
    local state=context or B;local redraw=context and context.redraw or B.Render
    local pageSize=context and 9 or 6;local geometry=grid(left,context);local stride=geometry.stride
    local apply=context and context.apply or function(change)local ok=change();redraw();return ok end
    local c=context and context.owner or B.Character();local location=R.locations[state.artLocation]
    if location and state.artCollection=="catalog" and not state.artChooser then
        local top=left.y
        local label=B.Text(left,"Search (Enter)",12);label:SetWidth(150)
        local input=B.Input(left,state.artCatalogQuery or"",function(value)state.artCatalogQuery=value;state.artPreview=nil;state.artMode=nil;state.artPage=1;state.artError=nil;redraw(true)end)
        input:ClearAllPoints();input:SetPoint('TOPLEFT',left.content,'TOPLEFT',178,-top);input:SetSize(width(left)-166,30);left.y=top+38
    else
        controls(left,{{location and"Decorating: "..location.name or"Choose a location",function()state.artChooser=not state.artChooser;redraw()end,state.artChooser}},1)
    end
    if state.artChooser or not location then
        local types={};for _,kind in ipairs({"all","Zone","Dungeon","Raid"})do local value=kind
            types[#types+1]={kind=="all"and"All types"or kind,function()state.artType=value;state.artLocationPage=1;redraw(true)end,(state.artType or"all")==kind}
        end;controls(left,types,4)
        B.Text(left,"Find a location; Enter to search",12)
        B.Input(left,state.artQuery or"",function(value)state.artQuery=value;state.artLocationPage=1;redraw(true)end)
        local locations=R.Locations(state.artType,state.artQuery);V.lastLocations=locations
        local first,last,count=bounds(locations,"artLocationPage",6,state)
        if #locations==0 then B.Text(left,"No catalog locations match this search.",15)end
        if count>1 then B.Text(left,"Locations / Page "..state.artLocationPage.." of "..count,12)end
        for i=first,last do local loc=locations[i];local f=B.Acquire(left,"artLocationRow")
            f:SetWidth(width(left));f.text:SetWidth(width(left)-186);f.status:SetWidth(150);f.meta:SetWidth(width(left)-24)
            f.text:SetText(E.Text(loc.name));f.status:SetText(loc.type);f.meta:SetText("Nine dedicated scenes + the anywhere collection")
            local h=math.max(f.text:GetStringHeight(),f.status:GetStringHeight());f.meta:ClearAllPoints();f.meta:SetPoint("TOPLEFT",12,-h-18);f:SetHeight(h+f.meta:GetStringHeight()+30)
            f.tint:SetAlpha(state.artLocation==loc.key and 1 or 0);f.accent:SetAlpha(state.artLocation==loc.key and 1 or 0)
            f:SetScript("OnClick",function()state.artLocation=loc.key;state.artMode=nil;state.artChooser=false;state.artPreview=nil;state.artPage=1;state.artError=nil;redraw(true)end);left.y=left.y+f:GetHeight()
        end;navigation(left,locations,"artLocationPage",6,state,redraw)
    end
    if not location then
        B.Text(right,"A LITTLE CHARACTER FOR EVERY CHAPTER",11);B.Text(right,"Choose a place to decorate",29)
        B.Text(right,"Pick a zone, dungeon or raid on the left. Preview a scene, then save it for this character's pages.",17)
        B.Text(right,"Nine dedicated illustrations belong to each location. The 27 anywhere illustrations form their own collection.",15)
        B.Text(right,"Location coverage and final artwork review remain in progress.",13);V.lastPreview=nil;return
    end
    local current,message=R.Resolve(c,location.key)
    local options={};for _,option in ipairs({{"all","Local + anywhere"},{"local","This location's nine"},{"anywhere","Anywhere collection"},{"catalog","All illustrations"}})do local value=option[1]
        options[#options+1]={option[2],function()state.artCollection=value;state.artCategory=nil;state.artTag=nil;state.artMode=nil;state.artPreview=nil;state.artPage=1;state.artError=nil;redraw(true)end,(state.artCollection or"all")==value}
    end
    local rows=R.Choices(location.key,state.artCollection,state.artCatalogQuery,state.artCategory,state.artTag);local preview=R.rows[state.artPreview];local included={}
    for _,row in ipairs(rows)do included[row.id]=true end
    if not preview or not included[preview.id]then preview=current and included[current.id]and current or rows[1]end
    V.lastPreview=preview;V.lastChoices=rows
    if not state.artChooser then
        controls(left,options,4)
        local first,last,count=bounds(rows,"artPage",pageSize,state);B.Text(left,"The collection / Page "..state.artPage.." of "..count.." / Click a scene to preview",12)
        local top=left.y
        for i=first,last do local row=rows[i];local n=i-first;local x=12+(n%3)*(geometry.tile+20);local y=top+math.floor(n/3)*stride
            left.y=y;local frame=V.Image(left,row,geometry.image,geometry.imageHeight,true);frame:ClearAllPoints();frame:SetPoint("TOPLEFT",left.content,"TOPLEFT",x+(context and 6 or 0),-y)
            local tile=B.Acquire(left,"artTile");tile:ClearAllPoints();tile:SetPoint("TOPLEFT",left.content,"TOPLEFT",x,-y);sizeTile(tile,geometry,context)
            tile.artID=row.id;tile.text:SetText(E.Text(title(row)));tile.status:SetText((current and current.id==row.id and"SAVED / "or"")..(row.type=="Anywhere"and"Anywhere"or"Dedicated")..(row.texture and""or" / Not bundled"))
            tile.accent:SetAlpha(preview and preview.id==row.id and 1 or 0);tile:SetScript("OnClick",function()state.artPreview=row.id;state.artMode=nil;state.artError=nil;redraw(true)end)
        end
        left.y=top+math.ceil(math.max(0,last-first+1)/3)*stride;navigation(left,rows,"artPage",pageSize,state,redraw)
        if #rows==0 then B.Text(left,"No available illustrations match this search.",16)end
    end
    B.Text(right,"DECORATING / "..location.type:upper(),11);B.Text(right,location.name,29)
    B.Text(right,current and"Saved choice: "..current.title or message,13)
    if preview then
        local actions={}
        if preview.texture then
            local function save()local row,err=R.Select(c,location.key,preview.id);state.artError=err;if row then state.artPreview=row.id end;return row~=nil end
            if context then
                if state.artMode~="clear" then context.stage(save,"Apply keeps “"..title(preview).."” for "..location.name.." and closes this window.")end
            else actions[#actions+1]={"Use for "..location.name,function()apply(save)end,current and current.id==preview.id}end
        end
        if #actions>0 then controls(right,actions,2)end
        V.Image(right,preview,width(right),410,false,true)
        previewCaption(right,preview,15)
        if preview.texture then B.Text(right,preview.approved and"Decorative illustration"or"Development illustration / Final client review pending",12)
        else B.Text(right,"This scene is planned but has no bundled texture. Your saved choice stays unchanged.",14)end
    end
    if c.art and c.art[location.key]then
        local function clear()local ok=R.Clear(c,location.key);state.artError=nil;return ok end
        controls(right,{{"Clear this location's choice",function()if context then state.artMode="clear";redraw()else apply(clear)end end,state.artMode=="clear"}},2)
        if context and state.artMode=="clear"then context.stage(clear,"Apply removes this location’s saved choice and closes this window.")end
    end
    if state.artError then B.Text(right,state.artError,14)end
    B.Text(right,"Previewing does not save a choice. Decorative illustrations never replace captured screenshots or change the facts of a memory.",13)
end
function V.Record(page,c,record)
    if record.kind=="milestone"and not R.CanCustomize(c,record)then return end
    if record.kind=='milestone'and R.CanCustomize(c,record)then
        B.Action(page,"Choose milestone illustration",function()E.ArtDialog.OpenRecord(record)end)
    end
    local overridden=record.artMode=='fixed'or record.artMode=='none'or record.artMode=='location'
    local milestones=not overridden and R.MilestoneChoices(c,record)or{}
    if #milestones>0 then
        local choice=V.weaponSelection
        if not choice or choice.character~=c.id or choice.record~=record then
            choice={character=c.id,record=record,threshold=milestones[#milestones].milestone};V.weaponSelection=choice
        end
        local selected=#milestones
        for i,entry in ipairs(milestones)do if entry.milestone==choice.threshold then selected=i;break end end
        choice.threshold=milestones[selected].milestone
        local weapon=R.weapons["weapon-skill-"..record.skillID]
        local name=weapon and weapon.name or record.skillName or "Weapon skill"
        B.Text(page,name.." / "..choice.threshold.." points",18)
        if #milestones>1 then
            local actions={}
            local function choose(index)return function()choice.threshold=milestones[index].milestone;B.Render()end end
            if selected>1 then actions[#actions+1]={"Previous milestone",choose(selected-1)}end
            if selected<#milestones then actions[#actions+1]={"Next milestone",choose(selected+1)}end
            controls(page,actions,2)
            B.Text(page,"Recorded milestones / "..selected.." of "..#milestones,12)
        end
        local art=milestones[selected].art
        if art then V.Image(page,art,width(page),410,false,true);B.Text(page,"Decorative illustration | "..R.CollectionName(art).." | "..art.title,12)
        else
            local fallback=R.MilestoneFallback(c,record)
            if fallback then
                V.Image(page,fallback,width(page),410,false,true)
                B.Text(page,"Decorative artwork · "..choice.threshold.."-point illustration pending",12)
            else B.Text(page,"No bundled illustration for "..name.." at "..choice.threshold.." points.",13)end
        end
        return
    end
    local row,message,key=R.ForRecord(c,record)
    if not row then if (record.kind=="memory"or record.kind=="milestone")and record.artMode=="fixed" then B.Text(page,message,14)end;return end
    V.Image(page,row,width(page),410,false,true)
    B.Text(page,"Decorative illustration | "..R.CollectionName(row).." | "..row.title,12)
end
-- Retained for earlier standalone review fixtures; production entry points use the dialog.
function V.OpenMemoryInline(record)
    B.artMemoryID=record.id;B.artMemoryCharacter=B.Character().id;B.memoryArtQuery="";B.memoryArtPage=1;B.memoryArtPreview=record.artID;B.artError=nil
    B.memoryMode="memory-art";B.selected=nil;B.Render(true)
end
function V.Memory(left,right,context)
    local state=context or B;local redraw=context and context.redraw or B.Render
    local pageSize=context and 9 or 6;local geometry=grid(left,context);local stride=geometry.stride
    local apply=context and context.apply or function(change)local ok=change();redraw();return ok end
    local c=context and context.owner or B.Character();local record=c.id==state.artMemoryCharacter and c.records[state.artMemoryID]
    if not R.CanCustomize(c,record)then B.Text(right,"This entry is no longer available in this scrapbook.",18);return end
    local milestone=record.kind=="milestone"or record.kind=="recap";local kind=record.kind
    local function back()B.memoryMode="saved";B.selected=record.id;B.memoryFocus=record.id;B.memoryEditing=false;state.artMemoryID=nil;redraw(true)end
    if not context then controls(left,{{"Back to this memory",back}},1)end
    B.Text(left,"Find a scene, mob, place or Easter egg (Enter)",12)
    B.Input(left,state.memoryArtQuery or "",function(value)state.memoryArtQuery=value;state.memoryArtMode=nil;state.memoryArtPage=1;state.memoryArtPreview=nil;redraw(true)end)
    local rows=R.MemoryChoices(state.memoryArtQuery,state.artCategory,state.artTag);V.lastMemoryChoices=rows
    local first,last,count=bounds(rows,"memoryArtPage",pageSize,state);local included={};for _,row in ipairs(rows)do included[row.id]=true end
    local preview=included[state.memoryArtPreview] and R.rows[state.memoryArtPreview] or rows[first]
    local default,defaultMessage,defaultKey,pendingThreshold
    if milestone then default,defaultMessage,defaultKey,pendingThreshold=R.DefaultRecord(c,record)end
    local defaultPreview=milestone and state.memoryArtMode=="default"
    local follow=state.memoryArtMode=="location"
    local noArt=state.memoryArtMode=="none"
    local locationMessage,locationKey
    if defaultPreview then preview=default
    elseif follow then preview,locationMessage,locationKey=R.LocationChoice(c,record)
    elseif noArt then preview=nil end
    V.lastMemoryPreview=preview
    B.Text(left,#rows.." available scenes / Page "..state.memoryArtPage.." of "..count,12)
    local top=left.y
    for i=first,last do local row=rows[i];local n=i-first;local x=12+(n%3)*(geometry.tile+20);local y=top+math.floor(n/3)*stride
        left.y=y;local frame=V.Image(left,row,geometry.image,geometry.imageHeight,true);frame:ClearAllPoints();frame:SetPoint("TOPLEFT",left.content,"TOPLEFT",x+(context and 6 or 0),-y)
        local tile=B.Acquire(left,"artTile");tile:ClearAllPoints();tile:SetPoint("TOPLEFT",left.content,"TOPLEFT",x,-y);sizeTile(tile,geometry,context)
        tile.artID=row.id;tile.text:SetText(E.Text(title(row)));tile.status:SetText(record.artMode=="fixed" and record.artID==row.id and "SAVED FOR THIS "..record.kind:upper() or "Decorative illustration")
        tile.accent:SetAlpha(preview and preview.id==row.id and 1 or 0);tile:SetScript("OnClick",function()state.memoryArtPreview=row.id;state.memoryArtMode="fixed";redraw(true)end)
    end
    left.y=top+math.ceil(math.max(0,last-first+1)/3)*stride;navigation(left,rows,"memoryArtPage",pageSize,state,redraw)
    if #rows==0 then B.Text(left,"No available illustrations match this search.",16)end
    B.Text(right,"AN ILLUSTRATION FOR THIS "..kind:upper(),11);B.Text(right,record.title or (milestone and"Personal milestone"or"Personal memory"),29)
    local current,message,currentKey=R.ForRecord(c,record)
    if milestone and record.artMode==nil then
        current=default
        if pendingThreshold then message="Decorative artwork · "..pendingThreshold.."-point illustration pending"end
    end
    local savedLocation=R.locations[currentKey]
    B.Text(right,record.artMode=="fixed" and (current and "Kept illustration: "..current.title or message) or record.artMode=="none" and "No illustration selected." or milestone and record.artMode~="location"and("Default artwork: "..(current and current.title or message or"No illustration available"))or (savedLocation and "Following location: "..savedLocation.name or "No matching artwork location."),14)
    local function save(mode,id)return function()local ok,err=R.SelectRecord(c,record.id,mode,id);state.artError=err;return ok end end
    local function select(mode,id)if context then state.memoryArtMode=mode;redraw()else apply(save(mode,id))end end
    local modes={{"Follow location",function()select("location")end,state.memoryArtMode=="location"},{"No illustration",function()select("none")end,state.memoryArtMode=="none"}}
    if milestone then table.insert(modes,1,{"Use default",function()select("default")end,state.memoryArtMode=="default"})end
    controls(right,modes,milestone and 3 or 2)
    if follow then
        local location=R.locations[locationKey]
        if location then B.Text(right,"Location preview · "..location.name,14)end
        if not preview then B.Text(right,locationMessage,14)end
    elseif noArt then
        B.Text(right,"This page will have no illustration.",14)
    end
    if preview then
        if not context then controls(right,{{"Use for this memory",function()select("fixed",preview.id)end}},1)end
        V.Image(right,preview,width(right),410,false,true)
        if defaultPreview and pendingThreshold then B.Text(right,"Decorative artwork · "..pendingThreshold.."-point illustration pending",12)end
        previewCaption(right,preview,14)
    end
    if context then
        local mode=state.memoryArtMode or "fixed"
        if mode=="default"and milestone then context.stage(save(mode),"Apply restores this "..kind.."’s automatic artwork and closes this window.")
        elseif mode=="location"then context.stage(save(mode),"Apply makes this "..kind.." follow its location’s artwork and closes this window.")
        elseif mode=="none"then context.stage(save(mode),"Apply removes this "..kind.."’s illustration and closes this window.")
        elseif preview then context.stage(save("fixed",preview.id),"Apply keeps “"..title(preview).."” with this "..kind.." and closes this window.")end
    end
    if state.artError then B.Text(right,state.artError,14)end
    B.Text(right,"Previewing does not save a choice. Illustration choices never edit your words or the linked historical records.",12)
end

function V.OpenMemory(record)return E.ArtDialog.OpenMemory(record)end
