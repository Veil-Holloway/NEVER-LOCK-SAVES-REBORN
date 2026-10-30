-- Run: texlua test_autosave_policy.lua /absolute/path/autosave_policy.lua
local modulePath = assert(arg[1], 'module path required')
local policy = assert(loadfile(modulePath))()
local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message or ('assertion '..assertions))
end
local function eq(actual, expected, message)
  check(actual == expected, (message or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function copy(t)
  local c = {}; for k,v in pairs(t) do c[k] = v end; return c
end
local function snapshot()
  return {session=1, playerReady=true, introComplete=true, bridgeReady=true,
    paused=false, nativeUnlocked=true, stableReady=true, queueBusy=false,
    combatKnown=true, combatActive=false, vehicleKnown=true, vehicleActive=false,
    phoneKnown=true, phoneActive=false}
end
local function new(options)
  local s=policy.new()
  check(policy.configure(s,options or {enabled=true,intervalSeconds=60,cooldownSeconds=30}))
  return s
end
local function tick(s,p,callback,delta)
  return policy.tick(s,delta or 0.25,p,callback)
end
local function advance(s,p,seconds,callback)
  for _=1,seconds*4 do tick(s,p,callback) end
end
local function fixture()
  local s,p=new(),snapshot()
  tick(s,p)
  advance(s,p,30)
  return s,p
end
local function pendingEvent()
  local s,p=fixture()
  p.combatActive=true; p.nativeUnlocked=false; p.stableReady=false
  tick(s,p)
  p.combatActive=false
  tick(s,p)
  eq(policy.status(s).pendingReason,'post_combat','captured event')
  return s,p
end

-- Missing feature negative control: alpha2 has no scheduler module at this path.
do
  local s,p=policy.new(),snapshot()
  local calls=0
  advance(s,p,600,function() calls=calls+1; return true end)
  eq(calls,0,'default off has no requests')
  eq(policy.status(s).enabled,false)
  eq(policy.status(s).status,'disabled')
end

-- Config validation is atomic, bounded, rejects falsey coercion and unknown keys.
do
  local s=new()
  local invalid={
    {intervalSeconds=59}, {intervalSeconds=1801}, {intervalSeconds=60.5},
    {intervalSeconds=0/0}, {intervalSeconds=math.huge}, {cooldownSeconds=29},
    {cooldownSeconds=601}, {cooldownSeconds='60'}, {enabled=1},
    {postCombat='yes'}, {vehicleExit=0}, {exploration=1}, {questMilestone='true'}, {inventedTrigger=true}}
  for _,options in ipairs(invalid) do
    local ok=policy.configure(s,options)
    eq(ok,false,'invalid configuration refused')
    eq(policy.status(s).intervalSeconds,60,'invalid config preserves active interval')
  end
  check(policy.configure(s,{intervalSeconds=1800,cooldownSeconds=600,postCombat=false}))
  eq(policy.status(s).intervalSeconds,1800)
  eq(policy.status(s).cooldownSeconds,600)
  eq(policy.status(s).postCombat,false)
  local options={intervalSeconds=120}; check(policy.configure(s,options)); options.intervalSeconds=60
  eq(policy.status(s).intervalSeconds,120,'caller cannot mutate configuration')
end

-- Quest completion events are separately opt-in and cannot bypass readiness.
do
  local s,p=fixture(); local calls=0
  p.questMilestone=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'quest event default off')
  eq(policy.status(s).questMilestone,false)
end
local function questFixture()
  local s=new({enabled=true,intervalSeconds=60,cooldownSeconds=30,
    exploration=false,postCombat=false,vehicleExit=false,questMilestone=true})
  local p=snapshot()
  tick(s,p); advance(s,p,30)
  return s,p
end
do
  local s,p=questFixture(); local calls=0
  p.questMilestone=true
  eq(tick(s,p,function(reason,session)
    calls=calls+1; eq(reason,'quest_milestone'); eq(session,1); return true
  end),'queue_request_accepted')
  eq(calls,1,'fresh verified event schedules once')
  eq(policy.status(s).status,'queue_request_accepted','queue acceptance has its own status')
  eq(policy.status(s).checkpointSubmission,'Unknown','queue acceptance does not prove engine submission')
  p.questMilestone=nil
  advance(s,p,120,function() calls=calls+1; return true end)
  eq(calls,1,'no completion-state polling or initial scanning')
end
do
  for _,value in ipairs({false,1,'true',{},0/0}) do
    local s,p=questFixture(); local calls=0
    p.questMilestone=value
    tick(s,p,function() calls=calls+1; return true end)
    eq(calls,0,'only literal true is a verified quest event')
  end
end
do
  local s,p=questFixture(); local calls=0
  p.questMilestone=true; p.nativeUnlocked=false; p.stableReady=false
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'quest event cannot bypass native gate')
  eq(policy.status(s).pendingReason,'quest_milestone')
  p.questMilestone=nil; p.nativeUnlocked=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'quest event cannot bypass stabilization')
  p.stableReady=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,1)
end
for _,interruption in ipairs({'session','paused','queueBusy','introComplete','stall'}) do
  local s,p=questFixture(); local calls=0
  p.questMilestone=true; p.nativeUnlocked=false; p.stableReady=false
  tick(s,p)
  eq(policy.status(s).pendingReason,'quest_milestone')
  p.questMilestone=nil
  if interruption=='session' then p.session=2
  elseif interruption=='paused' or interruption=='queueBusy' then p[interruption]=true
  elseif interruption=='introComplete' then p.introComplete=false end
  tick(s,p,function() calls=calls+1; return true end,interruption=='stall' and 2 or 0.25)
  eq(policy.status(s).pendingReason,'none','interruption clears quest event')
  p.nativeUnlocked=true; p.stableReady=true; p.paused=false; p.queueBusy=false; p.introComplete=true
  advance(s,p,90,function() calls=calls+1; return true end)
  eq(calls,0,'suspended/reloaded event never resumes')
end
do
  local s,p=questFixture(); local calls=0
  p.questMilestone=true; p.nativeUnlocked=false; p.stableReady=false
  tick(s,p)
  p.questMilestone=nil
  advance(s,p,30)
  eq(policy.status(s).pendingReason,'none','quest event deadline expires')
  p.nativeUnlocked=true; p.stableReady=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'late readiness cannot resurrect a quest event')
end
do
  local s,p=questFixture(); local calls=0
  check(policy.reset(s,1,'load boundary'))
  p.questMilestone=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'first sample after load cannot schedule a buffered event')
  p.questMilestone=nil
  advance(s,p,90,function() calls=calls+1; return true end)
  eq(calls,0,'buffered event is discarded rather than delayed after load')
end
do
  local s,p=questFixture(); local calls=0
  p.questMilestone=true; p.combatActive=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(policy.status(s).pendingReason,'none','active combat discards quest event')
  p.questMilestone=nil; p.combatActive=false
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'combat ending cannot resurrect discarded quest event')
end

-- Exploration counts only active small frames and submits once per cadence.
do
  local s,p=new(),snapshot(); local calls=0; local reasons={}
  local cb=function(reason,session) calls=calls+1; reasons[#reasons+1]=reason; eq(session,1); return true end
  tick(s,p,cb)
  advance(s,p,59.75,cb); eq(calls,0,'before exploration cadence')
  tick(s,p,cb); eq(calls,1,'cadence fires once')
  eq(reasons[1],'exploration_interval')
  advance(s,p,59.75,cb); eq(calls,1,'no repeated request within cadence')
  tick(s,p,cb); eq(calls,2)
  eq(policy.status(s).accepted,2)
  eq(policy.status(s).checkpointSubmission,'Unknown','queue handoff is not engine dispatch')
  eq(policy.status(s).written,'Unknown')
  eq(policy.status(s).reload,'Unknown')
end

-- A known transition while engine locks clear becomes one bounded pending request.
do
  local s,p=pendingEvent(); local calls=0
  advance(s,p,2,function() calls=calls+1; return true end)
  eq(calls,0,'locked pending cannot dispatch')
  p.nativeUnlocked=true
  advance(s,p,1,function() calls=calls+1; return true end)
  eq(calls,0,'unstable native unlock cannot dispatch')
  p.stableReady=true
  eq(tick(s,p,function(reason) calls=calls+1; eq(reason,'post_combat'); return true end),'queue_request_accepted')
  eq(calls,1)
  advance(s,p,20,function() calls=calls+1; return true end)
  eq(calls,1,'postcombat deduplicated')
end
do
  local s,p=fixture(); local reason
  p.vehicleActive=true; tick(s,p)
  p.vehicleActive=false; tick(s,p,function(r) reason=r; return true end)
  eq(reason,'vehicle_exit')
end
do
  local s,p=fixture(); local reason
  p.vehicleActive=true; p.combatActive=true; tick(s,p)
  p.vehicleActive=false; p.combatActive=false
  tick(s,p,function(r) reason=r; return true end)
  eq(reason,'post_combat','simultaneous edges have one stable priority')
  eq(policy.status(s).accepted,1)
end

-- TTL does not grow while waiting; a late unlock cannot resurrect a trigger.
do
  local s,p=pendingEvent(); local calls=0
  advance(s,p,30,function() calls=calls+1; return true end)
  eq(policy.status(s).pendingReason,'none')
  p.nativeUnlocked=true; p.stableReady=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'expired edge is never submitted')
end

-- Player request, phone, resumed combat/vehicle cancel even a captured event.
for _,field in ipairs({'queueBusy','phoneActive','combatActive','vehicleActive'}) do
  local s,p=pendingEvent(); local calls=0
  p[field]=true; tick(s,p,function() calls=calls+1; return true end)
  eq(policy.status(s).pendingReason,'none',field..' clears captured trigger')
  p[field]=false; p.nativeUnlocked=true; p.stableReady=true
  -- New combat/vehicle true->false is a new real edge, not resurrection.
  if field=='combatActive' or field=='vehicleActive' then
    tick(s,p,function() calls=calls+1; return true end)
    eq(calls,1,'new edge may request')
  else
    tick(s,p,function() calls=calls+1; return true end)
    eq(calls,0,field..' no stale request')
  end
end
do
  local s,p=fixture(); local calls=0
  p.queueBusy=true; p.combatActive=true; tick(s,p)
  p.queueBusy=false; p.combatActive=false
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'a user queue finishing cannot cause an immediate automatic request')
  check(policy.status(s).cooldownRemaining>0,'user work rearms automatic cooldown')
end

-- Unknown/invalid safety data resets timer, edges, pending and warmup.
local invalidFields={playerReady=false,introComplete=false,bridgeReady=false,paused=true,
  combatKnown=false,vehicleKnown=false,phoneKnown=false,combatActive='false',
  vehicleActive=0,phoneActive=1,nativeUnlocked='true',stableReady=1,queueBusy=0,
  session=0}
for field,value in pairs(invalidFields) do
  local s,p=pendingEvent(); local calls=0
  local bad=copy(p); bad[field]=value
  tick(s,bad,function() calls=calls+1; return true end)
  eq(policy.status(s).pendingReason,'none',field..' invalid clears pending')
  p.nativeUnlocked=true; p.stableReady=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,field..' requires new baseline')
end
for _,field in ipairs({'playerReady','introComplete','bridgeReady','paused','combatKnown',
  'vehicleKnown','phoneKnown','combatActive','vehicleActive','phoneActive','nativeUnlocked',
  'stableReady','queueBusy','session'}) do
  local s,p=pendingEvent(); local calls=0
  p[field]=nil; tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,field..' nil cannot dispatch')
  eq(policy.status(s).pendingReason,'none')
end

-- Repeated unchanged blockers are idempotent: one transition, no per-frame reset storm.
do
  local s,p=fixture(); local before=policy.status(s)
  p.phoneKnown=false
  tick(s,p)
  local first=policy.status(s)
  for _=1,1000 do tick(s,p) end
  local after=policy.status(s)
  eq(after.resets,first.resets,'unchanged phone blocker does not increment resets each frame')
  eq(after.blockedTransitions,first.blockedTransitions,'unchanged phone blocker records one transition')
  eq(after.blockedReason,'phone unknown','blocker remains diagnosable')
  p.phoneKnown=true;p.phoneActive=false
  tick(s,p)
  eq(policy.status(s).blockedReason,'none','valid sample clears blocker')
  eq(policy.status(s).reason,'session baseline','recovery establishes fresh edge baseline')
end
do
  local s,p=fixture();p.phoneKnown=false;tick(s,p);local one=policy.status(s).blockedTransitions
  p.phoneKnown=true;p.phoneActive=false;tick(s,p)
  p.vehicleKnown=false;tick(s,p)
  eq(policy.status(s).blockedTransitions,one+1,'different blocker records a new transition')
  eq(policy.status(s).blockedReason,'vehicle unknown')
end

-- Pauses, stalls, invalid times and session changes never accrue a catchup burst.
for _,delta in ipairs({1.001,10,-1,0/0,math.huge}) do
  local s,p=pendingEvent(); local calls=0
  tick(s,p,function() calls=calls+1; return true end,delta)
  eq(policy.status(s).pendingReason,'none','bad delta clears pending')
  p.nativeUnlocked=true; p.stableReady=true
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0)
end
do
  local s,p=pendingEvent(); p.session=2; p.nativeUnlocked=true; p.stableReady=true
  local calls=0
  tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'session change drops old event')
  eq(policy.status(s).session,2)
  eq(policy.status(s).elapsedSeconds,0)
  eq(policy.status(s).pendingReason,'none')
end
do
  local s,p=new(),snapshot(); local calls=0
  tick(s,p)
  for _=1,59 do tick(s,p,function() calls=calls+1; return true end,1) end
  eq(calls,0,'frame credit is capped to quarter second')
end

-- Rejection/error retries are bounded and literal true is the only acceptance.
do
  local s,p=pendingEvent(); p.nativeUnlocked=true; p.stableReady=true; local calls=0
  local reject=function() calls=calls+1; return 'true' end
  eq(tick(s,p,reject),'request_rejected'); eq(calls,1)
  advance(s,p,4.75,reject); eq(calls,1,'no perframe rejection loop')
  tick(s,p,reject); eq(calls,2,'retry after five active seconds')
  eq(policy.status(s).rejected,2)
  eq(policy.status(s).accepted,0)
  advance(s,p,5,function() calls=calls+1; error('injected boundary failure') end)
  eq(calls,3); eq(policy.status(s).errors,1)
  advance(s,p,5,function() calls=calls+1; return true end)
  eq(calls,4); eq(policy.status(s).accepted,1)
end
do
  local s,p=pendingEvent(); p.nativeUnlocked=true; p.stableReady=true
  tick(s,p)
  eq(policy.status(s).accepted,0,'missing callback does not consume trigger')
  eq(policy.status(s).pendingReason,'post_combat')
end

-- Reentrant callbacks and configuration changes cannot restore consumed/stale work.
do
  local s,p=pendingEvent(); p.nativeUnlocked=true; p.stableReady=true; local calls=0
  local callback
  callback=function()
    calls=calls+1
    eq(tick(s,p,callback),'dispatching','reentrant tick blocked')
    return true
  end
  tick(s,p,callback)
  eq(calls,1); eq(policy.status(s).pendingReason,'none')
end
do
  local s,p=pendingEvent(); p.nativeUnlocked=true; p.stableReady=true
  tick(s,p,function() check(policy.configure(s,{enabled=false})); return false end)
  eq(policy.status(s).enabled,false)
  eq(policy.status(s).pendingReason,'none','callback disable cannot restore pending')
end

-- Options and reset clear runtime work; all reported data is bounded and detached.
do
  local s,p=pendingEvent()
  check(policy.configure(s,{postCombat=false,vehicleExit=false,exploration=false}))
  p.nativeUnlocked=true; p.stableReady=true; local calls=0
  advance(s,p,300,function() calls=calls+1; return true end)
  p.combatActive=true; tick(s,p); p.combatActive=false; tick(s,p,function() calls=calls+1; return true end)
  p.vehicleActive=true; tick(s,p); p.vehicleActive=false; tick(s,p,function() calls=calls+1; return true end)
  eq(calls,0,'all trigger switches are effective')
  local report=policy.status(s); report.enabled=false
  eq(policy.status(s).enabled,true,'status copy is detached')
  for _,value in pairs(report) do check(type(value)~='table' and type(value)~='function','scalar report only') end
  check(policy.reset(s,1,'user reset'))
  eq(policy.status(s).pendingReason,'none')
  eq(policy.status(s).elapsedSeconds,0)
end
print('AUTOSAVE_POLICY_ASSERTIONS='..assertions)
