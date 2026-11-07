"""Controller integration in real-TOC Lua 5.1 VMs; no hardware/security emulation."""
from pathlib import Path
import argparse
from time import perf_counter
import subprocess
import sys

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def run(spec='controller_coverage_spec.lua', locale='enUS'):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.globals().TEST_CONTROLLER_LOCALE = locale
    vm.execute("E={};time=os.time;date=os.date;GetLocale=function()return TEST_CONTROLLER_LOCALE end")

    def execute(path):
        vm.execute(path.read_text(encoding='utf-8'), name=path.name)

    for module in (ROOT / 'MyEpoch/MyEpoch.toc').read_text(encoding='utf-8').splitlines():
        if not module or module.startswith('#'):
            continue
        if module == 'Book.lua':
            execute(ROOT / 'tests/core_spec.lua')
            execute(ROOT / 'tests/wow_mock.lua')
        vm.execute('local source,name=...;assert(loadstring(source,"@"..name))("MyEpoch",E)',
                   (ROOT / 'MyEpoch' / module).read_text(encoding='utf-8'), module)
    for name in ('craft_projection_test_support.lua', 'sidebar_test_support.lua', 'integration_spec.lua'):
        execute(ROOT / 'tests' / name)
    execute(ROOT / 'tests/controller_test_support.lua')
    vm.execute('local source,name=...;E.TestProjection.WithFrames(function()assert(loadstring(source,"@"..name))()end)',
               (ROOT / 'tests' / spec).read_text(encoding='utf-8'), spec)
    return vm


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--spec', help='Run just one real-TOC Lua spec')
    parser.add_argument('--locale', default='enUS')
    args = parser.parse_args()
    started = perf_counter()
    if args.spec:
        run(args.spec, args.locale)
    else:
        for spec in ('controller_coverage_spec.lua', 'controller_navigation_spec.lua', 'controller_text_spec.lua', 'controller_entry_spec.lua', 'controller_focus_entry_spec.lua'):
            run(spec, args.locale)
        for host in ('controller_input_host.py', 'controller_focus_host.py', 'controller_adapters_host.py', 'controller_unicode_host.py',
                     'test_controller_unicode_data.py'):
            subprocess.run([sys.executable, '-B', '-X', 'utf8', str(ROOT / 'tests' / host)],
                           cwd=ROOT, check=True)
    print(f'PASS controller host integration: {perf_counter() - started:.2f}s')


if __name__ == '__main__':
    main()
