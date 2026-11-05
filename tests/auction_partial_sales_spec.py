"""Exercise the addon's actual auction and mailbox collectors in an isolated Lua 5.1 VM."""
import argparse
from pathlib import Path

from lupa.lua51 import LuaRuntime


def run(project=None, overlay=None, review=None):
    test_dir = Path(__file__).resolve().parent
    project = Path(project) if project else test_dir.parent
    addon_dir = project / "MyEpoch"
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("E={};time=os.time;date=os.date")
    for entry in (addon_dir / "MyEpoch.toc").read_text(encoding="utf-8").splitlines():
        if not entry or entry.startswith("#"):
            continue
        if entry == "Book.lua":
            lua.execute((project / "tests/wow_mock.lua").read_text(encoding="utf-8"))
        path = addon_dir / entry
        if overlay and (Path(overlay) / entry).is_file():
            path = Path(overlay) / entry
        lua.execute('assert(loadstring(...))("MyEpoch",E)', path.read_text(encoding="utf-8"))
    lua.execute('E.Store.Open();MyEpochDB=E.db;E.runtime={interface=16001};'
                'E.current=E.Store.Character("partial-sales-host",{})')
    for helper in ("craft_projection_test_support.lua", "sidebar_test_support.lua"):
        lua.execute((project / "tests" / helper).read_text(encoding="utf-8"))
    lua.execute("E.Book.Open();TEST_PREPARE_BOOK()")
    def with_frames(path):
        lua.execute("local s=...; E.TestProjection.WithFrames(function() assert(loadstring(s))() end)",
                    path.read_text(encoding="utf-8"))
    with_frames(test_dir / "auction_partial_sales_spec.lua")
    if review:
        lua.execute('assert(loadstring(...))("MyEpoch",E)', Path(review).read_text(encoding="utf-8"))
        with_frames(Path(review).parent / "review_sale_ui_spec.lua")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path)
    parser.add_argument("--overlay", type=Path)
    parser.add_argument("--review", type=Path)
    args = parser.parse_args()
    run(args.project, args.overlay, args.review)
