local E,A,S,H,C,F,B=E,E.API,E.Store,E.History,E.Collectors,E.Economy,E.Book
local c=E.current;local session=C.session;local t=A.Now()
local byKind=function(kind,book)
    local out={};book=book or c
    for _,id in ipairs(book.order)do if book.records[id].kind==kind then out[#out+1]=book.records[id]end end
    return out
end
local amount=c.state.wallet.amount;local size=2;local reads,rosters=0,0
local actualGUID=UnitGUID
local function id(unit)if unit=="party1"then return "Player-1-004"end;return actualGUID(unit)end
UnitGUID=id;UnitFullName=function(unit)return unit=="player"and"Adventurer"or"Reed","Realm"end
GetNumGroupMembers=function()rosters=rosters+1;return size end
GetMoney=function()reads=reads+1;return amount end
local alt=S.Character("wallet-observer-alt",{name="Offline scrapbook"})
B.Open();B.ChangeCharacter(alt.id)
local n=#byKind("gold");local priorBalance=#byKind("balance")
C.partyGUID="Party-0-unique"
t=t+1;TEST_NOW(t);fire("GROUP_ROSTER_UPDATE");local group=assert(c.records[c.state.group])
local before=c.state.wallet.amount
amount=before+37;fire("PLAYER_MONEY");assert(#byKind("gold")==n+1)
local w=byKind("gold")[n+1];assert(w.amount==37 and w.before==before and w.after==amount and w.source=="unknown" and w.quality=="unknown")
assert(w.character==c.id and w.observerGroup==group.id and w.observerGroupState=="group" and w.refs[1]==w.window and w.refs[2]==group.id and not w.group and not w.evidenceRefs)
assert(#byKind("gold",alt)==0 and B.Character()==alt)
local count=rosters;fire("PLAYER_MONEY");assert(rosters==count and #byKind("gold")==n+1,"unchanged amount must skip full roster read")
-- Source proof remains independent of the observer link when classified and revoked.
local proof=S.Add(c,"money_evidence",t,{source="loot",amount=37})
F.Attribute(c,w.id,"loot","inferred",{proof.id},true)
assert(w.refs[1]==w.window and w.refs[2]==group.id and w.refs[3]==proof.id and #w.evidenceRefs==1 and w.evidenceRefs[1]==proof.id)
F.Attribute(c,w.id,"unknown","unknown",{},nil)
assert(w.refs[1]==w.window and w.refs[2]==group.id and not w.refs[3] and #w.evidenceRefs==0)
-- A changed heartbeat observes one roster only; a partial roster cannot borrow the prior group.
local roster=A.Roster;local polls=0;A.Roster=function(...)polls=polls+1;return roster(...)end
amount=amount-7;t=t+1;TEST_NOW(t);C.Heartbeat();assert(polls==1)
local spend=byKind("gold")[n+2];assert(spend.amount==-7 and spend.observerGroup==group.id and spend.observerGroupState=="group")
local start=amount
UnitGUID=function(unit)if unit=="party1"then return nil end;return id(unit)end
amount=start+2;fire("PLAYER_MONEY")
local partial=byKind("gold")[n+3];assert(partial.amount==2 and partial.observerGroupState=="unknown" and not partial.observerGroup and #partial.refs==1)
UnitGUID=id;size=0;amount=amount+3;fire("PLAYER_MONEY")
local solo=byKind("gold")[n+4];assert(solo.observerGroupState=="solo" and not solo.observerGroup and #solo.refs==1)
-- Same-timestamp nested amount wins; the stale return must not manufacture a reverse delta.
local current=amount;local inner=false
GetMoney=function()if not inner then inner=true;amount=current+10;fire("PLAYER_MONEY");return current+1 end;return amount end
fire("PLAYER_MONEY");assert(#byKind("gold")==n+5 and byKind("gold")[n+5].amount==10 and c.state.wallet.amount==amount)
GetMoney=function()return amount end
-- A newer wallet observed during membership verification also supersedes the outer sample.
inner=false;A.Roster=function(...)if not inner then inner=true;amount=amount+4;fire("PLAYER_MONEY")end;return roster(...)end
local previously=amount;amount=amount+5;fire("PLAYER_MONEY")
assert(#byKind("gold")==n+6 and c.state.wallet.amount==previously+9)
A.Roster=roster
-- A change seen across an unobserved gap establishes a balance, not group income.
t=t+20;TEST_NOW(t);amount=amount+55;count=rosters;fire("PLAYER_MONEY")
assert(#byKind("gold")==n+6 and #byKind("balance")==priorBalance+1 and rosters==count)
local gap=byKind("balance")[priorBalance+1];assert(gap.unobservedChange==55 and not gap.observerGroupState and not gap.observerGroup)
-- Real reload / next login retains the historical group reference and starts a new window.
TEST_WALLET_ID=w.id;TEST_GROUP_ID=group.id;TEST_GOLD=#byKind("gold")
-- Guard player/session/source identity before and after money and roster reads.
local seq,old=c.seq,c.state.wallet
GetMoney=function()E.current=alt;return amount+1000 end;fire("PLAYER_MONEY");assert(c.state.wallet==old and not alt.state.wallet);E.current=c
GetMoney=function()C.session="other";return amount+2000 end;fire("PLAYER_MONEY");assert(c.state.wallet==old);C.session=session
GetMoney=function()return amount+3000 end;A.Roster=function()E.current=alt;return {}end;fire("PLAYER_MONEY");assert(c.state.wallet==old and not alt.state.wallet);E.current=c
A.Roster=roster;GetMoney=function()return amount end
assert(#byKind("gold")==TEST_GOLD and c.seq==seq)
-- A preserved gold row must keep its linked expired group reachable from retention.
c.retention.groups=1
local plan=S.PreviewExpiry(c,A.ShiftDay(t,40))
assert(plan.aged[group.id] and not plan.ids[group.id] and plan.reasons[group.id].kind=="retainedReference")
local saved={}
for _,row in ipairs(byKind("gold"))do
    if row.observerGroup==group.id then saved[row]=row.refs;row.refs={row.window};S.Changed(c,row)end
end
assert(S.PreviewExpiry(c,A.ShiftDay(t,40)).ids[group.id],"without any retained wallet ref the same old group expires")
for row,refs in pairs(saved)do row.refs=refs;S.Changed(c,row)end
local ready=S.PreviewExpiry(c,A.ShiftDay(t,40));S.ApplyExpiry(c,ready);assert(c.records[group.id]==group)
print("PASS observed group/solo/unknown wallet deltas, active/offline characters, no duplicate cash or source evidence, same-timestamp nested reads, heartbeat and retention")
