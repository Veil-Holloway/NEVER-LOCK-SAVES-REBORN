local root=assert(arg[1]);local file=assert(arg[0]):gsub('[^/]+$','')..'combat_events_fixture.lua'
local f=dofile(file);local fixture,check=f.fixture,f.check
-- Actual init, event driver, queue and UI modules; only game/CET/disk boundaries are doubles.
for _,mounted in ipairs({0,1})do
 for _,source in ipairs({1,2})do
  local h=fixture({ttl=1});h.combat=true;h.unlocked=false;h.mounted=mounted;h:queue(source);h:run(600)
  check(h.player.pending and h.dispatches==0,'ten-minute combat retains request on foot/in vehicle')
  local r=h:report();check(r.queue.retention=='session' and r.queue.expires_in=='unknown','report marks non-expiring session retention without false zero')
  check(r.queue.gate=='combat_active','exact waiting reason exported')
  h.combat=false;h.unlocked=true;h:signal('OnCombatStateChanged',nil,2)
  h:run(1.75);check(h.dispatches==0,'no immediate event callback save')
  h:run(2);check(h.dispatches==1 and not h.player.pending,'save released after combat while mounted when allowed')
  h:signal('OnCombatStateChanged',nil,2);h:run(20);check(h.dispatches==1,'duplicate events never resubmit')
  r=h:report();check(r.queue.state=='Submitted' and r.checkpoint_attempt.write_status=='Unknown','dispatch not mislabeled written')
 end
end
-- Native locks can outlast combat without discarding user intent.
do local h=fixture();h.combat=true;h.unlocked=false;h:queue();h:run(2)
 h.combat=false;h:signal('OnCombatStateChanged',nil,2);h:run(180)
 check(h.player.pending and h.dispatches==0 and h.attempts==0,'post-combat native lock retains request without entering dispatch')
 check(h:report().queue.gate=='native_save_lock','distinct native lock reason')
 h.unlocked=true;h:run(4);check(h.dispatches==1,'watchdog detects native unlock without another combat event')end
-- Renewed combat interrupts stability; foreign callbacks cannot release current state.
do local h=fixture();h.combat=true;h:queue();h:run(1);h.combat=false;h:signal('OnCombatStateChanged',nil,2);h:run(1.5)
 h.combat=true;h:signal('OnCombatStateChanged',nil,1);h:run(10);check(h.dispatches==0,'renewed combat blocks')
 h.combat=false;h:signal('OnCombatStateChanged',nil,2);h:run(1.5);check(h.dispatches==0,'stabilization restarted')
 h:run(2);check(h.dispatches==1,'second transition completes once')end
-- Cancellation, disable, death, detach and reload invalidate requests, never replay.
for _,cancel in ipairs({'button','disable','death','detach','reload','shutdown'})do
 local h=fixture();h.combat=true;h.unlocked=false;h:queue();h:run(1)
 if cancel=='button'then h:press('Cancel queued request##nls_cancel_overview')
 elseif cancel=='disable'then h.native['Deferred Save'].callback(false)
 elseif cancel=='death'then h:signal('OnDeath')
 elseif cancel=='detach'then h:signal('OnDetach')
 elseif cancel=='reload'then h.present=false;h:step();h.present=true;h.player.session=0
 elseif cancel=='shutdown'then h.events.onShutdown()end
 h:step();h.combat=false;h.unlocked=true;h:signal('OnCombatStateChanged',nil,2);h:run(10)
 check(h.dispatches==0,'no replay after '..cancel)
end
-- Event-hook absence is visible, fails to watchdog mode rather than silently disabling saves.
do local h=fixture({noEvents=true});h.combat=true;h:queue();h:run(130);h.combat=false;h:run(4)
 check(h.dispatches==1,'watchdog catches missing event after long fight')
 check(h:report().queue.event_driver.unavailable==3,'registration failure exported')end
-- Unknown readings and paused/menu state are not permission.
for _,state in ipairs({'unknownCombat','paused','menu'})do
 local h=fixture();h.combat=true;h:queue();h:step();h.combat=false;h[state]=state=='unknownCombat' and true or 1
 h:signal('OnCombatStateChanged',nil,2);h:run(140);check(h.player.pending and h.dispatches==0,'blocked unknown/pause/menu')
 if state=='unknownCombat' then h[state]=false else h[state]=0 end;h:run(4);check(h.dispatches==1,'resumes once state known clear: '..state)
end
-- User replacement remains one item, with no expiry inherited.
do local h=fixture();h.combat=true;h:queue(1);h:run(60);h:queue(2);h:run(60);h.combat=false;h:signal('OnCombatStateChanged',nil,2);h:run(4)
 check(h.dispatches==1 and h.player.serial==2,'replacement coalesces into one submission')end
-- Exceptions/native refusals must not turn watchdog into a retry storm.
for _,fault in ipairs({'reject','dispatchThrows'})do
 local h=fixture();h.combat=true;h:queue();h:step();h.combat=false;h[fault]=true;h:signal('OnCombatStateChanged',nil,2);h:run(10)
 h[fault]=false;h:signal('OnCombatStateChanged',nil,2);h:run(100)
 check(h.attempts==1 and h.dispatches==0,'no engine retry after '..fault)
end
-- A preflight relock that never entered the checkpoint helper retains intent.
do local h=fixture();h.combat=true;h:queue();h:step();h.combat=false;h.relock=true;h:signal('OnCombatStateChanged',nil,2);h:run(4)
 check(h.player.pending and h.checkpointAttempts==0,'preflight relock preserves intent without engine request')
 h.relock=false;h.unlocked=true;h:run(4);check(h.dispatches==1 and h.checkpointAttempts==1,'native unlock after preflight refusal dispatches once')end
-- Clock stalls cannot fill the stabilization window.
do local h=fixture();h.combat=true;h:queue();h:step();h.combat=false;h:signal('OnCombatStateChanged',nil,2);h:run(1)
 h:step(60);check(h.dispatches==0,'long frame no dispatch');h:run(1);check(h.dispatches==0,'stability reset after stall');h:run(2);check(h.dispatches==1,'fresh stabilization after stall')end
-- No pending intent: combat events do nothing. Dry runs retain finite TTL and never save.
do local h=fixture({ttl=1});for i=1,50 do h:signal('OnCombatStateChanged',nil,i%3);h:step()end
 check(h.dispatches==0,'no automatic combat saves')
 h:press('Queue dry-run test##nls_queue');h:run(2);check(h.dispatches==0 and h:report().queue.state=='Expired','dry run expires without save')
 h.returnFalse=true;h:press('Export support report##nls_support_export');check(h:contains('Report export failed'),'nonthrowing report failure visible')end
print('PASS actual-init combat-event integration: '..f.count()..' assertions')
