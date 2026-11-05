"""Exercise actual saved recap controls in fresh Lua 5.1 addon instances."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
for name in ("recap_navigation_spec.lua", "recap_badge_spec.lua", "recap_view_spec.lua"):
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
    if name=="recap_view_spec.lua":test("fixtures/uiforever-recaps.lua")
    vm.execute('local s,n=...; E.TestProjection.WithFrames(function()assert(loadstring(s,"@"..n))()end)',(ROOT/"tests"/name).read_text(encoding="utf8"),name)
