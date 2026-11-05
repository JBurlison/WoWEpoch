"""Run record illustration regressions in independent Lua 5.1 addon instances."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
NAMES = ('recap_art_spec.lua', 'milestone_art_spec.lua', 'milestone_default_art_spec.lua',
         'milestone_art_dialog_spec.lua', 'character_level_art_spec.lua', 'memory_art_spec.lua',
         'art_dialog_spec.lua', 'art_location_alias_spec.lua', 'physical_instance_art_spec.lua')
failures = []
for name in NAMES:
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute('E={};time=os.time;date=os.date')
    def test(path):
        vm.execute((ROOT/'tests'/path).read_text(encoding='utf8'), name=path)
    for module in (ROOT/'MyEpoch/MyEpoch.toc').read_text().splitlines():
        if not module or module.startswith('#'): continue
        if module == 'Book.lua':
            test('core_spec.lua'); test('wow_mock.lua')
        vm.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',
                   (ROOT/'MyEpoch'/module).read_text(encoding='utf8'), module)
    for support in ('craft_projection_test_support.lua', 'sidebar_test_support.lua', 'integration_spec.lua'):
        test(support)
    try:
        vm.execute('local s,n=...;E.TestProjection.WithFrames(function()assert(loadstring(s,"@"..n))()end)',
                   (ROOT/'tests'/name).read_text(encoding='utf8'), name)
    except Exception as error:
        failures.append(name); print('FAIL', name, str(error), flush=True)
if failures: raise SystemExit('Failed: ' + ', '.join(failures))
