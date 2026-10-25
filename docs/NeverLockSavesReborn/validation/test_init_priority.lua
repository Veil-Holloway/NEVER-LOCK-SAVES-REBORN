-- Independent actual-init scheduler/manual priority checks. All external CET,
-- game and REDscript method boundaries are doubles. No game saves are created.
local root=assert(arg[1],'release root required')
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function fixture(enabled)
  local h={events={},time=0,present=true,done=1,unlocked=true,paused=0,menu=0,phone=0,
    combat=false,mounted=0,autoQueued=0,dispatches={},resets={}}
  local p={session=0,pending=false,serial=0,source=0,manual=false,auto=false,mode=1,tone=1,notifications=true}
  h.player=p
  function p:NLSRebornDeferredSession(candidate)if self.session==0 then self.session=candidate end return self.session end
  function p:NLSRebornDeferredCancel()self.pending=false end
  function p:NLSRebornDeferredSetEnabled(v)self.manual=v;if not v and self.source~=3 then self.pending=false end end
  function p:NLSRebornAutosaveSetEnabled(v)self.auto=v;if not v and self.source==3 then self.pending=false end end
  function p:NLSRebornDeferredGetSerial()return self.serial end
  function p:NLSRebornDeferredIsPending()return self.pending end
  function p:NLSRebornDeferredGetSource()return self.source end
  function p:NLSRebornDeferredNativeUnlocked()return h.unlocked and h.done>0 end
  function p:NLSRebornPausedState()return h.paused end
  function p:NLSRebornMenuState()return h.menu end
  function p:NLSRebornMountedState()return h.mounted end
  function p:NLSRebornNotificationPhoneState()return h.phone end
  function p:NLSRebornAutosaveReady()
    return self.auto and self:NLSRebornDeferredNativeUnlocked() and self:NLSRebornPausedState()==0 and self:NLSRebornMenuState()==0 and self:NLSRebornNotificationPhoneState()==0 and self:IsInCombat()==false and self:NLSRebornMountedState()==0
  end
  function p:NLSRebornAutosaveQueue()
    if self.pending or not self:NLSRebornAutosaveReady() then return false end
    self.serial=self.serial+1;self.source=3;self.pending=true;h.autoQueued=h.autoQueued+1;return true
  end
  function p:NLSRebornDeferredDispatch(serial)
    if not self.pending or self.serial~=serial or not self:NLSRebornDeferredNativeUnlocked() then return false end
    if self.source==3 and not self:NLSRebornAutosaveReady() then return false end
    if self.source~=3 and not self.manual then return false end
    h.dispatches[#h.dispatches+1]={time=h.time,source=self.source}
    self.pending=false;return true
  end
  function p:NLSRebornSetMode(v)self.mode=v end
  function p:NLSRebornGetMode()return self.mode end
  function p:NLSRebornSetOptions()end
  function p:NLSRebornSetObservedState()end
  function p:NLSRebornSetContext()end
  function p:NLSRebornSetShuffleSeed()end
  function p:NLSRebornSetTone(v)self.tone=v end
  function p:NLSRebornGetTone()return self.tone end
  function p:NLSRebornSetNotificationsEnabled(v)self.notifications=v end
  function p:NLSRebornGetNotificationsEnabled()return self.notifications end
  function p:NLSRebornSetDFNotifications()end
  function p:NLSRebornGetDFNotificationMask()return 15 end
  function p:NLSRebornShowActivation()end
  function p:IsInCombat()return h.combat end
  function p:IsCrouching()return false end
  local env=setmetatable({}, {__index=_G})
  env.print=function()end
  env.registerForEvent=function(n,cb)h.events[n]=cb end
  env.GetMod=function()return nil end
  env.ItemID={new=function()return {} end}
  env.Game={
    GetPlayer=function()return h.present and p or nil end,
    GetQuestsSystem=function()return {GetFactStr=function(_,key)if key=='q000_done' then return h.done end return 1 end,SetFactStr=function()end}end,
    GetScriptableSystemsContainer=function()return {Get=function()return {GetBodyTypeSuffix=function()return 'female' end}end}end}
  env.require=function(name)
    if name=='config_store' then return {load=function()return {mode=3,deferredEnabled=true,autosaveEnabled=enabled,
      autosaveIntervalSeconds=60,autosaveCooldownSeconds=30} end,save=function()return true end}end
    if name=='deferred_save' then return assert(loadfile(dir..'deferred_save.lua','t',env))()end
    if name=='autosave_policy' then
      local m=assert(loadfile(arg[2] or (dir..'autosave_policy.lua'),'t',env))()
      local create=m.new;local reset=m.reset
      m.new=function()h.scheduler=create();h.policy=m;return h.scheduler end
      m.reset=function(s,session,why)h.resets[#h.resets+1]=why;return reset(s,session,why)end
      return m
    end
    if name=='dark_future' then return {sample=function()return {}end,describe=function()return 'unknown' end}end
    error('optional module intentionally unavailable: '..name)
  end
  assert(loadfile(dir..'init.lua','t',env))()
  h.events.onInit()
  function h:step(n)
    for _=1,n or 1 do self.time=self.time+.25;self.events.onUpdate(.25)end
  end
  function h:manual()
    p.serial=p.serial+1;p.source=1;p.pending=true
  end
  function h:status()return self.policy.status(self.scheduler)end
  function h:untilCredit(target)
    for _=1,2000 do
      if self:status().elapsedSeconds>=target then return end
      self:step()
    end
    error('scheduler did not accumulate required interval')
  end
  h.events.onUpdate(0)
  return h
end

do
  local h=fixture(false);h:step(1000)
  check(h.autoQueued==0 and #h.dispatches==0,'default/explicit off cannot schedule')
end
do
  local h=fixture(true);h:step(270)
  check(h.autoQueued==1 and #h.dispatches==1,'one interval creates one dispatch')
  check(h.dispatches[1].source==3,'automatic lane')
  h:step(100);check(h.autoQueued==1 and #h.dispatches==1,'no postdispatch duplicate')
end
do
  local h=fixture(true);h:untilCredit(59.5);h:manual();h:step(9)
  check(#h.dispatches==1 and h.dispatches[1].source==1,'near-deadline manual request dispatched first')
  check(h.autoQueued==0,'manual adoption cancels near-due interval')
  check(h:status().cooldownRemaining>28,'manual dispatch restarts automatic cooldown')
  h:step(80);check(h.autoQueued==0 and #h.dispatches==1,'no automatic follower after user checkpoint')
end
do
  local h=fixture(true);h:untilCredit(59.5);h.paused=1;h:step(60)
  check(h.autoQueued==0,'pause at deadline suppresses automation')
  h.paused=0;h:step(200);check(h.autoQueued==0,'resume has no retained interval credit')
end
do
  local h=fixture(true);h:untilCredit(59.5);h.player.session=11;h:step(200)
  check(h.autoQueued==0,'different session has no retained interval credit')
end
do
  local h=fixture(true);h:untilCredit(59.5);h.present=false;h:step(10);h.present=true;h:step(200)
  check(h.autoQueued==0,'player gap has no retained interval credit')
end
do
  local h=fixture(true)
  for _=1,2000 do if h.autoQueued==1 then break end;h:step()end
  check(h.autoQueued==1 and h.player.pending,'automatic work accepted into bridge')
  h:manual();h:step(10)
  check(#h.dispatches==1 and h.dispatches[1].source==1,'manual replaces unadopted automatic bridge request')
  check(h.autoQueued==1,'replaced auto does not reappear')
end

-- Once accepted into the bridge, automatic work is still cancellable. A later
-- resumed/unpaused frame cannot resurrect the old accepted scheduling event.
local interrupted={
  {'pause',function(h)h.paused=1 end},
  {'menu',function(h)h.menu=1 end},
  {'phone',function(h)h.phone=1 end},
  {'combat',function(h)h.combat=true end},
  {'mounted',function(h)h.mounted=1 end},
  {'pause_unknown',function(h)h.paused=-1 end},
  {'menu_unknown',function(h)h.menu=-1 end},
  {'phone_unknown',function(h)h.phone=-1 end},
  {'mounted_unknown',function(h)h.mounted=-1 end},
  {'combat_unknown',function(h)h.player.IsInCombat=function()return nil end end},
  {'combat_throws',function(h)h.player.IsInCombat=function()error('unreadable combat sensor')end end},
  {'native_unknown',function(h)h.unlocked=nil end},
  {'stalled_frame',function()end,2}
}
local staleFailures={}
for _,age in ipairs({0,7})do
  for _,variant in ipairs(interrupted)do
    local h=fixture(true)
    for _=1,2000 do if h.autoQueued==1 then break end;h:step()end
    check(h.autoQueued==1 and h.player.pending,'handoff fixture has accepted automatic work')
    h:step(age)
    local combatMethod=h.player.IsInCombat
    variant[2](h)
    h.events.onUpdate(variant[3] or .25)
    checks=checks+1
    if h.player.pending then staleFailures[#staleFailures+1]=variant[1]..'/'..age..': bridge retained old request' end
    h.paused=0;h.menu=0;h.phone=0;h.combat=false;h.mounted=0;h.unlocked=true;h.player.IsInCombat=combatMethod
    h:step(80)
    checks=checks+1
    if #h.dispatches~=0 then staleFailures[#staleFailures+1]=variant[1]..'/'..age..': old request dispatched after interruption' end
  end
end
check(#staleFailures==0,'stale automatic handoff: '..table.concat(staleFailures,'; '))

-- A known native lock is a bounded wait, not a lifecycle interruption. Manual
-- work retains its existing waiting behavior even while automatic work cancels.
do
  local h=fixture(true)
  for _=1,2000 do if h.autoQueued==1 then break end;h:step()end
  h.unlocked=false;h:step(12)
  check(h.player.pending and #h.dispatches==0,'known native relock retains bounded automatic wait')
  h.unlocked=true;h:step(9)
  check(#h.dispatches==1 and h.dispatches[1].source==3,'known relock can dispatch before expiry')
end
do
  local h=fixture(true);h:step(12);h.unlocked=false;h:manual();h.paused=1;h:step(12)
  check(h.player.pending and #h.dispatches==0,'manual request remains waiting through pause plus native lock')
  h.paused=0;h.unlocked=true;h:step(9)
  check(#h.dispatches==1 and h.dispatches[1].source==1,'manual request retains existing release behavior')
end
print('PASS independent actual-init priority assertions='..checks)

