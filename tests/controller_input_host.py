"""Isolated input ownership tests; no simulated controller result is hardware evidence."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def main():
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute((ROOT / 'tests/controller_input_spec.lua').read_text(encoding='utf8'))
    vm.execute('assert(loadstring(...))("MyEpoch", E)',
               (ROOT / 'MyEpoch/Controller.lua').read_text(encoding='utf8'))
    vm.execute('TEST_CONTROLLER_INPUT()')
    print('PASS controller input ownership, three layouts, held input, combat, overlays and lifecycle')


if __name__ == '__main__':
    main()
