"""Selective focus-key host checks; not client security or hardware evidence."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def main():
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute((ROOT / 'tests/controller_focus_spec.lua').read_text(encoding='utf-8'))
    vm.execute('assert(loadstring(...))("MyEpoch",E)',
               (ROOT / 'MyEpoch/ControllerFocus.lua').read_text(encoding='utf-8'))
    vm.execute('TEST_CONTROLLER_FOCUS()')


if __name__ == '__main__':
    main()
