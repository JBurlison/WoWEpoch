-- Disposable visual preview ONLY, for the contradictory UIForever texture stubs.
-- This does not change the production loader or certify image readiness.
-- Only the single bundled wf-bread texture is allowed. Reload to discard this preview.
assert(MyEpochBook and MyEpochBook:IsShown(),'Open the Chronicle comparison character first')
local wanted='Interface\\AddOns\\MyEpoch\\Media\\Illustrations\\wf-bread.tga'
local shown=0
local function preview(parent)
    if not parent:IsShown()then return end
    if parent.image and parent.message and parent.image:GetTexture()==wanted then
        parent:SetScript('OnUpdate',nil);parent.image:Show();parent.message:Hide();shown=shown+1
    end
    for _,child in ipairs({parent:GetChildren()})do preview(child)end
end
preview(MyEpochBook)
assert(shown==1,'Expected exactly one known bundled illustration; no fallback paths accepted')
local label=MyEpochBook:CreateFontString(nil,'OVERLAY')
label:SetFont('Fonts\\FRIZQT__.TTF',12,'');label:SetTextColor(1,.8,.4)
label:SetPoint('TOP',0,-20);label:SetText('UIFOREVER ART PREVIEW / SYNTHETIC HISTORY')
print('ART_COMPARISON_ONLY: one known image displayed; normal loader remains unverified.')
