-- Synthetic review only; never included in the production package.
local _,E=...
function MyEpochRecapMetricsReview()
    local id='myepoch-recap-metrics-review-full';local c=E.db.characters[id]
    local day=assert(E.API.ParseDay('2026-10-31'))
    if not c then
        c=E.Store.Character(id,{name='Aldren',realm='TEST: Expanded Recaps',level=22})
        c.state.firstObserved=day
        local function add(kind,data)return E.Store.Add(c,kind,day+3600,data)end
        add('play',{title='Recorded play',ended=day+18000,status='active',session='review-session'})
        add('milestone',{title='Character level 21 -> 22',subject=id,milestoneType='level',before=21,after=22,major=true})
        add('milestone',{title='Swords 99 -> 100',subject=id,milestoneType='skill',skillID=43,skillName='Swords',before=99,after=100})
        add('crafted',{title='Copper Bar',recipient=id,itemID=2840,quantity=10})
        add('gathered',{title='Copper Ore',recipient=id,itemID=2770,quantity=15})
        for i=1,3 do add('death',{title='A death to remember',subject=id})end
        add('damage',{title='Damage taken',subject=id,amount=123456})
        add('health',{title='Health gained',subject=id,amount=118250})
        add('gold',{title='Wallet gain',amount=1234567});add('gold',{title='Wallet loss',amount=-654321})
        for i=1,12 do add('auction',{title='Auction bought',source='purchase',auctionID=i})end
        for i=13,20 do add('auction',{title='Auction sold',source='owned',auctionID=i,auctionData={statusLabel='Reported sold'}})end
        add('xp',{title='XP gained',subject=id,amount=45850})
        add('travel',{title='Distance traveled',subject=id,amount=18430})
        for i=1,18 do add('quest',{title='Completed quest',status='completed'})end
        add('loot',{title='Items looted',recipient=id,itemID=2589,quantity=1234})
        for i=1,5 do add('roll_win',{title='Item roll won',subject=id,confirmed=true})end
        for i=1,4 do add('duel',{title='Duel won',subject=id,outcome='won'})end
        add('duel',{title='Duel lost',subject=id,outcome='lost'})
        for i=1,3 do add('battleground',{title='Battleground won',subject=id,outcome='won'})end
        for i=1,2 do add('battleground',{title='Battleground lost',subject=id,outcome='lost'})end
    end
    E.Book.ChangeCharacter(id);E.Book.recapKind='weekly';E.Book.recapDate=day;E.Book.Open();E.Book.SetChapter('Recaps')
end
function MyEpochRecapMetricsScroll()
    E.Book.right.scroll:SetVerticalScroll(E.Book.right.scroll:GetVerticalScrollRange())
end
