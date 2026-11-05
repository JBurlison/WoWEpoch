"""Exercise the completed Quests chapter through actual Book and frame updates."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def run():
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute('E={};time=os.time;date=os.date')
    for name in (ROOT / 'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
        if not name or name.startswith('#'):
            continue
        if name == 'Book.lua':
            vm.execute((ROOT / 'tests/wow_mock.lua').read_text(encoding='utf8'), name='wow_mock.lua')
        vm.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)', (ROOT / 'MyEpoch' / name).read_text(encoding='utf8'), name)
    vm.execute((ROOT / 'tests/craft_projection_test_support.lua').read_text(encoding='utf8'))
    vm.execute('E.frame.scripts.OnEvent(E.frame,"ADDON_LOADED","MyEpoch")')
    vm.execute('local s=...;E.TestProjection.WithFrames(function()assert(loadstring(s,"@quest_completed_history_spec.lua"))()end)',
               (ROOT / 'tests/quest_completed_history_spec.lua').read_text(encoding='utf8'))


if __name__ == '__main__':
    run()
