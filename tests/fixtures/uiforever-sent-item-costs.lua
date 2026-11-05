-- Synthetic saved history. No mail, inventory or money game action is invoked.
do
local id='myepoch-ui-fixture-076'
if not MyEpochDB.characters[id]then
 local t=time()-3600;local session='TEST: outgoing items';local visit=session..':mail:1'
 local c={id=id,identity={name='Tessa',realm='TEST: Mailed items',level=24},state={},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
 local function add(kind,ts,r)
  c.seq=c.seq+1;r.id=id..':'..c.seq;r.character=id;r.sequence=c.seq;r.kind=kind;r.category='gold';r.ts=ts;r.session=session;r.visit=visit;r.refs=r.refs or{}
  c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 add('cost_lot',t-20,{title='Copper Bars / earlier purchase / TEST',itemID=2840,quantity=3,cost=5,evidence='synthetic',basis='FIFO'})
 add('cost_lot',t-10,{title='Copper Bars / later purchase / TEST',itemID=2840,quantity=7,cost=11,evidence='synthetic',basis='FIFO'})
 add('cost_lot',t-10,{title='Peacebloom / TEST',itemID=2447,quantity=2,cost=7,evidence='synthetic',basis='FIFO'})
 add('cost_lot',t-10,{title='Linen Cloth / cost unknown / TEST',itemID=2589,quantity=4,evidence='synthetic',basis='FIFO'})
 local base=add('inventory',t-1,{title='Before composing the parcel / TEST',scope='bags and equipment',carried={[2840]=10,[2447]=2,[2589]=4},equipment={},items={}})
 local anchor={record=base.id,ts=base.ts,sequence=base.sequence,session=session,scope=base.scope}
 local items={{slot=1,itemID=2840,quantity=5,name='Copper Bar'},{slot=2,itemID=2447,quantity=2,name='Peacebloom'},{slot=3,itemID=2589,quantity=4,name='Linen Cloth'}}
 local draft=add('mail_draft',t,{title='Packing supplies / TEST',inventoryAnchor=anchor,requests={},refs={base.id},snapshots={{ts=t,data={complete=true,items={}}},{ts=t+1,data={complete=true,items=items}}}})
 local inv=add('inventory',t+1,{title='Supplies leave the bags / TEST',scope=base.scope,previousRecord=base.id,observedFrom=base.ts,carried={[2840]=5,[2447]=0,[2589]=0},equipment={},
  items={{itemID=2840,before=10,after=5,delta=-5},{itemID=2447,before=2,after=0,delta=-2},{itemID=2589,before=4,after=0,delta=-4}}})
 for _,item in ipairs(items)do local movement=add('stock_move',inv.ts,{title='Original inventory outflow / TEST',itemID=item.itemID,quantity=item.quantity,source='inventory observation',reason='Observed net decrease',evidence=inv.id,refs={inv.id}});inv.refs[#inv.refs+1]=movement.id end
 local batch=add('mail_collection',t+2,{title='A parcel for Bramble / TEST',recipient='Bramble',subject='For the road',inventoryAnchor=anchor,requests={},notices={},wallets={},settledAt=t+5})
 local request=add('mail_request',t+2,{title='Send-mail request / TEST',method='SendMail',recipient='Bramble',subject='For the road',collection=batch.id,refs={batch.id,draft.id},
  sendData={postageQuote=30,moneyRequested=0,codRequested=0,items=items,attachmentsComplete=true,draft=draft.id,draftSnapshot=2}})
 local notice=add('mail_notice',t+3,{title='Send success / TEST',event='MAIL_SEND_SUCCESS',collection=batch.id,refs={batch.id}})
 draft.requests={request.id};draft.closedAt=notice.ts;draft.successNotice=notice.id;draft.refs={base.id,request.id,notice.id}
 batch.sendRequest=request.id;batch.requests={request.id};batch.notices={notice.id};batch.refs={base.id,draft.id,request.id,notice.id,inv.id};inv.refs[#inv.refs+1]=batch.id
 c.state.sentItemFixture={batch=batch.id,draft=draft.id,inventory=inv.id}
 c.notes['record:'..batch.id]={text='Supplies for a friend. The item quantities and prices on this test page are synthetic.',updated=t+5}
 MyEpochDB.characters[id]=c
end
print('SENT076 Tessa / TEST: Mailed items ready; source costs are synthetic, no mail was sent.')
end
