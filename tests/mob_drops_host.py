"""Pure report regressions on the actual addon store and source records."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def run():
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute('E={};time=os.time;date=os.date')
    for name in (ROOT/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
        if not name.endswith('.lua'):
            continue
        if name == 'Book.lua':
            vm.execute((ROOT/'tests/wow_mock.lua').read_text(encoding='utf8'))
        vm.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(ROOT/'MyEpoch'/name).read_text(encoding='utf8'),name)
    if not vm.eval('E.MobDrops~=nil'):
        vm.execute('assert(loadstring(...))("MyEpoch",E)',(ROOT/'MyEpoch/MobDrops.lua').read_text(encoding='utf8'))
    vm.execute('E.Store.Open()')
    vm.execute((ROOT/'tests/mob_drops_spec.lua').read_text(encoding='utf8'),name='mob_drops_spec.lua')

if __name__ == '__main__':
    run()
