-- Actual pure modules, synthetic clock and observer boundary. No game API invoked.
local root=assert(arg[1]);local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local Q=dofile(dir..'deferred_save.lua');local E=dofile(dir..'combat_events.lua')
local n=0;local function ck(v,m)n=n+1;assert(v,m)end
local safe={playerReady=true,introComplete=true,nativeSavingUnlocked=true,enginePermissionOnly=true}
for _,source in ipairs({'manual','quicksave'}) do
  local q=Q.new();Q.request(q,0,source,1,'session');local calls=0
  for t=0,7200,1 do
    ck(Q.tick(q,t,{playerReady=true,introComplete=true,nativeSavingUnlocked=false,enginePermissionOnly=true},function()calls=calls+1 end)=='waiting','two-hour fight retains request')
  end
  ck(q.pending.expires==nil and q.pending.retention=='session' and calls==0,'no deadline or early submission')
  ck(Q.tick(q,7201,safe,function()calls=calls+1;return true end)=='request_submitted','retained request releases')
  for t=7202,7210 do Q.tick(q,t,safe,function()calls=calls+1;return true end) end
  ck(calls==1,'exactly one dispatch')
end
for _,source in ipairs({'manual','quicksave','autosave'}) do
 local q=Q.new();Q.request(q,0,source,30)
 ck(Q.tick(q,30,safe,function()error('expired callback')end)=='expired','legacy bounded queue retained for '..source)
end
ck(not pcall(Q.request,Q.new(),0,'autosave',30,'session'),'autosave cannot silently become unlimited')
ck(not pcall(Q.request,Q.new(),0,'manual',30,'bad'),'unknown retention rejected')
-- Recovery of a proven no-submit result must respect reentrant cancellation.
for _,cancel in ipairs({false,true})do
 local q=Q.new();Q.request(q,0,'manual',30,'session')
 Q.tick(q,1,safe,function()if cancel then Q.cancel(q)end;return 'preflight_wait'end)
 ck((q.pending~=nil)==(not cancel),'preflight wait never revives cancelled intent')
end
local e=E.new(function(p)return p.session end);local handlers={}
local function reg(c,m,f)ck(c=='PlayerPuppet','correct event owner');handlers[m]=f end
-- No engine calls are needed to construct the pure object.
e:register(reg,reg);e:register(reg,reg);ck(e.requested==3,'one registration per target')
e:bind(10);handlers.OnCombatStateChanged({session=10},1)
ck(not e:due(0),'event without request never schedules a save')
ck(e:arm(10,1,0) and e:due(0),'new intent wakes')
ck(not e:sample(0,false,'combat_active'),'active combat does not grant eligibility')
for i=1,59 do ck(not e:due(i/60),'no per-frame polling during native wait')end
ck(e:due(1),'one-second fallback');e:sample(1,false,'combat_active')
handlers.OnCombatStateChanged({session=11},2);ck(not e:due(1.1),'foreign session ignored')
handlers.OnCombatStateChanged({session=10},2);ck(e:due(1.1),'combat event immediately wakes eligibility')
ck(not e:sample(1.1,true,'stabilizing'),'event not automatic permission')
for i=1,7 do local t=1.1+i*.25;ck(e:due(t),'stabilization sampling');ck(not e:sample(t,true,'stabilizing'),'full stability required')end
handlers.OnCombatStateChanged({session=10},1);ck(e.stable==0,'combat return resets accumulated stability')
ck(e:due(3) and not e:sample(3,false,'combat_active'),'renewed combat waits')
handlers.OnCombatStateChanged({session=10},2);ck(e:due(3.1),'second combat-end wake');e:sample(3.1,true,'stabilizing')
for i=1,8 do local t=3.1+i*.25;ck(e:due(t),'sample due');local ready=e:sample(t,true,'stabilizing');ck(ready==(i==8),'two-second quiet window')end
e:interrupt();ck(e.stable==0 and e:due(99),'stall restarts eligibility');ck(not e:sample(99,true,'stabilizing'),'long frame cannot satisfy readiness')
e:clear();handlers.OnCombatStateChanged({session=10},2);ck(not e:due(100),'cancelled request cannot be resurrected')
e:arm(10,2,101);handlers.OnDeath({session=10});ck(e.invalidated and not e:due(102),'death invalidates');ck(not e:arm(10,3,103),'same dead session cannot rearm')
e:bind(12);e:arm(12,1,104);handlers.OnDetach({session=10});ck(not e.invalidated,'old detach cannot cancel new session')
handlers.OnDetach({session=12});ck(e.invalidated,'current detach invalidates')
e:bind(13);e:arm(13,1,105);e:shutdown();handlers.OnCombatStateChanged({session=13},2);ck(not e:due(106),'shutdown observers inert')
local missing=E.new(function(p)return p.session end);missing:register(nil,nil);ck(missing.unavailable==3,'missing observers explicit');missing:arm(1,1,0);ck(missing:due(0),'fallback still active when hook unavailable')
local library=dofile(dir..'status_message_library.lua')
for tone=0,2 do for body=0,2 do for _,text in ipairs(library.get('queued',tone,body))do
 ck(not text:find('until its expiry',1,true) and not text:find('It will expire',1,true) and not text:find('Expiry still applies',1,true),'player queue wording never advertises old timeout')
end end end
print('PASS event module and retained queue: '..n..' assertions')
