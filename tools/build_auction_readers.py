"""Generate checkpointed private readers from the authoritative addon sources."""
from pathlib import Path
import argparse,hashlib,json,re
NAMES='Store Query Economy Trades Mail Buyback AuctionCosts CostMatch BuybackCosts BankCosts TradeCosts MailCosts SentMailCosts CraftCosts MailMoney AuctionProceeds AuctionLinks AuctionSettlement AuctionDeposits AuctionReturns'.split()
def tokens(source):
    pos=0
    while pos<len(source):
        start=pos
        if source.startswith('--',pos):
            match=re.match(r'\[(=*)\[',source[pos+2:])
            if match:
                end=source.find(']'+match[1]+']',pos+2+len(match[0]));assert end>=0;pos=end+len(match[1])+2
            else:
                end=source.find('\n',pos);pos=len(source)if end<0 else end
        elif source[pos]in "\"'":
            quote=source[pos];pos+=1
            while pos<len(source):
                if source[pos]=='\\':pos+=2
                elif source[pos]==quote:pos+=1;break
                else:pos+=1
        elif(match:=re.match(r'\[(=*)\[',source[pos:])):
            end=source.find(']'+match[1]+']',pos+len(match[0]));assert end>=0;pos=end+len(match[1])+2
        elif(match:=re.match(r'[A-Za-z_]\w*',source[pos:])):pos+=len(match[0])
        else:pos+=1
        yield source[start:pos]
HELPERS='''local pairs=E.PreparationWalletAccess and E.PreparationWalletAccess.Pairs or pairs
local next=E.PreparationWalletAccess and E.PreparationWalletAccess.Next or next
local rawget=E.PreparationWalletAccess and E.PreparationWalletAccess.RawGet or rawget

local function _auctionTick()if E.PreparationWork then E.PreparationState.phase='MODULE';E.PreparationWork()end end
local function _auctionSort(rows,less)if E.PreparationWork then return E.PreparationSort(rows,less)end;return table.sort(rows,less)end
local function _auctionCopy(value)if E.PreparationWork then return E.RetentionWork.Copy(value,E.PreparationWork)end;return E.Copy(value)end
local function _auctionSame(a,b)if E.PreparationWork then return E.RetentionWork.Same(a,b,E.PreparationWork)end;return E.Same(a,b)end
'''
def build(directory):
    output='-- Generated private read engines. Regenerate/check with tools/build_auction_readers.py.\nlocal _,E=...\nE.AuctionReaderFactories={}\nE.AuctionReaderSources={}\nE.AuctionWalletReadInstrumentation=1\n'
    hashes={};counts={}
    for name in NAMES:
        source=(directory/(name+'.lua')).read_text(encoding='utf-8');hashes[name+'.lua']=hashlib.sha256(source.encode()).hexdigest()
        header,body=source.split('\n',1);assert re.fullmatch(r'local\s+_\s*,\s*E\s*=\s*\.\.\.\s*',header),header
        words=list(tokens(body));out=[];index=0;count=0
        while index<len(words):
            token=words[index];triple=''.join(words[index:index+3])
            replacement={'table.sort':'_auctionSort','E.Copy':'_auctionCopy','E.Same':'_auctionSame'}.get(triple)
            if replacement:out.append(replacement);index+=3;continue
            out.append(token)
            if token in ['do','repeat']:out.append(' _auctionTick();');count+=1
            index+=1
        output+='\n-- '+name+'.lua\ndo\nlocal function create(E)\n'+HELPERS.replace('MODULE',name)+''.join(out)+'\nend\n'
        output+='E.AuctionReaderFactories[#E.AuctionReaderFactories+1]={name="'+name+'",create=create}\n'
        output+='E.AuctionReaderSources["'+name+'.lua"]="'+hashes[name+'.lua']+'"\nend\n';counts[name]=count
    return output,hashes,counts
def main():
    root=Path(__file__).resolve().parents[1];parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,default=root/'MyEpoch');parser.add_argument('--output',type=Path,default=root/'MyEpoch/AuctionReaders.lua');parser.add_argument('--check',action='store_true');args=parser.parse_args()
    output,hashes,counts=build(args.source)
    if args.check:
        assert args.output.exists()and args.output.read_text(encoding='utf-8')==output,'AuctionReaders.lua is stale; regenerate it before packaging.'
    else:args.output.write_text(output,encoding='utf-8',newline='\n')
    print('Verified'if args.check else'Generated',len(hashes),'private readers and',sum(counts.values()),'loop checkpoints.')
if __name__=='__main__':main()
