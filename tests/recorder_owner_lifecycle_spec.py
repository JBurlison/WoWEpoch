"""Execute a real TOC in five independent Lua VMs, persisting SavedVariables between logins."""
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime
here=Path(__file__).resolve().parent
target=Path(sys.argv[1] if len(sys.argv)>1 else '.').resolve()
snapshot='nil'
for phase in ('seed','cutoff','logout','logout_then_switch','reload'):
    vm=LuaRuntime(unpack_returned_tuples=True)
    vm.execute('E={};time=os.time;date=os.date')
    for line in (target/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
        if not line or line.startswith('#'):continue
        if line=='Book.lua':
            vm.execute((target/'tests/wow_mock.lua').read_bytes())
        vm.execute('local src,name=...;assert(loadstring(src,"@"..name))("MyEpoch",E)',(target/'MyEpoch'/line).read_bytes(),line)
    vm.execute('MyEpochDB='+snapshot)
    vm.globals().TEST_OWNER_PHASE=phase
    vm.execute((here/'recorder_owner_lifecycle_spec.lua').read_bytes())
    if phase.startswith("logout"):continue # Independent logout-only fork; preserve the verified automatic session from cutoff.
    snapshot=vm.eval('function(v) local function encode(x) if type(x)=="table" then local t={} for k,y in pairs(x) do t[#t+1]="["..encode(k).."]="..encode(y) end;return "{"..table.concat(t,",").."}" elseif type(x)=="string" then return string.format("%q",x) elseif type(x)=="number" or type(x)=="boolean" then return tostring(x) end;error("non saved data") end;return encode(v) end')(vm.globals().MyEpochDB)
print('PASS real login, unavailable/restricted recovery, readable owner change, pending screenshot, logout and real SavedVariables reload')
