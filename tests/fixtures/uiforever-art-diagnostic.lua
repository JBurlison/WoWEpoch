-- VISUAL DIAGNOSTIC ONLY. Never packaged. Run after selecting Aldren's
-- Chronicle fixture. UIForever returns false from SetTexture even though
-- GetTexture and IsObjectLoaded identify a decoded, renderable texture.
-- This reveals that existing texture for a clearly labeled layout screenshot;
-- it does not alter the API or certify production illustration loading.
-- Reload the simulator afterward to remove these temporary widget changes.
do
local expected=[[Interface\AddOns\MyEpoch\Media\Illustrations\gen-map.tga]]
local count=0
local function visit(parent)
 for _,f in ipairs({parent:GetChildren()})do
  if f.image and f.message and f:IsShown() and f.image:GetTexture()==expected and f.image:IsObjectLoaded()==true then
   f.image:Show(); f.message:ClearAllPoints(); f.message:SetPoint("BOTTOM",0,8)
   f.message:SetFont("Fonts\\FRIZQT__.TTF",11,"")
   f.message:SetText("DIAGNOSTIC PREVIEW: simulator reported failure for this loaded texture")
   f.message:Show(); count=count+1
  end
  visit(f)
 end
end
visit(MyEpochBook); print("Labeled illustration diagnostics:",count)
end
