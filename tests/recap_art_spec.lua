local R,S,B,D,V=E.Artwork,E.Store,E.Book,E.ArtDialog,E.RecapView
local c=S.Character('recap-art-owner',{name='Painter',faction='Alliance'})
local other=S.Character('recap-art-other',{name='Other'})
local today=E.API.DayStart(time());c.state.recapLoginThrough=today
local function recap(n,source)
 local from=E.API.ShiftDay(today,-n-1);local through=E.API.ShiftDay(today,-n)
 local r=S.Add(c,'recap',through,{title='Chapter '..n,periodKind=source and'milestone'or'daily',
  key=source and'milestone:'..source.id or'daily:'..E.API.Day(from),from=from,through=through,
  facts={},refs={},text='Recorded adventures.',read=true,generation=1})
 c.state.recaps=c.state.recaps or{};c.state.recaps[r.key]=r.id;return r
end
local first,second=recap(1),recap(2)
local a,b=R.ForRecord(c,first),R.ForRecord(c,second)
assert(a and b and R.CanCustomize(c,first))
local seen={}
for i=3,24 do local r=recap(i);seen[R.ForRecord(c,r).id]=true end
local count=0;for _ in pairs(seen)do count=count+1 end;assert(count>3,'automatic recaps must vary across entries')
assert(R.Select(c,'zone:westfall','anywhere-07'))
local original,location=E.Copy(second),E.Copy(c.art)
assert(R.SelectRecord(c,first.id,'fixed','wetlands-03'))
assert(R.ForRecord(c,first).id=='wetlands-03'and R.ForRecord(c,second)==b)
assert(E.Same(second,original)and E.Same(c.art,location))
assert(not R.SelectRecord(other,first.id,'none')and not R.ForRecord(c,E.Copy(first)))
assert(R.SelectRecord(c,first.id,'default')and R.ForRecord(c,first)==a)
local level=S.Add(c,'milestone',time(),{subject=c.id,milestoneType='level',major=true,after=2,zone='Westfall'})
local levelRecap=recap(25,level);local dedicated=R.byCharacterLevel.Alliance[2]
assert(R.ForRecord(c,level)==dedicated and R.ForRecord(c,levelRecap)==dedicated)
assert(R.SelectRecord(c,level.id,'fixed','wetlands-03')and R.ForRecord(c,levelRecap)==dedicated)
assert(R.SelectRecord(c,levelRecap.id,'fixed','anywhere-07')and R.ForRecord(c,level).id=='wetlands-03')
assert(R.SelectRecord(c,levelRecap.id,'default')and R.ForRecord(c,levelRecap)==dedicated)
local weapon=S.Add(c,'milestone',time(),{subject=c.id,milestoneType='skill',major=true,skillID=43,thresholds={25,50}})
assert(R.ForRecord(c,recap(26,weapon))==R.byWeapon[43][50])
-- The header must target the recap shown even when B.selected is nil.
B.ChangeCharacter(c.id);B.SetChapter('Recaps');V.SelectSaved(c,first);TEST_PREPARE_BOOK()
assert(B.selected==nil and B.recapFocus==first.id)
local context=D.OpenForPage();assert(context.record==first and context.artLocation==nil)
local chosen=D.left.pool.artTile[2].artID;D.left.pool.artTile[2]:Click();D.cancel:Click()
assert(first.artMode==nil and R.ForRecord(c,first)==a)
D.OpenForPage();D.left.pool.artTile[2]:Click();D.apply:Click();TEST_PREPARE_BOOK()
assert(first.artID==chosen and first.artMode=='fixed'and E.Same(c.art,location))
assert(B.left.pool.artImage[1].image.texture==R.rows[chosen].texture)
assert(R.ForRecord(c,second)==b)
local stale=D.OpenForPage();local apply=stale.pending
V.SelectSaved(c,second);D.Apply(stale,apply or function()error('stale callback ran')end)
assert(second.artMode==nil and first.artID==chosen)
V.SelectSaved(c,first);D.OpenForPage()
for i=1,D.right.used.artControl do local f=D.right.pool.artControl[i];if f.text:GetText()=='Use default'then f:Click();break end end
assert(first.artID==chosen and E.ArtView.lastMemoryPreview==a)
D.apply:Click();assert(first.artMode==nil and first.artID==nil and R.ForRecord(c,first)==a)
assert(E.Same(c.art,location),'no per-entry operation may write shared location preferences')
assert(R.SelectRecord(c,first.id,'fixed','wetlands-03'))
local regenerated=E.Diary.Generate(c,first.key,first.from,first.through,first.title,{periodKind='daily'})
assert(regenerated==first and first.artID=='wetlands-03','rewriting a recap must retain its illustration override')
local root=E.db
local saved={schema=E.schema,characters={[c.id]=E.Copy(c)},settings=E.Copy(root.settings),bankOrder=root.bankOrder}
S.Open(saved);local reopened=saved.characters[c.id]
assert(R.ForRecord(reopened,reopened.records[first.id]).id=='wetlands-03')
assert(R.ForRecord(reopened,reopened.records[second.id])==b,'automatic choice remains stable across save/reopen')
E.db=root
print('PASS recap artwork: stable varied defaults, dedicated milestones, independent overrides, header target, cancel/apply/reset and stale selection')
