local S,H,X,A,B,V=E.Store,E.History,E.Search,E.API,E.Book,E.SearchView
local function eq(a,b,label)assert(a==b,(label or "Search mismatch")..": "..tostring(a).." ~= "..tostring(b))end
local c=S.Character("search-owner",{name="Searcher"}); local other=S.Character("search-other",{name="Other"})
local now=A.ParseDay("2026-10-31")+3600; TEST_NOW(now+100)
local group=H.Group(c,now,{{id=c.id,name="Searcher"},{id="friend",name="Helpful Friend"}},"search-session","party")
local chats={}
for i=1,30 do chats[i]=S.Add(c,"chat",now+i,{title="Helpful Friend",author="Helpful Friend",text=i==15 and "A 100% [literal] victory |Hfake|h" or "conversation line "..i,
    group=group.id,refs={group.id}}) end
local quest=S.Add(c,"quest",now+40,{title="The Relic",zone="Westfall",questID=200})
local item=S.Add(c,"loot",now+41,{title="Copper Ore",itemID=2770,quantity=2,recipientName="Helpful Friend"})
local recap=S.Add(c,"recap",now+42,{title="Weekly recap",key="weekly:test",from=now,through=now+100,periodKind="weekly",text="Recorded progress"})
S.Note(c,"record:"..quest.id,"A copper-coloured relic",now+50)
S.Note(c,"record:"..recap.id,"Legacy recap note",now+50)
S.Note(c,"day:2026-10-30","A note without a generated diary",now+50)
S.Note(c,"record:missing-record","The orphan's note",now+50)
S.Note(other,"day:2026-10-30","secret other character",now)
eq(X.Find(c,"secret other character").total,0,"character isolation")
eq(X.Find(c,"100% [literal]","chat").total,1,"query is literal, never Lua pattern syntax")
eq(X.Find(c,"Helpful Friend","group").hits[1].record,group.id,"group members indexed")
eq(X.Find(c,"Helpful Friend","items").hits[1].record,item.id,"item recipients indexed")
eq(X.Find(c,"Westfall").hits[1].record,quest.id,"location indexed")
eq(X.Find(c,"relic").total,1,"matching title and note still produces one canonical result")
eq(X.Find(c,"copper-coloured","notes").hits[1].record,quest.id)
S.Note(c,"record:"..quest.id,"Changed wording",now+51)
eq(X.Find(c,"copper-coloured").total,0); eq(X.Find(c,"Changed wording").total,1,"note save refreshes index")
S.Note(c,"record:"..quest.id,"",now+52); eq(X.Find(c,"Changed wording").total,0,"empty notes remove old terms")
quest.title="A different quest"; S.Changed(c,quest); eq(X.Find(c,"Relic").total,0,"record edits refresh index")
eq(X.Find(c,"Legacy recap note").total,1)
E.Diary.NoteKey(c,recap)
eq(X.Find(c,"Legacy recap note").total,1,"note migration doesn't duplicate or lose hits")
eq(c.notes["record:"..recap.id],nil)
local internal=S.Add(c,"wallet_window",now,{title="An interval",ended=now,opening=0,closing=0})
S.Note(c,"record:"..internal.id,"A note on the source interval",now)
eq(X.Find(c,"source interval","notes").total,1)
S.Note(c,"record:"..internal.id,"",now); eq(X.Find(c,"source interval","notes").total,0,"cached internal-note results invalidate")
local hit=X.Find(c,"orphan's").hits[1]; eq(hit.ts,nil,"unknown event date is not invented from note edit time")
local first=X.Find(c,"conversation line","chat",1,12); local second=X.Find(c,"conversation line","chat",2,12)
eq(first.total,29); eq(#first.hits,12); assert(first.hits[1].id~=second.hits[1].id)
B.ChangeCharacter(c.id); B.search="100% [literal]"; B.searchFilter="chat"; B.SetChapter("Search")
local searchHit=V.lastResult.hits[1]; assert(V.Open(searchHit)); eq(B.chapter,"Company"); eq(B.selected,chats[15].id); eq(B.groupFocus,group.id)
TEST_PREPARE_BOOK()
local escaped=false
for i=1,B.right.used.label or 0 do if B.right.pool.label[i]:GetText():find("||Hfake||h",1,true) then escaped=true end end
assert(escaped,"chat text cannot create executable/clickable imported markup")
local function click(text)
    for _,page in ipairs({B.left,B.right}) do for i=1,page.used.button or 0 do local f=page.pool.button[i]
        if f.text:GetText()==text then f:Click(); return end
    end end
    return TEST_UI_CLICK(text,prefix)
end
click("Open this group's transcript"); eq(B.selected,group.id); eq(B.transcriptPage,2); eq(B.transcriptHighlight,chats[15].id)
eq(#X.Transcript(c,group.id,"100% [literal]"),1)
click("Back to search results"); eq(B.chapter,"Search"); eq(B.search,"100% [literal]")
local gold=H.Wallet(c,now,100,"money"); gold=H.Wallet(c,now+5,150,"money")
B.goldPreset="ytd"; B.goldSource="repair"; B.goldQuality="confirmed"
assert(V.Open(X.Find(c,"Wallet change","finance").hits[1]))
eq(B.chapter,"Gold"); eq(B.selected,gold.id); eq(B.goldFrom,"2026-10-31"); eq(B.goldSource,"unknown"); eq(B.goldQuality,"unknown")
assert(V.Open(X.Find(c,"without a generated diary","notes").hits[1])); eq(B.chapter,"Calendar"); eq(A.Day(B.day),"2026-10-30")
assert(V.Open(hit)); eq(B.chapter,"Search"); eq(B.searchNoteKey,"record:missing-record")
local stale=X.Find(c,"A different quest","quests").hits[1]
c.records[quest.id]=nil; E.Emit("RECORDS_REMOVED",c,{[quest.id]=true})
assert(not V.Open(stale)); assert(B.searchError:find("no longer available",1,true))
B.ChangeCharacter(other.id); assert(not V.Open(searchHit)); eq(B.Character().id,other.id,"stale hit cannot switch to another character")
local large=S.Character("search-large",{name="Long transcript"})
local largeGroup=H.Group(large,now,{{id=large.id,name="Long transcript"}},"long","large-group")
for i=1,25000 do S.Add(large,"chat",now+i,{title="Companion",author="Companion",text="A retained message "..i..(i%1000==0 and " archive needle" or ""),group=largeGroup.id}) end
local started=os.clock(); local results=X.Find(large,"archive needle","chat"); local elapsed=os.clock()-started
eq(results.total,25); eq(#results.hits,12)
local stats=X.IndexStats(large); X.Find(large,"archive needle","chat",2); eq(X.IndexStats(large).updates,stats.updates,"paging reuses the canonical index")
B.ChangeCharacter(large.id); B.search="archive needle"; B.searchFilter="chat"; B.SetChapter("Search")
assert((B.right.used.searchRow or 0)<=8,"visible search result widgets stay paginated")
local count=X.IndexStats(large).documents
S.Note(large,"record:"..largeGroup.id,"A new annotation",now+30000)
eq(X.Find(large,"new annotation").total,1); eq(X.IndexStats(large).documents,count,"notes attach without adding duplicate documents")
eq(X.Excerpt(string.rep("é",100),""):sub(1,192),string.rep("é",96),"excerpt preserves complete UTF-8 characters")
local warming=S.Character("search-warming",{name="Background index"})
for i=1,3000 do S.Add(warming,"memory",now+i,{title="Memory "..i,text="Original text"}) end
B.Open();B.ChangeCharacter(warming.id); B.SetChapter("Search"); assert(not X.IsReady(warming))
local edit=B.left.pool.edit[1]; edit:SetText("Unsubmitted words"); edit.scripts.OnTextChanged(edit,true)
S.Add(warming,"memory",now+4000,{title="A newly added record",text="Arrived while indexing"})
S.Note(warming,"record:"..warming.order[2],"Annotated during indexing",now+4001)
local steps=0
while not X.IsReady(warming) do X.Process(250); steps=steps+1; assert(steps<20) end
eq(B.left.pool.edit[1]:GetText(),"Unsubmitted words","background completion preserves draft query")
eq(B.search,nil,"draft wasn't submitted implicitly")
eq(X.Find(warming,"Arrived while indexing").total,1)
eq(X.Find(warming,"Annotated during indexing").total,1)
eq(X.IndexStats(warming).documents,3001,"live additions indexed once during warmup")
local noteHit=X.Find(warming,"Annotated during indexing").hits[1]
warming.records[noteHit.record]=nil; E.Emit("RECORDS_REMOVED",warming,{[noteHit.record]=true})
local orphan=X.Find(warming,"Annotated during indexing").hits[1]
eq(orphan.record,nil); eq(orphan.noteKey,"record:"..noteHit.record,"notes survive source deletion with honest routing")
print(string.format("PASS search: notes/migrations, literal phrases, isolation, direct source navigation, transcript context, missing sources; 25,000-message initial search %.1f ms (host only)",elapsed*1000))
