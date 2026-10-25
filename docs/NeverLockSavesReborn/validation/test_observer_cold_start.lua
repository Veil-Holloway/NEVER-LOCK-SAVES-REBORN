-- Cold-start lifecycle regression using actual init/Guardian/quest modules.
-- CET observer functions appear after top-level mod load and before onInit.
-- Game, registration and config IO are external doubles. No native compilation
-- or save write/reload is exercised, and no changed source seam is replaced.
local root=assert(arg[1],'release root required')
local expectGap=arg[2]=='--expect-gap'
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end

local function fixture(behavior,warm)
  local h={events={},callbacks={},registrationAttempts=0,registrations=0,
    dispatches=0,autoRequests=0,writes=0,phase='load',modules={}}
  local p={session=0,nlsDeferredSerial=0,nlsDeferredPending=false,source=0,
    mode=2,tone=0,notifications=true,mask=15}
  h.player=p
  function p:NLSRebornDeferredSession(candidate) if self.session==0 then self.session=candidate end return self.session end
  function p:NLSRebornDeferredCancel() self.nlsDeferredPending=false end
  function p:NLSRebornDeferredSetEnabled() end
  function p:NLSRebornDeferredGetSerial() return self.nlsDeferredSerial end
  function p:NLSRebornDeferredIsPending() return self.nlsDeferredPending end
  function p:NLSRebornDeferredGetSource() return self.source end
  function p:NLSRebornDeferredNativeUnlocked() return false end
  function p:NLSRebornDeferredDispatch() h.dispatches=h.dispatches+1;return false end
  function p:NLSRebornRequestCheckpoint() h.dispatches=h.dispatches+1;return false end
  function p:NLSRebornAutosaveQueue() h.autoRequests=h.autoRequests+1;return false end
  function p:NLSRebornAutosaveSetEnabled() end
  function p:NLSRebornSetStatusNotificationsEnabled() end
  function p:NLSRebornSetMode(v) self.mode=v end
  function p:NLSRebornGetMode() return self.mode end
  function p:NLSRebornSetTone(v) self.tone=v end
  function p:NLSRebornGetTone() return self.tone end
  function p:NLSRebornSetNotificationsEnabled(v) self.notifications=v end
  function p:NLSRebornGetNotificationsEnabled() return self.notifications end
  function p:NLSRebornSetDFNotifications() end
  function p:NLSRebornGetDFNotificationMask() return self.mask end
  function p:NLSRebornSetOptions() end
  function p:NLSRebornSetObservedState() end
  function p:NLSRebornSetContext() end
  function p:NLSRebornSetShuffleSeed() end
  function p:NLSRebornNotificationPhoneState() return 0 end
  function p:NLSRebornMountedState() return 0 end
  function p:NLSRebornQuestMilestoneState(hash) return hash==123 and 2 or 0 end
  function p:IsInCombat() return false end
  function p:IsCrouching() return false end
  local env=setmetatable({}, {__index=function(_,key)
    if key=='ObserveBefore' or key=='ObserveAfter' then return nil end
    return _G[key]
  end})
  h.env=env
  env.print=function() end
  env.registerForEvent=function(name,callback) h.events[name]=callback end
  env.GetMod=function() return nil end
  env.ItemID={new=function() return {} end}
  env.Game={GetPlayer=function() return p end,
    GetQuestsSystem=function() return {GetFactStr=function(_,key) return key=='q000_done' and 1 or 0 end,SetFactStr=function() end} end,
    GetScriptableSystemsContainer=function() return {Get=function() return {GetBodyTypeSuffix=function() return 'female' end} end} end}
  env.require=function(name)
    if name=='config_store' then
      return {load=function() return {mode=2,deferredEnabled=false,guardianEnabled=true,
        autosaveEnabled=true,autosaveQuestMilestone=true} end,
        save=function() h.writes=h.writes+1;return true end}
    end
    local capture={guardian='ledger',guardian_bridge='bridge',quest_milestones='quest'}
    if name=='deferred_save' or capture[name] then
      if not h.modules[name] then h.modules[name]=assert(loadfile(dir..name..'.lua','t',env))() end
      local actual=h.modules[name]
      if capture[name] then
        return {new=function(...)
          local object=actual.new(...);h[capture[name]]=object;return object
        end}
      end
      return actual
    end
    error('Optional module outside lifecycle test: '..name)
  end
  function h:installObservers(kind)
    kind=kind or behavior
    if kind=='missing' then env.ObserveBefore=nil;env.ObserveAfter=nil;return end
    local function register(when,class,method,callback)
      self.registrationAttempts=self.registrationAttempts+1
      check(self.phase~='load','observer API must not be called during module load')
      if kind=='throwing' then error('injected registration failure') end
      local key=when..':'..class..'.'..method
      check(self.callbacks[key]==nil,'registration target unique in a CET lifetime: '..key)
      self.callbacks[key]=callback;self.registrations=self.registrations+1
    end
    env.ObserveBefore=function(...) return register('before',...) end
    env.ObserveAfter=function(...) return register('after',...) end
  end
  function h:load()
    self.phase='load';assert(loadfile(dir..'init.lua','t',env))()
    check(self.registrationAttempts==0,'top-level init does not register observers')
    check(self.dispatches==0 and self.autoRequests==0 and self.writes==0,'module load has no save or IO side effect')
    check(type(self.events.onInit)=='function','actual init registers onInit')
  end
  function h:start()
    self.phase='onInit';self.events.onInit();self.events.onUpdate(0)
  end
  function h:fire(key,...)
    local cb=assert(self.callbacks[key],'observer callback registered: '..key)
    check(cb(...)==nil,'observer supplies no return value')
  end
  if warm then h:installObservers(behavior) end
  h:load()
  return h
end

local function ready(h,label)
  local g,q=h.bridge:diagnostics(),h.quest:diagnostics()
  check(h.registrations==11 and h.registrationAttempts==11,label..' registers ten Guardian plus one quest observer')
  check(g.attempted and g.requested==10 and g.unavailable==0,label..' Guardian registration reported accurately')
  check(q.attempted and q.requested and not q.unavailable,label..' quest registration reported accurately')
  h.events.onInit()
  check(h.registrations==11 and h.registrationAttempts==11,label..' duplicate onInit does not reattach')
  check(h.dispatches==0 and h.autoRequests==0,label..' lifecycle does not request a checkpoint')
end

local cold=fixture('working',false)
cold:installObservers();cold:start()
if expectGap then
  local g,q=cold.bridge:diagnostics(),cold.quest:diagnostics()
  check(cold.registrations==0 and cold.registrationAttempts==0,'baseline captured APIs before they became available')
  check(g.requested==0 and g.unavailable==10,'baseline reproduces all ten unavailable Guardian targets')
  check(not q.requested and q.unavailable,'baseline reproduces unavailable quest observer')
else
  ready(cold,'cold start')
  cold:fire('before:PauseMenuGameController.HandlePressToQuickSaveGame',{})
  cold:fire('after:PauseMenuGameController.HandlePressToQuickSaveGame',{})
  cold:fire('after:PauseMenuGameController.OnSavingComplete',{},true)
  cold.bridge:drain(cold.player.session)
  local report=cold.ledger:report()
  check(report.total_requests==1 and #report.records==1,'actual Guardian callbacks record one request')
  check(report.records[1].source=='pause_quicksave','actual wrapper source retained')
  check(report.records[1].write_status=='Unknown' and report.records[1].reload_status=='Unknown','callback return is not write/reload proof')
  check(#report.uncorrelated_hints==1 and report.uncorrelated_hints[1].outcome=='SuccessHint','completion callback remains uncorrelated hint')
  check(cold.bridge:diagnostics().observed==3,'public Guardian diagnostics confirm callback execution')
  check(#cold.quest:drain(cold.player.session)==0,'quest baseline arms without replaying old work')
  cold:fire('after:QuestTrackerGameController.OnStateChanges',{},123,'gameJournalQuestObjective')
  local milestones=cold.quest:drain(cold.player.session)
  check(#milestones==1 and milestones[1].hash==123,'actual quest callback resolves one milestone')
  check(cold.quest:diagnostics().callbackObserved and cold.quest:diagnostics().resolved==1,'public quest diagnostics confirm callback and resolution')
  check(#cold.quest:drain(cold.player.session)==0,'quest milestone is consumed once')
  check(cold.dispatches==0 and cold.autoRequests==0,'observation alone never dispatches')
end

local warm=fixture('working',true);warm:start();ready(warm,'warm load')
-- CET clears its registrations before reloading a mod. Reuse the actual module
-- factories and actual init source while recreating that registration lifetime.
for _=1,2 do
  warm.callbacks={};warm.registrations=0;warm.registrationAttempts=0;warm.events={}
  warm:load();warm:start();ready(warm,'CET reload')
end

for _,behavior in ipairs({'missing','throwing'}) do
  -- Present throwing functions during load too, so baseline mode also tests
  -- registration error handling independently of the nil-capture reproduction.
  local h=fixture(behavior,true)
  h:start()
  local g,q=h.bridge:diagnostics(),h.quest:diagnostics()
  check(h.registrations==0,behavior..' APIs do not fabricate registrations')
  check(h.registrationAttempts==(behavior=='throwing' and 11 or 0),behavior..' API invocation count is truthful')
  check(g.requested==0 and g.unavailable==10,behavior..' Guardian remains unavailable')
  check(not q.requested and q.unavailable,behavior..' quest remains unavailable')
  check(g.observed==0 and not q.callbackObserved,behavior..' callbacks are not invented')
  check(h.dispatches==0 and h.autoRequests==0,behavior..' registration failure cannot request a checkpoint')
end
print('PASS observer cold-start lifecycle: '..checks..' assertions; '..
  (expectGap and 'expected baseline startup gap detected; warm-load control passes' or 'cold start, warm load, reloads, callbacks and missing/throwing boundaries pass')..
  '. Actual Lua modules; external CET/game doubles; no native compilation or save proof.')
