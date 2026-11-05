"""Run the registered single-cast multicraft regression against a chosen addon source."""
import argparse
from pathlib import Path
from lupa.lua51 import LuaRuntime

here = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=here.parent / 'MyEpoch')
parser.add_argument('--mock', type=Path, default=here / 'wow_mock.lua')
args = parser.parse_args()
for mode in ['fixed', 'range', 'rivalOrder', 'ordinaryRivals', 'hiddenPrior', 'rollbackPrior', 'quietAgain']:
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute('E={}; time=os.time; date=os.date')
    vm.globals().MODE = mode
    vm.globals().EXPECT_BASE = False
    for name in (args.source / 'MyEpoch.toc').read_text().splitlines():
        if name.endswith('.lua'):
            if name == 'Book.lua':
                vm.execute(args.mock.read_bytes())
            vm.execute('local src,name=...; assert(loadstring(src,"@"..name))("MyEpoch",E)',
                       (args.source / name).read_bytes(), name)
    result = vm.execute((here / 'multicraft_output_spec.lua').read_bytes())
    print('PASS',mode,result)

