-- Review fixture only. Never packaged or installed with the production addon.
local _,E=...
local collections={{'Stratholme','stratholme'},{'Dire Maul','dire-maul'}}
function MyEpochArt140(index,page)
 if not E.db then print('Wait for My Epoch to load.');return end
 local entry=collections[index or 1];if not entry then return end
 local c=E.Store.Character('myepoch-art-140',{name='Mira',realm='TEST: Dungeon illustrations 140',level=60})
 c.state.art140=c.state.art140 or{}
 local id=c.state.art140[entry[2]];local r=id and c.records[id]
 if not r then
  r=E.Store.Add(c,'milestone',time()-3600,{title='First recorded visit to '..entry[1],milestoneType='discovery',zone=entry[1],major=true,subject=c.id})
  c.state.art140[entry[2]]=r.id
 end
 local B,D=E.Book,E.ArtDialog;B.Open();B.ChangeCharacter(c.id);B.SetChapter('Chronicle');B.selected=r.id;B.Render(true)
 local context=D.OpenLocation('dungeon:'..entry[2]);context.artCollection='local';context.artPage=page or 1;context.artPreview=entry[2]..(page==2 and'-07'or'-01');D.Render(true)
 print('ART140',entry[1],context.artPage,B.chapter,B.selected,'Synthetic illustration review only')
end
