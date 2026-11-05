"""Execute registered collector events, with SavedVariables round-tripped into a fresh Lua 5.1 VM."""
import hashlib,json,sys
from pathlib import Path
from lupa.lua51 import LuaRuntime
here=Path(__file__).resolve().parent
base=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else here.parent
saved='nil'
for phase in ('record','replay','other'):
    vm=LuaRuntime(unpack_returned_tuples=True);vm.execute('E={};time=os.time;date=os.date')
    for name in (base/'MyEpoch/MyEpoch.toc').read_text().splitlines():
        if not name or name.startswith('#'): continue
        if name=='Book.lua':vm.execute((base/'tests/wow_mock.lua').read_bytes())
        vm.execute('local s,n=...;assert(loadstring(s,n))("MyEpoch",E)',(base/'MyEpoch'/name).read_bytes(),name)
    for support in ['craft_projection_test_support.lua','sidebar_test_support.lua']:vm.execute((base/'tests'/support).read_bytes())
    vm.globals().PHASE=phase;vm.execute('MyEpochDB='+saved)
    vm.execute((here/'finance_through_sale_spec.lua').read_bytes())
    saved=vm.eval('function(v) local function code(x) if type(x)=="table" then local t={} for k,y in pairs(x)do t[#t+1]="["..code(k).."]="..code(y)end return "{"..table.concat(t,",").."}" elseif type(x)=="string" then return string.format("%q",x)else return tostring(x)end end return code(v) end')(vm.globals().MyEpochDB)
