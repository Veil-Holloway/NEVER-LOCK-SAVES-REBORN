local root=assert(arg[1]);local dir=assert(arg[0]):gsub('[^/]+$','')
local f=dofile(dir..'guardian_trace_fixture.lua');local check=f.check
local function last(h)local r=h:report().guardian.records;return r[#r]end
local function ledger(h)h:press('Export Guardian report##nls_guardian_export');return h.files['guardian-report.json']end
-- The real event driver/coordinator are unchanged in behavior with tracing enabled.
for _,mounted in ipairs({0,1})do
 local h=f.fixture({ttl=1});h.mounted=mounted;h.combat=true;h.unlocked=false;h:queue(2);h:run(600)
 local r=last(h)
 check(r and r.phase=='Waiting' and r.reason=='combat_active','actual-init specific Guardian combat wait')
 check(r.source=='quicksave','generic quicksave source without invented wrapper subtype')
 check(r.observed_age_seconds>=599,'actual-init observed age from coordinator clock')
 check(h.player.pending and h.dispatches==0,'trace does not introduce expiry')
 h.combat=false;h.unlocked=true;h.relock=true;h:signal('OnCombatStateChanged',nil,2);h:run(4)
 r=last(h);check(r.phase=='Waiting','actual-init preflight refusal not stuck Executing')
 check(h.checkpointAttempts==0 and h.player.pending,'final preflight never entered engine helper')
 local found=false;for _,t in ipairs(ledger(h).transitions)do
  if t.reason=='native_permission_changed' and t.phase=='Waiting'then found=true end
 end
 check(found,'verified-preflight transition recorded in same trace')
 local trace=r.id;h.relock=false;h.unlocked=true;h:run(4)
 r=last(h);check(r.id==trace and r.phase=='Submitted','one accepted attempt retains trace')
 check(h.dispatches==1 and h.checkpointAttempts==1,'one engine-boundary call after final unlock')
 check(r.awaiting_write_evidence and r.write_status=='Unknown','accepted never promoted to written')
 local callback=h.observers['gameuiInGameMenuGameController.OnSavingComplete'];check(type(callback)=='function','existing completion target registered')
 callback({},true);h:step()
 local report=h:report();local hints=report.guardian.uncorrelated_hints
 check(#hints==1 and hints[1].session==h.player.session,'existing hint transported with event session')
 check(hints[1].outcome=='SuccessHint' and hints[1].correlated==false,'uncorrelated success stays separate')
 check(last(h).phase=='Submitted' and last(h).write_status=='Unknown','hint never certifies current request')
 check(h:contains('Accepted, write NOT verified'),'Guardian UI displays evidence boundary')
 check(h:contains('reason: submitted'),'Guardian UI includes reason')
 h:run(10);check(h.dispatches==1,'trace diagnostics never cause retries')
 h:queue(1);h:run(4);check(h.dispatches==2,'next explicit request is not blocked by observational ledger')
 check(h:report().guardian.evidence_summary.submitted_unverified==2,'retained accepted/unverified count')
end
-- Unknown state and user cancellation stay intact.
do local h=f.fixture();h.combat=true;h:queue();h:step();h.combat=false;h.unknownCombat=true;h:run(5)
 check(last(h).reason=='combat_unknown','unknown combat reason retained')
 h:press('Cancel queued request##nls_cancel_overview');h.unknownCombat=false;h:run(8)
 check(h.dispatches==0,'cancelled trace cannot save');check(last(h).phase=='Cancelled','cancellation remains terminal')end
print('PASS Guardian trace integration: '..f.count()..' assertions; actual modules, external game boundaries simulated')
