from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1];HERE=ROOT/'tests';STAGE=ROOT
def runtime(certified=True):
    lua=LuaRuntime(unpack_returned_tuples=True);lua.execute('E={};time=os.time;date=os.date')
    for line in (STAGE/'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):continue
        path=STAGE/'MyEpoch'/line.replace(chr(92),'/')
        if path.name=='Book.lua':lua.execute((STAGE/'tests/wow_mock.lua').read_text(encoding='utf-8'))
        lua.execute('assert(loadstring(...))("MyEpoch",E)',path.read_text(encoding='utf-8'))
    lua.execute('E.Store.Open(nil);E.current=E.Store.Character("postseal-controller",{name="TEST"})')
    lua.execute((STAGE/'tests/fixtures/auction_history_performance.lua').read_text(encoding='utf-8'))
    if not certified:lua.execute('E.AuctionReaderSources["Economy.lua"]="unreviewed source"')
    return lua
if __name__=='__main__':
    lua=runtime();lua.execute((HERE/'auction_wallet_read_guards_spec.lua').read_text(encoding='utf-8'))
    for offline in [False,True]:
        for cadence in [50,10]:
            lua=runtime();lua.globals().OFFLINE=offline;lua.globals().HEARTBEAT_FRAMES=cadence;lua.execute((HERE/'auction_wallet_heartbeat_spec.lua').read_text(encoding='utf-8'))
    lua=runtime(False);lua.execute('''
local c,letters=AuctionPerfHistory(1,'varied');local t=E.API.Now();E.History.Wallet(c,t,1000,'certificate')
local P=E.AuctionPreparation;local j=P.Start(c,{kind='invoice',record=letters[1].id})
assert(not j.audit.walletTracked and not E.AuctionWalletReads.Certified())
for n=1,10000 do P.Step(j,1);if not j.audit.snapshotOpen then break end end
assert(not j.audit.snapshotOpen);E.History.Wallet(c,t+5,1000,'certificate');assert(not P.HistoryValid(j))
print('PASS unreviewed reader-source certificate uses strict post-seal invalidation')
''')
