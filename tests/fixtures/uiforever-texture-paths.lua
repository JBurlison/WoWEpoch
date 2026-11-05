-- Disposable native API/path probe; not shipped with My Epoch.
if MyEpochTexturePathProbe then MyEpochTexturePathProbe:Hide() end
local f=CreateFrame('Frame',nil,UIParent);MyEpochTexturePathProbe=f
f:SetSize(880,450);f:SetPoint('CENTER');f:SetFrameStrata('TOOLTIP');f.tests={}
local paths={
 'Interface\\AddOns\\MyEpoch\\Media\\Illustrations\\dun-morogh-01.tga',
 'Interface\\AddOns\\MyEpoch\\Media\\Illustrations\\dun-morogh-01',
 'Interface/AddOns/MyEpoch/Media/Illustrations/dun-morogh-01.tga',
 'Interface/AddOns/MyEpoch/Media/Illustrations/dun-morogh-01',
 'Interface\\AddOns\\MyEpoch\\Media\\Illustrations\\intentionally-missing-control.tga',
 'Interface\\AddOns\\MyEpoch\\Media\\Book\\book-v1.tga',
 'Interface\\Icons\\INV_Misc_QuestionMark',
 'Interface\\AddOns\\MyEpoch\\Media\\Illustrations\\dun-morogh-01-thumb.tga',
}
for i,path in ipairs(paths)do
 local t=f:CreateTexture(nil,'ARTWORK');local raw=f:CreateTexture(nil,'ARTWORK');raw:Hide()
 local ok=t:SetTexture(path);local rawOK=raw:SetTexture(path)
 t:SetSize(210,105);t:SetPoint('TOPLEFT',((i-1)%4)*220,-math.floor((i-1)/4)*180)
 local label=f:CreateFontString(nil,'OVERLAY');label:SetFont('Fonts\\FRIZQT__.TTF',14,'OUTLINE');label:SetPoint('TOPLEFT',((i-1)%4)*220,-math.floor((i-1)/4)*180-110);label:SetText('Path '..i..' / returned '..tostring(ok))
 f.tests[i]={shown=t,raw=raw,path=path}
 print('PATH061 SET',i,ok,rawOK,t:GetTexture(),raw:GetWidth(),raw:GetHeight(),raw:IsObjectLoaded())
 if C_UIFileAsset then
  print('PATH061 FILE',i,C_UIFileAsset.IsKnownFile and C_UIFileAsset.IsKnownFile(path),
   C_UIFileAsset.IsLooseFile and C_UIFileAsset.IsLooseFile(path),C_UIFileAsset.GetFileID and C_UIFileAsset.GetFileID(path))
 end
end
C_Timer.After(2,function()for i,v in ipairs(f.tests)do print('PATH061 READY',i,v.raw:GetWidth(),v.raw:GetHeight(),v.raw:IsObjectLoaded())end end)
