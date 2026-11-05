-- Synthetic saved history only; no SendMail/setter/collection API is invoked.
do
local id='myepoch-ui-fixture-070'
if not MyEpochDB.characters[id]then
 local t=time()-3600;local session='TEST: outgoing mail';local visit=session..':visit'
 local c={id=id,identity={name='Tessa',realm='TEST: Outgoing mail',level=24},state={},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,ts,r)
  c.seq=c.seq+1;r.id=id..':'..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.category='gold';r.ts=ts;r.session=session;r.visit=visit;r.refs=r.refs or{}
  c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local base=add('balance',t,{title='Observed wallet / TEST',balance=100000})
 local window=add('wallet_window',t,{title='Wallet interval / TEST',ended=t+5,opening=100000,closing=98470,transactionCount=1,refs={base.id}})
 local batch=add('mail_collection',t+1,{title='Outgoing mail to Bramble / TEST',recipient='Bramble',subject='Supplies for the road',status='Gold matched (inferred)',
  walletAnchor={window=window.id,ts=t,amount=100000,sequence=window.sequence,session=session},requests={},notices={},wallets={},refs={window.id}})
 local items={};for i=1,8 do items[i]={slot=i,name='Supplies / TEST '..i,itemID=2840,quantity=i}end
 local request=add('mail_request',t+1,{title='Send-mail request / TEST',method='SendMail',recipient='Bramble',subject='Supplies for the road',collection=batch.id,refs={batch.id},
  sendData={postageQuote=30,moneyRequested=1500,codRequested=0,attachmentsComplete=true,items=items,coverage='Synthetic post-request snapshot'}})
 local wallet=add('gold',t+2,{title='Wallet change / TEST',amount=-1530,before=100000,after=98470,window=window.id,source='mailSent',quality='inferred',automaticAttribution=true,refs={window.id}})
 local notice=add('mail_notice',t+2,{title='Mail sending succeeded / TEST',event='MAIL_SEND_SUCCESS',collection=batch.id,refs={batch.id}})
 batch.sendRequest=request.id;batch.requests={request.id};batch.notices={notice.id};batch.wallets={wallet.id};batch.lastRequestAt=t+1;batch.lastRequestSequence=request.sequence
 batch.settledAt=t+5;batch.walletAfter=98470;batch.refs={window.id,request.id,notice.id,wallet.id}
 local proof=add('money_evidence',wallet.ts,{title='Outgoing mail match / TEST',amount=-1530,source='mailSent',walletID=wallet.id,mailCollection=batch.id,refs={batch.id}})
 wallet.evidenceRefs={proof.id};wallet.refs={window.id,proof.id};batch.refs[#batch.refs+1]=proof.id
 c.state.outgoingFixture={batch=batch.id,request=request.id,wallet=wallet.id}
 c.notes['record:'..batch.id]={text='A parcel for a friend. These notes are separate from the cash observations.',updated=t+5}
 MyEpochDB.characters[id]=c
end
print('OUTGOING070 synthetic Tessa / TEST: Outgoing mail ready. Open Gold / Letters & parcels. No message or gameplay transaction was sent.')
end
