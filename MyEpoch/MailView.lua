local _,E=...
local V,B,A,S,F,L={},E.Book,E.API,E.Store,E.FinanceView,E.LedgerStyle;E.MailView=V
local function redraw()B.Render()end
local function preparedLink(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('links',c,r,E.AuctionLinks.Invoice)end;return E.AuctionLinks.Invoice(c,r)end
local function preparedMailPlan(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('mailPlans',c,r,E.MailMoney.Plan)end;return E.MailMoney.Plan(c,r)end
local function preparedMailCosts(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('mailCosts',c,r,E.MailCosts.Plan)end;return E.MailCosts.Plan(c,r)end
local function preparedMailSent(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('mailSent',c,r,E.SentMailCosts.Info)end;return E.SentMailCosts.Info(c,r)end
local function preparedMailResolve(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('mailResolve',c,r,E.MailCosts.Resolve)end;return E.MailCosts.Resolve(c,r)end
local function preparedPrice(c,r,id)if E.AuctionPreparationView then return E.AuctionPreparationView.Price(c,r,id)end;return E.MailCosts.Price(c,r,id)end

local function sentRefs(c,r)local plan=E.SentMailCosts.Plan(c,r);return plan and plan.refs or{}end
local function preparedSentRefs(c,r)if E.AuctionPreparationView then return E.AuctionPreparationView.Read('mailSentRefs',c,r,sentRefs)end;return sentRefs(c,r)end
local function icons(d)local out,seen={},{};for _,item in ipairs(d and d.items or{})do if item.itemID and not seen[item.itemID]then out[#out+1]=item.itemID;seen[item.itemID]=true end end;return out end
function V.Render(left,right,range)
 local c=B.Character();B.Text(left,E.L['Letters & parcels'],23)
 B.Text(left,E.L['Saved mailbox observations and collection attempts. Observation dates are not delivery dates.'],14)
 B.Navigation.Controls(function(left)
    local filters={};for _,pair in ipairs({{'all',E.L['All entries']},{'mail',E.L['Envelopes']},{'mail_collection',E.L['Collections']},{'sent',E.L['Outgoing mail']}})do local key=pair[1]
  filters[#filters+1]={pair[2],function()B.mailFilter=key;B.mailPage=1;B.selected=nil;redraw()end,(B.mailFilter or'all')==key}
 end;F.Actions(left,filters,2)
 B.Text(left,E.L['Find a sender, subject or attachment'],12);B.Input(left,B.mailQuery or'',function(v)B.mailQuery=v;B.mailPage=1;B.selected=nil;redraw()end)
 end)
    local rows=E.AuctionPreparationView and E.AuctionPreparationView.Rows(c,'mailRows')
 if not rows then
 rows={};local query=(B.mailQuery or''):lower();local filter=B.mailFilter or'all'
 for _,r in ipairs(E.Query.Range(c,range.from,range.through))do if (r.kind=='mail'or r.kind=='mail_collection')and(filter=='all'or r.kind==filter or filter=='sent'and r.sendRequest)then
  local request=r.sendRequest and c.records[r.sendRequest];local d=r.mailData or request and request.sendData or{};local words={E.Display.RecordTitle(r)or'',r.sender or'',r.recipient or'',r.subject or'',E.L[r.status or'']}
  for _,item in ipairs(d.items or{})do words[#words+1]=E.Display.Item(item.itemID,item.name or'');words[#words+1]=tostring(item.itemID or item.currencyID or'')end
  if d.invoice then words[#words+1]=d.invoice.itemName or'';words[#words+1]=d.invoice.player or''end
  if table.concat(words,' '):lower():find(query,1,true)then rows[#rows+1]=r end
 end end
 table.sort(rows,function(a,b)return S.Before(b,a)end)
 end
 local pages=math.max(1,math.ceil(#rows/6));B.mailPage=math.max(1,math.min(B.mailPage or 1,pages))
 if #rows>0 then B.Text(left,E.Format('{count} saved entries / Page {page} of {pages}',{count=#rows,page=B.mailPage,pages=pages}),12)end
 for i=(B.mailPage-1)*6+1,math.min(#rows,B.mailPage*6)do local r=E.AuctionPreparationView and E.AuctionPreparationView.Row and E.AuctionPreparationView.Row(c,'mailRows',i)or rows[i]
  local rowIcons=r.preparedIcons
  if not rowIcons then
   local request=r.sendRequest and c.records[r.sendRequest];rowIcons=icons(r.mailData or request and request.sendData);local receipt=r.kind=='mail_collection'and preparedMailCosts(c,r)
   if receipt then rowIcons=E.SortedKeys(receipt.items)end
  end
  F.Row(left,E.Display.RecordTitle(r),A.RecordDate(r)..' / '..(r.sender or E.L[r.status or'Observed']),'', '',function()B.selected=r.id;B.Render(true)end,r.id,rowIcons)
 end
 local nav={};if B.mailPage>1 then nav[#nav+1]={E.L['Previous letters'],function()B.mailPage=B.mailPage-1;redraw()end}end
 if B.mailPage<pages then nav[#nav+1]={E.L['More letters'],function()B.mailPage=B.mailPage+1;redraw()end}end;F.Actions(left,nav,2)
 local selected=B.selected and c.records[B.selected];if selected and selected.kind:match('^mail')then return end
 B.Text(right,E.L['A page for the post'],29);B.Text(right,#rows>0 and E.L['Choose an envelope or collection to revisit its items, invoice and original evidence.']or E.L['No matching mailbox history has been recorded.'],16)
end
local function links(page,c,rows,label)
 local pages=math.max(1,math.ceil(#rows/8));B.mailLinkPage=math.max(1,math.min(B.mailLinkPage or 1,pages))
 for i=(B.mailLinkPage-1)*8+1,math.min(#rows,B.mailLinkPage*8)do local id=rows[i];local r=c.records[id]
  if r then B.Action(page,E.Format('{label} {index}: {title}',{label=label,index=i,title=E.Display.RecordTitle(r)}),function()E.SearchView.Open({character=c.id,record=id})end)
  else B.Text(page,E.L['Original entry no longer retained.'],12)end
 end
 local nav={};if B.mailLinkPage>1 then nav[#nav+1]={E.L['Earlier linked entries'],function()B.mailLinkPage=B.mailLinkPage-1;redraw()end}end
 if B.mailLinkPage<pages then nav[#nav+1]={E.L['More linked entries'],function()B.mailLinkPage=B.mailLinkPage+1;redraw()end}end;F.Actions(page,nav,2)
end
function V.Record(page,c,r)
 if B.mailFocus~=r.id then B.mailFocus=r.id;B.mailItemPage=1;B.mailSentPage=1;B.mailLinkPage=1 end
 local d=r.mailData
 local plan,reason;if r.kind=='mail_collection'then plan,reason=preparedMailPlan(c,r)end
 local receipt=r.kind=='mail_collection'and preparedMailCosts(c,r)
 local sentMatch,sentReason;if r.kind=='mail_collection'and r.sendRequest then sentMatch,sentReason=preparedMailSent(c,r)end
 local status=r.kind=='mail_collection'and(plan and E.L['Matched observations']or sentMatch and E.L['Outgoing items matched (inferred)']or receipt and E.L['Items matched (inferred)']or E.L['Unresolved collection'])or r.kind=='mail'and E.L['Observed envelope']or E.L[r.status or'Observation']
 L.Heading(page,E.Display.RecordTitle(r)or E.L['Mailbox entry'],E.L['GOLD / LETTERS & PARCELS'],status,A.RecordDate(r)..' / '..E.L['Local time'])
 if E.AuctionReturnView then E.AuctionReturnView.Record(page,c,r)end
 local send=r.sendData;local request=r.sendRequest and c.records[r.sendRequest]
 if request then send=request.sendData end
 if send then
  L.Section(page,E.L['Outgoing request'])
  B.Text(page,E.Format('Recipient entered: {name}',{name=(request or r).recipient or E.L['Unknown']}),16)
  L.Amount(page,E.L['Quoted postage'],send.postageQuote);L.Amount(page,E.L['Gold requested to send'],send.moneyRequested);L.Amount(page,E.L['COD requested / not income'],send.codRequested)
  B.Text(page,E.L['Attachment snapshot after the send request; this does not confirm delivery, item consumption or cost transfer.'],13)
  if not send.attachmentsComplete then B.Text(page,E.L['Some attachment details were unavailable.'],13)end
  local rows=send.items or{};local pages=math.max(1,math.ceil(#rows/6));B.mailItemPage=math.max(1,math.min(B.mailItemPage or 1,pages))
  for i=(B.mailItemPage-1)*6+1,math.min(#rows,B.mailItemPage*6)do local item=rows[i];L.Item(page,item.itemID,E.Display.Item(item.itemID,item.name or E.L['Unknown attachment']),item.quantity,E.L['Post-request observation'],item.itemLink)end
  local nav={};if B.mailItemPage>1 then nav[#nav+1]={E.L['Earlier attachments'],function()B.mailItemPage=B.mailItemPage-1;redraw()end}end
  if B.mailItemPage<pages then nav[#nav+1]={E.L['More attachments'],function()B.mailItemPage=B.mailItemPage+1;redraw()end}end;F.Actions(page,nav,2)
 end
 if r.kind=='mail_collection'and r.sendRequest then
  local sent,why=sentMatch,sentReason
  L.Section(page,E.L['Outgoing goods & FIFO cost'])
  B.Text(page,E.L[why or "Unknown"],13)
  if sent then
   local ids=E.SortedKeys(sent.items);local pages=math.max(1,math.ceil(#ids/6));B.mailSentPage=math.max(1,math.min(B.mailSentPage or 1,pages))
   for i=(B.mailSentPage-1)*6+1,math.min(#ids,B.mailSentPage*6)do local id=ids[i];local item=sent.items[id]
    L.Item(page,id,L.Name(id),item.quantity,E.L['Outgoing items / inferred'])
    L.Amount(page,E.L['Recorded FIFO acquisition cost'],item.cost)
    if item.unknownQuantity>0 then B.Text(page,E.Format('{count} units have unknown acquisition cost.',{count=item.unknownQuantity})..(item.knownCost>0 and E.Format(' Known portion: {amount}',{amount=F.Money(item.knownCost)})or''),12)end
   end
   local nav={};if B.mailSentPage>1 then nav[#nav+1]={E.L['Earlier outgoing goods'],function()B.mailSentPage=B.mailSentPage-1;redraw()end}end
   if B.mailSentPage<pages then nav[#nav+1]={E.L['More outgoing goods'],function()B.mailSentPage=B.mailSentPage+1;redraw()end}end;F.Actions(page,nav,2)
   B.Text(page,E.L['These original inventory movements are not sales. No revenue, delivery or receiving-character cost is inferred.'],12)
   B.Action(page,E.L['Reject outgoing-item inference'],function()r.rejectSentItems=true;S.Changed(c,r);redraw()end)
  elseif r.rejectSentItems then B.Action(page,E.L['Re-evaluate outgoing items'],function()r.rejectSentItems=nil;S.Changed(c,r);redraw()end)end
 end
 if d then
  B.Text(page,E.Format('From {name}',{name=d.sender or E.L['Unknown sender']}),18)
  L.Amount(page,E.L['Gold attached'],d.money);L.Amount(page,E.L['Cash on delivery requested'],d.cod)
  if not d.complete then B.Text(page,E.L['Some envelope details were unavailable; no complete receipt is established.'],13)end
  local invoice=d.invoice
  if invoice then
   L.Section(page,invoice.type=='buyer'and E.L['Auction purchase invoice']or invoice.type=='seller'and E.L['Auction sale invoice']or E.L['Pending or other invoice'])
   if invoice.itemName then local link=invoice.type=='seller'and preparedLink(c,r)
    L.Item(page,link and link.itemID,invoice.itemName,invoice.count,link and E.L['Item identity inferred from listing']or E.L['Auction invoice / item ID not reported'])end
   if invoice.player then B.Text(page,E.Format('Counterparty: {name}',{name=invoice.player}),14)end
   L.Amount(page,invoice.type=='buyer'and E.L['Reported purchase price']or E.L['Reported sale price'],invoice.bid)
   if invoice.type~='buyer'then L.Amount(page,E.L['Deposit returned on invoice'],invoice.deposit);L.Amount(page,E.L['Auction house cut on invoice'],invoice.cut)end
   B.Text(page,E.L['These are invoice values. They do not create another wallet entry, item acquisition or FIFO sale.'],13)
   if invoice.type=='seller'then E.AuctionView.InvoiceLink(page,c,r)end
  end
  if #d.items>0 then
   L.Section(page,E.L['Enclosed items'])
   local pages=math.max(1,math.ceil(#d.items/6));B.mailItemPage=math.max(1,math.min(B.mailItemPage or 1,pages))
   for i=(B.mailItemPage-1)*6+1,math.min(#d.items,B.mailItemPage*6)do local item=d.items[i]
    L.Item(page,item.itemID,E.Display.Item(item.itemID,item.name or E.L['Attachment details unavailable']),item.quantity,E.Format('{type} / Slot {slot}',{type=item.isCurrency and E.L['Currency attachment']or E.L['Item attachment'],slot=item.slot}))
   end
   local nav={};if B.mailItemPage>1 then nav[#nav+1]={E.L['Earlier attachments'],function()B.mailItemPage=B.mailItemPage-1;redraw()end}end
   if B.mailItemPage<pages then nav[#nav+1]={E.L['More attachments'],function()B.mailItemPage=B.mailItemPage+1;redraw()end}end;F.Actions(page,nav,2)
  end
  B.Text(page,E.L['Inbox positions can change. Repeated observations are not a count of distinct letters; attachments are not inventory receipts.'],13)
  if r.scan and c.records[r.scan]then B.Action(page,E.L['Open mailbox observation'],function()E.SearchView.Open({character=c.id,record=r.scan})end)end
 elseif r.kind=='mail_collection'then
  if not receipt then B.Text(page,E.L[reason or "Unknown"],14)end
  if plan then
   local attributed=true;for _,w in ipairs(plan.wallets)do if w.source~=plan.source or(w.quality~='inferred'and w.quality~='confirmed')then attributed=false end end
   L.Amount(page,plan.outgoing and E.L['Matching outgoing gold']or E.L['Matching collected gold'],plan.outgoing and-plan.amount or plan.amount)
   if plan.outgoing then L.Amount(page,E.L['Postage / inferred'],plan.postage);L.Amount(page,E.L['Attached gold / inferred'],plan.sentGold)end
   B.Text(page,attributed and E.Format('Ledger source: {source} / inferred',{source=E.L[E.Economy.sources[plan.source]or plan.source]})or E.L['Current ledger attribution is unknown or disputed.'],13)
  end
  if receipt then
   L.Section(page,E.L['Goods received & recorded costs'])
   local match,why=preparedMailResolve(c,receipt.records[1]);B.Text(page,E.L[why or "Unknown"],13)
   local ids=E.SortedKeys(receipt.items);local pages=math.max(1,math.ceil(#ids/6));B.mailItemPage=math.max(1,math.min(B.mailItemPage or 1,pages))
   for i=(B.mailItemPage-1)*6+1,math.min(#ids,B.mailItemPage*6)do local id=ids[i];local item=receipt.items[id]
    L.Item(page,id,L.Name(id),item.quantity,E.L['Matched attachment and inventory / inferred receipt'])
    local price,why=preparedPrice(c,r,id)
    if match and price then L.Amount(page,E.L['Inferred acquisition cost'],E.Economy.Part(price.amount,price.quantity,price.offset,item.quantity));B.Text(page,E.L[why or "Unknown"],12)
    else B.Text(page,match and E.L[why or'Unknown']or E.L['Acquisition cost remains unknown while sources conflict.'],12)end
   end
   local nav={};if B.mailItemPage>1 then nav[#nav+1]={E.L['Earlier received items'],function()B.mailItemPage=B.mailItemPage-1;redraw()end}end
   if B.mailItemPage<pages then nav[#nav+1]={E.L['More received items'],function()B.mailItemPage=B.mailItemPage+1;redraw()end}end;F.Actions(page,nav,2)
   B.Text(page,E.L['Existing inventory lots supply the quantities. Reconciliation adds no duplicate loot receipt, cash entry or sale.'],12)
  end
  E.AuctionView.ProceedsCollection(page,c,r)
  local related={};if r.beforeScan then related[#related+1]=r.beforeScan end;if r.afterScan then related[#related+1]=r.afterScan end
  for _,kind in ipairs({'wallets','requests','notices'})do for _,id in ipairs(r[kind]or{})do related[#related+1]=id end end
  if receipt then for _,inv in ipairs(receipt.records)do related[#related+1]=inv.id end end
  for _,id in ipairs(preparedSentRefs(c,r))do related[#related+1]=id end
  links(page,c,related,E.L['Open original'])
 elseif r.kind=='mail_draft'then
  B.Text(page,E.L['Attachment observations during composition. A draft is not a sent message; no message body is saved.'],14)
  local snapshot=r.snapshots and r.snapshots[#r.snapshots];local items=snapshot and snapshot.data.items or{}
  if snapshot then B.Text(page,E.Format('Last attachment observation: {date}',{date=A.Date(snapshot.ts)}),13);if not snapshot.data.complete then B.Text(page,E.L['Some attachment details were unavailable.'],13)end end
  local pages=math.max(1,math.ceil(#items/6));B.mailItemPage=math.max(1,math.min(B.mailItemPage or 1,pages))
  for i=(B.mailItemPage-1)*6+1,math.min(#items,B.mailItemPage*6)do local item=items[i];L.Item(page,item.itemID,E.Display.Item(item.itemID,item.name or E.L['Unknown attachment']),item.quantity,E.L['Draft observation'])end
  local nav={};if B.mailItemPage>1 then nav[#nav+1]={E.L['Earlier draft items'],function()B.mailItemPage=B.mailItemPage-1;redraw()end}end
  if B.mailItemPage<pages then nav[#nav+1]={E.L['More draft items'],function()B.mailItemPage=B.mailItemPage+1;redraw()end}end;F.Actions(page,nav,2)
  links(page,c,r.refs or{},E.L['Open draft evidence'])
 elseif r.kind=='mail_scan'then
  B.Text(page,r.complete and E.L['Complete loaded list observed.']or E.L['Partial mailbox coverage; missing rows remain unknown.'],14)
  if r.loaded and r.loaded>0 then B.Text(page,E.Format('Loaded envelopes: {count}',{count=r.loaded}),14)end
  if r.total and r.total>0 then B.Text(page,E.Format('Client-reported total: {count}',{count=r.total}),14)end
  if #r.entries==0 then B.Text(page,E.L['No envelopes were present in the readable loaded list.'],14)end
  links(page,c,r.entries,E.L['Open envelope'])
 else
  if r.recipient then B.Text(page,E.Format('Recipient entered: {name}',{name=r.recipient}),16)end
  if r.subject then B.Text(page,E.Format('Subject entered: {subject}',{subject=r.subject}),16)end
  B.Text(page,E.L['Requests and notifications are retained separately; neither alone establishes delivery or settlement.'],14)
  if r.collection and c.records[r.collection]then B.Action(page,E.L['Open collection interval'],function()E.SearchView.Open({character=c.id,record=r.collection})end)end
 end
 F.Actions(page,{{E.L['Open mail day'],function()B.chapter='Calendar';B.day=A.DayStart(r.ts);B.calendarFilter='all';B.calendarPage=1;B.selected=nil;B.Render(true)end},
  {r.starred and E.L['Unstar this memory']or E.L['Star and protect this memory'],function()r.starred=not r.starred;S.Changed(c,r);redraw()end}},2)
 B.Note(page,E.Diary.NoteKey(c,r))
end
