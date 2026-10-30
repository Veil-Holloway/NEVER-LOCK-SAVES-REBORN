-- Optional Smart Autosave scheduler. Pure policy: the host supplies observations
-- and queues requests; this module cannot call game APIs, perform IO, or prove a save.
local M = {}
local DEFAULTS = {enabled=false, intervalSeconds=300, cooldownSeconds=60,
  exploration=true, postCombat=true, vehicleExit=true, questMilestone=false, apartmentEntry=false}
local PENDING_SECONDS, RETRY_SECONDS, MAX_FRAME_CREDIT = 30, 5, 0.25
local function finite(value)
  return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
end
local function integer(value, low, high)
  return finite(value) and value==math.floor(value) and value>=low and value<=high
end
local function boolean(value) return type(value)=='boolean' end
local function copy(values)
  local result={}; for key,value in pairs(values) do result[key]=value end; return result
end
local function reason(value)
  if type(value)~='string' then return 'reset' end
  return value:gsub('[%c]',' '):sub(1,80)
end
local function requireState(state)
  assert(type(state)=='table' and type(state.options)=='table','invalid autosave state')
end
function M.new()
  return {options=copy(DEFAULTS), session=nil, baseline=nil, elapsedSeconds=0,
    cooldownRemaining=DEFAULTS.cooldownSeconds, retryRemaining=0, pending=nil,
    accepted=0, rejected=0, errors=0, resets=0, blockedTransitions=0, generation=0,
    blockedReason=nil, dispatching=false, status='disabled', reason='disabled'}
end
function M.reset(state, session, why)
  requireState(state)
  if session~=nil and not integer(session,1,2147483647) then return false,'invalid session' end
  state.session=session; state.baseline=nil; state.elapsedSeconds=0
  state.cooldownRemaining=state.options.cooldownSeconds
  state.retryRemaining=0; state.pending=nil; state.blockedReason=nil
  state.resets=state.resets+1; state.generation=state.generation+1
  state.status=state.options.enabled and 'waiting' or 'disabled'
  state.reason=reason(why)
  return true
end
function M.configure(state, options)
  requireState(state)
  if type(options)~='table' then return false,'options must be a table' end
  local candidate=copy(state.options)
  for key,value in pairs(options) do
    if DEFAULTS[key]==nil then return false,'unsupported option' end
    if key=='intervalSeconds' then
      if not integer(value,60,1800) then return false,'interval must be 60..1800 whole seconds' end
    elseif key=='cooldownSeconds' then
      if not integer(value,30,600) then return false,'cooldown must be 30..600 whole seconds' end
    elseif not boolean(value) then return false,'trigger options must be Boolean' end
    candidate[key]=value
  end
  local changed=false
  for key,value in pairs(candidate) do if state.options[key]~=value then changed=true end end
  if changed then state.options=candidate; M.reset(state,nil,'configuration changed') end
  return true
end
local function invalidSnapshot(snapshot, options)
  if type(snapshot)~='table' then return 'observations unavailable' end
  if not integer(snapshot.session,1,2147483647) then return 'session unavailable' end
  if snapshot.playerReady~=true then return 'player unavailable' end
  if snapshot.bridgeReady~=true then return 'bridge unavailable' end
  if snapshot.introComplete~=true then return 'introduction protected or unknown' end
  if snapshot.paused~=false then return 'paused or pause state unknown' end
  for _,sensor in ipairs({'combat','vehicle','phone'}) do
    if snapshot[sensor..'Known']~=true or not boolean(snapshot[sensor..'Active']) then
      return sensor..' unknown'
    end
  end
  if not boolean(snapshot.nativeUnlocked) then return 'native lock state unknown' end
  if not boolean(snapshot.stableReady) then return 'stability state unknown' end
  if not boolean(snapshot.queueBusy) then return 'queue state unknown' end
  if options.apartmentEntry and (snapshot.apartmentKnown~=true or not boolean(snapshot.apartmentInside)) then
    return 'apartment location unknown'
  end
  return nil
end
local function wait(state, why)
  state.status='waiting'; state.reason=why; return 'waiting'
end
-- Unknown/blocked observations are a state, not a per-frame reset command.
-- The first sample entering a blocker clears captured automatic work and edges;
-- repeated samples of the same blocker remain inert until valid data returns.
local function block(state, snapshot, why)
  local session=type(snapshot)=='table' and snapshot.session or nil
  local validSession=integer(session,1,2147483647)
  local changed=state.blockedReason~=why or (validSession and state.session~=session)
  if changed then
    state.baseline=nil; state.elapsedSeconds=0; state.retryRemaining=0; state.pending=nil
    state.cooldownRemaining=state.options.cooldownSeconds
    if validSession then state.session=session end
    state.generation=state.generation+1; state.blockedTransitions=state.blockedTransitions+1
    state.blockedReason=why
  end
  return wait(state,why)
end
local function interrupt(state, snapshot, why)
  return block(state,snapshot,why)
end
function M.tick(state, delta, snapshot, request)
  requireState(state)
  if state.dispatching then return 'dispatching' end
  if not state.options.enabled then
    state.pending=nil; state.baseline=nil; state.elapsedSeconds=0
    state.status='disabled'; state.reason='disabled'
    return 'disabled'
  end
  if not finite(delta) or delta<0 or delta>1 then return interrupt(state,snapshot,'clock interrupted') end
  local invalid=invalidSnapshot(snapshot,state.options)
  if invalid then return interrupt(state,snapshot,invalid) end
  if state.blockedReason~=nil then
    -- First valid sample after a blocker establishes a fresh edge baseline.
    state.blockedReason=nil; state.baseline={combat=snapshot.combatActive,vehicle=snapshot.vehicleActive,apartment=snapshot.apartmentInside}
    state.elapsedSeconds=0; state.retryRemaining=0; state.cooldownRemaining=state.options.cooldownSeconds
    state.status='waiting'; state.reason='session baseline'
    return 'waiting'
  end
  if state.session~=snapshot.session or not state.baseline then
    M.reset(state,snapshot.session,'session baseline')
    state.baseline={combat=snapshot.combatActive, vehicle=snapshot.vehicleActive,
      apartment=snapshot.apartmentInside}
    return wait(state,'session baseline')
  end

  -- Count bounded active game time, never a resumed frame's missed wall time.
  local credit=math.min(delta,MAX_FRAME_CREDIT)
  state.cooldownRemaining=math.max(0,state.cooldownRemaining-credit)
  state.retryRemaining=math.max(0,state.retryRemaining-credit)
  local combatEnded=state.baseline.combat and not snapshot.combatActive
  local vehicleExited=state.baseline.vehicle and not snapshot.vehicleActive
  local apartmentEntered=state.options.apartmentEntry and state.baseline.apartment==false and snapshot.apartmentInside==true
  state.baseline.combat=snapshot.combatActive
  state.baseline.vehicle=snapshot.vehicleActive
  state.baseline.apartment=snapshot.apartmentInside
  if state.pending then
    state.pending.age=state.pending.age+credit
    if state.pending.age>=PENDING_SECONDS then state.pending=nil; state.retryRemaining=0 end
  end
  -- Entry work belongs to this apartment visit, never a later outside state.
  if state.pending and state.pending.reason=='apartment_entry' and snapshot.apartmentInside~=true then
    state.pending=nil; state.retryRemaining=0
  end

  -- User work always wins; active contexts invalidate captured automatic work.
  if snapshot.queueBusy or snapshot.phoneActive or snapshot.combatActive or snapshot.vehicleActive then
    state.pending=nil; state.elapsedSeconds=0; state.retryRemaining=0
    -- A player's queued request may just have dispatched when busy clears.
    -- Give that work a full cooldown instead of immediately adding another save.
    if snapshot.queueBusy then state.cooldownRemaining=state.options.cooldownSeconds end
    return wait(state,snapshot.queueBusy and 'player queue has priority' or
      snapshot.phoneActive and 'phone active' or snapshot.combatActive and 'combat active' or 'vehicle active')
  end
  if not state.pending and state.cooldownRemaining<=0 then
    if combatEnded and state.options.postCombat then state.pending={reason='post_combat',age=0}
    elseif vehicleExited and state.options.vehicleExit then state.pending={reason='vehicle_exit',age=0}
    -- The host supplies a freshly drained, source-verified completion event.
    -- This is an event, not a quest-state scan; the adapter owns deduplication
    -- and clears buffered events across suspend/load/session boundaries.
    elseif state.options.questMilestone and snapshot.questMilestone==true then
      state.pending={reason='quest_milestone',age=0}
    elseif apartmentEntered then
      state.pending={reason='apartment_entry',age=0}
    end
  end
  if not snapshot.nativeUnlocked or not snapshot.stableReady then
    state.elapsedSeconds=0
    if state.pending and state.pending.reason=='exploration_interval' then state.pending=nil; state.retryRemaining=0 end
    return wait(state,not snapshot.nativeUnlocked and 'native save lock' or 'native unlock stabilizing')
  end

  if state.options.exploration then
    state.elapsedSeconds=math.min(state.options.intervalSeconds,state.elapsedSeconds+credit)
    if not state.pending and state.elapsedSeconds>=state.options.intervalSeconds and state.cooldownRemaining<=0 then
      state.pending={reason='exploration_interval',age=0}
    end
  else state.elapsedSeconds=0 end
  if not state.pending then return wait(state,state.cooldownRemaining>0 and 'cooldown' or 'watching supported triggers') end
  if state.retryRemaining>0 then return wait(state,'retry delay') end
  if type(request)~='function' then return wait(state,'request callback unavailable') end

  -- Consume before calling the host so reentrant callbacks cannot submit twice.
  local pending=state.pending
  local generation=state.generation
  state.pending=nil; state.dispatching=true
  local ok,accepted=pcall(request,pending.reason,state.session)
  state.dispatching=false
  if ok and accepted==true then
    state.accepted=state.accepted+1
    if state.generation==generation then
      state.elapsedSeconds=0; state.cooldownRemaining=state.options.cooldownSeconds
      state.retryRemaining=0; state.status='queue_request_accepted'; state.reason=pending.reason
    end
    return 'queue_request_accepted'
  end
  if ok then state.rejected=state.rejected+1 else state.errors=state.errors+1 end
  if state.generation==generation then
    state.pending=pending; state.retryRemaining=RETRY_SECONDS
    state.status=ok and 'request_rejected' or 'request_error'
    state.reason=ok and 'host did not accept request' or 'host request failed'
  end
  return ok and 'request_rejected' or 'request_error'
end
function M.status(state)
  requireState(state)
  local report=copy(state.options)
  report.status=state.status; report.reason=state.reason; report.session=state.session or 0
  report.elapsedSeconds=state.elapsedSeconds; report.cooldownRemaining=state.cooldownRemaining
  report.retryRemaining=state.retryRemaining
  report.pendingReason=state.pending and state.pending.reason or 'none'
  report.pendingRemaining=state.pending and math.max(0,PENDING_SECONDS-state.pending.age) or 0
  report.accepted=state.accepted; report.rejected=state.rejected; report.errors=state.errors; report.resets=state.resets
  report.blockedTransitions=state.blockedTransitions; report.blockedReason=state.blockedReason or 'none'
  -- Acceptance counts host queue handoffs, never engine dispatch or completion.
  report.checkpointSubmission='Unknown'; report.written='Unknown'; report.reload='Unknown'
  return report
end
return M
