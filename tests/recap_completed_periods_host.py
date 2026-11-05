from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
saved=None
for phase in ('record','dayframes','repeat','dayfinish','late','retained'):
    v=LuaRuntime(unpack_returned_tuples=True)
    v.execute('E={};time=os.time;date=os.date')
    for name in (root/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
        if not name or name.startswith('#'):continue
        if name=='Book.lua':v.execute((root/'tests/wow_mock.lua').read_text(encoding='utf8'))
        v.execute('assert(loadstring(...))("MyEpoch",E)',(root/'MyEpoch'/name).read_text(encoding='utf8'))
    if saved:v.execute(saved)
    v.globals().CASE='day'if phase=='dayframes'else phase
    v.globals().NORMAL_FRAMES=phase=='dayframes'
    v.execute((root/'tests/recap_completed_periods_spec.lua').read_text(encoding='utf8'))
    saved=v.execute("""local function enc(v)
        if type(v)=='table'then local t={};for k,x in pairs(v)do t[#t+1]='['..enc(k)..']='..enc(x)end;return '{'..table.concat(t,',')..'}'end
        if type(v)=='string'then return string.format('%q',v)end;return tostring(v)
    end;return 'MyEpochDB='..enc(MyEpochDB)""")
