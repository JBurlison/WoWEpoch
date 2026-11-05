"""Each installed hook or live UI action is the first entry after changing the simulated live player."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
actions = ('SetSendMailMoney SetSendMailCOD TakeInboxMoney TakeInboxItem AutoLootMailItem SendMail DeleteInboxItem ReturnInboxItem '
           'PostItem PostCommodity CraftRecipe CraftEnchant CraftSalvage BuyMerchantItem BuybackItem RepairAllItems UseContainerItem '
           'TakeTaxiNode BuyTrainerService Capture Whisper AddFriend').split()
modules=[]
for name in (ROOT/'MyEpoch/MyEpoch.toc').read_text(encoding='utf8').splitlines():
    if name.endswith('.lua'):
        if name=='Book.lua': modules.append(('mock',(ROOT/'tests/wow_mock.lua').read_bytes()))
        modules.append((name,(ROOT/'MyEpoch'/name).read_bytes()))
case=(ROOT/'tests/recorder_hook_owner_spec.lua').read_bytes()
def start():
    v=LuaRuntime(unpack_returned_tuples=True);v.execute('E={};time=os.time;date=os.date')
    for name,src in modules:
        if name=='mock':v.execute(src)
        else:v.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)',src,name)
    v.execute("E.frame.scripts.OnEvent(E.frame,'ADDON_LOADED','MyEpoch');assert(E.db)")
    return v
def run():
    assert start().execute((ROOT/'tests/recorder_detach_spec.lua').read_bytes())
    print('PASS stored evidence, owner-bound jobs and interrupted partial pulls during financial detach',flush=True)
    for mode in ('owner','changed','secret','stale'):
        # Completed-only Quests no longer offers manual profile/catalog refresh controls.
        # Collector/session coverage remains below; these are the extant live UI actions.
        for action in ('Refresh saved sessions','Refresh available roll history'):
            assert start().execute((ROOT/'tests/recorder_refresh_owner_spec.lua').read_bytes(),action,mode)
    print('PASS sixteen populated real refresh button owner/order checks',flush=True)
    for reading in ('owner','missing','secret','other'):
        for action in actions:
            v=start()
            assert v.execute(case,action,reading)
        print('PASS',reading,len(actions),'before-frame hook/action entries',flush=True)
if __name__=='__main__':run()
