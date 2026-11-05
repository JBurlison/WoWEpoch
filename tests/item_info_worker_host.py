from pathlib import Path
import time
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def fresh():
    vm=LuaRuntime(unpack_returned_tuples=True);vm.execute("E={};time=os.time;date=os.date")
    for name in (ROOT/"MyEpoch/MyEpoch.toc").read_text(encoding="utf8").splitlines():
        if not name or name.startswith("#"):continue
        if name=="Book.lua":vm.execute((ROOT/"tests/wow_mock.lua").read_bytes())
        vm.execute('local source,n=...;assert(loadstring(source,"@"..n))("MyEpoch",E)',(ROOT/"MyEpoch"/name).read_bytes(),name)
    vm.execute("E.frame.scripts.OnEvent(E.frame,'ADDON_LOADED','MyEpoch');assert(E.db)")
    return vm
for case in ('scale','mixed','churn','retention','switch','nested','bad','edits','pressure'):
    vm=fresh();vm.globals().CASE=case;vm.globals().HOST_NOW=time.perf_counter
    result=vm.execute((ROOT/'tests/item_info_worker_spec.lua').read_bytes(),name='item_info_worker_spec.lua')
    print('PASS item-information case',case,result)
