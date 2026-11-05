"""Source boundaries for the seven reviewed ATT faction branches."""
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[1]
gen=runpy.run_path(str(ROOT/'tools/build-quest-catalog.py'))
source=runpy.run_path(str(ROOT/'tools/quest_faction_start_areas.py'))
branch=source['branch'];deps=(gen['RANKS']['declarations'],gen['LiteralParser'])
assert branch('{qg=1,coord={2,3,MAP.IRONFORGE}}',False,*deps)==([('n',1)],[(1455,2,3)])
assert branch('{qgs={1},coords={[1455]={{2,3}}}}',True,*deps)==([('n',1)],[(1455,2,3)])
for compiled,text in (
    (False,'{g={qg=1,coord={2,3,MAP.IRONFORGE}}}'),
    (False,'{qg=1,coords={{2,3,MAP.IRONFORGE}},hqd={qg=2}}'),
    (False,'{qg=1,qgs={1},coord={2,3,MAP.IRONFORGE}}'),
    (False,'{qg=1,coord={2,101,MAP.IRONFORGE}}'),
    (False,'{providers={{"i",12721}},coord={2,3,MAP.IRONFORGE}}'),
    (True,'{qgs={1},coords={[1455]={{2,3},{1,2,3}}}}'),
    (True,'{qgs={1},coords={[1455]={{false,3}}}}'),
):
    try:branch(text,compiled,*deps)
    except ValueError:pass
    else:raise AssertionError('Accepted unsupported branch '+text)
facts=source['load'](ROOT,[{'questID':n,'sourceDisputes':{'mapIDs':True}} for n in (5050,7562,8151,8233,8250,8254,8417)],*deps)
assert facts[7562]['Alliance']==[{'mapID':1453,'area':'Stormwind City'},{'mapID':1455,'area':'Ironforge'}]
assert len(facts)==7 and sum(len(x) for sides in facts.values() for x in sides.values())==29
print('PASS independent authored/compiled starter and coordinate fields, nested and malformed source refusal, seven quests / 29 scoped area memberships')
