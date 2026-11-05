"""Exercise stable roster identities, click targets, maximum-raid bounds and a saved-group reload."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
def start(archive=None):
    vm=LuaRuntime(unpack_returned_tuples=True);vm.execute("E={};time=os.time;date=os.date")
    for n in (ROOT/"MyEpoch/MyEpoch.toc").read_text(encoding="utf8").splitlines():
        if not n or n.startswith("#"):continue
        if n=="Book.lua":vm.execute((ROOT/"tests/wow_mock.lua").read_bytes())
        vm.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(ROOT/"MyEpoch"/n).read_bytes(),n)
    if archive:vm.execute(archive)
    vm.execute("E.frame.scripts.OnEvent(E.frame,'ADDON_LOADED','MyEpoch');assert(E.db)")
    return vm
def run(v,mode):
    return v.execute((ROOT/'tests/group_roster_race.lua').read_bytes())(mode)
v=start();assert run(v,'new')
v=start();original=run(v,'save')
raw=v.execute("""local function raw(t) if type(t)=='string' then return string.format('%q',t) elseif type(t)~='table' then return tostring(t) end
 local a={'{'};for k,v in pairs(t) do a[#a+1]='['..raw(k)..']='..raw(v)..','end;a[#a+1]='}';return table.concat(a) end;return 'MyEpochDB='..raw(E.db)""")
v=start(raw);v.globals().ORIGINAL_GROUP=original;v.globals().SESSION='roster206-second';assert run(v,'reload')
v=start();assert v.execute((ROOT/'tests/roster_bounds.lua').read_bytes())()==82
print('PASS stable party identities, stale whisper-target refusal, fresh VM continuity and a bounded 40-player scan')

start().execute((ROOT / 'tests/group_leave_spec.lua').read_bytes(), name='group_leave_spec.lua')

start().execute((ROOT / 'tests/recorder_recovery_spec.lua').read_bytes(), name='recorder_recovery_spec.lua')
