"""The private recap policy must depend on the actual source declaration."""
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess,sys,shutil,runpy,re
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
generator=ROOT/'tools/build_craft_projection_readers.py';instrument=ROOT/'tools/build_auction_readers.py'
build=runpy.run_path(str(generator))['build']
with TemporaryDirectory(prefix='myepoch-projection-generator-')as temporary:
    folder=Path(temporary)
    for name in ('Production.lua','Items.lua','RecapView.lua','CraftProjectionReaders.lua'):shutil.copy2(ROOT/'MyEpoch'/name,folder/name)
    command=[sys.executable,'-B',str(generator),'--source',str(folder),'--output',str(folder/'CraftProjectionReaders.lua'),'--instrument',str(instrument)]
    assert subprocess.run(command+['--check'],capture_output=True,text=True).returncode==0
    original=(folder/'RecapView.lua').read_text(encoding='utf-8')
    literal='local eligible={level=true,skill=true,profession=true}'
    assert original.count(literal)==1
    changed=original.replace(literal,'local eligible={level=true,skill=false,profession=true}')
    (folder/'RecapView.lua').write_text(changed,encoding='utf-8')
    assert subprocess.run(command+['--check'],capture_output=True,text=True).returncode!=0,'changing only eligible must invalidate the generated reader'
    subprocess.run(command,capture_output=True,text=True,check=True)
    subprocess.run(command+['--check'],capture_output=True,text=True,check=True)
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('E={Store={}}')
    lua.execute('assert(loadstring(...))("MyEpoch",E)',(folder/'CraftProjectionReaders.lua').read_text(encoding='utf-8'))
    lua.execute('for _,f in ipairs(E.CraftProjectionReaderFactories)do if f.name=="ProjectionRecaps"then f.create(E)end end')
    declaration=re.findall(r'^local eligible=.*$',changed,re.M)[0]
    allowed=changed[changed.index('function V.Allowed'):changed.index('function V.Sources')]
    lua.execute('local V={};'+declaration+'\n'+allowed+'\nPUBLIC_ALLOWED=V.Allowed')
    lua.execute('''local c={id='owner'}
      for _,kind in ipairs({'level','skill','profession','achievement'})do
       local r={kind='milestone',subject=c.id,milestoneType=kind}
       assert(not not PUBLIC_ALLOWED(c,r)==not not E.ProjectionRecaps.Allowed(c,r))
      end
      assert(not E.ProjectionRecaps.Allowed(c,{kind='milestone',subject=c.id,milestoneType='skill'}))''')
    for replacement in ('local eligible=UNKNOWN_POLICY',literal+'\n'+literal,'-- eligible declaration missing'):
        (folder/'RecapView.lua').write_text(original.replace(literal,replacement),encoding='utf-8')
        try:build(folder,instrument)
        except AssertionError:pass
        else:raise AssertionError('unsupported or ambiguous policy must fail closed')
print('PASS projection generator: eligible-only change fails CLI freshness, regenerated private/public policy agrees, missing/dynamic/duplicate declarations fail closed')
