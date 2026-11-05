"""Replay both independent race probes on the complete staged TOC in fresh VMs."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime
here=Path(__file__).resolve().parent;stage=here.parent
samples={"frontier": ["negative", "negativeInfinity", "positiveInfinity", "notANumber", "firstMembership", "partialStart", "tooLarge", "fractional", "below", "equal", "above", "orphan", "noEnd", "legacy", "stringEnd", "invalidStart", "unknownKill", "newAtFrontier", "extendAtFrontier"], "interleavings": ["neutral", "star", "link", "financial", "note", "replace", "otherCleanup", "queue", "questInterval", "nested", "commitLink", "commitQueue"]}
modules=[]
for n in (stage/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
    if n.endswith('.lua'):
        if n=='Book.lua':modules.append((None,(stage/'tests/wow_mock.lua').read_bytes()))
        modules.append((n,(stage/'MyEpoch'/n).read_bytes()))
results={}
for family,cases in samples.items():
    results[family]={}
    for case in cases:
        v=LuaRuntime(unpack_returned_tuples=True);v.globals().CASE=case
        v.execute('E={};time=os.time;date=os.date')
        for name,source in modules:
            if name:v.execute('local s,n=...;assert(loadstring(s,n))("MyEpoch",E)',source,name)
            else:v.execute(source)
        results[family][case]=dict(v.execute((here/('automatic_retention_'+family+'_spec.lua')).read_bytes()).items())
    print('PASS',family,len(cases),flush=True)
