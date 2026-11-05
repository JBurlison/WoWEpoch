-- Synthetic character for presentation review; excluded from the addon package.
do
local id="myepoch-ui-fixture-035"
if not MyEpochDB.characters[id]then
 local now=time();local first={id=id..":1",character=id,sequence=1,kind="memory",category="memories",ts=now-3600,createdAt=now-3600,title="An afternoon in Westfall",text="We took the long way home.",zone="Westfall",refs={}}
 MyEpochDB.characters[id]={id=id,identity={name="Mira",realm="TEST: Illustrations",level=22},state={level=22,firstObserved=now},seq=1,records={[first.id]=first},order={first.id},dedup={},notes={},retention={},art={},revision=1}
end
print("Synthetic Mira / TEST: Illustrations added; decorative choices do not rewrite its saved memory.")
end
