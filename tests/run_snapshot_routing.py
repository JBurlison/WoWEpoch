"""Place beside auction_snapshot_routing_spec.lua in tests/. Requires Lupa Lua 5.1."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--history',type=Path);a=p.parse_args()
root=a.root.resolve();lua=LuaRuntime(unpack_returned_tuples=True);lua.execute('E={API={Now=function()return 1810000000 end}}')
for path in [root/'MyEpoch/Core.lua',root/'MyEpoch/Store.lua',root/'MyEpoch/RetentionWork.lua',a.history.resolve()if a.history else root/'MyEpoch/AuctionHistory.lua']:
    lua.execute('assert(loadstring(...))("MyEpoch",E)',path.read_text(encoding='utf-8'))
lua.execute(Path(__file__).with_name('auction_snapshot_routing_spec.lua').read_text(encoding='utf-8'))
