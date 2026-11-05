-- Disposable negative-control probe. Never shipped and never changes addon APIs.
do
local f=CreateFrame('Frame',nil,UIParent);local probes={}
for _,entry in ipairs({{'bundled',[[Interface\AddOns\MyEpoch\Media\Illustrations\gen-camp.tga]]},{'missing',[[Interface\AddOns\MyEpoch\Media\Illustrations\deliberately-missing-control.tga]]}})do
 local t=f:CreateTexture(nil,'ARTWORK');t:Hide();local result=t:SetTexture(entry[2]);probes[#probes+1]={name=entry[1],texture=t}
 print('TEXTURE_CONTROL_INITIAL',entry[1],result,t:GetTexture(),t:IsObjectLoaded())
end
local elapsed=0
f:SetScript('OnUpdate',function(self,delta)
 elapsed=elapsed+delta;if elapsed<3 then return end
 for _,p in ipairs(probes)do print('TEXTURE_CONTROL_LATER',p.name,p.texture:GetTexture(),p.texture:IsObjectLoaded());p.texture:SetTexture(nil)end
 self:SetScript('OnUpdate',nil);self:Hide();print('TEXTURE_CONTROL_FINISHED')
end)
end
