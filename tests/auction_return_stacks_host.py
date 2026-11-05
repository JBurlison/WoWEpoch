from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
p=argparse.ArgumentParser();p.add_argument('--source',type=Path);p.add_argument('--overlay',type=Path);p.add_argument('--mock',type=Path);p.add_argument('--base-control',action='store_true')
args=p.parse_args();tests=Path(__file__).resolve().parent;source=args.source or tests.parent/'MyEpoch';mock=args.mock or tests/'wow_mock.lua'
def vm():
    v=LuaRuntime(unpack_returned_tuples=True);v.execute('E={};time=os.time;date=os.date')
    for n in (source/'MyEpoch.toc').read_text().splitlines():
        if not n.endswith('.lua'):continue
        if n=='Book.lua':v.execute(mock.read_bytes())
        f=args.overlay/n if args.overlay and (args.overlay/n).exists() else source/n
        v.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',f.read_bytes(),n)
    v.execute('E.Store.Open();MyEpochDB=E.db;E.runtime={interface=16001,build=70532};E.current=E.Store.Character("two-stack-reader",{})')
    v.execute((mock.parent/'sidebar_test_support.lua').read_bytes())
    return v
for big,twin in ((False,False),(True,False),(False,True)):
    v=vm()
    v.globals().BIG=big;v.globals().TWIN=twin
    v.globals().EXPECT_BASE=args.base_control
    print(v.execute((tests/'auction_return_stacks_spec.lua').read_bytes()))
    if not big and not twin and not args.base_control:
        journal=v.execute("""local function emit(x)
            if type(x)=='table' then local a={} for k,v in pairs(x) do a[#a+1]='['..emit(k)..']='..emit(v)end return '{'..table.concat(a,',')..'}' end
            if type(x)=='string'then return string.format('%q',x)end return tostring(x)end
            return emit(SAVED_RETURN)""")
        env=v.globals().SAVED_ENVELOPE
        fresh=vm()
        fresh.execute("local env,c=...;c=assert(loadstring('return '..c))();MyEpochDB={schema=E.schema,settings={},characters={[c.id]=c}};E.Store.Open(MyEpochDB);local e=c.records[env];assert(e.auctionReturnReview.version==2 and E.Economy.Replay(c,math.huge).inventoryKnownCost==83);assert(E.AuctionReturns.Clear(c,e)and E.Economy.Replay(c,math.huge).inventoryUnknownQuantity==3)",env,journal)
        print('PASS separate Lua VM restores the reviewed parcel and can withdraw its inferred FIFO basis')
