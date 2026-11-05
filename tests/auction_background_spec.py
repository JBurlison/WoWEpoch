"""Exercise the actual auction/mail UI using only checked-in addon and fixtures."""
from pathlib import Path
import runpy
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
generator=runpy.run_path(str(ROOT/'tools/build_auction_readers.py'))
expected,hashes,counts=generator['build'](ROOT/'MyEpoch')
assert (ROOT/'MyEpoch/AuctionReaders.lua').read_text(encoding='utf-8')==expected,'Private auction readers are stale; regenerate before packaging.'
print(f'PASS private reader freshness: {len(hashes)} modules / {sum(counts.values())} loop checkpoints')
def runtime():
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={};time=os.time;date=os.date')
    for line in (ROOT/'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):continue
        path=ROOT/'MyEpoch'/line.replace(chr(92),'/')
        if path.name=='Book.lua':lua.execute((ROOT/'tests/wow_mock.lua').read_text(encoding='utf-8'))
        lua.execute('assert(loadstring(...))("MyEpoch",E)',path.read_text(encoding='utf-8'))
    lua.execute('E.Store.Open(nil);E.current=E.Store.Character("background-test-controller",{name="TEST"});EXPECT_GATE=true;EXPECT_REFS=true')
    lua.execute((ROOT/'tests/fixtures/auction_history_performance.lua').read_text(encoding='utf-8'))
    return lua
for name in ['mail','sent_refs','pages','metadata','inventory','modal']:
    lua=runtime()
    spec=(ROOT/f'tests/auction_background_{name}_spec.lua').read_text(encoding='utf-8')
    if name=='sent_refs':spec=(ROOT/'tests/sent_mail_costs_spec.lua').read_text(encoding='utf-8').split("for _,staging in ipairs({true,false})do")[0]+'\n'+spec
    lua.execute(spec)
