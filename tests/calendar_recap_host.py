"""Open recap links in Calendar after real login-driven period generation."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
saved = None
for phase in ('record', 'day', 'dayfinish', 'late'):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute('E={};time=os.time;date=os.date')
    for name in (root/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
        if not name.endswith('.lua'):
            continue
        if name == 'Book.lua':
            vm.execute((root/'tests/wow_mock.lua').read_text(encoding='utf8'))
        vm.execute('assert(loadstring(...))("MyEpoch",E)', (root/'MyEpoch'/name).read_text(encoding='utf8'))
    if saved:
        vm.execute(saved)
    vm.globals().CASE = phase
    vm.execute((root/'tests/recap_completed_periods_spec.lua').read_text(encoding='utf8'))
    if phase in ('day','late'):
        vm.execute((root/'tests/calendar_recap_spec.lua').read_text(encoding='utf8'))
    saved = vm.execute("""local function encode(v)
        if type(v)=='table' then local out={};for k,x in pairs(v)do out[#out+1]='['..encode(k)..']='..encode(x)end;return '{'..table.concat(out,',')..'}'end
        if type(v)=='string'then return string.format('%q',v)end;return tostring(v)
    end;return 'MyEpochDB='..encode(MyEpochDB)""")

