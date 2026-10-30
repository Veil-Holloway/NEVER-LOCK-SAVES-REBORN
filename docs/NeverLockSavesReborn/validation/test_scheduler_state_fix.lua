-- Focused regression for scheduler blocker idempotence and support-report state separation.
local root=assert(arg[1],'release root required')
local mod=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
package.path=mod..'?.lua;'..package.path
local policy=require('autosave_policy')
local report=require('support_report')
local n=0
local function check(v,m)n=n+1;assert(v,m or ('assertion '..n))end
local function eq(a,b,m)check(a==b,(m or 'value')..': '..tostring(a)..' != '..tostring(b))end
local function snap()
  return {session=7,playerReady=true,introComplete=true,bridgeReady=true,paused=false,
    combatKnown=true,combatActive=false,vehicleKnown=true,vehicleActive=false,
    phoneKnown=true,phoneActive=false,nativeUnlocked=true,stableReady=true,queueBusy=false}
end
local s=policy.new();check(policy.configure(s,{enabled=true,intervalSeconds=60,cooldownSeconds=30}))
local p=snap();policy.tick(s,.25,p)
local before=policy.status(s)
p.phoneKnown=false
policy.tick(s,.25,p)
local first=policy.status(s)
for _=1,2000 do policy.tick(s,.25,p) end
local after=policy.status(s)
eq(after.resets,first.resets,'persistent unknown sensor is not a reset storm')
eq(after.blockedTransitions,first.blockedTransitions,'persistent blocker is idempotent')
eq(after.blockedReason,'phone unknown','phone blocker remains observable')
check(after.blockedTransitions>=1,'block transition counted')
p.phoneKnown=true;p.phoneActive=false
policy.tick(s,.25,p)
local recovered=policy.status(s)
eq(recovered.blockedReason,'none','valid sample clears blocker')
eq(recovered.reason,'session baseline','recovery requires fresh baseline')

local r=report.build({build='1.0.0-scheduler-state.1',sensors={combatKnown=true,combatActive=false,
  vehicleKnown=true,vehicleActive=true,phoneKnown=false,phoneActive=false,phoneBridgeStatus='bridge_unknown',phoneRawState=-1,
  autosavePhoneBridgeStatus='bridge_unknown',autosavePhoneRawState=-1,autosavePhoneSource='phone_manager',paused=false,inMenu=false},
  queue={pending=false,source='unknown',serial=0,session=7,gate='idle',state='Submitted',currentState='Idle',lastOutcomeState='Submitted',lastOutcomeReason='submitted',retention='none'},
  autosave={enabled=true,status='waiting',reason='phone unknown',resets=before.resets,blockedTransitions=after.blockedTransitions,blockedReason='phone unknown'}})
eq(r.queue.current_state,'Idle','live queue is explicitly idle')
eq(r.queue.last_outcome_state,'Submitted','historical submitted outcome remains separate')
eq(r.queue.state_scope,'legacy_last_observed_phase','legacy queue state is labelled')
eq(r.context.phone,'unknown','unknown phone remains conservative')
eq(r.context.phone_evidence.status,'bridge_unknown','phone bridge diagnostic explains unknown')
eq(r.context.phone_evidence.raw_state,-1,'raw tri-state is bounded and retained')
eq(r.context.phone_evidence.autosave_source,'phone_manager','phone evidence source retained')
eq(r.autosave.blocked_reason,'phone_unknown','scheduler blocker normalized')
print('PASS scheduler-state focused regression: '..n..' assertions')
