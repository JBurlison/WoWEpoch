local K,Q,S,T,M,F,B,A=E.GoldChecks,E.Query,E.Store,E.Trades,E.MailMoney,E.Economy,E.Book,E.API
local now=A.ParseDay('2026-11-02')+7200;TEST_NOW(now);local previous=B.character
local function raw(c,kind,ts,data)
 c.seq=c.seq+1;local r={id=c.id..':'..c.seq,sequence=c.seq,character=c.id,kind=kind,category=S.categories[kind],ts=ts,session='gold-review',title='Observed '..kind}
 for k,v in pairs(data or{})do r[k]=v end;c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
end
local function trade(c)
 local window=raw(c,'wallet_window',now)
 local r=raw(c,'trade',now,{walletBefore=100,walletAfter=120,walletWindow=window.id,closedAt=now+2,completionAt=now+2})
 local offer=raw(c,'trade_offer',now+1,{trade=r.id,offer={complete=true,playerAccepted=1,targetAccepted=1,playerMoney=0,targetMoney=20}})
 local notice=raw(c,'trade_notice',now+2,{trade=r.id})
 local w=raw(c,'gold',now+2,{window=window.id,before=100,after=120,amount=20,source='trade',quality='inferred',automaticAttribution=true})
 local proof=raw(c,'money_evidence',now+2,{trade=r.id,walletID=w.id,amount=20,source='trade'})
 r.offers={offer.id};r.completionOffer=offer.id;r.completionNotice=notice.id;r.wallets={w.id};w.evidenceRefs={proof.id}
 assert(T.ValidProof(c,proof));return w,offer,r,proof
end
local function mail(c)
 local window=raw(c,'wallet_window',now-1)
 local r=raw(c,'mail_collection',now,{visit='visit',settledAt=now+3,walletAfter=80,
  walletAnchor={amount=100,sequence=window.sequence,ts=now-1,session='gold-review',window=window.id}})
 local request=raw(c,'mail_request',now+1,{collection=r.id,visit=r.visit,method='SendMail',recipient='A friend',
  sendData={postageQuote=10,moneyRequested=10,codRequested=0}})
 local notice=raw(c,'mail_notice',now+2,{collection=r.id,visit=r.visit,event='MAIL_SEND_SUCCESS'})
 local w=raw(c,'gold',now+2,{window=window.id,before=100,after=80,amount=-20,source='mailSent',quality='inferred',automaticAttribution=true})
 local proof=raw(c,'money_evidence',now+2,{mailCollection=r.id,walletID=w.id,amount=-20,source='mailSent'})
 r.requests={request.id};r.notices={notice.id};r.sendRequest=request.id;r.lastRequestAt=request.ts;r.lastRequestSequence=request.sequence;r.wallets={w.id};w.evidenceRefs={proof.id}
 assert(M.ValidProof(c,proof));return w,notice,r,proof
end
local c=S.Character('gold-checks-large',{name='Merchant'})
for i=1,100000 do raw(c,'chat',now,{text='Retained conversation'})end
local rows,deleted={},{}
for i=1,200 do
 local w,proofSource,r,proof
 if i%2==0 then w,proofSource,r,proof=mail(c)else w,proofSource,r,proof=trade(c)end
 rows[i]={wallet=w,source=proofSource,record=r,proof=proof,expected=w.source}
 if i%4<2 then deleted[proofSource.id]=true;rows[i].expected='unknown'end
end
rows[1].wallet.quality='confirmed';rows[1].expected='trade'
rows[5].wallet.automaticAttribution=false;rows[5].expected='trade'
S.Note(c,'keep','My invoice note',now)
for id in pairs(deleted)do c.records[id]=nil end
local originalPairs=pairs;pairs=function(t)assert(t~=c.records,'Cleanup must not synchronously enumerate the full archive');return originalPairs(t)end
E.Emit('RECORDS_REMOVED',c,deleted,{kinds={trade_offer=true,mail_notice=true}})
assert(K.Pending(c)and not Q.IsWarm(c)and Q.Preparation(c).scanned<=64)
B.ChangeCharacter(c.id);B.SetChapter('Chronicle');assert(B.preparingCharacter==c)
local check=T.CheckWallet;local visits=0
T.CheckWallet=function(owner,w)if owner==c and w.source~='unknown'then visits=visits+1 end;return check(owner,w)end
local frames=0
while K.Pending(c)or E.Gathering.Pending(c)do
 Q.ProcessPreparation(500);E.Gathering.Process();local before=visits;K.Process();assert(visits-before<=16)
 B.PreparationTick();frames=frames+1;assert(frames<10000)
end
T.CheckWallet=check;pairs=originalPairs
assert(visits==200 and not B.preparingCharacter and frames>200)
for _,row in ipairs(rows)do local w=row.wallet
 assert(w.source==row.expected and w.before==100 and w.after-w.before==w.amount)
 assert(w.amount==(row.proof.source=='trade'and 20 or -20))
end
assert(c.notes.keep.text=='My invoice note'and rows[1].wallet.quality=='confirmed')
assert(rows[5].wallet.source=='trade'and rows[5].wallet.automaticAttribution==false)
-- A changed source behind the cursor forces another pass; ordinary chat edits do not.
K.Request(c);assert(K.Pending(c));local target=rows[3]
target.source.kind='chat';S.Changed(c,target.source)
rows[6].source.kind='chat';S.Changed(c,rows[6].source)
for i=1,200 do
 local chat=c.records[c.order[i]];chat.text='Edited conversation';S.Changed(c,chat)
 Q.ProcessPreparation(500);E.Gathering.Process();K.Process()
 if not K.Pending(c)then break end
end
assert(not K.Pending(c)and target.wallet.source=='unknown','the corrected old proof is revisited without chat starvation')
assert(rows[6].wallet.source=='unknown','mail plan caches discard an old dependency even when its kind changes')
-- A failed background check is explicit and can be retried through the book.
T.CheckWallet=function()error('Injected wallet-check failure')end;K.Request(c)
assert(K.Status(c)=='failed');B.Render();assert(B.preparationStatus=='failed')
T.CheckWallet=check;local retry
for i=1,B.left.used.button or 0 do local f=B.left.pool.button[i];if f.text:GetText()=='Retry opening this scrapbook'then retry=f end end
assert(retry);retry:Click();TEST_PREPARE_HISTORY(c);B.PreparationTick();assert(not B.preparingCharacter)
-- Replacing the pending cleanup, append-only arrivals, and character isolation.
local other=S.Character('gold-checks-other',{name='Other'});local ow,os=trade(other);other.records[os.id]=nil
E.Emit('RECORDS_REMOVED',other,{[os.id]=true},{});TEST_PREPARE_HISTORY(other);assert(ow.source=='unknown')
K.Request(c);local added,missing=trade(c);c.records[missing.id]=nil
-- Raw fixture setup is followed by canonical notifications as a live arrival would be.
S.Changed(c,added);K.Request(c);TEST_PREPARE_HISTORY(c);assert(added.source=='unknown')
local detached=S.Character('gold-checks-detached',{name='Detached'})
for i=1,1000 do raw(detached,'chat',now)end;trade(detached);K.Request(detached);E.db.characters[detached.id]=nil
for i=1,1000 do Q.ProcessPreparation(500);K.Process();if not K.Pending(detached)then break end end
assert(not K.Pending(detached))
-- An interrupted cleanup is remembered across logout/reload and resumed.
local reload=S.Character('gold-checks-reload',{name='Returning merchant'})
for i=1,100 do local wallet,missing=trade(reload);reload.records[missing.id]=nil end
Q.EnsureWarm(reload);for i=1,100 do Q.ProcessPreparation(500);if Q.IsWarm(reload)then break end end
K.Request(reload);assert(K.Pending(reload)and reload.state.goldChecksPending)
local restored=E.Copy(reload);E.db.characters[reload.id]=restored
assert(K.Ensure(restored)=='preparing');TEST_PREPARE_HISTORY(restored)
assert(not restored.state.goldChecksPending)
for _,wallet in ipairs(Q.Kind(restored,'gold'))do assert(wallet.source=='unknown'and wallet.amount==20)end
if E.db.characters[previous]then B.ChangeCharacter(previous)end
print('PASS gold cleanup queue: 100,000 unrelated records, 200 trade/mail wallets, '..frames..' frames, at most 16 wallets per background service; missing evidence, confirmed/manual protection, amounts/notes, behind-cursor correction, chat edits, UI retry, replacement, arrivals and isolation')
