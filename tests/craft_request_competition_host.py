"""Regression for observed craft rivals and explicit source ordering in a real TOC VM."""
import argparse
from pathlib import Path
from lupa.lua51 import LuaRuntime

tests = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=tests.parent / 'MyEpoch')
parser.add_argument('--mock', type=Path, default=tests / 'wow_mock.lua')
args = parser.parse_args()
prefix = (tests / 'multicraft_output_spec.lua').read_text().split('local function matched()')[0]
request = "set(3);C_TradeSkillUI.CraftRecipe(900,1,nil)"
begin = "set(4);evt('TRADE_SKILL_CRAFT_BEGIN',900)"
receive = "evt('CHAT_MSG_LOOT','You create: '..link..'x'..total..'.',nil,nil,nil,nil,nil,nil,nil,nil,nil,1001)"
g = "C_TradeSkillUI.CraftRecipe(nil,1,nil)"

def real_vm():
    vm = LuaRuntime(unpack_returned_tuples=True)
    vm.globals().MODE = 'fixed'
    vm.execute('E={};time=os.time;date=os.date')
    for name in (args.source / 'MyEpoch.toc').read_text().splitlines():
        if name.endswith('.lua'):
            if name == 'Book.lua':
                vm.execute(args.mock.read_bytes())
            vm.execute('local s,n=...;assert(loadstring(s,"@"..n))("MyEpoch",E)', (args.source/name).read_bytes(), name)
    return vm

for mode in ('ordinary', 'secret', 'newBagRow', 'resultBeforeBegin', 'receiptBeforeBegin',
             'gapAfterResult', 'twoCompleted', 'rejectEarlier', 'conflictingEarlierFinance'):
    src=prefix.replace("local total=MODE=='ordinaryRivals'and 2 or 5", 'local total=2')
    if mode=='secret':
        src=src.replace(request,request+";local hidden={};issecretvalue=function(v)return rawequal(v,hidden)end;C_TradeSkillUI.CraftRecipe(hidden,1,nil)")
    elif mode=='newBagRow':
        src=src.replace(begin,"bag[3]=item(777,1);update(4);set(5);C_TradeSkillUI.CraftRecipe(900,1,nil);req=Q.Kind(c,'craft_request')[2];set(6);evt('TRADE_SKILL_CRAFT_BEGIN',900)")
        src=src.replace("set(5);evt('TRADE_SKILL_ITEM_CRAFTED_RESULT'","set(7);evt('TRADE_SKILL_ITEM_CRAFTED_RESULT'").replace("local inv=update(6)","local inv=update(8)")
    elif mode in ('resultBeforeBegin','receiptBeforeBegin'):
        src=src.replace(begin,'')
        src=src.replace(receive, (receive+';'+begin+';set(5)') if mode=='receiptBeforeBegin' else (begin+';set(5);'+receive))
    elif mode=='gapAfterResult':
        src=src.replace(receive,"set(-5000);"+g+";set(5);"+receive)
    elif mode in ('twoCompleted','rejectEarlier','conflictingEarlierFinance'):
        src+="""
        local prior=req
        set(7);C_TradeSkillUI.CraftRecipe(900,1,nil);req=assert(Q.Kind(c,'craft_request')[2])
        set(8);evt('TRADE_SKILL_CRAFT_BEGIN',900)
        set(9);evt('TRADE_SKILL_ITEM_CRAFTED_RESULT',{itemID=205,hyperlink=link,quantity=2,operationID=84,isEnchant=false,firstCraftReward=false,bonusCraft=false,multicraft=0})
        evt('CHAT_MSG_LOOT','You create: '..link..'x2.',nil,nil,nil,nil,nil,nil,nil,nil,nil,1002)
        bag[1]=nil;bag[2]=item(205,4);update(10)
        assert(K.Info(c,prior).cost==15 and K.Info(c,req).cost==15)
        """
        if mode=='rejectEarlier':
            src+="prior.rejectCraftCosts=true;S.Changed(c,prior);"
        if mode=='conflictingEarlierFinance':
            src+="local bank=S.Add(c,'bank',inv.ts,{inventoryRecord=inv.id,transfers={{itemID=100}}});"
    matched=real_vm().execute(src+"\nlocal p=K.Info(c,req);return p and p.cost or false")
    assert matched==(15 if mode in ('ordinary','twoCompleted') else False), (mode,matched)
    print('PASS',mode,matched)

