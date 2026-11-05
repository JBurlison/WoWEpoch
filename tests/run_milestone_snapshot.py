"""Exercise snapshot capture and rendering in separate Lua 5.1 runtimes."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
files = [ROOT / 'MyEpoch' / line.replace('\\', '/')
         for line in (ROOT / 'MyEpoch/MyEpoch.toc').read_text().splitlines()
         if line and not line.startswith('#')]
ui_start = next(i for i, path in enumerate(files) if path.name == 'Book.lua')

for spec in ('milestone_snapshot_spec.lua', 'milestone_snapshot_view_spec.lua'):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={};time=os.time;date=os.date')
    for path in files[:ui_start]:
        lua.execute('assert(loadstring(...))("MyEpoch",E)', path.read_text(encoding='utf-8'))
    for name in ('core_spec.lua', 'wow_mock.lua'):
        lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
    for path in files[ui_start:]:
        lua.execute('assert(loadstring(...))("MyEpoch",E)', path.read_text(encoding='utf-8'))
    if spec == 'milestone_snapshot_view_spec.lua':
        for name in ('craft_projection_test_support.lua', 'sidebar_test_support.lua', 'integration_spec.lua'):
            lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
        lua.execute('SlashCmdList.MYEPOCH("stats")')
    lua.execute((ROOT / 'tests' / spec).read_text(encoding='utf-8'))
