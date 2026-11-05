-- A same-runtime switch only recovers pending sources on the entering journal.
local S=E.Store
local function pending(id)
    local c=S.Character(id,{name=id})
    local function row(kind) return S.Add(c,kind,100,{title=kind}) end
    local collection,draft,trade,pull=row("mail_collection"),row("mail_draft"),row("trade"),row("pull")
    c.state.activeMailCollection,c.state.activeMailbox,c.state.activeMailDraft=collection.id,"old visit",draft.id
    c.state.activeTrade=trade.id
    c.state.activePullRecords={[pull.id]=true}
    return {c=c,collection=collection,draft=draft,trade=trade,pull=pull}
end
local function recover(c,session,ownerOnly)
    E.current,E.Collectors.session=c,session
    E.Pulls.Start(c,session,ownerOnly)
    E.Trades.Start(c,session,ownerOnly)
    E.Mail.Start(c,session,ownerOnly)
    for _,module in ipairs({E.Pulls,E.Trades,E.Mail}) do
        assert(module.owner==c and module.session==session)
    end
end
local function recovered(r)
    local state=r.c.state
    assert(r.collection.interrupted and r.draft.interrupted and r.trade.interrupted)
    assert(not state.activeMailCollection and not state.activeMailbox and not state.activeMailDraft and not state.activeTrade)
    assert(not next(state.activePullRecords) and r.pull.trackingClosedObservedAt and not r.pull.trackingClosedAt)
end
local entering,offline=pending("entering"),pending("untouched")
local revision=offline.c.revision
recover(entering.c,"verified switch",true)
recovered(entering)
assert(offline.c.revision==revision and offline.c.state.activePullRecords[offline.pull.id])
assert(offline.c.state.activeTrade==offline.trade.id and offline.c.state.activeMailDraft==offline.draft.id
    and offline.c.state.activeMailCollection==offline.collection.id and offline.c.state.activeMailbox=="old visit")
assert(not offline.collection.interrupted and not offline.draft.interrupted and not offline.trade.interrupted
    and not offline.pull.trackingClosedObservedAt)
-- A genuine login continues to repair prior-runtime roots across journals.
recover(entering.c,"new login")
recovered(offline)
print("PASS recording handoff: only entering owner recovers pending mail, trade and pull records; login retains cross-journal recovery")
