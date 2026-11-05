-- Synthetic purchase invoice and split inventory receipt; never packaged.
do
 local id='myepoch-ui-fixture-059'
 if not MyEpochDB.characters[id]then
  local now=time()-180;local session='test-mail-costs';local visit=session..':1'
  local c={id=id,identity={name='Tessa',realm='TEST: Mail costs',level=28},seq=0,revision=1,state={firstObserved=now},order={},records={},dedup={},notes={},retention={},art={}}
  local function add(kind,ts,d)
   c.seq=c.seq+1;d.id=id..':'..c.seq;d.character=id;d.sequence=c.seq;d.kind=kind;d.ts=ts;d.category='gold';d.session=session;d.visit=visit;d.refs=d.refs or{}
   c.records[d.id]=d;c.order[#c.order+1]=d.id;return d
  end
  local base=add('inventory',now-1,{title='TEST: opening inventory',baseline=true,scope='bags and equipment',carried={},equipment={},items={}})
  local window=add('wallet_window',now,{opening=100000,closing=100000,ended=now+4,transactionCount=0})
  local before=add('mail_scan',now,{title='TEST: mailbox before collection',loaded=1,total=1,complete=true,finishedAt=now,lastObservedAt=now,entries={}})
  local envelope=add('mail',now,{title='Copper for a fresh adventure',sender='Auction House',index=1,scan=before.id,refs={before.id},mailData={
   complete=true,sender='Auction House',subject='Copper for a fresh adventure',money=0,cod=0,itemCount=1,
   items={{slot=1,itemID=2840,name='Copper Bar',quantity=20,quality=1,complete=true,isCurrency=false}},
   invoice={type='buyer',itemName='Copper Bar',player='Bramble',bid=34001,count=20}}})
  before.entries={envelope.id};before.refs={envelope.id}
  local sequence=c.seq
  local batch=add('mail_collection',now+1,{title='Copper delivered to your pack',status='Items observed / payment recorded earlier',beforeScan=before.id,
   inventoryAnchor={record=base.id,scope=base.scope,session=session,ts=now,sequence=sequence},
   walletAnchor={amount=100000,window=window.id,session=session,ts=now,sequence=sequence},walletAfter=100000,
   requests={},notices={},wallets={},refs={before.id,base.id,window.id}})
  local request=add('mail_request',now+1,{title='TEST: collect envelope request',method='AutoLootMailItem',index=1,collection=batch.id,refs={batch.id}})
  batch.requests={request.id};batch.refs[#batch.refs+1]=request.id;batch.lastRequestAt=request.ts;batch.lastRequestSequence=request.sequence
  local notice=add('mail_notice',now+1,{title='TEST: mail success',event='MAIL_SUCCESS',itemID=2840,collection=batch.id,refs={batch.id}})
  batch.notices={notice.id};batch.refs[#batch.refs+1]=notice.id
  local current=0
  for i,n in ipairs({7,13})do
   local inv=add('inventory',now+1+i,{title='TEST: Copper Bar receipt '..i,scope=base.scope,previousRecord=base.id,observedFrom=i==1 and now or base.ts,
    accountingTime=now+1+i,carried={[2840]=current+n},equipment={},items={{itemID=2840,before=current,after=current+n,delta=n}},mailCandidates={batch.id},refs={batch.id}})
   local lot=add('cost_lot',inv.ts,{title='TEST: original unknown-cost inventory lot',source='inventory observation',itemID=2840,quantity=n,quality='unknown',evidence=inv.id,refs={inv.id}})
   inv.refs[#inv.refs+1]=lot.id;batch.refs[#batch.refs+1]=inv.id;base=inv;current=current+n
   if i==1 then c.state.reviewInventory=inv.id;c.state.reviewLot=lot.id end
  end
  local after=add('mail_scan',now+4,{title='TEST: mailbox after collection',loaded=0,total=0,complete=true,finishedAt=now+4,lastObservedAt=now+4,entries={}})
  batch.afterScan=after.id;batch.refs[#batch.refs+1]=after.id;batch.settledAt=now+5
  c.state.reviewCollection=batch.id;c.state.reviewInvoice=envelope.id
  c.notes['record:'..batch.id]={text='TEST: Bramble sent the copper. The invoice price was paid earlier.',updated=now}
  MyEpochDB.characters[id]=c
 end
 print('MAILCOST059 Tessa / TEST: Mail costs ready; all items and prices are synthetic.')
end
