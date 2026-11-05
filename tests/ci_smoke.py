"""Small, fixed CI gate; exhaustive/stress regressions remain in tests/run.py."""
from pathlib import Path
from time import perf_counter
import subprocess
import sys
from xml.etree import ElementTree

from lupa.lua51 import LuaRuntime
from quest_zone_entry_host import run

ROOT = Path(__file__).resolve().parents[1]

# Each spec loads the complete production TOC in a fresh Lua 5.1 VM and runs
# core_spec + integration_spec first (character isolation, startup and UI).
# Keep this list deliberately small; do not auto-discover the stress suite.
SPECS = (
    'calendar_tabs_spec.lua',
    'finance_view_spec.lua',
    'economy_spec.lua',
    'inventory_spec.lua',
    'production_spec.lua',
    'company_spec.lua',
    'retention_controls_spec.lua',
)
HOSTS = (
    'localization_host.py',
    'quest_completed_history_host.py',
    'recap_completed_periods_host.py',
    'recorder_owner_lifecycle_spec.py',
)


def main():
    started = perf_counter()
    bindings = ElementTree.parse(ROOT / 'MyEpoch/Bindings.xml').getroot()
    assert bindings.tag == 'Bindings'
    lua = LuaRuntime()
    for binding in bindings:
        assert binding.tag == 'Binding' and not binding.get('default')
        assert binding.get('name') == 'MYEPOCH_CAPTURE'
        lua.execute('assert(loadstring(...))', binding.text)
    for name in SPECS:
        before = perf_counter()
        run((name,))
        print(f'SMOKE {name}: {perf_counter() - before:.2f}s', flush=True)
    for name in HOSTS:
        before = perf_counter()
        subprocess.run([sys.executable, '-B', '-X', 'utf8', str(ROOT / 'tests' / name)],
                       cwd=ROOT, check=True, timeout=60)
        print(f'SMOKE {name}: {perf_counter() - before:.2f}s', flush=True)
    print(f'PASS CI smoke suite: {perf_counter() - started:.2f}s', flush=True)


if __name__ == '__main__':
    main()
