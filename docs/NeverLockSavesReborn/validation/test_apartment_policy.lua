-- Public scheduler contract for the source-backed original V apartment trigger.
-- Pure Lua only; Game/CET/REDscript observations are boundary data.
local policy=assert(loadfile(assert(arg[1],'scheduler module path required')))()
local n=0
local function eq(actual,expected,label)
  n=n+1;assert(actual==expected,(label or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function check(value,label) n=n+1;assert(value,label) end
local function observations()
  return {session=4,playerReady=true,introComplete=true,bridgeReady=true,paused=false,
    combatKnown=true,combatActive=false,vehicleKnown=true,vehicleActive=false,
    phoneKnown=true,phoneActive=false,nativeUnlocked=true,stableReady=true,queueBusy=false,
    apartmentKnown=true,apartmentInside=false}
end
local function state(extra)
  local s=policy.new()
  local options={enabled=true,exploration=false,postCombat=false,vehicleExit=false,
    questMilestone=false,apartmentEntry=true,intervalSeconds=60,cooldownSeconds=30}
  for k,v in pairs(extra or {}) do options[k]=v end
  check(policy.configure(s,options),'valid apartment trigger configuration')
  return s
end
local function tick(s,p,cb,delta) return policy.tick(s,delta or .25,p,cb) end
local function advance(s,p,seconds,cb) for _=1,seconds*4 do tick(s,p,cb) end end
local function ready(extra)
  local s,p=state(extra),observations();tick(s,p);advance(s,p,30);return s,p
end
local function enter(s,p,cb) p.apartmentInside=true;return tick(s,p,cb) end
local function pending()
  local s,p=ready();p.nativeUnlocked=false;p.stableReady=false
  enter(s,p)
  eq(policy.status(s).pendingReason,'apartment_entry','known entry captures bounded work')
  return s,p
end

-- Configuration is individually opt-in and atomic; unknown optional data is
-- irrelevant when the apartment trigger is disabled.
do
  local s=policy.new();eq(policy.status(s).apartmentEntry,false,'apartment trigger defaults off')
  check(policy.configure(s,{enabled=true,intervalSeconds=60,cooldownSeconds=30}))
  local p=observations();p.apartmentKnown=nil;p.apartmentInside=nil
  tick(s,p);local calls=0;advance(s,p,61,function() calls=calls+1;return true end)
  eq(calls,1,'disabled apartment trigger cannot break existing exploration')
  for _,value in ipairs({1,0,'true','false',{}}) do
    eq(policy.configure(s,{apartmentEntry=value}),false,'invalid option type refused')
    eq(policy.status(s).apartmentEntry,false,'invalid config has no partial change')
  end
end

do
  local s,p=ready({apartmentEntry=false});local calls=0
  enter(s,p,function() calls=calls+1;return true end)
  advance(s,p,60,function() calls=calls+1;return true end)
  eq(calls,0,'disabled apartment option creates no entry request')
end
do
  local s,p=state({enabled=false}),observations();local calls=0
  local cb=function() calls=calls+1;return true end
  tick(s,p,cb);advance(s,p,60,cb);enter(s,p,cb);advance(s,p,60,cb)
  eq(calls,0,'master off suppresses apartment trigger')
end

-- Starting or enabling inside is baseline only, not an entry. Constant inside
-- never replays a callback; later known outside->inside is a genuine new event.
do
  local s,p=state(),observations();p.apartmentInside=true
  local calls=0;local function cb(reason,session)
    calls=calls+1;eq(reason,'apartment_entry','precise trigger reason');eq(session,4,'same session');return true
  end
  tick(s,p,cb);advance(s,p,120,cb);eq(calls,0,'initial inside observation creates no request')
  p.apartmentInside=false;tick(s,p,cb)
  eq(enter(s,p,cb),'queue_request_accepted','known outside-to-inside accepted')
  eq(calls,1,'one request per edge')
  advance(s,p,120,cb);eq(calls,1,'remaining inside never creates repeats')
  eq(policy.status(s).checkpointSubmission,'Unknown','handoff is not engine submission')
  eq(policy.status(s).written,'Unknown','handoff is not written evidence')
  eq(policy.status(s).reload,'Unknown','handoff is not reload evidence')
end

-- Shared cooldown drops entry events during the window. There is no deferred
-- catch-up after staying inside; another outside->inside is required.
do
  local s,p=ready();local calls=0;local cb=function()calls=calls+1;return true end
  enter(s,p,cb);eq(calls,1)
  p.apartmentInside=false;tick(s,p,cb);enter(s,p,cb);eq(calls,1,'shared cooldown wins')
  advance(s,p,45,cb);eq(calls,1,'entry during cooldown does not catch up later')
  p.apartmentInside=false;tick(s,p,cb);enter(s,p,cb);eq(calls,2,'later new entry may hand off')
end

-- Captured work waits for native permission/stability, expires, and is discarded
-- when the player leaves the apartment before readiness.
do
  local s,p=pending();local calls=0;local cb=function()calls=calls+1;return true end
  p.nativeUnlocked=true;tick(s,p,cb);eq(calls,0,'entry does not bypass stabilization')
  p.stableReady=true;tick(s,p,cb);eq(calls,1,'stable native unlock accepts one handoff')
  advance(s,p,10,cb);eq(calls,1,'pending is consumed once')
end
do
  local s,p=pending();local calls=0;local cb=function()calls=calls+1;return true end
  advance(s,p,30,cb);eq(policy.status(s).pendingReason,'none','apartment event TTL expires')
  p.nativeUnlocked=true;p.stableReady=true;advance(s,p,40,cb)
  eq(calls,0,'expired entry cannot resurrect')
end
do
  local s,p=pending();p.apartmentInside=false;tick(s,p)
  eq(policy.status(s).pendingReason,'none','leaving before readiness cancels apartment work')
  p.nativeUnlocked=true;p.stableReady=true;local calls=0
  advance(s,p,45,function()calls=calls+1;return true end)
  eq(calls,0,'no late apartment request after leaving')
end

-- Unknown/malformed location data interrupts only when the new trigger is on.
-- It cannot become an entry upon returning directly to an inside state.
for _,change in ipairs({
  function(p)p.apartmentKnown=false end,function(p)p.apartmentKnown=nil end,
  function(p)p.apartmentKnown='true' end,function(p)p.apartmentInside=nil end,
  function(p)p.apartmentInside=1 end,function(p)p.apartmentInside='true' end}) do
  local s,p=pending();change(p);tick(s,p)
  eq(policy.status(s).pendingReason,'none','unknown apartment data cancels captured event')
  p.apartmentKnown=true;p.apartmentInside=true;p.nativeUnlocked=true;p.stableReady=true
  local calls=0;advance(s,p,45,function()calls=calls+1;return true end)
  eq(calls,0,'unknown-to-inside is baseline only')
end

-- Every existing safety interruption must discard pending apartment work.
for _,change in ipairs({
  function(p)p.paused=true end,function(p)p.queueBusy=true end,function(p)p.phoneActive=true end,
  function(p)p.combatActive=true end,function(p)p.vehicleActive=true end,
  function(p)p.playerReady=false end,function(p)p.introComplete=false end,
  function(p)p.bridgeReady=false end,function(p)p.session=5 end,
  function(p)p.nativeUnlocked=nil end,function(p)p.stableReady=nil end}) do
  local s,p=pending();change(p);tick(s,p)
  eq(policy.status(s).pendingReason,'none','readiness interruption clears apartment event')
  local fresh=observations();fresh.apartmentInside=true
  local calls=0;advance(s,fresh,45,function()calls=calls+1;return true end)
  eq(calls,0,'interruption cannot replay an old entry')
end
do
  local s,p=pending();tick(s,p,nil,2)
  eq(policy.status(s).pendingReason,'none','long frame clears apartment work')
  p.nativeUnlocked=true;p.stableReady=true;local calls=0
  advance(s,p,45,function()calls=calls+1;return true end)
  eq(calls,0,'long frame cannot catch up')
end

-- A player's pending queue always wins over a same-frame entry event and
-- rearms the shared cooldown after that player work clears.
do
  local s,p=ready();p.queueBusy=true
  local calls=0;local cb=function()calls=calls+1;return true end
  enter(s,p,cb);eq(calls,0,'manual queue outranks apartment entry')
  p.queueBusy=false;advance(s,p,45,cb);eq(calls,0,'clearing player queue cannot resurrect entry')
end

-- Disabling/reconfiguring and reset never retain stale location identity.
do
  local s,p=pending();check(policy.configure(s,{apartmentEntry=false}))
  p.nativeUnlocked=true;p.stableReady=true
  local calls=0;advance(s,p,45,function()calls=calls+1;return true end)
  eq(calls,0,'disabled apartment option discards old work')
  check(policy.configure(s,{apartmentEntry=true}));tick(s,p)
  advance(s,p,45,function()calls=calls+1;return true end)
  eq(calls,0,'enabling inside cannot create entry')
end

print('PASS apartment scheduler: '..n..' public-boundary assertions; no game/save evidence')
