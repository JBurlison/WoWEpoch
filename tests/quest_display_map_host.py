"""Run 221 quest display-map capture and real book source navigation in two fresh Lua VMs."""
from pathlib import Path
from tempfile import TemporaryDirectory
from argparse import ArgumentParser
from lupa.lua51 import LuaRuntime
tests=Path(__file__).resolve().parent
p=ArgumentParser();p.add_argument('--addon',type=Path,default=tests.parent/'MyEpoch');p.add_argument('--overlay',type=Path);p.add_argument('--fixtures',type=Path,default=tests)
args=p.parse_args()
def vm():
 v=LuaRuntime(encoding=None,unpack_returned_tuples=True);v.execute(b'E={};time=os.time;date=os.date')
 for name in (args.addon/'MyEpoch.toc').read_text(encoding='utf8').splitlines():
  if not name.endswith('.lua'):continue
  if name=='Book.lua':v.execute((args.fixtures/'wow_mock.lua').read_bytes())
  path=args.overlay/name if args.overlay and (args.overlay/name).is_file() else args.addon/name
  v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',path.read_bytes(),name.encode())
 v.execute((tests/'sidebar_test_support.lua').read_bytes())
 return v
with TemporaryDirectory(prefix='myepoch-quest-map-')as scratch:
 f=Path(scratch)/'MyEpoch.lua'
 for mode in ('capture','offline'):
  v=vm();v.globals().MODE=mode.encode();v.globals().SAVED=str(f).encode()
  if mode=='offline':v.execute(b'assert(loadfile(SAVED))()')
  v.execute(b'local s,n=...;assert(loadstring(s,"@"..n))()', (tests/'quest_display_map_spec.lua').read_bytes(),b'quest_display_map_spec')
 print('PASS registered quest display maps, capture guards, separate physical evidence, compiled save/offline book, source selection and occurrence paging.')
