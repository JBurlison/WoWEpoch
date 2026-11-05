local B,A,S,V,X=E.Book,E.API,E.Store,E.SearchView,E.Search
local c=S.Character("selected-quote-guard",{name="Owner"});local alt=S.Character("selected-quote-alt",{name="Alt"});local ts=A.Now()
local group=S.Add(c,"group",ts,{memberships={},title="Session"})
local quote=S.Add(c,"chat",ts+1,{text="selected quote secret",title="A quote",group=group.id})
local function ready(owner)while B.HistoryReadiness(owner)~="ready"do E.Query.ProcessPreparation(500);E.Gathering.Process();E.GoldChecks.Process()end end
local function txt(s)
 for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText()==s then return true end end
end
local function clickfn(label)
 for i=1,B.right.used.button or 0 do local f=B.right.pool.button[i];if f.text:GetText()==label then return f.scripts.OnClick end end;error(label)
end
local function note()
 for i=B.right.used.edit or 0,1,-1 do local f=B.right.pool.edit[i];if f.scripts.OnTextChanged then return f.scripts.OnTextChanged end end;error("note")
end
local fake={GetText=function()return "stale note"end}
ready(c);ready(alt);B.ChangeCharacter(c.id);local hit=assert(X.Find(c,"selected quote secret","chat").hits[1]);assert(V.Open(hit));assert(txt(quote.text))
local keep,save=clickfn("Save and protect this quote"),note()
quote.character=alt.id;S.Changed(c,quote);keep();save(fake,true)
assert(not quote.starred and not c.notes["record:"..quote.id])
B.Render();assert(txt("This recorded quote is unavailable.") and not txt(quote.text) and (B.right.used.edit or 0)==0)
quote.character=c.id;quote.kind="memory";S.Changed(c,quote);B.Render()
assert(txt("This recorded quote is unavailable.") and not txt(quote.text))
local clone=E.Copy(quote);clone.kind="chat";c.records[quote.id]=clone;S.Changed(c,clone);B.Render()
assert(txt("This recorded quote is unavailable.") and not txt(clone.text))
-- Deliberately navigate away and open a new canonical hit, which may use the same ID.
B.SetChapter("Search");X.Refresh(c);assert(V.Open(X.Find(c,"selected quote secret","chat").hits[1]))
assert(txt(clone.text));TEST_UI_CLICK("Open this group's transcript")
assert(B.selected==group.id and B.right.used.companyChat==1)
local row=B.right.pool.companyChat[1];local rowKeep,rowOpen=row.keep.scripts.OnClick,row.scripts.OnClick
clone.character=alt.id;S.Changed(c,clone);rowKeep();rowOpen()
assert(not clone.starred and B.selected==group.id)
clone.character=c.id;S.Changed(c,clone);B.Render()
B.right.pool.companyChat[1].keep:Click();assert(clone.starred)
B.right.pool.companyChat[1]:Click();assert(B.selected==clone.id and txt(clone.text))
local nowValidSave=note();nowValidSave(fake,true);assert(c.notes["record:"..clone.id].text=="stale note")
local missing="record:expired";S.Note(c,missing,"A kept note",ts)
assert(V.Open({character=c.id,noteKey=missing}));local orphanSave=note()
B.ChangeCharacter(alt.id);orphanSave(fake,true)
assert(c.notes[missing].text=="A kept note" and not alt.notes[missing])
print("PASS already-open source after owner/kind/object change, stale notes/Keep/row click, valid fresh route, missing-source note across owner switch")
