"""Fresh real-TOC VMs keep authored API readings and catalog providers local to each test."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]

def run(names=("quest_zone_entry_spec.lua","quest_zone_fresh_spec.lua")):
    for name in names:
        vm=LuaRuntime(unpack_returned_tuples=True)
        vm.execute("E={};time=os.time;date=os.date")
        def test(path):
            vm.execute((ROOT/"tests"/path).read_text(encoding="utf8"),name=path)
        for module in (ROOT/"MyEpoch/MyEpoch.toc").read_text(encoding="utf8").splitlines():
            if not module or module.startswith("#"):continue
            if module=="Book.lua":
                test("core_spec.lua")
                test("wow_mock.lua")
            vm.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',(ROOT/"MyEpoch"/module).read_text(encoding="utf8"),module)
        for support in ("craft_projection_test_support.lua","sidebar_test_support.lua","integration_spec.lua"):
            test(support)
        vm.execute('local s,n=...; E.TestProjection.WithFrames(function()assert(loadstring(s,"@"..n))()end)',(ROOT/"tests"/name).read_text(encoding="utf8"),name)
if __name__=="__main__":run()
