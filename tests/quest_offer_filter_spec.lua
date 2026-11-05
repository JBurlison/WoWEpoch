local S,T,B=E.Store,E.QuestAtlas,E.Book
local live=E.current
local c=S.Character("offer-filter-reader",{name="Reader",faction="Alliance"})
local other=S.Character("offer-filter-neighbor",{name="Neighbor"})
local function add(owner,id,t,map,name)
    return S.Add(owner,"quest_offer",t,{questID=id,title="Quest "..id,mapID=map,giverName=name})
end
local first=add(c,373,100,1433,"Old giver")
local recent=add(c,373,120,1421,"New giver")
local second=add(c,999929,110,1433,"Other giver")
add(c,999930,115,nil,"Unmapped giver")
add(other,999931,140,1433,"Different journal")
c.state.historicalCompleted={[373]=true}
local function rows(map,query)return T.Rows(c,map,"offered",query,true).rows end
local here=rows(1433)
assert(#here==2 and here[1].questID==999929 and here[2].listedOffer==first)
assert(here[2].completed==true and here[1].completed==nil)
assert(#rows(291)==0,"A catalog destination cannot stand in for the giver visit")
local all=rows("all")
assert(#all==3 and all[1].listedOffer==recent and all[2].questID==999930)
assert(#rows("all","373")==1 and rows(1421)[1].listedOffer==recent)
B.Open();B.ChangeCharacter(c.id);B.questZone=1433;B.questFilter="all";B.questQuery="";B.SetChapter("Quests")
TEST_PREPARE_BOOK()
assert(B.questFilter=="completed" and B.Character()==c and B.questAtlasID==373)
assert(#E.QuestView.lastReport.rows==1 and E.QuestView.lastReport.rows[1].completed)
assert(B.left.pool.questRow[1].meta:GetText()=="Completion date unknown")
-- A direct historical offer remains readable without becoming a primary quest row.
B.selected=second.id;B.Render();assert(B.selected==second.id and #E.QuestView.lastReport.rows==1)
B.selected=nil;B.Render()
recent.mapID=1433;S.Changed(c,recent)
assert(rows(1433)[1].listedOffer==recent and #rows(1421)==0)
second.mapID=1421;S.Changed(c,second);B.Render();TEST_PREPARE_BOOK()
assert(B.questAtlasID==373 ,"Corrected visit must leave the old zone selection")
local originalKey=recent.id
recent.id=originalKey..":invalid";recent.kind="chat";S.Changed(c,recent)
assert(c.records[originalKey]==recent and rows(1433)[1].listedOffer==first,
    "An edited internal ID and kind must invalidate the previously indexed visit immediately")
B.Close(true);if live then B.ChangeCharacter(live.id)end
print("PASS giver filter: one quest per scoped visit history, cross-zone, unmapped and saved-owner isolation, state independence, corrections and real sidebar/list selection")
