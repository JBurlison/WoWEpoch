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

local function drain(c)
 K.Ensure(c)
 for i=1,10000 do Q.ProcessPreparation(500);K.Process();if not K.Pending(c)then return end end
 error('Dependency review did not finish')
end
for _,mode in ipairs({'trade','mail'})do
 local c=S.Character('gold-dependency-'..mode,{name=mode})
 local w,source,r,proof
 if mode=='trade'then w,source,r,proof=trade(c)else w,source,r,proof=mail(c)end
 local expected=w.source;drain(c);assert(not K.Pending(c))
 if mode=='trade'then source.offer.targetAccepted=0 else source.event='MAIL_FAILED'end
 S.Changed(c,source);drain(c);assert(w.source=='unknown',mode..' invalidation')
 if mode=='trade'then source.offer.targetAccepted=1 else source.event='MAIL_SEND_SUCCESS'end
 S.Changed(c,source);drain(c);assert(w.source==expected,mode..' repaired dependency restores inference without editing wallet/proof')
 local kind=source.kind;source.kind='chat';S.Changed(c,source);drain(c);assert(w.source=='unknown',mode..' reclassified dependency')
 source.kind=kind;S.Changed(c,source);drain(c);assert(w.source==expected,mode..' restored dependency kind')
 local ownerKey=mode=='trade'and'trade'or'collection';local ownerID=source[ownerKey]
 source[ownerKey]='wrong-parent';S.Changed(c,source);drain(c);assert(w.source=='unknown',mode..' old link remains reviewable after reparenting')
 source[ownerKey]=ownerID;S.Changed(c,source);drain(c);assert(w.source==expected,mode..' repaired parent link')
 local window=c.records[w.window];local originalSession=window.session
 window.session='changed';S.Changed(c,window);drain(c);assert(w.source=='unknown',mode..' changed window session')
 window.session=originalSession;S.Changed(c,window);drain(c);assert(w.source==expected,mode..' restored window session')
 window.ended=now+100;window.closing=12345;S.Changed(c,window)
 assert(K.Pending(c),mode..' arbitrary window edit is not a verified heartbeat');drain(c)
 assert(w.before==100 and w.after-w.before==w.amount)
end
-- Only a linked wallet is queued among a large retained financial history.
local large=S.Character('gold-dependency-targeted',{name='Targeted'})
for i=1,10000 do raw(large,'gold',now-1000-i,{amount=1,before=i,after=i+1,source='unknown',quality='unknown',session='older'})end
local lw,ls=trade(large);drain(large)
local check=F.CheckWallet;local visits=0
F.CheckWallet=function(c,w)if c==large then visits=visits+1 end;return check(c,w)end
local walletKeys=Q.WalletKeys
Q.WalletKeys=function(c)assert(c~=large,'Targeted review must not traverse the whole wallet directory');return walletKeys(c)end
ls.offer.targetAccepted=0;S.Changed(large,ls);drain(large);assert(lw.source=='unknown'and visits==1)
ls.offer.targetAccepted=1;S.Changed(large,ls);drain(large);assert(lw.source=='trade'and visits==2)
Q.WalletKeys=walletKeys;F.CheckWallet=check

-- Targeted requests merge, requeue an already visited wallet, and survive reload.
local merged=S.Character('gold-dependency-merged',{name='Merged'});local linked={}
for i=1,24 do local w,source=trade(merged);linked[i]={w=w,source=source}end;drain(merged)
for _,row in ipairs(linked)do row.source.offer.targetAccepted=0;S.Changed(merged,row.source)end
assert(K.Pending(merged));K.Step(merged,16)
linked[1].source.offer.targetAccepted=1;S.Changed(merged,linked[1].source);drain(merged)
assert(linked[1].w.source=='trade')
for i=2,24 do assert(linked[i].w.source=='unknown')end
for _,row in ipairs(linked)do row.source.offer.targetAccepted=1;S.Changed(merged,row.source)end
assert(K.Pending(merged)and merged.state.goldChecksPending)
local restored=E.Copy(merged);E.db.characters[merged.id]=restored;drain(restored)
for _,row in ipairs(linked)do assert(restored.records[row.w.id].source=='trade')end
assert(restored.state.goldSourceReviewVersion==5 and not restored.state.goldChecksPending)
print('PASS gold dependency corrections: trade/mail invalidation, repair, reclassification and wallet-window session changes')
print('PASS targeted gold queue: 10,000 unrelated wallet records, one wallet per linked edit, heartbeat suppression, merged requests, behind-cursor repair and reload recovery')
