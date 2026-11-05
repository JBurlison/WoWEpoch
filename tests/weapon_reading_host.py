"""Run the weapon skill fixtures with their own fake player and client globals."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
tests = ROOT / "tests"
def run(spec):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("E={};time=os.time;date=os.date")
    def execute(path, source=False):
        code = 'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)' if source else 'local s,n=...;assert(loadstring(s,"@"..n))()'
        lua.execute(code, path.read_text(encoding="utf-8"), path.name)
    for name in (ROOT / "MyEpoch/MyEpoch.toc").read_text(encoding="utf-8").splitlines():
        if name and not name.startswith("#"):
            if name == "Book.lua":
                execute(tests / "core_spec.lua")
                execute(tests / "wow_mock.lua")
            execute(ROOT / "MyEpoch" / name, source=True)
    for name in ("craft_projection_test_support.lua", "sidebar_test_support.lua", "integration_spec.lua"):
        execute(tests / name)
    lua.execute('local s,n=...;E.TestProjection.WithFrames(function()assert(loadstring(s,"@"..n))()end)',(tests / spec).read_text(encoding="utf-8"),spec)

for filename in ("weapon_reading_spec.lua", "weapon_reading_guards_spec.lua"):
    run(filename)
