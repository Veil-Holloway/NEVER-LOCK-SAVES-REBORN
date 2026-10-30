local root=assert(arg[1]);local dir=assert(arg[0]):gsub('[^/]+$','')
local f=dofile(dir..'guardian_trace_fixture.lua')
local n=0
local function check(v,label)n=n+1;assert(v,label)end
local function fixture()
 local h=f.fixture();h.notices={}
 function h.player:NLSRebornCompletionNotify(success)
  h.notices[#h.notices+1]=success
  if h.throwNotice then error('UI failure')end
  return true
 end
 return h,h.observers['gameuiInGameMenuGameController.OnSavingComplete']
end
for _,success in ipairs({true,false})do
 local h,callback=fixture()
 callback({},success);h:step();check(#h.notices==0,'unrelated callback stays silent')
 h:queue(2);h:run(4);check(h.dispatches==1,'one dispatch accepted')
 check(#h.notices==0,'submission is never a completion notice')
 callback({},nil);h:step();check(#h.notices==0,'unknown callback stays silent')
 check(h:report().save_completion.current.state=='InFlight','unknown callback retains completion guard')
 callback({},success);h:step()
 check(#h.notices==1 and h.notices[1]==success,'matched success/failure has exactly one notice')
 check(h:report().save_completion.current.state=='unknown','completion guard retains established behavior')
 callback({},success);h:step();check(#h.notices==1,'duplicate callback does not repeat notice')
end
do local h,callback=fixture();h:queue(2);h:run(4)
 h.native['Enable notifications'].callback(false)
 callback({},true);h:step();check(#h.notices==0,'master toggle suppresses completion notice')
 check(h:report().save_completion.current.state=='unknown','master toggle does not change completion tracking')end
do local h,callback=fixture();h:queue(2);h:run(4);h.throwNotice=true
 callback({},true);h:step();check(h:report().save_completion.current.state=='unknown','UI failure cannot block completion or cause retry')
 h:run(4);check(h.dispatches==1,'UI failure does not retry save')end
do local h,callback=fixture();h:queue(2);h:run(4);h.present=false;h:step()
 callback({},true);h:step();check(#h.notices==0,'session loss prevents stale confirmation')end
do local h,callback=fixture();h.native['Save Guardian request ledger'].callback(false)
 h:queue(2);h:run(4);callback({},true);h:step()
 check(#h.notices==1 and h.notices[1]==true,'completion notice works with optional Guardian ledger disabled')end
package.path=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/?.lua;'..package.path
local s=require('status_messages').new(17);s:configure(true);s:reset(1)
s:enqueue('submitted',1,1,0);s:enqueue('queued',1,2,0)
check(not s:complete(2,1),'foreign completion cannot dismiss notices')
check(s:complete(1,1),'matching completion dismisses old saving notice')
check(s:status().pending==1,'unrelated queued notice retained')
local message;s:drain(0,0,function(t)message=t;return true end)
check(message:lower():find('queued')~=nil or message:lower():find('waiting')~=nil,'no stale saving notice after completion')
print('PASS completion notice: '..n..' assertions; actual-init callbacks with external game/UI doubles')
