local n=600;local c,envelopes=AuctionPerfHistory(n,'varied');local records=c.seq
local links=AuctionPerfMeasure(c,envelopes,'links');assert(links.linked==n)
local ownership=AuctionPerfMeasure(c,envelopes,'ownership')
assert(ownership.linked==n and ownership.plan_calls<=3*n,'Ownership lookup must not probe every historical post for every invoice')
assert(ownership.kind_rows_returned<=12*n,'Cold chronology/ownership lookup must not materialize quadratic full-history arrays')
assert(c.seq==records,'Lookup cannot manufacture recorded events')
local small,letters=AuctionPerfHistory(100,'varied');local full=AuctionPerfMeasure(small,letters,'full')
assert(full.linked==100 and full.matched==100 and full.margin==103650,'Optimization must preserve full FIFO/house-cut arithmetic')
local repeated,identical=AuctionPerfHistory(100,'repeated');assert(AuctionPerfMeasure(repeated,identical,'links').linked==0,'Repeated indistinguishable identities remain ambiguous')
print('PASS scaling budgets: 600 exact links, bounded Plan/history-array work, unchanged source count, exact 100-sale margin and repeated-identity ambiguity')

-- Each ID-bearing notice can compete with every invoice for the same item.
-- Revalidate the eligible listing evidence once per snapshot, and preserve
-- independent amounts and chronology for each of the distinct buyer receipts.
local sales,letters=AuctionPerfHistory(100,'distinct_commodity')
local dense=AuctionPerfMeasure(sales,letters,'full')
assert(dense.linked==100 and dense.matched==100 and dense.margin==313750)
assert(dense.plan_calls<=5*#letters,'Listing proofs were rebuilt per rival/invoice pair')
print('PASS dense same-item sales: exact copper and bounded Plan calls across 100 identified notices')
