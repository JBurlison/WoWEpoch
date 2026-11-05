"""Locale contracts and real-TOC UI navigation in fresh, bounded Lua 5.1 VMs."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
CASES={'enUS':'enUS','enGB':'enUS','deDE':'deDE','frFR':'frFR','itIT':'itIT','esES':'esES',
       'esMX':'esES','ptBR':'ptBR','ruRU':'ruRU','koKR':'koKR','zhCN':'zhCN','zhTW':'zhTW','unknown':'enUS'}

def main():
    catalogs={}
    for raw,expected in CASES.items():
        vm=LuaRuntime(unpack_returned_tuples=True)
        vm.globals().TEST_LOCALE=raw
        vm.execute("E={};time=os.time;date=os.date;GetLocale=function()return TEST_LOCALE end;STANDARD_TEXT_FONT='client-native-font'")
        def test(name): vm.execute((ROOT/'tests'/name).read_text(encoding='utf8'),name=name)
        for name in (ROOT/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
            if not name or name.startswith('#'):continue
            if name=='Book.lua':
                test('core_spec.lua');test('wow_mock.lua')
            vm.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(ROOT/'MyEpoch'/name).read_text(encoding='utf8'),name)
        assert vm.globals().E.locale==expected
        for name in ('craft_projection_test_support.lua','sidebar_test_support.lua','integration_spec.lua'):
            test(name)
        for name in ('localization_spec.lua','display_localization_spec.lua','company_localization_spec.lua',
                     'archive_localization_spec.lua','adventure_localization_spec.lua',
                     'quest_localization_spec.lua','memory_localization_spec.lua',
                     'search_localization_spec.lua','pull_localization_spec.lua',
                     'economy_localization_spec.lua','diary_presentation_localization_spec.lua'):
            vm.execute('local s,n=...; E.TestProjection.WithFrames(function()assert(loadstring(s,"@"..n))()end)',(ROOT/'tests'/name).read_text(encoding='utf8'),name)
        catalog=dict(vm.globals().E.L.items())
        if expected!='enUS':catalogs[expected]=set(catalog)
        print('PASS locale',raw,'->',expected)
    assert len(catalogs)==9 and len({frozenset(keys) for keys in catalogs.values()})==1
    print('PASS nine matching catalogs:',len(next(iter(catalogs.values()))),'messages each; aliases, fallback, placeholders, plurals, UI actions and saved text')

if __name__=='__main__':main()
