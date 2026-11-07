"""Run every shared-UI case in a fresh VM with the complete production TOC.

Case order and preceding data fixtures come from run.py. Explicit prerequisite
specs below build the long crafting archive used by its dependent budget tests;
they run with all assertions enabled. Other specs cannot leak API mocks or
navigation state between cases. Cold-work tests never use the settled wrapper.
"""
import argparse
import ast
from pathlib import Path
import time
import traceback

from lupa.lua51 import LuaRuntime


EXTRA = {
    "minimap_spec.lua", "book_header_spec.lua", "art_dialog_spec.lua",
    "milestone_art_dialog_spec.lua", "characters_spec.lua", "ledger_style_spec.lua",
    "bookmark_preparation_spec.lua", "craft_profession_projection_spec.lua",
    "craft_projection_touch_spec.lua", "craft_projection_preparation_spec.lua",
    "craft_projection_dense_spec.lua", "craft_projection_polling_spec.lua",
}
PREREQUISITES = {
    "craft_projection_touch_spec.lua": ("craft_profession_projection_spec.lua",),
    "craft_projection_preparation_spec.lua": ("craft_profession_projection_spec.lua",),
    "craft_projection_dense_spec.lua": ("craft_profession_projection_spec.lua",),
    "craft_projection_polling_spec.lua": (
        "craft_profession_projection_spec.lua", "craft_projection_dense_spec.lua",
    ),
}


def cases_from_runner(root):
    path = root / "tests/run.py"
    source = path.read_text(encoding="utf-8")
    fixtures, cases = [], []
    for statement in ast.parse(source).body:
        if not isinstance(statement, ast.Expr):
            continue
        text = ast.get_source_segment(source, statement)
        if "lua.execute" in text and "tests/fixtures/" in text:
            fixtures.append(statement)
        if not isinstance(statement.value, ast.Call):
            continue
        call = statement.value
        name = None
        if isinstance(call.func, ast.Name) and call.func.id == "settled_ui":
            name = call.args[0].value
        else:
            for node in ast.walk(statement):
                if isinstance(node, ast.Constant) and isinstance(node.value, str):
                    filename = node.value.removeprefix("tests/")
                    if filename in EXTRA:
                        name = filename
        if name:
            cases.append((name, list(fixtures)))
    return cases


def ready(root):
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.execute("E={};time=os.time;date=os.date")

    def test(name):
        vm.execute((root / "tests" / name).read_text(encoding="utf-8"), name=name)

    for module in (root / "MyEpoch/MyEpoch.toc").read_text(encoding="utf-8").splitlines():
        if not module or module.startswith("#"):
            continue
        if module == "Book.lua":
            test("core_spec.lua")
            test("wow_mock.lua")
        vm.execute(
            'local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',
            (root / "MyEpoch" / module).read_text(encoding="utf-8"), module,
        )
    for name in ("craft_projection_test_support.lua", "sidebar_test_support.lua", "integration_spec.lua"):
        test(name)
    vm.execute("MyEpochDB=E.db")
    return vm


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--spec", action="append", help="Run only this filename; repeat for several cases")
    parser.add_argument("--list", action="store_true", help="List available case filenames")
    args = parser.parse_args()
    root = args.root.resolve()
    cases = cases_from_runner(root)
    available = {name for name, _ in cases}
    if not cases:
        parser.error("No shared-UI cases found in tests/run.py")
    missing = set(args.spec or ()) - available
    if missing:
        parser.error("Unknown shared-UI specs: " + ", ".join(sorted(missing)))
    if args.spec:
        cases = [(name, prior) for name, prior in cases if name in args.spec]
    if args.list:
        print("\n".join(name for name, _ in cases))
        return 0

    started, failures, passed = time.monotonic(), [], 0
    for name, prior in cases:
        print(f"SHARED UI START {name} fixtures={len(prior)}", flush=True)
        try:
            vm = ready(root)
            scope = {"ROOT": root, "lua": vm}
            for statement in prior:
                exec(compile(ast.Module(body=[statement], type_ignores=[]), str(root / "tests/run.py"), "exec"), scope)
            for prerequisite in PREREQUISITES.get(name, ()):
                vm.execute((root / "tests" / prerequisite).read_text(encoding="utf-8"), name=prerequisite)
            source = (root / "tests" / name).read_text(encoding="utf-8")
            cold = name == "bookmark_preparation_spec.lua" or name.startswith("craft_projection_") or name == "craft_profession_projection_spec.lua"
            if cold:
                vm.execute(source, name=name)
            else:
                vm.execute('local s,n=...;E.TestProjection.WithFrames(function()assert(loadstring(s,"@"..n))()end)', source, name)
            passed += 1
            print(f"SHARED UI PASS {name}", flush=True)
        except Exception as error:
            failures.append((name, str(error)))
            print(f"SHARED UI FAIL {name}: {error}", flush=True)
            traceback.print_exc()
    print(f"SHARED UI FINISHED total={len(cases)} passed={passed} failed={len(failures)} seconds={time.monotonic() - started:.1f}", flush=True)
    for name, error in failures:
        print(f"SHARED UI FAILURE SUMMARY {name}: {error}", flush=True)
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
