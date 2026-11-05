-- Synthetic custody history, for review only; excluded from the addon ZIP.
do
local donorID,receiverID='myepoch-ui-fixture-037-donor','myepoch-ui-fixture-037-receiver'
if not MyEpochDB.characters[receiverID] then
 local base=time({year=2026,month=10,day=31,hour=12,min=0,sec=0})
 local function character(id,name)
  local c={id=id,identity={name=name,realm='TEST: Custody',level=22},state={firstObserved=base-10*86400},seq=0,records={},order={},dedup={},notes={},retention={},art={},revision=1}
  MyEpochDB.characters[id]=c;return c
 end
 local function add(c,kind,ts,r)
  c.seq=c.seq+1;r.id=c.id..':'..c.seq;r.kind=kind;r.character=c.id;r.sequence=c.seq;r.ts=ts;r.refs=r.refs or {};r.category='gold'
  if kind=='bank' then MyEpochDB.bankOrder=(MyEpochDB.bankOrder or 0)+1;r.bankOrder=MyEpochDB.bankOrder end
  c.records[r.id]=r;c.order[#c.order+1]=r.id;return r
 end
 local function bank(c,ts,baseline,quantity,previous,inv,before,direction,n)
  return add(c,'bank',ts,{title='Account-bank supplies observed',bankType='account',baseline=baseline,usable=true,
   counts=quantity>0 and {[2770]=quantity} or {},tabs={{id=31}},usesBags=false,items=baseline and {{itemID=2770,after=quantity}} or {{itemID=2770,before=before,after=quantity,delta=quantity-before}},
   transfers=baseline and {} or {{itemID=2770,quantity=n,direction=direction,quality='inferred'}},previousRecord=previous and previous.id,inventoryRecord=inv and inv.id,observedFrom=previous and previous.ts,
   refs=inv and {inv.id,previous.id} or {},coverage='Synthetic balanced account-bank observations. Custody is inferred, not proof of physical identity.'})
 end
 local a=character(donorID,'Aldren');local b=character(receiverID,'Mira')
 local ai=add(a,'inventory',base,{title='Pack baseline',baseline=true,scope='bags and equipment',items={{itemID=2770,after=18}}})
 for i=1,9 do add(a,'cost_lot',base-(10-i)*86400,{title='Copper ore / original purchase '..i,itemID=2770,quantity=2,cost=200*i,evidence=ai.id,refs={ai.id},quality='inferred'})end
 local ab=bank(a,base+1,true,0)
 local ao=add(a,'inventory',base+2,{title='Ore moved from Aldren’s pack',scope='bags and equipment',previousRecord=ai.id,observedFrom=ai.ts,items={{itemID=2770,before=18,after=0,delta=-18}}})
 local am=add(a,'stock_move',base+2,{title='Ore deposited into shared storage',itemID=2770,quantity=18,reason='Observed count decrease',source='inventory observation',evidence=ao.id,refs={ao.id}});ao.refs={am.id}
 bank(a,base+2,false,18,ab,ao,0,'deposit',18)
 local bi=add(b,'inventory',base+3,{title='Mira’s empty ore pocket',baseline=true,scope='bags and equipment',items={{itemID=2770,after=0}}})
 local bb=bank(b,base+4,true,18)
 local bw=add(b,'inventory',base+5,{title='Ore arrived in Mira’s pack',scope='bags and equipment',previousRecord=bi.id,observedFrom=bi.ts,items={{itemID=2770,before=0,after=17,delta=17}}})
 local bl=add(b,'cost_lot',base+5,{title='Copper ore from the account bank',itemID=2770,quantity=17,source='inventory observation',evidence=bw.id,refs={bw.id}});bw.refs={bl.id}
 bank(b,base+5,false,1,bb,bw,18,'withdrawal',17)
 b.notes['record:'..bl.id]={text='Aldren saved these for my next round at the forge.',updated=base+6}
end
print('Synthetic Aldren and Mira / TEST: Custody added. Costs and movements are illustrative, not observed gameplay.')
end
