-- Session-scoped wake-up coordinator. No game objects are retained and no saving,
-- file I/O or UI work occurs inside an observer callback. Live reads remain the
-- host's responsibility; event values are wake hints, never save permission.
local M = {}
local function finite(v)
  return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge
end
local LIMIT = 2147483647
local function inc(v) return math.min(LIMIT,v+1) end
function M.new(sessionOf)
  assert(type(sessionOf)=='function','session resolver required')
  local self={session=nil,serial=nil,dirty=false,nextCheck=0,lastSample=nil,stable=0,
    invalidated=false,stopped=false,registered=false,requested=0,unavailable=0,
    observed=0,ignored=0,checks=0,wakes=0,lastWake='none',lastGate='idle'}
  function self:bind(session)
    if self.session~=session then
      self.session=session;self.invalidated=false;self:clear()
    end
  end
  function self:clear()
    self.serial=nil;self.dirty=false;self.nextCheck=0;self.lastSample=nil;self.stable=0;self.lastGate='idle'
  end
  function self:arm(session,serial,now)
    self:bind(session)
    if self.stopped or self.invalidated then return false end
    self.serial=serial;self.dirty=true;self.nextCheck=now;self.lastSample=nil;self.stable=0
    self.lastWake='request';self.lastGate='waiting';return true
  end
  function self:signal(session,reason)
    if self.stopped or not session or session~=self.session then self.ignored=inc(self.ignored);return false end
    self.observed=inc(self.observed)
    if reason=='death' or reason=='detach' then
      self.invalidated=true;self.lastWake=reason;self.stable=0;self.dirty=false
      return true
    end
    if self.invalidated or not self.serial then return false end
    self.dirty=true;self.stable=0;self.lastSample=nil;self.lastWake=reason;self.wakes=inc(self.wakes)
    return true
  end
  function self:interrupt()
    if self.serial then
      self.stable=0;self.lastSample=nil;self.dirty=true;self.lastWake='clock_interrupted'
    end
  end
  function self:due(now)
    if self.stopped or self.invalidated or not self.serial or not finite(now) then return false end
    if not self.dirty and now+0.000001<self.nextCheck then return false end
    self.dirty=false;self.checks=inc(self.checks);return true
  end
  function self:sample(now,eligible,reason)
    if not finite(now) or self.invalidated or self.stopped or not self.serial then self.stable=0;return false end
    if eligible==true then
      if self.lastSample then self.stable=self.stable+math.min(math.max(0,now-self.lastSample),0.25) end
      self.lastSample=now;self.nextCheck=now+0.25
    else
      self.stable=0;self.lastSample=nil;self.nextCheck=now+1.0
    end
    self.lastGate=reason or 'unknown'
    return self.stable+0.000001>=2.0
  end
  function self:register(after,before)
    if self.registered or self.stopped then return end
    self.registered=true
    local function install(observe,method,reason)
      self.requested=inc(self.requested)
      if type(observe)~='function' then self.unavailable=inc(self.unavailable);return end
      local ok,result=pcall(observe,'PlayerPuppet',method,function(player,_)
        if self.stopped then return end
        local read,session=pcall(sessionOf,player)
        if read and finite(session) and session>0 then self:signal(session,reason)
        else self.ignored=inc(self.ignored) end
      end)
      -- A nonthrowing observer registration is requested, not runtime-confirmed.
      if not ok or result==false then self.unavailable=inc(self.unavailable) end
    end
    install(after,'OnCombatStateChanged','combat_changed')
    install(before,'OnDeath','death')
    install(before,'OnDetach','detach')
  end
  function self:shutdown() self.stopped=true;self:clear() end
  function self:diagnostics()
    return {requested=self.requested,unavailable=self.unavailable,observed=self.observed,
      ignored=self.ignored,checks=self.checks,wakes=self.wakes,lastWake=self.lastWake,
      invalidated=self.invalidated,armed=self.serial~=nil,driver='event_with_watchdog',
      fallbackSeconds=1,stabilizationSeconds=2,registration='requested_not_confirmed'}
  end
  return self
end
return M
