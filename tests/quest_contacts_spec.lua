local J,K,B,S=E.QuestieBridge,E.QuestCatalog,E.Book,E.Store
local c=E.current
assert(not J.ContactSource(c,109))
local calls={starters=0,finishers=0,names=0,areas=0}
local start,finish={[1]={1,2,3},[2]={11,12},[3]={21}},{{2}}
local lib={
    RequireContract=function(n)return n==3 end,
    ModeIndicator={GetStatus=function()return {mode="source",expansion="Forever"}end},
    Support={Get=function()return {private={areaIdToUiMapId="return {[40]=1436}"}}end},
    Quest={
        GetAllIds=function()return {109,687}end,
        GetAll=function(id,fields)return {n=#fields,[1]="Mock contact quest "..id}end,
        startedBy=function()calls.starters=calls.starters+1;return start end,
        finishedBy=function()calls.finishers=calls.finishers+1;return finish end,
    },
}
for _,kind in ipairs({"Npc","Object","Item"})do
    local label=kind
    lib[kind]={name=function(id)
        calls.names=calls.names+1
        if id==2 then error("unreadable provider name")end
        return label.." "..id
    end,zoneID=function(id)
        assert(label~="Item","Items cannot have NPC/object usual areas")
        calls.areas=calls.areas+1;return id==12 and 99999 or 40
    end}
end
LibQuestieDB=lib;assert(J.Start());while J.worker do J.Tick(.2)end
assert(calls.starters==0 and calls.finishers==0 and calls.names==0 and calls.areas==0)
local source=assert(J.ContactSource(c,109));assert(not J.ContactSource(c,987654))
local before=E.Copy(E.db)
local a=assert(J.ContactPage(source,c,109,1));assert(a.total==7 and a.page==1 and a.pages==2 and #a.rows==5)
assert(calls.names==5 and calls.areas==5 and a.rows[1].name=="Npc 1" and a.rows[1].mapID==1436)
assert(a.rows[2].name==nil and a.rows[2].kind=="Npc" and a.rows[2].id==2)
assert(a.rows[4].kind=="Object" and a.rows[5].mapID==nil)
local b=assert(J.ContactPage(source,c,109,3));assert(b.page==2 and #b.rows==2 and calls.names==7 and calls.areas==6)
assert(b.rows[1].role=="Starter" and b.rows[1].kind=="Item" and not b.rows[1].mapID)
assert(b.rows[2].role=="Finisher" and b.rows[2].kind=="Npc" and b.rows[2].id==2)
assert(E.Same(before,E.db),"Contact reads must not alter the saved account")
start={[1]={1,1,2}};finish={[3]={4}};a=assert(J.ContactPage(source,c,109,1))
assert(a.total==2 and a.startersKnown and not a.finishersKnown)
local oversized={};for i=1,65 do oversized[i]=i end;start={oversized};finish={{99}}
a=assert(J.ContactPage(source,c,109,1));assert(not a.startersKnown and a.finishersKnown and a.total==1 and a.rows[1].id==99)
start={[1]={[1]=5,[3]=8}};a=assert(J.ContactPage(source,c,109,1));assert(not a.startersKnown)
start={};finish={};a=assert(J.ContactPage(source,c,109,1));assert(a.total==0 and a.startersKnown and a.finishersKnown)
local secret={};local oldSecret=issecretvalue
issecretvalue=function(x)return rawequal(x,secret)or oldSecret and oldSecret(x)end
start={{secret}};a=assert(J.ContactPage(source,c,109,1));assert(not a.startersKnown);issecretvalue=oldSecret
local was=E.Collectors.session
lib.Quest.startedBy=function()E.Collectors.session="switched-during-contact-read";return {{99}}end
assert(not J.ContactPage(source,c,109,1));E.Collectors.session=was
local canonical=E.db.characters[c.id];E.db.characters[c.id]={};assert(not J.ContactPage(source,c,109,1));E.db.characters[c.id]=canonical
local quest=lib.Quest;lib.Quest=true;assert(not J.ContactSource(c,109));lib.Quest=quest
local other=S.Character("quest-contacts-other",{name="Other"});assert(not J.ContactPage(source,other,109,1))
local cb=lib.Quest.GetAll;lib.Quest.GetAll=function()end;assert(not J.ContactSource(c,109));lib.Quest.GetAll=cb
K.Remove("questiedb-installed");assert(not J.ContactPage(source,c,109,1))
print("PASS optional quest contacts: lazy, bounded, read-only, typed endpoints, incomplete and stale providers")
