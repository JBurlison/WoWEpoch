-- Disposable texture-format review addon. Never shipped with MyEpoch.
-- Ordinary texture APIs only; no overrides, SavedVariables or automatic display.
local scenes={"dun-morogh-02","undercity-02","darnassus-05","stormwind-city-09"}
local variants={"tga","bc1-base","bc1-mips","1024-tga","1024-bc1","bc3","missing","corrupt"}
local root="Interface\\AddOns\\MyEpochTextureReview\\Media\\"
local frame,scene,variant,revision
revision=0
local function known(path)
 if C_UIFileAsset and C_UIFileAsset.IsKnownFile then return C_UIFileAsset.IsKnownFile(path) end
 return "API unavailable"
end
local function loaded(t)
 if t.IsObjectLoaded then return t:IsObjectLoaded() end
 return "API unavailable"
end
local function text(f,value,x,y,w,size)
 local t=f:CreateFontString(nil,"OVERLAY");t:SetFont("Fonts\\FRIZQT__.TTF",size or 16)
 t:SetSize(w or 780,24);t:SetPoint("TOPLEFT",x,y);t:SetJustifyH("LEFT");t:SetText(value);return t
end
local function button(f,label,x,y,w,action)
 local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(w,26);b:SetPoint("TOPLEFT",x,y)
 b:SetText(label);b:SetScript("OnClick",action);return b
end
function MyEpochTextureCompare(wantedScene,wantedVariant)
 scene=wantedScene or scene or "darnassus-05";variant=wantedVariant or variant or "tga"
 local found=false;for _,v in ipairs(scenes)do if v==scene then found=true end end;assert(found,"Unknown review scene")
 found=false;for _,v in ipairs(variants)do if v==variant then found=true end end;assert(found,"Unknown review variant")
 if not frame then
  frame=CreateFrame("Frame","MyEpochTextureReviewFrame",UIParent);frame:SetSize(820,700);frame:SetPoint("CENTER");frame:SetFrameStrata("TOOLTIP")
  local bg=frame:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.07,.07,.09,.98)
  frame.title=text(frame,"",20,-10,730,18)
  frame.image=frame:CreateTexture(nil,"ARTWORK");frame.image:SetSize(728,364);frame.image:SetPoint("TOPLEFT",46,-50)
  text(frame,"Existing TGA thumbnail",100,-421,300,15);text(frame,"BC1 thumbnail with mips",430,-421,300,15)
  frame.reference=frame:CreateTexture(nil,"ARTWORK");frame.reference:SetSize(256,128);frame.reference:SetPoint("TOPLEFT",100,-449)
  frame.thumbnail=frame:CreateTexture(nil,"ARTWORK");frame.thumbnail:SetSize(256,128);frame.thumbnail:SetPoint("TOPLEFT",430,-449)
  for i,v in ipairs(variants)do local choice=v;button(frame,v,20+(i-1)*98,-590,94,function()MyEpochTextureCompare(scene,choice)end)end
  for i,v in ipairs(scenes)do local choice=v;button(frame,v,20+(i-1)*196,-625,190,function()MyEpochTextureCompare(choice,"tga")end)end
  frame.status=text(frame,"",20,-660,780,12)
  button(frame,"X",778,-8,28,function()frame:Hide()end)
  frame:SetScript("OnHide",function(self)revision=revision+1;self.image:SetTexture(nil);self.reference:SetTexture(nil);self.thumbnail:SetTexture(nil)end)
 end
 revision=revision+1;local token=revision
 local prefix=root..scene.."-";local suffix={tga="image.tga",["bc1-base"]="image-bc1-base.blp",["bc1-mips"]="image-bc1-mips.blp",["1024-tga"]="image1024.tga",["1024-bc1"]="image1024-bc1-mips.blp",bc3="image-bc3-mips.blp",missing="deliberately-missing.blp",corrupt="truncated.blp"}
 local path=prefix..suffix[variant]
 frame.title:SetText("TEXTURE REVIEW / "..scene.." / "..variant)
 frame:Show()
 frame.reference:SetTexture(prefix.."thumbnail.tga");frame.thumbnail:SetTexture(prefix.."thumbnail-bc1-mips.blp")
 local setResult=frame.image:SetTexture(path)
 frame.status:SetText("Known file: "..tostring(known(path)).." / SetTexture: "..tostring(setResult).." / Loaded: "..tostring(loaded(frame.image)))
 print("TEXTURE_BUDGET_INITIAL",scene,variant,known(path),setResult,frame.image:GetTexture(),loaded(frame.image))
 C_Timer.After(2,function()
  if revision~=token then return end
  frame.status:SetText("Known file: "..tostring(known(path)).." / Loaded after 2s: "..tostring(loaded(frame.image)).." / VISUAL CHECK REQUIRED")
  print("TEXTURE_BUDGET_LATER",scene,variant,known(path),frame.image:GetTexture(),loaded(frame.image))
 end)
end
function MyEpochTextureCompareHide()if frame then frame:Hide()end end
print("My Epoch disposable texture review available; call MyEpochTextureCompare().")
