local S,F,K,M,Q,G=E.Store,E.Economy,E.MailCosts,E.MailMoney,E.Query,E.GoldChecks
local template=E.Copy(E.db.characters['myepoch-ui-fixture-059'])
local function drain(c)
 G.Ensure(c)
 for i=1,10000 do Q.ProcessPreparation(500);G.Process();if not G.Pending(c)then return end end
 error('COD dependency review did not finish')
end
local function fresh()
 local c=E.Copy(template);E.db.characters[c.id]=c
 local r=c.records[c.state.reviewCollection];local e=c.records[c.state.reviewInvoice];local inv=c.records[c.state.reviewInventory]
 e.mailData.invoice=nil;e.mailData.cod=10001;S.Changed(c,e)
 local w=S.Add(c,'gold',r.ts+1,{before=100000,after=89999,amount=-10001,source='unknown',quality='unknown',session=r.session,window=r.walletAnchor.window,refs={r.walletAnchor.window}})
 r.wallets={w.id};r.walletAfter=89999;S.Changed(c,r)
 local proof=F.Evidence(c,w.ts,{source='mail',amount=w.amount,session=r.session,walletID=w.id,mailCollection=r.id,refs={r.id,r.beforeScan,r.afterScan}},'cod-dependency')
 drain(c);assert(w.source=='mail'and M.ValidProof(c,proof)and K.Price(c,r,2840).amount==10001)
 local window=c.records[w.window];window.ended=r.settledAt+100;window.closing=89999;S.Changed(c,window)
 assert(G.Pending(c),'arbitrary COD window edit requires review');drain(c)
 return c,r,inv,w,proof
end
for _,cold in ipairs({false,true})do for _,mode in ipairs({'gap-kind','gap-time','fork-kind','bank-kind','bank-link'})do
 local c,r,inv,w,proof=fresh();local conflict
 if mode:find('gap',1,true)then conflict=S.Add(c,'inventory_gap',r.ts+1,{session=r.session,reason='Recorded interruption'})
 elseif mode=='fork-kind'then local fields=E.Copy(inv);fields.id=nil;fields.sequence=nil;conflict=S.Add(c,'inventory',inv.ts,fields)
 else conflict=S.Add(c,'bank',inv.ts,{inventoryRecord=inv.id,transfers={{itemID=2840,quantity=7,direction='withdrawal'}}})end
 drain(c);assert(w.source=='unknown'and not M.ValidProof(c,proof),mode..' conflicting source revokes inferred COD payment')
 if cold then
  local copy=E.Copy(c);E.db.characters[c.id]=copy;c=copy
  r=c.records[r.id];inv=c.records[inv.id];w=c.records[w.id];proof=c.records[proof.id];conflict=c.records[conflict.id]
  assert(not M.ValidProof(c,proof),'saved invalid COD evidence reconstructs its dependencies')
 end
 if mode=='gap-time'then conflict.ts=r.settledAt+10000
 elseif mode=='bank-link'then conflict.inventoryRecord='unrelated-inventory'
 else conflict.kind='chat'end
 local keys=Q.WalletKeys;Q.WalletKeys=function(owner)assert(owner~=c,'Linked COD correction must not scan the whole wallet directory');return keys(owner)end
 S.Changed(c,conflict);drain(c);Q.WalletKeys=keys
 assert(w.source=='mail',mode..' corrected competing evidence restores COD without editing the batch or wallet')
 assert(M.ValidProof(c,proof)and K.Price(c,r,2840).amount==10001)
 local replay=F.Replay(c,math.huge);assert(replay.inventoryKnownCost==10001 and replay.inventoryQuantity==20)
 assert(w.before==100000 and w.after==89999 and w.amount==-10001 and c.notes['record:'..r.id].text==template.notes['record:'..r.id].text)
end end
-- A saved character already reviewed by build 0.118 needs one upgrade pass.
local c,r,inv,w=fresh();local gap=S.Add(c,'inventory_gap',r.ts+1,{session=r.session,reason='Old conflicting observation'});drain(c)
assert(w.source=='unknown');gap.kind='chat'
local saved=E.Copy(c);saved.state.goldSourceReviewVersion=2;E.db.characters[c.id]=saved
drain(saved);assert(saved.records[w.id].source=='mail'and saved.state.goldSourceReviewVersion==5)
print('PASS COD dependency corrections: gap kind/time, inventory fork and bank kind/link repair; warm/cold dependency recovery, targeted wallet review, upgrade resumption, restored FIFO basis and unchanged balances, items and notes')
E.db.characters[template.id]=E.Copy(template)
