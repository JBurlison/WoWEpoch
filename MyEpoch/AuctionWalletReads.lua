local _,E=...
local R={};E.AuctionWalletReads=R
-- The generated factories bind these iterator/copy helpers. A changed source
-- certificate defaults to strict invalidation until its read surface is audited.
R.Expected={
 ["Store.lua"]="55c95d20066dca6d43a77dcc04a8304e603fe4d5f41c37764fee7100a9af2926",
 ["Query.lua"]="9215baa503f6bf90b68efac3e13945403e2e9828311098f5839dfc0ca562ac0f",
 ["Economy.lua"]="8ab6288bca92335779e116a1dd42bb8f0b6d89a15dd9be4082558167bda6b68c",
 ["Trades.lua"]="e69aa92b2e8900406ef0234a54b065ad0dd17d720374907670d2681781c4c63d",
 ["Mail.lua"]="cea7f719ffa567b69eaf046d3bc5a5937fa4eed8a3e7db919a196ab96cf08024",
 ["Buyback.lua"]="cf90d6bc8f2390ae67b497e3847c0fbc45c90cfe4c81b7bcda72c004b8135cff",
 ["AuctionCosts.lua"]="14aeeff45425c0c0c7f287193eca2ee3321e301156d2a504edeec7c47ba914fc",
 ["CostMatch.lua"]="34c5aa062cab36522bb6cde97c033a7dc623e596eca6d71948c08741d4228c82",
 ["BuybackCosts.lua"]="123dbc81001de55188be99dc639a50bdba80df79a5c029246d2cc6291dce968c",
 ["BankCosts.lua"]="a883f40fb70d66c72e4a2809e008addb7571bc30bc200a6ce75520512cc1bca9",
 ["TradeCosts.lua"]="3f1e0dfcc82f530174b430f5ad89c62e72050d780d48e044c4cc830288843b4a",
 ["MailCosts.lua"]="59e7265298a4b80e7c7f47a0f2356d67048a32affb4c4159b96e708b865f5d9a",
 ["SentMailCosts.lua"]="453b3d2759286498bb73721c29709ca968d4e274f3510e9e578866f1419dfa96",
 ["CraftCosts.lua"]="e0de5f94ddd43ee4bc11a4dca55a5ef13e2272ebc5e5e02cc3063b3687346c47",
 ["MailMoney.lua"]="90d5a5414c27905d101ceae2a9d9bba4fe8d554d2a1643cc52b33f008b457e4a",
 ["AuctionProceeds.lua"]="8c9ae5b9370bf22e392a8c19f6b492c7ea79f724c7c49bc7db500fa331d91733",
 ["AuctionLinks.lua"]="0e4f1e9fdc5935a4b79c2fd3a7cf3a4357b16c0670d862e16c192f8d6c15ca6d",
 ["AuctionSettlement.lua"]="65aa923135386a239f4a991e7f883adb72947d330fb8089686fda56d2d88987d",
 ["AuctionDeposits.lua"]="208c9549586a59e8cce5883e8319eae4efb2ecd0835a86013b26a0c5942de8ac",
 ["AuctionReturns.lua"]="b4651b194f6522ab4dd0b7f34b6734c9f18a296e96b4f2559ab7876b75d21b6a",
}
function R.Certified()
 if E.AuctionWalletReadInstrumentation~=1 then return false end
 if type(E.AuctionReaderSources)~='table'or type(E.AuctionReaderFactories)~='table'then return false end
 local count=0
 for name,hash in pairs(R.Expected)do count=count+1;if E.AuctionReaderSources[name]~=hash then return false end end
 for name in pairs(E.AuctionReaderSources or{})do if not R.Expected[name]then return false end end
 if #(E.AuctionReaderFactories or{})~=count then return false end
 local seen={};for _,factory in ipairs(E.AuctionReaderFactories)do
  local name=type(factory.name)=='string'and factory.name..'.lua'
  if not name or seen[name]or not R.Expected[name]then return false end;seen[name]=true
 end
 return next(R.Expected)~=nil
end
function R.Install(a,work)
 assert(a.walletTracked and not a.snapshotOpen and not a.walletInstalling and not a.walletGuarded,'Wallet guards require an unused sealed snapshot')
 a.walletInstalling=true
 local g={};local registry=setmetatable({},{__mode='k'})
 local function read(meta)
  a.walletReads[meta.source]=true
  if a.walletDrift[meta.source]then a.invalid=true;error('Wallet endpoint was consumed after it changed; a fresh snapshot is required')end
  return meta.ended
 end
 function g.RawGet(value,key)
  local meta=registry[value]
  if meta and key=='ended'then return read(meta)end
  return rawget(value,key)
 end
 function g.Next(value,key)
  local meta=registry[value]
  if not meta or meta.exposed then return next(value,key)end
  local at=key==nil and 0 or meta.index[key]
  assert(at~=nil,'Invalid key to next')
  local following=meta.keys[at+1]
  if following~=nil then return following,g.RawGet(value,following)end
 end
 function g.Pairs(value)return g.Next,value,nil end
 function g.Copy(value,checkpoint)
  if type(value)~='table'then return E.Copy(value)end
  local out={};local active={[value]=true};local stack={{input=value,output=out}}
  while #stack>0 do
   if checkpoint then checkpoint()end
   local f=stack[#stack];local key,item=g.Next(f.input,f.key);f.key=key
   if key==nil then active[f.input]=nil;stack[#stack]=nil
   else
    assert(type(key)=='string'or type(key)=='number','Invalid data key')
    if type(item)=='table'then
     assert(not active[item],'Cyclic data');active[item]=true
     local clone={};f.output[key]=clone;stack[#stack+1]={input=item,output=clone}
    else f.output[key]=E.Copy(item)end
   end
  end
  return out
 end
 function g.Same(left,right,checkpoint)
  local stack={{a=left,b=right}}
  while #stack>0 do
   if checkpoint then checkpoint()end
   local f=stack[#stack]
   if type(f.a)~=type(f.b)then return false end
   if type(f.a)~='table'then
    if f.a~=f.b then return false end;stack[#stack]=nil
   elseif not f.second then
    local key,value=g.Next(f.a,f.key);f.key=key
    if key==nil then f.second=true
    else stack[#stack+1]={a=value,b=f.b[key]}end
   else
    local key=g.Next(f.b,f.key);f.key=key
    if key==nil then stack[#stack]=nil elseif f.a[key]==nil then return false end
   end
  end
  return true
 end
 -- Capture original key order before hiding the endpoint scalar. All factory
 -- next/pairs calls see that same order, including the virtual ended entry.
 for source,copies in pairs(a.walletCopies or{})do
  work()
  for _,value in ipairs(copies)do
   work();local meta={source=source,ended=value.ended,keys={},index={}}
   for key in pairs(value)do work();meta.keys[#meta.keys+1]=key;meta.index[key]=#meta.keys end
   registry[value]=meta;rawset(value,'ended',nil)
   setmetatable(value,{__index=function(_,key)if key=='ended'then return read(meta)end end,
    __newindex=function(t,key,v)if key=='ended'then a.invalid=true;error('Private wallet endpoints are read-only')end;rawset(t,key,v)end})
  end
 end
 a.walletCopies=nil
 a.walletInstalling=nil;a.walletGuarded=true
 -- A raw wallet returned to the ordinary renderer is itself an endpoint read.
 -- Unmask only after recording that permanent dependency; future extensions
 -- then revoke this audit, including any reusable engine using this table.
 function g.FinishResult(value,checkpoint)
  local seen={};local pending={value}
  while #pending>0 do
   checkpoint();local row=pending[#pending];pending[#pending]=nil
   if type(row)=='table'and not seen[row]then
    seen[row]=true;local meta=registry[row]
    if meta and not meta.exposed then rawset(row,'ended',read(meta));meta.exposed=true;setmetatable(row,nil)end
    for key,item in pairs(row)do checkpoint();if type(key)=='table'then pending[#pending+1]=key end;if type(item)=='table'then pending[#pending+1]=item end end
   end
  end
 end
 g.Registry=registry
 return g
end
