"""Run the packaged capture recovery source in fresh Lua 5.1 hosts. Synthetic data only."""
from pathlib import Path
import time
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def host(root):
  v=LuaRuntime(unpack_returned_tuples=True);v.execute('E={};time=os.time;date=os.date')
  for n in (root/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
   if n.endswith('.lua'):
    if n=='Book.lua':v.execute((root/'tests/wow_mock.lua').read_bytes())
    v.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(root/'MyEpoch'/n).read_bytes(),n)
  return v
def run(root=ROOT):
 spec=(root/'tests/capture_recovery_spec.lua').read_bytes()
 for mode in ('empty','sparse','dense','lifecycle','retention','reentry','error','corruptClock','fresh'):
  v=host(root)
  v.execute("E.frame.scripts.OnEvent(E.frame,'ADDON_LOADED','MyEpoch');assert(E.db)")
  v.globals().MODE=mode;v.globals().NEW=True;v.globals().CLOCK=time.perf_counter
  r=v.execute(spec)
  if mode=='fresh':
   # Separate host, ordinary raw SavedVariables shape + real boot entry points.
   fresh=host(root)
   fresh.execute(r);fresh.execute("""local f=E.frame;f.scripts.OnEvent(f,'ADDON_LOADED','MyEpoch');f.scripts.OnEvent(f,'PLAYER_LOGIN')
   local c=E.current;assert(c.records['actual-player:1'].status=='pending')
   for i=1,1200 do f.scripts.OnUpdate(f,.01);if c.records['actual-player:1'].status=='unconfirmed'then break end end
   assert(c.records['actual-player:1'].status=='unconfirmed' and c.records['actual-player:2'].status=='failed')""")
  print('PASS capture recovery:', mode)
if __name__=='__main__':run()
