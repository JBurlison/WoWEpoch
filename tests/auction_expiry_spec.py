"""Portable raw expiry integration test; no simulator or live game actions."""
from pathlib import Path
import argparse,runpy
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--addon',type=Path,default=ROOT/'MyEpoch')
p.add_argument('--support-root',type=Path,default=ROOT)
a=p.parse_args();support=a.support_root
generated=runpy.run_path(str(support/'tools/build_auction_readers.py'))['build'](a.addon)[0]
assert (a.addon/'AuctionReaders.lua').read_text(encoding='utf-8')==generated
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute('E={};time=os.time;date=os.date')
for line in (a.addon/'MyEpoch.toc').read_text(encoding='utf-8').splitlines():
    if not line or line.startswith('#'):continue
    path=a.addon/line.replace(chr(92),'/')
    if path.name=='Book.lua':lua.execute((support/'tests/wow_mock.lua').read_text(encoding='utf-8'))
    lua.execute('assert(loadstring(...))("MyEpoch",E)',path.read_text(encoding='utf-8'))
lua.execute('E.Store.Open(nil);E.current=E.Store.Character("expiry-portable",{name="TEST"});MyEpochDB=E.db;E.Book.Build();E.Book.frame:Show()')
lua.execute((support/'tests/fixtures/auction_history_performance.lua').read_text(encoding='utf-8'))
lua.execute(Path(__file__).with_suffix('.lua').read_text(encoding='utf-8'))
print('PASS portable expiry: current TOC modules, actual Bootstrap, prepared Book, evidence and retention')
