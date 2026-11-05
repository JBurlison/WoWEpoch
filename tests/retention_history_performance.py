"""Isolated Lua 5.1 retention benchmark; instruction counts are host-only guards."""
import argparse
import json
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def measure(store_path, enforce=True):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={};')
    for path in (ROOT / 'MyEpoch/Core.lua', store_path):
        lua.execute('assert(loadstring(...))("MyEpoch",E)', path.read_text(encoding='utf-8'))
    lua.execute('E.API={Now=function()return 10000000 end}; E.Store.Open()')
    rows = []
    for mode in ('forever', 'retained_quests', 'starred_quests'):
        row = lua.execute('''
          local mode=...; local S=E.Store
          local c=S.Character(mode,{});local now=10000000
          local function add(kind,ts,extra)
            c.seq=c.seq+1;local id=c.id..':'..c.seq;local r=extra or{}
            r.character=c.id;r.id=id;r.sequence=c.seq;r.kind=kind;r.category=S.categories[kind];r.ts=ts
            c.records[id]=r;c.order[#c.order+1]=id;return r
          end
          for i=1,10000 do add('kill',i,{npcID=i%19})end
          for i=1,1000 do add('quest_attempt',1,{ended=10002,
            starred=mode=='starred_quests',intervals={{from=1,through=10001},{from=50,through=9000}}})end
          local chat=add('chat',1,{text='Unlinked expired conversation'})
          if mode~='forever'then c.retention.questKills=1;c.retention.chat=1 end
          collectgarbage('collect');local memory=collectgarbage('count')
          local instructions=0;debug.sethook(function()instructions=instructions+1000 end,'',1000)
          local start=os.clock();local p=S.PreviewExpiry(c,now);local ms=(os.clock()-start)*1000
          debug.sethook()
          assert(p.count==(mode=='forever'and 0 or 1)and (mode=='forever'or p.ids[chat.id]))
          for _,id in ipairs(c.order)do if c.records[id].kind=='kill'then assert(not p.ids[id])end end
          return {mode=mode,records=#c.order,milliseconds=ms,instructions=instructions,
            heap_delta_kib=collectgarbage('count')-memory,eligible=p.count}
        ''', mode)
        row = dict(row.items())
        if enforce:
            assert row['instructions'] < 12_000_000, f'Repeated overlapping-quest work: {row}'
            if mode == 'forever':
                assert row['instructions'] < 100_000, f'Forever preview traversed history: {row}'
        rows.append(row)
    return rows

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--store', type=Path, default=ROOT / 'MyEpoch/Store.lua')
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = measure(args.store, not args.baseline)
    report = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(report+'\n', encoding='utf-8')
    print(report)
