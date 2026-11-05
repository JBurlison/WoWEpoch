local S,F=E.Store,E.Economy
local c,letters=AuctionPerfHistory(400,'varied')
AuctionPerfMeasure(c,letters,'links');AuctionPerfMeasure(c,letters,'ownership')
local original=F.Replay;local calls=0
F.Replay=function(...)calls=calls+1;return original(...)end
local report=E.AuctionSettlement.Report(c,0,math.huge)
assert(report.matchedBasis==400 and report.marginAfterHouseCut==474600)
assert(calls==1,'Compatible historical allocations must share one replay')
E.AuctionSettlement.Report(c,0,math.huge);assert(calls==1,'Unchanged allocation preparation must be reused')
local other=S.Character('allocation-budget-donor',{});F.Lot(other,1,{itemID=2840,quantity=1,cost=100,evidence='acquisition'},'source')
local updated=E.AuctionSettlement.Report(c,0,math.huge);assert(calls==2 and updated.marginAfterHouseCut==report.marginAfterHouseCut,'A relevant change on another character must invalidate shared preparation')
local retro=S.Character('allocation-budget-retro',{})
F.Lot(retro,1,{itemID=2840,quantity=10,cost=10,evidence='acquisition'},'initial')
local early=F.Move(retro,10,{itemID=2840,quantity=5,evidence='observation',reason='outflow'},'early')
F.Lot(retro,0,{itemID=2840,quantity=5,cost=100,evidence='late acquisition'},'late')
assert(original(retro,math.huge).movements[early.id].cost==100,'Fixture must demonstrate that naive present-day reuse is wrong')
local before=calls;assert(F.MovementAllocation(retro,early).cost==5);assert(calls==before+2,'Retroactive history must take its original sequence reference path')
assert(F.MovementAllocation(retro,early).cost==5 and calls==before+2,'Unchanged fallback allocation may be memoized')
local tied=S.Character('allocation-budget-tied',{})
F.Lot(tied,1,{itemID=2840,quantity=2,cost=7,evidence='acquisition',observationSequence=1},'one')
F.Lot(tied,1,{itemID=2840,quantity=3,cost=11,evidence='acquisition',observationSequence=1},'two')
local target=F.Move(tied,2,{itemID=2840,quantity=4,evidence='observation',reason='outflow'},'target')
before=calls;local expected=original(tied,math.huge,S.Sequence(target)).movements[target.id]
assert(E.Same(F.MovementAllocation(tied,target),expected)and calls==before+2,'Indistinguishable same-item ordering must take the reference path')
F.Replay=original
print('PASS allocation budgets: 400 exact margins in one replay, warm reuse, cross-character invalidation, nonvacuous retroactive counterexample and tied-order fallback')
