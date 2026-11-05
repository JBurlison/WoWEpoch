local c,b,r,n=fixture(true,true)
local B,G,P=E.Book,E.AuctionPreparationView,E.AuctionPreparation
local expected=E.Copy(assert(K.Plan(c,b)).refs)
local function warm()for i=1,10000 do if B.HistoryReadiness(c)=='ready'then return end;Q.ProcessPreparation(1000);E.Gathering.Process();E.GoldChecks.Process()end;error('Not warm')end
warm();B.character=c.id;B.chapter='Gold';B.goldSection='mail';B.goldPreset='all';B.selected=b.id;B.Build();B.frame:Show()
local original=K.Plan;local calls=0;K.Plan=function(...)calls=calls+1;if EXPECT_REFS then error('Synchronous sent reference replay in renderer')end;return original(...)end
B.Render();for i=1,10000 do G.Process(1000);if G.job and G.job.status=='ready'then break end end
assert(G.job and G.job.status=='ready',G.job and G.job.error)
if not EXPECT_REFS then assert(calls>0,'Selected sent-reference reproduction disappeared');print('REPRODUCED selected collection called public SentMailCosts.Plan '..calls..' times');return end
assert(calls==0 and E.Same(G.job.model.mailSentRefs[b.id][1],expected),'Prepared source-reference IDs changed')
for _,id in ipairs(G.job.model.mailSentRefs[b.id][1])do assert(type(id)=='string','Sent reference projection retained a source table')end
K.Plan=original;n.event='MAIL_FAILED';S.Changed(c,n);warm();K.Plan=function()error('Synchronous sent plan after correction')end
B.Render();for i=1,10000 do G.Process(1000);if G.job and G.job.status=='ready'then break end end
assert(G.job and G.job.status=='ready'and #G.job.model.mailSentRefs[b.id][1]==0,'Changed send evidence left stale original-reference claim')
K.Plan=original
print('PASS selected sent collection: private exact reference IDs, no full plan payload/public replay, correction revocation and actual Book rendering')
