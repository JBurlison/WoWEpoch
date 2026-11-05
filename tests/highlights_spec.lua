local H,S,B,L=E.Highlights,E.Store,E.Book,E.CompanyLayout
local c=S.Character('highlight-owner',{name='Aldren'});local other=S.Character('highlight-other',{name='Mira'})
local g=S.Add(c,'group',time(),{title='A good evening',memberships={}})
local function chat(text,extra)
 local data=extra or {};data.group=g.id;data.refs={g.id};data.text=text;data.title='Rook';data.author='Rook';data.channel='PARTY'
 return S.Add(c,'chat',g.ts+1,data)
end
local quote=chat('Well done! Nice teamwork!');local original=E.Copy(quote)
assert(H.Reason(c,quote) and not H.Reason(other,quote))
assert(not H.Reason(c,chat('good jobber')) and not H.Reason(c,chat('heading south')))
assert(not H.Reason(c,chat('|Hitem:123|h[Great Job]|h |Tnice work:16|t |Awell done:16|a')))
assert(H.Reason(c,chat('|cffffffffTHANK YOU|r everyone')))
assert(H.Reason(c,chat('Not a good job.')):find('tone and context need your review',1,true),'phrase is not a sentiment verdict')
assert(H.Reason(c,chat('A biscuit for the road',{starred=true})):find('you kept',1,true))
local ungrouped=S.Add(c,'chat',g.ts,{text='great job'});assert(not H.Reason(c,ungrouped))
local defeat=S.Add(c,'encounter',g.ts+2,{phase='boss',encounterID=1,group=g.id,refs={g.id},title='Boss defeat reported: Test'})
local ending=S.Add(c,'encounter',g.ts+2,{phase='end',success=1,encounterID=1,group=g.id,refs={g.id},title='Encounter victory: Test'})
local failure=S.Add(c,'encounter',g.ts+2,{phase='end',success=0,group=g.id,refs={g.id}})
assert(H.Reason(c,defeat) and H.Reason(c,ending) and not H.Reason(c,failure))
local count=c.seq;assert(H.Dismiss(c,quote,true));assert(c.seq==count and quote.text==original.text and E.Same(quote.refs,original.refs))
assert(#H.Select({quote},'suggested')==0 and #H.Select({quote},'dismissed')==1)
quote.starred=true;S.Changed(c,quote);assert(#H.Select({quote},'kept')==1 and #H.Select({quote},'dismissed')==0)
assert(S.Protected(c)[quote.id] and S.Protected(c)[g.id]);assert(H.Dismiss(c,quote,false) and quote.starred)
S.Note(c,'record:'..quote.id,'A caption of my own',g.ts+3)
local function click(page,text)
 for _,kind in ipairs({'companyControl','companyRow','button'})do for i=1,page.used[kind] or 0 do
  local f=page.pool[kind][i];if f.text:GetText()==text then f:Click();return end
 end end;return TEST_UI_CLICK(text)
end
B.ChangeCharacter(c.id);B.SetChapter('Company');TEST_PREPARE_BOOK();click(B.right,'Highlights');click(B.right,'Kept')
assert(#L.lastHighlights==2)
local captionShown=false;for i=1,B.right.used.companyRow do if B.right.pool.companyRow[i].meta:GetText():find('Your caption: A caption of my own',1,true)then captionShown=true end end;assert(captionShown)
click(B.right,quote.text)
assert(B.selected==quote.id);click(B.right,'Dismiss suggestion');assert(quote.highlightDismissed and quote.starred)
click(B.right,'Unstar this memory');assert(not quote.starred);click(B.right,'Back to highlights');click(B.right,'Dismissed')
assert(#L.lastHighlights==1);click(B.right,quote.text);click(B.right,'Restore suggestion');click(B.right,'Back to highlights');click(B.right,'Suggested')
assert(quote.text==original.text and c.notes['record:'..quote.id].text=='A caption of my own')
click(B.right,quote.text);click(B.right,"Open this group's transcript")
assert(B.transcriptHighlight==quote.id and B.groupTab=='chat')
for i=1,1200 do chat('Great job! '..i)end
click(B.right,'Highlights');local frames=#B.right.pool.companyRow
for p=1,210 do B.highlightPage=p;B.Render();assert(B.right.used.companyRow<=6 and #B.right.pool.companyRow==frames)end
for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do
 UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)
 local rows={};for i=1,B.right.used.companyControl do local f=B.right.pool.companyControl[i];local point=f.point;local x,y=point[4],point[5]
  assert(x>=12 and x+f:GetWidth()<=772);rows[y]=rows[y] or {};table.insert(rows[y],{x=x,w=f:GetWidth()})
 end
 for _,row in pairs(rows)do table.sort(row,function(a,b)return a.x<b.x end);for i=2,#row do assert(row[i-1].x+row[i-1].w<=row[i].x)end end
end
UIParent:SetSize(1920,1080);B.Fit();B.ChangeCharacter(other.id);B.SetChapter('Company');assert(not B.companySessionFocus and not B.highlightMode)
assert(#E.Diary.Facts(c,g.ts-1,g.ts+10).refs==0,'highlight choices never create progression recap facts')
print('PASS highlights: phrase boundaries/markup, contextual suggestions, own group records, reversible dismissal, keeps/protection, separate captions, transcript return, bounded pagination and geometry')
