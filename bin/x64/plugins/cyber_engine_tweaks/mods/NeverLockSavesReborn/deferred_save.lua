-- Deferred queue policy v0.10.4. Host supplies state and request callback.
-- enginePermissionOnly is the explicit experimental native-lock policy.
local M = {}
local MAX_AGE = 30
local function number(x) return type(x) == 'number' and x == x and x ~= math.huge and x ~= -math.huge end
function M.new()
  return {pending=nil, serial=0, lastResult='idle'}
end
function M.request(s, now, source, maxAge)
  assert(type(s)=='table' and number(now), 'invalid queue state or clock')
  assert(source=='manual' or source=='quicksave' or source=='autosave', 'unsupported request source')
  local ttl = maxAge or MAX_AGE
  assert(number(ttl) and ttl>=1 and ttl<=120, 'invalid TTL')
  -- One pending request maximum. Repeated presses replace the earlier request.
  s.serial = s.serial + 1
  s.pending = {id=s.serial, created=now, expires=now+ttl, source=source}
  s.lastResult='queued'
  return s.pending.id
end
function M.cancel(s)
  local had = s.pending ~= nil
  s.pending=nil
  s.lastResult=had and 'cancelled' or 'idle'
  return had
end
function M.tick(s, now, state, callback)
  assert(type(s)=='table' and number(now) and type(state)=='table', 'invalid tick arguments')
  if not s.pending then return 'idle' end
  if now>=s.pending.expires then s.pending=nil; s.lastResult='expired'; return 'expired' end
  -- Only explicitly verified safe state can release a request.
  -- nil/unknown is NOT equivalent to false for any safety flag.
  local engineGate=state.enginePermissionOnly==true
  if state.playerReady~=true or state.introComplete~=true or state.nativeSavingUnlocked~=true
      or (not engineGate and (state.scriptedTransition~=false or state.loading~=false)) then
    s.lastResult='waiting'
    return 'waiting'
  end
  if type(callback)~='function' then s.lastResult='waiting'; return 'waiting' end
  local pending=s.pending
  -- Remove before invoking callback to avoid reentrant duplicate saves.
  s.pending=nil
  local ok, accepted=pcall(callback, pending.source, pending.id)
  if ok and accepted==true then s.lastResult='request_submitted'; return 'request_submitted' end
  s.lastResult='request_failed'
  return 'request_failed'
end
return M
