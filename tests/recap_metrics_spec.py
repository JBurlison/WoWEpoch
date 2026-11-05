from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
read = lambda name: (ROOT/name).read_text(encoding='utf-8-sig')
lua.execute('E={};time=os.time;date=os.date')
for name in read('MyEpoch/MyEpoch.toc').splitlines():
    if not name or name.startswith('#'): continue
    if name == 'Book.lua': lua.execute(read('tests/wow_mock.lua'))
    lua.execute('assert(loadstring(...))("MyEpoch",E)',read('MyEpoch/'+name))
lua.execute('E.Store.Open();MyEpochDB=E.db')
lua.execute(read('tests/recap_metrics_spec.lua'))
lua.execute(read('tests/recap_activity_spec.lua'))
