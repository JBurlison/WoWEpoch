local P,M,S,X,B=E.SavedPages,E.Memories,E.Store,E.Search,E.Book
local c=S.Character("saved-pages-differential",{})
local ts=1701000000
local refs={}
for i=1,290 do
 local kind=({"memory","screenshot","chat","milestone","chat","kill"})[(i-1)%6+1]
 local r=S.Add(c,kind,ts+i%5,{title=i%2==0 and "cap.[x]" or "T",text="café\t 海",tags={"needle","two","final"},starred=i%3==0,subject=c.id})
 r.observationSequence=i%3
 if i%11==0 then r.ts=nil end
 if r.kind=="chat" and i%2==0 then r.character="foreign" end
 refs[i]=r
end
local long=refs[1];long.text=string.rep("ñ ",95000)..string.rep("  \t",8000).."Café.needle"..string.rep("🐾",4000);S.Changed(c,long)
local function compare(owner,query,page)
 local expected=M.Saved(owner,query)
 local actual,previews,selected
 for n=1,90000 do
  actual,previews,selected=P.Page(owner,query,page);if actual then break end
 end
 assert(actual and #actual==#expected,query.." wrong count")
 for i,r in ipairs(expected)do assert(actual[i]==r,query.." row "..i)end
 for r,preview in pairs(previews)do assert(preview==X.Excerpt(r.caption or r.text or "",query,160),query.." wrong excerpt")end
 return actual
end
for _,q in ipairs({"","NEEDLE, TWO","two, final","café","T café","café\t 海 needle","[x]","%x","needle two",string.rep("ñ ",3000).."  ","海","🐾🐾","Café.needle"})do
 compare(c,q,1);compare(c,q,9)
end
-- Exact permutations for equal time/sequence, including filtered subsets,
-- new/removed rows, ordinary correction, replacement and explicit undated rows.
refs[3].starred=false;S.Changed(c,refs[3]);compare(c,"",4)
refs[5].starred=true;refs[5].character=c.id;S.Changed(c,refs[5]);compare(c,"needle",2)
refs[13].title="specific edit";refs[13].tags={"B","C"};S.Changed(c,refs[13]);compare(c,"B, c",1)
local old=refs[19];local copy=E.Copy(old);copy.caption="replacement";c.records[copy.id]=copy;S.Changed(c,copy);compare(c,"replacement",1)
local alt=S.Character("saved-pages-alt",{});assert(#compare(alt,"",1)==0)
S.Add(alt,"memory",ts,{title="Alt only"});compare(alt,"",1);compare(c,"specific edit",1)
print("PASS saved pages: exact synchronous IDs and native tie permutations, literal Unicode/tags, separators, long-record excerpts, source corrections and separate journals")
