return function()
 local A=E.API;local count,raid,reads,owners,changed,opaque,invalid,shiftSize,shiftMode,replaceLast,flag=40,true,0,0
 local trace={}
 local function reset()reads,owners,changed,opaque,invalid,shiftSize,shiftMode,replaceLast,flag=0,0,nil,nil,nil,nil,nil,nil,nil;trace={}end
 GetNumGroupMembers=function()if shiftSize and reads>=count then return count-1 end;return count end
 IsInRaid=function()if shiftMode and reads>=count then return not raid end;return raid end
 UnitFullName=function(u)return u,'Test' end
 UnitIsGroupLeader=function(u)return flag or u=='raid1' end
 local secret={};issecretvalue=function(v)return v==secret end
 UnitGUID=function(u)
  reads=reads+1;trace[#trace+1]=u
  if u=='player'then owners=owners+1;if opaque and owners>=opaque then return secret end
   return (changed and owners>1)and 'player-2' or 'player-1'
  end
  local idx=tonumber(u:match('%d+'));if invalid and idx==3 then return 'player-1' end
  if replaceLast and u=='raid1'and reads>40 then return 'player-800' end
  return 'player-'..idx
 end
 reset();local r=A.Roster();assert(#r==40 and reads==82 and owners==2)
 assert(trace[1]=='player'and trace[82]=='player')
 for i=1,40 do assert(trace[i+1]=='raid'..i and trace[i+41]=='raid'..i and r[i].id=='player-'..i)end
 reset();changed=true;assert(not A.Roster())
 reset();opaque=1;assert(not A.Roster())
 reset();opaque=2;assert(not A.Roster())
 reset();invalid=true;assert(not A.Roster())
 reset();replaceLast=true;assert(not A.Roster())
 reset();shiftSize=true;assert(not A.Roster())
 reset();shiftMode=true;assert(not A.Roster())
 reset();flag=secret;assert(A.Roster()[1].isLeader==nil)
 reset();count=41;assert(not A.Roster() and reads==0)
 reset();count=0;changed=true;assert(not A.Roster())
 reset();count=0;opaque=2;assert(not A.Roster())
 reset();count=0;assert(#A.Roster()==0)
 reset();count=2;raid=false;changed=true;assert(not A.Roster())
 return 82
end
