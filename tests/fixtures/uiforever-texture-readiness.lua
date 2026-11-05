-- Simulator-only negative control. Never included in the addon package.
-- Run in the UIForever Lua console; call MyEpochTextureReadinessProbe:Hide() afterwards.
if MyEpochTextureReadinessProbe then MyEpochTextureReadinessProbe:Hide() end
local f=CreateFrame('Frame',nil,UIParent); MyEpochTextureReadinessProbe=f
f:SetSize(600,180);f:SetPoint('CENTER');f:SetFrameStrata('TOOLTIP');f.images={}
local paths={
    'Interface\\AddOns\\MyEpoch\\Media\\Illustrations\\redridge-mountains-09.tga',
    'Interface\\AddOns\\MyEpoch\\Media\\Illustrations\\intentionally-missing-control.tga',
}
for i,path in ipairs(paths)do
    local t=f:CreateTexture(nil,'ARTWORK');t:SetSize(280,140);t:SetPoint('TOPLEFT',(i-1)*300,0);f.images[i]=t
    print('TEXTURE_NEGATIVE_CONTROL_SET',i,t:SetTexture(path),t:GetTexture(),t:IsObjectLoaded())
end
C_Timer.After(2,function()
    for i,t in ipairs(f.images)do print('TEXTURE_NEGATIVE_CONTROL_READY',i,t:GetTexture(),t:IsObjectLoaded())end
end)
