-- Synthetic mail, invoice and collection records, excluded from the addon ZIP.
do
 local id='myepoch-ui-fixture-058'
 if not MyEpochDB.characters[id]then
  local now=time()-600;local session='test-mail';local visit=session..':1'
  local c={id=id,identity={name='Tessa',realm='TEST: Mail',level=28},seq=0,revision=1,state={firstObserved=now},order={},records={},dedup={},notes={},retention={},art={}}
  local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
  local function add(kind,ts,d)
   c.seq=c.seq+1;d.id=id..':'..c.seq;d.character=id;d.sequence=c.seq;d.kind=kind;d.ts=ts;d.category='gold';d.session=session;d.visit=visit;d.refs=d.refs or{}
   c.records[d.id]=d;c.order[#c.order+1]=d.id;return d
  end
  local letters={}
  letters[1]={sender='Auction House',subject='Copper Bar: a successful auction',money=46103,cod=0,itemCount=0,items={},complete=true,
   invoice={type='seller',itemName='Copper Bar',player='Bramble',bid=48003,buyout=48003,deposit=500,cut=2400,count=20}}
  local items={};for i,v in ipairs({{2840,'Copper Bar',20},{2447,'Peacebloom',4},{2589,'Linen Cloth',12},{765,'Silverleaf',7},{785,'Mageroyal',2},{2450,'Briarthorn',3},{2453,'Bruiseweed',2}})do
   items[#items+1]={slot=i,itemID=v[1],name=v[2],quantity=v[3],quality=1,complete=true,isCurrency=false}
  end
  letters[2]={sender='Bramble',subject='A parcel for the next adventure',money=0,cod=0,itemCount=#items,items=items,complete=true}
  for i=3,8 do letters[i]={sender='Sample companion '..i,subject='Supplies and a small story '..i,money=0,cod=0,itemCount=1,items={copy(items[1])},complete=true}end
  local function snapshot(ts,values)
   local scan=add('mail_scan',ts,{title='TEST: mailbox observation',loaded=#values,total=#values,complete=true,finishedAt=ts,lastObservedAt=ts,entries={}})
   for i,d in ipairs(values)do local r=add('mail',ts,{title=d.subject,sender=d.sender,mailData=copy(d),index=i,scan=scan.id,refs={scan.id}})
    scan.entries[#scan.entries+1]=r.id;scan.refs[#scan.refs+1]=r.id
   end
   return scan
  end
  local before=snapshot(now,letters)
  local window=add('wallet_window',now,{opening=100000,closing=146103,ended=now+4,transactionCount=1})
  local anchor={amount=100000,ts=now,sequence=c.seq,window=window.id,session=session}
  local batch=add('mail_collection',now+1,{title='A morning at the mailbox',status='Gold matched (inferred)',beforeScan=before.id,walletAnchor=anchor,requests={},notices={},wallets={},refs={before.id,window.id}})
  local request=add('mail_request',now+1,{title='TEST: take attached gold request',method='TakeInboxMoney',index=1,collection=batch.id,refs={batch.id}})
  batch.requests={request.id};batch.refs[#batch.refs+1]=request.id;batch.lastRequestAt=request.ts;batch.lastRequestSequence=request.sequence
  local w=add('gold',now+2,{title='TEST: collected auction proceeds',before=100000,after=146103,amount=46103,source='auctionSale',quality='inferred',automaticAttribution=true,window=window.id,refs={window.id}})
  batch.wallets={w.id};batch.refs[#batch.refs+1]=w.id;batch.walletAfter=146103
  local notice=add('mail_notice',now+2,{title='TEST: mail success notification',event='MAIL_SUCCESS',collection=batch.id,refs={batch.id}})
  batch.notices={notice.id};batch.refs[#batch.refs+1]=notice.id
  letters[1].money=0;local after=snapshot(now+3,letters);batch.afterScan=after.id;batch.refs[#batch.refs+1]=after.id;batch.settledAt=now+4
  local proof=add('money_evidence',now+2,{title='TEST: inferred mail collection',source='auctionSale',amount=46103,walletID=w.id,mailCollection=batch.id,refs={batch.id,before.id,after.id}})
  w.evidenceRefs={proof.id};w.refs[#w.refs+1]=proof.id;batch.refs[#batch.refs+1]=proof.id
  c.state.reviewEnvelope=after.entries[2];c.state.reviewInvoice=before.entries[1];c.state.reviewCollection=batch.id
  c.notes['record:'..c.state.reviewEnvelope]={text='TEST: Bramble packed herbs, copper, and a cheerful note.',updated=now}
  MyEpochDB.characters[id]=c
 end
 print('MAIL058 Tessa / TEST: Mail ready; envelopes and transactions are synthetic.')
end
