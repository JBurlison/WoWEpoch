-- Find and activate the real rendered controls, including collapsed sidebar choices.
function TEST_UI_FIND(text,prefix)
 local B=E.Book
 for _,page in ipairs({B.left,B.right,B.nav})do if page then for kind,pool in pairs(page.pool)do
  for i=1,page.used[kind]or 0 do local f=pool[i];local value=f.text and f.text.GetText and f.text:GetText()
   if value and not f.isChapter and f.scripts and f.scripts.OnClick and (value==text or prefix and value:sub(1,#text)==text)then return f end
  end
 end end end
end
function TEST_UI_CLICK(text,prefix)
 local f=TEST_UI_FIND(text,prefix);if f then f:Click();return f end
 local B=E.Book;local menus,seen={},{}
 for i=1,B.nav.used.button or 0 do local label=B.nav.pool.button[i].text:GetText();local suffix=label:sub(-3)
  local button=B.nav.pool.button[i]
  if button.navExpandable and(not button.navSubview or button.navActive)then local base=label;seen[base]=(seen[base]or 0)+1;menus[#menus+1]={base=base,ordinal=seen[base]}end
 end
 local function menu(entry)
  local count=0
  for i=1,B.nav.used.button or 0 do local button=B.nav.pool.button[i];local label=button.text:GetText()
   if label==entry.base and button.navExpandable then count=count+1;if count==entry.ordinal then return button end end
  end
 end
 for _,entry in ipairs(menus)do local button=menu(entry)
  if button then
   local openedHere=not button.navExpanded
   if openedHere then button:Click()end
   f=TEST_UI_FIND(text,prefix);if f then f:Click();return f end
   button=menu(entry);if openedHere and button and button.navExpanded then button:Click()end
  end
 end
 error("Missing visible sidebar/page control: "..text)
end

-- Exact catalog provenance/eligibility components are retained for historical
-- source readers. Exercise them explicitly, separate from the completed chapter.
function TEST_QUEST_SOURCE_REVIEW()
 local B,V,T,A=E.Book,E.QuestView,E.QuestAtlas,E.API
 local render=B.Render
 B.Render=function(...)
  local id=B.questAtlasID
  local result=render(...)
  if B.chapter~="Quests" or B.selected or not id then return result end
  local c=B.Character();local loc=B.questZone=="current" and A.Location() or c.state.lastLocation or {}
  local zone=(B.questZone=="current" or B.questZone=="recorded") and (loc.mapID or "unavailable") or B.questZone
  local report=T.Rows(c,zone,"all",B.questQuery,false,loc)
  local row=report.all[id] or T.Row(c,id)
  B.questAtlasID=id;V.lastReport=report
  B.Clear(B.right);V.StructuredDetail(B.right,row,report);B.Finish(B.right)
  return result
 end
 return function()B.Render=render end
end
