local S,H,F,Q,K=E.Store,E.History,E.Economy,E.Query,E.GoldChecks
local function eq(a,b,label)assert(a==b,(label or 'Money evidence mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local function drain(c)
 K.Ensure(c)
 for i=1,10000 do Q.ProcessPreparation(500);K.Process();if not K.Pending(c)then return end end
 error('Money review did not finish: '..tostring(K.Status(c)))
end
local function fixture(name)
 local c=S.Character('money-edit-'..name,{name=name})
 H.Wallet(c,1000,100,'first');local w=H.Wallet(c,1005,150,'first')
 local p=F.Evidence(c,1005,{amount=50,source='quest',session='first'},'proof')
 eq(w.source,'quest');eq(w.quality,'inferred');drain(c)
 -- Move the live recent cache beyond the historical proof being edited.
 H.Wallet(c,2000,150,'later');H.Wallet(c,2005,160,'later')
 return c,w,p
end
local c,w,p=fixture('history')
S.Note(c,w.id,'Keep my note',1006)
local function change(key,value,expected)
 p[key]=value;S.Changed(c,p);drain(c);eq(w.source,expected,'changed proof '..key)
 eq(w.amount,50);eq(w.before,100);eq(w.after,150)
end
change('amount',51,'unknown');change('amount',50,'quest')
change('session','other','unknown');change('session','first','quest')
change('ts',1010,'unknown');change('ts',1005,'quest')
change('walletID','another-wallet','unknown');change('walletID',w.id,'quest')
change('source','loot','loot');change('source','invalid-source','unknown');change('source','quest','quest')
change('kind','chat','unknown');change('kind','money_evidence','quest')
local original=p;p=E.Copy(p);c.records[p.id]=p;p.source='loot';S.Changed(c,p);drain(c)
eq(w.source,'loot','canonical replacement is used instead of cached old proof');eq(original.source,'quest')
c.records[p.id]=nil;E.Emit('RECORDS_REMOVED',c,{[p.id]=true},{kinds={money_evidence=true}});drain(c);eq(w.source,'unknown')
c.records[p.id]=p;E.Emit('RECORDS_REMOVED',c,{},{});drain(c);eq(w.source,'loot','restored evidence is re-evaluated')
local competing=F.Evidence(c,1006,{amount=50,source='quest',session='first'},'competitor')
drain(c);eq(w.source,'unknown','competing proof revokes inference')
competing.kind='chat';S.Changed(c,competing);drain(c);eq(w.source,'loot','removing competing proof restores unique inference')
eq(c.notes[w.id].text,'Keep my note')

-- One generic proof cannot be used by two nearby eligible wallet deltas.
local shared,x,proof=fixture('shared')
local y=S.Add(shared,'gold',1009,{amount=50,before=150,after=200,source='unknown',quality='unknown',session='first'})
proof.ts=1007;S.Changed(shared,proof);drain(shared)
eq(x.source,'unknown');eq(y.source,'unknown','competitor four seconds away is included')
proof.walletID=x.id;S.Changed(shared,proof);drain(shared);eq(x.source,'quest');eq(y.source,'unknown')

-- Explicit classifications are never silently rewritten by automatic review.
for _,quality in ipairs({'confirmed','inferred'})do
 local owner,tx,evidence=fixture(quality)
 evidence.source='loot';S.Changed(owner,evidence)
 F.Attribute(owner,tx.id,'loot',quality,{evidence.id},false)
 evidence.amount=999;S.Changed(owner,evidence);drain(owner)
 eq(tx.source,'loot');eq(tx.quality,quality);eq(tx.automaticAttribution,false)
end
local locked,lockedWallet,lockedProof=fixture('lock-existing')
F.Attribute(locked,lockedWallet.id,lockedWallet.source,lockedWallet.quality,lockedWallet.evidenceRefs,false)
eq(lockedWallet.automaticAttribution,false,'manual acceptance of unchanged values clears automatic flag')
lockedProof.amount=999;S.Changed(locked,lockedProof);drain(locked);eq(lockedWallet.source,'quest')
local manualUnknown,uw,up=fixture('manual-unknown')
F.Attribute(manualUnknown,uw.id,'unknown','unknown',{},false)
up.source='loot';S.Changed(manualUnknown,up);drain(manualUnknown)
eq(uw.source,'unknown');eq(uw.automaticAttribution,false)
F.Evidence(manualUnknown,1005,{amount=50,source='loot',session='first'},'new-manual-proof')
eq(uw.source,'unknown','live matching also preserves explicit unknown classification')
local reserved,rw,rp=fixture('reserved-proof')
F.Attribute(reserved,rw.id,rw.source,rw.quality,rw.evidenceRefs,false)
local duplicate=S.Add(reserved,'gold',1006,{amount=50,before=150,after=200,source='unknown',quality='unknown',session='first'})
eq(duplicate.source,'unknown','live matcher cannot reuse a generic proof matching a manual wallet')
K.Request(reserved);drain(reserved);eq(duplicate.source,'unknown','background review cannot reuse that proof either')
-- A saved pre-upgrade character receives the same check on first opening.
local legacy,lw,lp=fixture('upgrade');lp.amount=999;legacy.state.goldSourceReviewVersion=nil
drain(legacy)
eq(lw.source,'unknown');eq(legacy.state.goldSourceReviewVersion,5)
assert(not legacy.state.goldChecksPending)
local replaced=S.Character('money-edit-live-replacement',{name='Replacement'})
H.Wallet(replaced,10,100,'a');local replaceWallet=H.Wallet(replaced,15,150,'a')
local oldProof=F.Evidence(replaced,15,{amount=50,source='quest',session='a'},'old')
local newProof=E.Copy(oldProof);newProof.source='loot';replaced.records[newProof.id]=newProof
S.Changed(replaced,newProof);drain(replaced);eq(replaceWallet.source,'loot')
F.Evidence(replaced,16,{amount=999,source='quest',session='a'},'unrelated')
eq(replaceWallet.source,'loot','live recent cache recaptures canonical replacement after review')
print('PASS money evidence corrections: historical amount/session/time/source/kind/target edits, canonical replacement, removal/restoration, ambiguity, manual/confirmed protection, raw amounts/notes and upgrade review')
