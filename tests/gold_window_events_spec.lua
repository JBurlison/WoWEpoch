local S,H,Q,K=E.Store,E.History,E.Query,E.GoldChecks
local function eq(a,b,label)assert(a==b,(label or'window event')..': '..tostring(a)..' ~= '..tostring(b))end
local function ready(c)TEST_PREPARE_HISTORY(c);assert(not K.Pending(c))end
local c=S.Character('gold-window-events',{name='Wallet transitions'})
H.Wallet(c,100,1000,'one');ready(c)
local request=K.Request;local full=0
K.Request=function(owner,...)if owner==c then full=full+1 end;return request(owner,...)end
local w=H.Wallet(c,101,1100,'one');ready(c);eq(full,0,'live receipt does not schedule lifetime review')
H.Wallet(c,102,1100,'one');H.Wallet(c,102,1100,'one');eq(full,0,'heartbeats do not schedule review')
-- A full review in flight must finish despite continuous harmless heartbeats.
request(c,true)
for n=1,12 do H.Wallet(c,102+n,1100,'one');K.Step(c,64)end
assert(not K.Pending(c),'safe heartbeats must not keep full pass dirty')
local win=c.records[w.window];local original=win.ended
win.ended=100;S.Changed(c,win);eq(full,1,'explicit correction schedules review');ready(c)
win.ended=original;S.Changed(c,win);ready(c)
-- Replaying a transaction receipt without a new addition cannot hide an edit.
local before=E.Copy(win);before.closing=1000;before.ended=100;before.transactionCount=0
E.Emit('RECORD_CHANGED',c,win,nil,{character=c,reason='walletTransaction',detail={record=win,before=before,transaction=w}})
assert(K.Pending(c),'old transaction receipt rejected');ready(c)
-- A named heartbeat alone is not proof of a monotonic observation extension.
before=E.Copy(win);win.session='changed'
E.Emit('RECORD_CHANGED',c,win,nil,{character=c,reason='walletExtension',detail={record=win,before=before}})
assert(K.Pending(c),'changed heartbeat session rejected');ready(c)
win.session='one';S.Changed(c,win);ready(c)
-- Saved rows can be cold or displaced; both need conservative review.
local cold=S.Character('gold-window-cold',{name='Cold'})
H.Wallet(cold,1,100,'cold');cold.state.goldSourceReviewVersion=5
local cw=cold.records[cold.state.walletWindow];cw.kind='chat';S.Changed(cold,cw)
assert(K.Pending(cold),'cold kind correction schedules review');ready(cold)
local replacement=S.Character('gold-window-replacement',{name='Replacement'})
H.Wallet(replacement,1,100,'replace');ready(replacement)
local old=replacement.records[replacement.state.walletWindow];replacement.seq=old.sequence-1
local newer=S.Add(replacement,'chat',2,{text='Replaced window'})
eq(newer.id,old.id);assert(K.Pending(replacement),'same-ID replacement schedules review');ready(replacement)
-- Other owners and ordinary warm chat updates do not review this character.
local count=full;local chat=S.Add(c,'chat',115,{text='Hello'});chat.text='Hi';S.Changed(c,chat);eq(full,count)
K.Request=request
print('PASS window events: live append/heartbeat bounds, full-pass completion, invalid receipts, cold changes and displaced rows')
