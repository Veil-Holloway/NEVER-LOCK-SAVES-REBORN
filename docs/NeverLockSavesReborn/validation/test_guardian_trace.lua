-- Actual Lua modules. No game/compiler, no engine writes, no filesystem save evidence.
local root=assert(arg[1]); local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
package.path=dir..'?.lua;'..package.path
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..' expected '..tostring(b)..' got '..tostring(a)) end
local function last(g) local r=g:latest();return r[#r] end
local G=dofile(dir..'guardian.lua');local Q=dofile(dir..'deferred_save.lua')
local now=10;local g=G.new('trace-test',function()return now end);g:set_enabled(true)
local id=g:begin('gameplay_quicksave',2);g:queued(id,'quicksave',2,1)
now=610;g:waiting(2,1,'Waiting: combat active')
eq(last(g).reason,'combat_active','specific combat wait reason')
eq(last(g).observed_age_seconds,600,'ten minute retained intent age')
eq(last(g).phase_age_seconds,0,'new phase observation age')
for label,reason in pairs({['Waiting: combat state unknown']='combat_unknown',
 ['Waiting: pause/menu state unknown']='pause_unknown',['Waiting: paused or menu open']='paused',
 ['Waiting: native permission unknown']='native_state_unknown',['Waiting: native save lock']='native_save_lock',
 ['Waiting: dispatch cooldown']='cooldown',['Combat clear and native unlocked: stabilization']='stabilizing'})do
 g:waiting(2,1,label);eq(last(g).reason,reason,'specific gate '..reason)
end
g:waiting(2,1,'Combat clear and native unlocked: stabilization')
local n=#g:report().transitions
for _=1,1000 do g:waiting(2,1,'Combat clear and native unlocked: stabilization')end
eq(#g:report().transitions,n,'identical wait is deduplicated')
now=612;g:executing(2,1);eq(last(g).phase,'Executing','execution begins')
eq(g:preflight_wait(9,1),nil,'foreign session cannot rewind dispatch')
eq(g:preflight_wait(2,9),nil,'foreign serial cannot rewind dispatch')
eq(g:preflight_wait(2,1),id,'verified preflight restores same trace')
eq(last(g).phase,'Waiting','preflight refusal returns to Waiting')
eq(last(g).reason,'native_permission_changed','preflight reason retained')
g:waiting(2,1,'Waiting: native save lock');eq(last(g).reason,'native_save_lock','later gates update after preflight')
now=620;g:executing(2,1);g:submitted(2,1)
eq(last(g).phase,'Submitted','native acceptance remains Submitted')
check(last(g).awaiting_write_evidence,'acceptance needs write evidence')
eq(g:preflight_wait(2,1),nil,'submitted attempt cannot return to pending')
now=625;g:hint('game_notification',true,2)
local r=g:report();eq(r.uncorrelated_hints[1].session,2,'hint records event session')
eq(r.uncorrelated_hints[1].observed_seconds,625,'hint timestamp is update observation')
eq(r.uncorrelated_hints[1].correlated,false,'success hint stays uncorrelated')
eq(r.evidence_summary.submitted_unverified,1,'accepted/unverified retained count')
eq(r.evidence_summary.uncorrelated_callbacks,1,'retained callback count')
eq(last(g).write_status,'Unknown','callback never proves write')
eq(last(g).reload_status,'Unknown','callback never proves reload')
eq(last(g).phase_age_seconds,5,'accepted observation age')
now=600;eq(last(g).observed_age_seconds,'unknown','backwards clock is unknown')
now=0/0;eq(last(g).phase_age_seconds,'unknown','NaN clock is unknown')
now=math.huge;eq(last(g).phase_age_seconds,'unknown','infinite clock is unknown')
now=630;eq(last(g).phase_age_seconds,10,'clock recovery retains original transition')
local noClock=G.new();noClock:set_enabled(true);noClock:begin('manual',1)
eq(last(noClock).observed_age_seconds,'unknown','missing clock never invented')
local throwing=G.new('bad-clock',function()error('private marker')end);throwing:set_enabled(true);throwing:begin('manual',1)
eq(last(throwing).observed_age_seconds,'unknown','clock exception is isolated')
-- No historical time or success can be injected through a returned snapshot.
r.records[1].write_status='Written';r.records[1].first_observed_seconds=999
r.uncorrelated_hints[1].correlated=true
eq(last(g).write_status,'Unknown','snapshots cannot mutate write evidence')
eq(g:report().uncorrelated_hints[1].correlated,false,'snapshot cannot correlate hints')
-- Pending-state clock changes never expire a session-retained player request.
local state={playerReady=true,introComplete=true,nativeSavingUnlocked=true,enginePermissionOnly=true}
local s=Q.new();Q.request(s,0,'quicksave',1,'session')
local calls=0;local nestedCalls=0;local replacement;local nestedResult
local result=Q.tick(s,7200,state,function()
 calls=calls+1
 replacement=Q.request(s,7200,'manual',1,'session')
 nestedResult=Q.tick(s,7200,state,function()nestedCalls=nestedCalls+1;return true end)
 return true
end)
eq(nestedResult,'waiting','nested dispatch must wait')
eq(result,'request_submitted','outer callback submitted once')
eq(calls,1,'outer callback count')
eq(nestedCalls,0,'reentrant replacement cannot dispatch recursively')
check(s.pending and s.pending.id==replacement,'replacement is retained for next update')
eq(Q.tick(s,7201,state,function()calls=calls+1;return true end),'request_submitted','replacement later dispatch remains supported')
eq(calls,2,'ordinary subsequent dispatch not permanently blocked')
-- Cancel cannot drop the frame guard; preview restore cannot revive cancelled intent.
local t=Q.new();Q.request(t,0,'quicksave',1,'session')
Q.tick(t,2,state,function()
 Q.cancel(t);Q.request(t,2,'manual',1,'session')
 eq(Q.tick(t,2,state,function()nestedCalls=nestedCalls+1;return true end),'waiting','cancel does not clear executing frame')
 return 'preflight_wait'
end)
check(t.pending and t.pending.source=='manual','cancel/new request prevents stale resurrection')
eq(nestedCalls,0,'cancel/new request also cannot dispatch recursively')
-- A thrown callback is never retried automatically, nor a permanent Lua lock.
local e=Q.new();Q.request(e,0,'quicksave',1,'session')
eq(Q.tick(e,2,state,function()error('injected callback failure')end),'request_failed','throw is a failed dispatch attempt')
check(not e.dispatching and not e.pending,'callback frame ends without automatic replay')
Q.request(e,3,'manual',1,'session');eq(Q.tick(e,4,state,function()return true end),'request_submitted','new explicit request remains usable')
-- Bounded export and adversarial, untrusted report field values.
local S=require('support_report'); local snap={guardian=g:report()}
local report=S.build(snap)
eq(report.guardian.records[1].observed_age_seconds,620,'support export age sanitized')
eq(report.guardian.records[1].write_status,'Unknown','support never claims writes')
eq(report.guardian.uncorrelated_hints[1].correlated,false,'support hint uncorrelated')
for i=1,200 do g:begin('manual',2);g:hint('game_notification',i%2==0,2)end
r=g:report();eq(#r.records,64,'bounded ledger retained')
eq(#r.uncorrelated_hints,16,'bounded hint ring retained')
report=S.build({guardian=r});eq(#report.guardian.records,12,'support latest 12 only')
eq(#report.guardian.uncorrelated_hints,16,'support latest 16 hints only')
check(report.guardian.history_incomplete,'dropped history remains explicit')
local marker='/private/secret.dat'
r.records[64].observed_age_seconds=marker;r.records[64].phase_age_seconds=math.huge
r.uncorrelated_hints[16]={origin=marker,outcome='Saved',session=marker,observed_seconds=marker,correlated=true,write_status='Written'}
report=S.build({guardian=r})
eq(report.guardian.records[12].observed_age_seconds,'unknown','untrusted age rejected')
eq(report.guardian.records[12].phase_age_seconds,'unknown','infinite age rejected')
eq(report.guardian.uncorrelated_hints[16].correlated,false,'untrusted hint cannot claim correlation')
eq(report.guardian.uncorrelated_hints[16].write_status,'Unknown','untrusted hint cannot claim Written')
local function inspect(v)
 if type(v)=='table'then for k,x in pairs(v)do inspect(k);inspect(x)end
 elseif type(v)=='string'then check(not v:find(marker,1,true),'private marker excluded')end
end
inspect(report)
print('PASS guardian trace / dispatch re-entry: '..checks..' assertions; actual Lua, simulated host only')
