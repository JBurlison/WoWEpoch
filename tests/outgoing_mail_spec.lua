-- Called inside the mailbox harness so the same post-hooks and wallet reader are exercised.
function E.TestOutgoingMail(h)
 local M,K,S,F,A,C,Q,B=E.Mail,E.MailMoney,E.Store,E.Economy,E.API,E.Collectors,E.Query,E.Book
 local c=h.character;local hooks=h.callbacks
 local names={'SetSendMailMoney','SetSendMailCOD','GetSendMailPrice','HasSendMailItem','GetSendMailItem'}
 local saved={};for _,key in ipairs(names)do saved[key]=_G[key]end
 local quote,items=30,{}
 SetSendMailMoney=function()error('Recorder must not set mail gold')end
 SetSendMailCOD=function()error('Recorder must not set COD')end
 GetSendMailPrice=function()return quote end
 HasSendMailItem=function(slot)return items[slot]~=nil end
 GetSendMailItem=function(slot)local v=items[slot];if v then return v.name,v.id,123,v.quantity,1 end end
 M.InstallHooks();assert(hooks.SetSendMailMoney and hooks.SetSendMailCOD)
 local function begin(money,cod)
  h.open({});if money~=nil then hooks.SetSendMailMoney(money)end;if cod~=nil then hooks.SetSendMailCOD(cod)end
  hooks.SendMail('Bramble-Realm','For the road','DO_NOT_RECORD_BODY')
  local b=M.pending;return b,c.records[b.sendRequest]
 end
 local function finish(loss,event)
  if loss then h.spend(loss)end
  if event then C.handlers[event]()end
  h.tick(4)
 end
 -- Real attachment-update handler captures staging evidence without sending anything.
 local inventoryLive,inventoryState=E.Inventory.live,c.state.inventory
 h.open({})
 F.Lot(c,A.Now(),{itemID=2840,quantity=3,cost=5,evidence='draft fixture'},'draft-test-cost')
 local base=S.Add(c,'inventory',A.Now(),{scope='bags and equipment',session=C.session,carried={[2840]=3},equipment={},items={}})
 c.state.inventory={record=base.id,ts=base.ts,session=C.session,scope=base.scope}
 E.Inventory.live={c=c,session=C.session,continuous=true}
 M.Close();C.handlers.MAIL_SHOW();local draft=assert(M.draft)
 assert(draft.inventoryAnchor.record==base.id and S.Protected(c)[draft.id])
 items={{name='Copper Bar',id=2840,quantity=3}};C.handlers.MAIL_SEND_INFO_UPDATE();C.handlers.MAIL_SEND_INFO_UPDATE()
 assert(#draft.snapshots==2 and draft.snapshots[2].data.items[1].itemID==2840,'identical attachment events coalesce')
 local inv=S.Add(c,'inventory',A.Now(),{scope=base.scope,session=C.session,previousRecord=base.id,observedFrom=base.ts,carried={[2840]=0},equipment={},items={{itemID=2840,before=3,after=0,delta=-3}},refs={}})
 local move=F.Move(c,A.Now(),{itemID=2840,quantity=3,evidence=inv.id,source='inventory observation',reason='Observed net decrease',refs={inv.id}},'draft-test-outflow');inv.refs={move.id};S.Changed(c,inv)
 hooks.SetSendMailMoney(0);hooks.SetSendMailCOD(0);hooks.SendMail('Bramble','Test parcel','DO_NOT_RECORD_BODY')
 local draftBatch=M.pending;assert(c.records[draftBatch.sendRequest].sendData.draft==draft.id)
 finish(30,'MAIL_SEND_SUCCESS');local sent=assert(E.SentMailCosts.Info(c,draftBatch));assert(sent.cost==5 and sent.quantity==3)
 assert(not M.draft and not c.state.activeMailDraft and draft.successNotice)
 M.Close();assert(E.SentMailCosts.Info(c,draftBatch),'closing after completion does not revoke the saved send')
 E.Inventory.live=inventoryLive;c.state.inventory=inventoryState
 items={{name='Copper Bar',id=2840,quantity=3}}
 local goldBefore=#Q.Kind(c,'gold');local lotsBefore=#Q.Kind(c,'cost_lot')
 local b,r=begin(12500,0);assert(r.sendData.moneyRequested==12500 and r.sendData.postageQuote==30 and r.sendData.items[1].itemID==2840)
 assert(r.body==nil and r.text==nil and b.body==nil,'mail body is never stored')
 finish(12530,'MAIL_SEND_SUCCESS')
 local plan=assert(K.Plan(c,b));assert(plan.outgoing and plan.amount==-12530 and plan.postage==30 and plan.sentGold==12500)
 local wallet=plan.wallets[1];assert(wallet.source=='mailSent' and wallet.quality=='inferred')
 assert(#Q.Kind(c,'gold')==goldBefore+1 and #Q.Kind(c,'cost_lot')==lotsBefore)
 local balance=E.Economy.Report(c,b.ts,b.settledAt+1);assert(balance.cashOut>=12530 and balance.operatingOut==0,'inferred outgoing money is not confirmed operating spend')
 -- A later correction invalidates the old proof instead of leaving a stale source.
 r.sendData.moneyRequested=12501;S.Changed(c,r);assert(not K.Plan(c,b) and wallet.source=='unknown')
 r.sendData.moneyRequested=12500;S.Changed(c,r);TEST_PREPARE_HISTORY(c);assert(wallet.source=='mailSent')
 b.starred=true;S.Changed(c,b);local protected=S.Protected(c);assert(protected[r.id] and protected[b.notices[1]] and protected[wallet.id])
 assert(E.Search.Find(c,'Copper Bar','finance').total>0 and E.Search.Find(c,'DO_NOT_RECORD_BODY','all').total==0)
 B.ChangeCharacter(c.id);E.SearchView.Open({character=c.id,record=b.id});TEST_PREPARE_BOOK();TEST_PREPARE_HISTORY(c);B.PreparationTick()
 assert(not B.preparingCharacter and B.goldSection=='mail' and B.right.used.ledgerItem==1)
 local good=b
 local evidence=F.Evidence(c,wallet.ts,{source='quest',amount=wallet.amount,session=C.session,walletID=wallet.id},'outgoing-contested')
 assert(wallet.source=='unknown','competing cash evidence revokes automatic attribution')
 c.records[evidence.id]=nil;S.Touch(c);E.Emit('RECORDS_REMOVED',c,{[evidence.id]=true});TEST_PREPARE_HISTORY(c);F.ReconcileEvidence(c,C.session,wallet.ts)
 assert(wallet.source=='mailSent')
 -- COD is requested future payment, not outgoing gold or income.
 b,r=begin(0,90000);finish(30,'MAIL_SEND_SUCCESS');plan=assert(K.Plan(c,b))
 assert(plan.amount==-30 and plan.sentGold==0 and plan.codRequested==90000)
 -- Quotes and both setter observations must exist; no unobserved default zero.
 b=begin(nil,0);finish(30,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b))
 b=begin(0,nil);finish(30,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b))
 quote=nil;b=begin(0,0);finish(30,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b));quote=30
 b=begin(h.hidden,0);finish(30,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b))
 b=begin(1,1);finish(31,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b))
 b=begin(0,0);finish(31,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b),'mismatched cash stays unknown')
 b=begin(0,0);finish(30,'MAIL_SUCCESS');assert(not K.Plan(c,b),'generic collection success is not send success')
 b=begin(0,0);finish(30,'MAIL_FAILED');assert(not K.Plan(c,b))
 b=begin(0,0);h.spend(30);C.handlers.MAIL_SEND_SUCCESS();C.handlers.MAIL_SEND_SUCCESS();h.tick(4);assert(not K.Plan(c,b))
 b=begin(0,0);hooks.SetSendMailMoney(0);hooks.SetSendMailCOD(0);hooks.SendMail('Second','Other','private');finish(60,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b))
 b=begin(0,0);hooks.TakeInboxMoney(1);finish(30,'MAIL_SEND_SUCCESS');assert(not K.Plan(c,b))
 b=begin(0,0);h.spend(30);C.handlers.MAIL_SEND_SUCCESS();M.Close('Mailbox closed');h.tick(4);assert(not K.Plan(c,b))
 -- Split negative wallet events retain their identities and total, without extra gold rows.
 b=begin(500,0);h.spend(30);h.spend(500);C.handlers.MAIL_SEND_SUCCESS();h.tick(4)
 plan=assert(K.Plan(c,b));assert(#plan.wallets==2 and plan.amount==-530)
 -- Deleted original evidence revokes classification even outside the short matching window.
 local notice=c.records[b.notices[1]];c.records[notice.id]=nil;S.Touch(c);E.Emit('RECORDS_REMOVED',c,{[notice.id]=true});TEST_PREPARE_HISTORY(c)
 assert(not K.Plan(c,b) and plan.wallets[1].source=='unknown' and plan.wallets[2].source=='unknown')
 -- Snapshot rows are bounded and paginate in the themed invoice.
 items={};for i=1,12 do items[i]={name='Attachment '..i,id=3000+i,quantity=i}end
 b,r=begin(0,0);finish(30,'MAIL_SEND_SUCCESS');assert(K.Plan(c,b) and #r.sendData.items==12)
 E.SearchView.Open({character=c.id,record=b.id});TEST_PREPARE_BOOK();TEST_PREPARE_HISTORY(c);B.PreparationTick()
 assert(not B.preparingCharacter and B.right.used.ledgerItem==6)
 local function click(label) TEST_PREPARE_BOOK();for _,p in ipairs({B.left,B.right})do for i=1,p.used.button or 0 do local f=p.pool.button[i];if f.text:GetText()==label then f:Click();TEST_PREPARE_BOOK();return end end end;local clicked=TEST_UI_CLICK(label);TEST_PREPARE_BOOK();return clicked end
 click('More attachments');assert(B.mailItemPage==2 and B.right.used.ledgerItem==6)
 for _,size in ipairs({{1920,1080},{2560,1440},{3840,2160}})do UIParent:SetSize(size[1],size[2]);B.Fit();B.Render();TEST_PREPARE_BOOK();assert(B.frame:GetWidth()==1760 and B.frame:GetHeight()==940)end
 UIParent:SetSize(1920,1080);B.Fit()
 for _,key in ipairs(names)do _G[key]=saved[key]end
 print('PASS outgoing mail: passive setters/send snapshots, send success plus wallet match, inferred postage/attached gold, COD exclusions, missing/restricted/mixed/failed evidence, revocation, no duplicate money/items, search, protection and invoice pagination')
end
