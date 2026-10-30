local root=assert(arg[1],'release root required')
local mod=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
package.path=mod..'?.lua;'..package.path
local completion=require('save_completion')
local support=require('support_report')
local clock=0
local n=0
local function check(v,m)n=n+1;assert(v,m or ('assertion '..n))end
local function eq(a,b,m)check(a==b,(m or 'value')..': '..tostring(a)..' != '..tostring(b))end

local c=completion.new(function() return clock end)
local clear,why=c:can_dispatch(1);eq(clear,true,'initial dispatch clear')
check(c:submitted(1,4,'quicksave','10.000|10.000|2.5'),'submission tracked')
clear,why=c:can_dispatch(1);eq(clear,false,'second dispatch blocked');eq(why,'previous_save_completion_unknown','same-session reason')
local ok,reason=c:hint(2,true,'game_notification','11.000|11.000|2.5');eq(ok,false,'other session uncorrelated');eq(reason,'uncorrelated','uncorrelated result')
clear=c:can_dispatch(1);eq(clear,false,'uncorrelated callback does not clear')
ok,reason=c:hint(1,nil,'game_notification','11.000|11.000|2.5');eq(ok,false,'unknown callback not definitive')
clear=c:can_dispatch(1);eq(clear,false,'unknown callback retains inflight')
clock=2
ok,reason=c:hint(1,true,'game_notification','11.000|11.000|2.5');eq(ok,true,'success callback correlated');eq(reason,'completion_observed','success outcome')
clear=c:can_dispatch(1);eq(clear,true,'completion clears inflight')
local r=c:report();eq(r.last.write_status,'ObservedLatestMetadataChanged','metadata change is observed evidence');eq(r.last.reload_status,'Unknown','reload never inferred');eq(r.last.metadata_changed,true,'metadata change retained')

check(c:submitted(1,5,'autosave','20.000|20.000|2.5'),'second submission tracked')
ok,reason=c:hint(1,true,'save_notification','20.000|20.000|2.5');eq(ok,true,'same metadata callback correlated')
r=c:report();eq(r.last.write_status,'Unknown','unchanged metadata does not become write claim');eq(r.last.completion_success,true,'engine callback success retained')

check(c:submitted(1,6,'manual',nil),'unknown metadata submission tracked')
ok,reason=c:hint(1,false,'save_notification',nil);eq(ok,true,'failure callback correlated')
r=c:report();eq(r.last.write_status,'Failed','failure callback recorded');eq(r.last.reload_status,'Unknown','failure does not imply reload state')

check(c:submitted(3,1,'quicksave','1.000|1.000|2.5'),'third-session submission tracked')
check(c:invalidate(3,'session_changed'),'session invalidation clears inflight')
clear=c:can_dispatch(4);eq(clear,true,'new session clear after invalidation')
r=c:report();eq(r.last.write_status,'Unknown','session invalidation remains unknown')

-- Existing Guardian observer transports completion hints even when the optional ledger is disabled.
local observers={}
local completionEvent=nil
local ledger={hint=function() error('disabled guardian hint should not be required') end}
local bridge=require('guardian_bridge').new(ledger,{enabled=function() return false end,session=function() return 7 end,
  completion=function(session,success,origin) completionEvent={session,success,origin} end,
  ObserveBefore=function(class,method,fn) observers['B:'..class..'.'..method]=fn end,
  ObserveAfter=function(class,method,fn) observers['A:'..class..'.'..method]=fn end})
bridge:register()
check(observers['A:gameuiInGameMenuGameController.OnSavingComplete']~=nil,'completion observer registered')
observers['A:gameuiInGameMenuGameController.OnSavingComplete']({},true,{})
bridge:drain(7)
eq(completionEvent[1],7,'callback-time session transported');eq(completionEvent[2],true,'success scalar transported');eq(completionEvent[3],'game_notification','origin transported')

-- Support report must sanitize completion evidence and omit fingerprints.
local sr=support.build({build='1.0.0-scope-freeze.1',completion={correlation='single_reborn_inflight_only',
  current={state='InFlight',session=9,serial=3,source='quicksave',reason='awaiting_engine_completion'},
  last={session=8,serial=2,source='autosave',origin='game_notification',completion_success=true,metadata_changed=true,
    write_status='ObservedLatestMetadataChanged',reload_status='Unknown',evidence_scope='engine_completion_callback',metadata_before='SECRET',metadata_after='SECRET2'}},
  sensors={},queue={},autosave={}})
eq(sr.save_completion.current.state,'InFlight','support current inflight')
eq(sr.save_completion.last.write_status,'ObservedLatestMetadataChanged','support observed status')
eq(sr.save_completion.last.reload_status,'Unknown','support reload unknown')
check(sr.save_completion.last.metadata_before==nil and sr.save_completion.last.metadata_after==nil,'fingerprints not exported')
print('PASS completion evidence focused regression: '..n..' assertions')
