"""A fresh full addon VM for each opened or quarantined journal."""
from pathlib import Path
import argparse
from lupa.lua51 import LuaRuntime
tests=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=tests.parent/'MyEpoch')
p.add_argument('--overlay',type=Path);p.add_argument('--support',type=Path,default=tests)
args=p.parse_args()
modes=['fresh','sparse','benign-queue','live-reopen','legacy-identity','queue-tombstone','job-epoch','job-missing','job-scalar','job-index','job-modules','job-context','job-counterpart','corrupt-record','owner-conflict','foreign-record','wrong-id',
       'record-key','aliased-owner','queue-no-index','queue-hole','nonfinite-counter','identity','seq','revision','records','order','notes','dedup','state']
for mode in modes:
    v=LuaRuntime(unpack_returned_tuples=True);v.execute('E={};time=os.time;date=os.date')
    for n in (args.source/'MyEpoch.toc').read_text(encoding='utf8').splitlines():
        if not n.endswith('.lua'):continue
        if n=='Book.lua':v.execute((args.support/'wow_mock.lua').read_bytes())
        f=args.overlay/n if args.overlay and (args.overlay/n).is_file() else args.source/n
        v.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',f.read_bytes(),n)
    v.globals().MODE=mode
    v.execute('assert(loadstring(...,"@safe-open"))()', (tests/'archive_safe_open_spec.lua').read_bytes())
    if mode=='legacy-identity':v.execute((args.support/'inventory_legacy_queue_spec.lua').read_bytes())
    print('PASS safe journal open',mode,flush=True)
