local M=dofile(assert(arg[1],'quest module required'))
local n=0
local function eq(a,b,label) n=n+1;assert(a==b,label..': '..tostring(a)..' != '..tostring(b)) end
local Q='gameJournalQuest'
do
 local callback,a
 a=M.new({enabled=function() return true end,observe=function(_,_,f) callback=f end,
  resolve=function() a:clear();return {defined=true,succeeded=true,kind='quest'} end})
 a:register();a:drain(1);callback({},1,Q)
 eq(#a:drain(1),0,'clear during resolution suppresses interrupted batch')
end
do
 local callback,a,inside=false
 a=M.new({enabled=function() return true end,observe=function(_,_,f) callback=f end,
  resolve=function()
   if not inside then inside=true;a:drain(2) end
   return {defined=true,succeeded=true,kind='quest'}
  end})
 a:register();a:drain(1);callback({},2,Q)
 eq(#a:drain(1),0,'session change during resolver suppresses old batch')
 callback({},2,Q)
 local fresh=a:drain(2)
 eq(#fresh,1,'new session callback may resolve after reentry')
 eq(fresh[1].session,2,'new event uses actual new token')
end
do
 local callback,a,inside,inner=nil,nil,false,{}
 a=M.new({enabled=function() return true end,observe=function(_,_,f) callback=f end,
  resolve=function()
   if not inside then inside=true;callback({},3,Q);inner=a:drain(1) end
   return {defined=true,succeeded=true,kind='quest'}
  end})
 a:register();a:drain(1);callback({},3,Q)
 local outer=a:drain(1)
 eq(#inner+#outer<=1,true,'nested drain never emits duplicate same hash')
end
do
 local callback,a,enabled=nil,nil,true
 a=M.new({enabled=function() return enabled end,observe=function(_,_,f) callback=f end,
  resolve=function() enabled=false;return {defined=true,succeeded=true,kind='quest'} end})
 a:register();a:drain(1);callback({},4,Q)
 eq(#a:drain(1),0,'disabled during resolution suppresses batch')
end
do
 local callback,a,inside=nil,nil,false
 a=M.new({enabled=function() return true end,observe=function(_,_,f) callback=f end,
  resolve=function()
   if not inside then inside=true;a:drain(nil) end
   return {defined=true,succeeded=true,kind='quest'}
  end})
 a:register();a:drain(1);callback({},5,Q)
 eq(#a:drain(1),0,'unknown session during resolution suppresses batch')
 a:drain(1);callback({},5,Q)
 eq(#a:drain(1),1,'interrupted unresolved event not poisoned into dedup')
end
print('PASS independent quest reentrant boundaries: '..n..' assertions')
