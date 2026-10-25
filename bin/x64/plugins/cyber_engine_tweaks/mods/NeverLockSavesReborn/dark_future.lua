-- Optional, read-only adapter for the inspected Dark Future 2.x source snapshot.
-- DF gameplay validity is NOT save permission. Never write settings, needs,
-- quest facts, status effects, or save policy from this module.
local adapter = {}

function adapter.sample(player)
  local snapshot = {status = 'WAITING: no player'}
  if not player then return snapshot end

  -- Resolve every sample: no cached handles may survive load/session changes.
  local ok, service = pcall(function()
    return Game.GetScriptableSystemsContainer():Get('DarkFuture.Services.DFGameStateService')
  end)
  if not ok then
    snapshot.status = 'UNKNOWN: system lookup failed'
    snapshot.error = tostring(service)
    return snapshot
  end
  if not service then
    snapshot.status = 'NOT DETECTED: not installed or not initialized'
    return snapshot
  end

  local ready, state, enabled, attachedPlayer = pcall(function()
    -- DFSystem.state is public. CET Enum.value returns the value NAME.
    local lifecycle = service.state.value
    local settings = service.Settings
    return lifecycle, settings and settings.mainSystemEnabled, service.player
  end)
  if not ready then
    snapshot.status = 'UNKNOWN: lifecycle/settings unavailable'
    snapshot.error = tostring(state)
    return snapshot
  end
  snapshot.lifecycle = state
  if type(enabled) ~= 'boolean' then
    snapshot.status = 'WAITING: Dark Future settings not ready'
    return snapshot
  end
  snapshot.enabled = enabled
  if not enabled then
    snapshot.status = 'DISABLED: Dark Future master switch is off'
    return snapshot
  end
  if state == 'Uninitialized' or state == 'Suspended' then
    snapshot.status = 'WAITING: Dark Future '..state
    return snapshot
  end
  if state ~= 'Running' then
    snapshot.status = 'UNKNOWN: unrecognized Dark Future lifecycle'
    return snapshot
  end
  if attachedPlayer ~= player then
    snapshot.status = 'WAITING: Dark Future player attachment'
    return snapshot
  end

  local sampled, valid, sleeping, inMenu = pcall(function()
    -- GetGameState dereferences Settings and caller. Query only a running service.
    -- false,false = strict gameplay validity (no ignored temporary/limited state).
    return service:IsValidGameState(player, false, false),
      service:GetSleepingInVehicle(), service:IsInAnyMenu()
  end)
  if not sampled then
    snapshot.status = 'UNKNOWN: gameplay query failed'
    snapshot.error = tostring(valid)
    return snapshot
  end
  if type(valid) ~= 'boolean' or type(sleeping) ~= 'boolean' or type(inMenu) ~= 'boolean' then
    snapshot.status = 'UNKNOWN: unexpected gameplay query result'
    return snapshot
  end
  snapshot.valid = valid
  snapshot.sleepingInVehicle = sleeping
  snapshot.inMenu = inMenu
  snapshot.status = 'READABLE: Dark Future gameplay state sampled'
  return snapshot
end

function adapter.describe(snapshot)
  local function flag(value)
    if type(value) ~= 'boolean' then return 'UNKNOWN' end
    return value and 'true' or 'false'
  end
  return (snapshot.status or 'UNKNOWN')..' | lifecycle='..tostring(snapshot.lifecycle or 'UNKNOWN')..
    ' | enabled='..flag(snapshot.enabled)..' | gameplayValid='..flag(snapshot.valid)..
    ' | sleepingInVehicle='..flag(snapshot.sleepingInVehicle)..' | inMenu='..flag(snapshot.inMenu)
end

return adapter
