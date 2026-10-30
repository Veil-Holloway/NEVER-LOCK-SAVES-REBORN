-- Never Lock Saves Reborn v1.0.0 Stable
-- Persistent UI settings, runtime bridge, and diagnostics.
-- Player requests never bypass combat/native locks; mounted state alone is not a queue blocker.
-- DF switches control contextual messages only. Optional scheduler defaults OFF.
local title = 'Never Lock Saves: Reborn'
local VERSION = '1.0.0'
local deferred = require('deferred_save')
local deferredState = deferred.new()
local combatEvents = require('combat_events').new(function(player)
  return player:NLSRebornDeferredSession(0) -- read only: zero never allocates a token
end)
local deferredEnabled = false
local deferredClock = 0
local deferredStatus = 'Disabled'
local lastQueueOutcomeState,lastQueueOutcomeReason='Unknown','No completed request in this runtime'
local deferredSession = nil
local nextSession = 1
local deferredGameSerial = nil
local deferredTTL = 30
local deferredCooldownSeconds = 0
local deferredLastDispatch = -math.huge
local autosaveEnabled = false
local statusNotificationsEnabled=false
local statusEmitter=nil
local statusBridgeReady=false
local statusSession=nil
local statusAppliedEnabled=nil
local statusRuntime='Disabled'
local autosaveQueuedReason,autosaveQueuedSerial,autosaveQueuedSession=nil,nil,nil
local autosaveOptions = {enabled=false,intervalSeconds=300,cooldownSeconds=60,exploration=true,postCombat=true,vehicleExit=true,questMilestone=false,apartmentEntry=false}
local autosavePolicy,autosaveState=nil,nil
local questEvents=nil
local supportFailures={}
local failureCodes={write_failed=true,read_failed=true,bridge_unavailable=true,dispatch_rejected=true,
  scheduler_unavailable=true,report_failed=true,invalid_settings=true,invalid_bank=true,
  unreadable_bank=true,invalid_label=true,profile_not_found=true,bank_full=true,unsupported_schema=true,status_unavailable=true}
local function recordFailure(code)
  if not failureCodes[code] then return end
  if supportFailures[#supportFailures]==code then return end
  if #supportFailures>=8 then table.remove(supportFailures,1) end
  supportFailures[#supportFailures+1]=code
end
local autosaveStatus='Disabled'
local autosaveStable=0
local function optional(name)
  local ok,value=pcall(require,name)
  return ok and type(value)=='table' and value or nil
end
local uiCatalog=optional('settings_ui')
local overlayFactory=optional('overlay_ui')
local nativeUIFactory=optional('native_settings_ui')
autosavePolicy=optional('autosave_policy')
if autosavePolicy then
  local ok,value=pcall(function() return autosavePolicy.new() end)
  if ok and type(value)=='table' then autosaveState=value else autosavePolicy=nil end
end
local function configureAutosave()
  if questEvents then pcall(function() questEvents:clear() end) end
  autosaveOptions.enabled=autosaveEnabled
  autosaveStable=0
  if not autosavePolicy or not autosaveState then
    recordFailure('scheduler_unavailable')
    autosaveStatus='Module unavailable; scheduling disabled'
    return false
  end
  local ok,accepted=pcall(autosavePolicy.configure,autosaveState,autosaveOptions)
  if not ok or accepted~=true then recordFailure('scheduler_unavailable');autosaveStatus='Invalid scheduler configuration; scheduling disabled'; return false end
  autosaveStatus=autosaveEnabled and 'Waiting for readiness' or 'Disabled'
  return true
end
local questModule=optional('quest_milestones')
if questModule then
  local ok,value=pcall(function()
    return questModule.new({observe=function(...) return ObserveAfter(...) end,
      enabled=function() return autosaveEnabled and autosaveOptions.questMilestone end,
      resolve=function(hash)
        local player=Game.GetPlayer()
        local state=player:NLSRebornQuestMilestoneState(hash)
        if state==1 or state==2 then return {defined=true,kind=state==1 and 'quest' or 'objective',succeeded=true} end
        return nil
      end})
  end)
  if ok and type(value)=='table' then questEvents=value end
end
local function boundedInteger(value,low,high)
  return type(value)=='number' and value==value and value>=low and value<=high and value==math.floor(value)
end
local deferredSeenSerial = -1
local deferredOrigin = nil
local deferredUnlockStable = 0

local deferredBridge = 'Not checked'
local deferredGate = 'Not evaluated'
local deferredEvent = 'Idle'
-- Optional Guardian observes requests. Its results never enter save policy.
local guardianEnabled = false
local guardian, guardianBridge = nil, nil
local guardianStatus = 'Module unavailable'
local function guardianCall(name, ...)
  if not guardianEnabled or not guardian then return nil end
  local ok,value=pcall(function(target,method,...)
    local fn=target[method]
    assert(type(fn)=='function','Guardian interface unavailable')
    return fn(target,...)
  end,guardian,name,...)
  if not ok then guardianStatus='Tracking error; save policy unchanged'; return nil end
  return value
end
local function setGuardianEnabled(value)
  guardianEnabled=not not value
  if guardian then
    local ok=pcall(function() guardian:set_enabled(guardianEnabled) end)
    guardianStatus=ok and (guardianEnabled and 'Tracking enabled' or 'Tracking disabled') or 'Tracking error; save policy unchanged'
  end
end
local guardianLoaded,value=pcall(function()
  local factory=require('guardian')
  assert(type(factory)=='table' and type(factory.new)=='function','Guardian module unavailable')
  local stampOK,stamp=pcall(function() return os.time() end)
  local runId='R'..tostring(stampOK and type(stamp)=='number' and math.floor(stamp) or 0)..'-'..tostring(math.random(100000,999999))
  return factory.new(runId,function() return deferredClock end)
end)
if guardianLoaded and type(value)=='table' then guardian=value; guardianStatus='Tracking disabled' end

-- Completion correlation is independent of the optional Guardian setting. The same
-- observer callback transports both Guardian hints and the always-on in-flight state.
local completionTracker = nil
local notifySaveCompletion = nil
local function latestSaveFingerprint()
  local ok,handler=pcall(function() return GetSingleton('inkMenuScenario'):GetSystemRequestsHandler() end)
  if not ok or not handler then return nil end
  local okMeta,meta=pcall(function() return handler:GetLatestSaveMetadata() end)
  if not okMeta or not meta then return nil end
  local okPlay,play=pcall(function() return meta.playTime end)
  local okThrough,through=pcall(function() return meta.playthroughTime end)
  local okVersion,version=pcall(function() return meta.gameVersion end)
  if not okPlay or type(play)~='number' or play~=play or play<0 then return nil end
  if not okThrough or type(through)~='number' or through~=through or through<0 then return nil end
  return string.format('%.3f|%.3f|%s',play,through,okVersion and type(version)=='string' and version or 'unknown')
end
local completionLoaded,completionValue=pcall(function()
  local factory=require('save_completion')
  assert(type(factory)=='table' and type(factory.new)=='function','Completion tracker unavailable')
  return factory.new(function() return deferredClock end)
end)
if completionLoaded and type(completionValue)=='table' then completionTracker=completionValue end

if guardian then
  local ok,bridge=pcall(function()
    local factory=require('guardian_bridge')
    assert(type(factory)=='table' and type(factory.new)=='function','Guardian observer module unavailable')
    return factory.new(guardian,{enabled=function() return guardianEnabled end,
      session=function() return deferredSession or 0 end,
      completion=function(eventSession,success,origin)
        if completionTracker then
          local matched=completionTracker:hint(eventSession,success,origin,latestSaveFingerprint())
          if matched and notifySaveCompletion then notifySaveCompletion(eventSession,success) end
        end
      end,
      ObserveBefore=function(...) return ObserveBefore(...) end,ObserveAfter=function(...) return ObserveAfter(...) end})
  end)
  if ok and type(bridge)=='table' then guardianBridge=bridge end
end

-- Native save-lock gating is experimental; completion callbacks are evidence, not reload proof.

-- The optional adapter cannot alter RC5's save hooks or runtime policy bridge.
local adapterLoaded, darkFuture = pcall(require, 'dark_future')
local darkFutureStatus = 'Waiting for player'
local darkFutureError = nil
local lastDarkFutureSnapshot={}
if not adapterLoaded or type(darkFuture) ~= 'table' or
  type(darkFuture.sample) ~= 'function' or type(darkFuture.describe) ~= 'function' then
  darkFutureError = adapterLoaded and 'Invalid adapter module' or tostring(darkFuture)
  darkFuture = nil
  darkFutureStatus = 'UNKNOWN: compatibility adapter could not load'
end
local function sampleDarkFuture(player)
  if not darkFuture then return end
  local ok, snapshot = pcall(darkFuture.sample, player)
  if ok and type(snapshot) == 'table' then
    lastDarkFutureSnapshot=snapshot
    local described, summary = pcall(darkFuture.describe, snapshot)
    if described and type(summary) == 'string' then
      darkFutureStatus = summary
      darkFutureError = snapshot.error
      return
    end
  end
  darkFutureStatus = 'UNKNOWN: compatibility adapter failed'
  darkFutureError = ok and 'Invalid adapter response' or tostring(snapshot)
end
local dfNotifications = {dfNotifyVehicleSleep=true, dfNotifyAddiction=true,
  dfNotifyStarvation=true, dfNotifyDehydration=true}
local dfNotificationOptions = {
  {key='dfNotifyVehicleSleep', label='Notify: vehicle sleep',
    help='Show a contextual request message while DF reports vehicle sleep. This switch never changes save permission.'},
  {key='dfNotifyAddiction', label='Notify: addiction',
    help='Show a contextual request message for an enabled DF addiction stage above zero. Saving remains permitted when this message is off.'},
  {key='dfNotifyStarvation', label='Notify: starvation',
    help='Show a contextual request message at DF nutrition stage 4 (Starving). This switch only controls notifications.'},
  {key='dfNotifyDehydration', label='Notify: dehydration',
    help='Show a contextual request message at DF hydration stage 4 (Dehydrated). This switch only controls notifications.'}
}
local mode = 1
local allowCombat = false
local allowVehicle = false
local notificationsEnabled = true
-- Presentation only: the existing tracker decides whether a completion matches.
notifySaveCompletion=function(eventSession,success)
  if statusEmitter and completionTracker then
    pcall(function()
      local last=completionTracker:report().last
      if last then statusEmitter:complete(last.session,last.serial) end
    end)
  end
  if not notificationsEnabled or deferredSession~=eventSession then return end
  pcall(function()
    local player=Game.GetPlayer()
    if player and player:NLSRebornDeferredSession(0)==eventSession then
      player:NLSRebornCompletionNotify(success)
    end
  end)
end
local diagnosticDetails = true
local show = false
local lastApplied = -1
local lastPlayer = nil
local message = 'Waiting for player'
local attempts, successes, failures = 0, 0, 0
local names = {'Vanilla', 'Immersion', 'Unrestricted', 'Smart'}
local file = 'config.json'
local configStore = require('config_store')
local profilesModule=optional('profiles')
local supportReport=optional('support_report')
local dependencyVersions=optional('dependency_versions')
local profileBank=nil
local profileLabel='Default'
local profileLabels={}
local profileSelected=false
local profileStatus='Named settings presets' 
local reportStatus='Not exported'
if profilesModule then
  local ok,bank=pcall(function()
    return profilesModule.new(configStore,'profile-settings.json',function(path)
      local file,_,code=io.open(path,'r')
      if file then file:close(); return true end
      if code==2 then return false end
      return nil
    end)
  end)
  if ok and type(bank)=='table' then profileBank=bank end
end
local function refreshProfileLabels()
  if not profileBank then profileLabels={};return end
  local ok,labels=pcall(function() return profileBank:list() end)
  profileLabels=ok and type(labels)=='table' and labels or {}
end
local sensorStatus = 'Sensors not yet sampled' 
local phoneStatus = 'Phone-call detection informational'
local prologueStatus = 'Waiting for quest facts'
local prologueActive = false
local activationNoticeStatus = 'Pending'
local safetyBlock = true
local secondsSincePlayer = 0
local INTRO_GUARD_SECONDS = 0 -- quest-fact gate replaces timer
local context = 0
local body = 0
local bodyStatus = 'UNKNOWN'
local shuffleSeed = math.random(1, 999999)
local statusModule=optional('status_messages')
if statusModule then
  local ok,value=pcall(function() return statusModule.new(shuffleSeed) end)
  if ok and type(value)=='table' then statusEmitter=value end
end
local function statusCall(name,...)
  if not statusEmitter then return nil end
  local ok,value=pcall(function(target,method,...)
    local fn=target[method]
    if type(fn)~='function' then error('status interface unavailable') end
    return fn(target,...)
  end,statusEmitter,name,...)
  if not ok then
    statusEmitter=nil;statusBridgeReady=false;statusRuntime='Unavailable; original queue notices retained'
    return nil
  end
  return value
end
local function statusNotice(kind,session,serial)
  if statusBridgeReady then statusCall('enqueue',kind,session,serial,deferredClock) end
end
local function configureStatus(player,session)
  local previouslyActive=statusBridgeReady and statusSession==session
  local wanted=statusNotificationsEnabled and notificationsEnabled and statusEmitter~=nil and player~=nil and
    boundedInteger(session,1,2147483647)
  if statusSession~=session then
    statusCall('reset',session)
    statusSession=session;statusAppliedEnabled=nil;statusBridgeReady=false;previouslyActive=false
  end
  if statusAppliedEnabled==wanted then return previouslyActive and statusBridgeReady end
  local accepted=statusCall('configure',wanted)
  local active=wanted and accepted==true
  if player then
    local ok,value=pcall(function()
      player:NLSRebornSetStatusNotificationsEnabled(active)
      return player:NLSRebornGetStatusNotificationsEnabled()
    end)
    active=active and ok and value==true
    if not ok or value~=active then pcall(function() player:NLSRebornSetStatusNotificationsEnabled(false) end) end
  else active=false end
  statusAppliedEnabled=wanted;statusBridgeReady=active
  if statusNotificationsEnabled and notificationsEnabled and player and not active then recordFailure('status_unavailable') end
  statusRuntime=active and 'Ready; messages describe requests only' or
    statusNotificationsEnabled and 'Unavailable or waiting for player; original queue notices retained' or 'Disabled'
  return previouslyActive and active
end
local function detectBody(player)
  -- Body-type suffix is a documented PuppetStateSystem query. Optional API;
  -- custom/unsupported body types deliberately remain UNKNOWN.
  local ok, suffix = pcall(function()
    local system = Game.GetScriptableSystemsContainer():Get('PuppetStateSystem')
    return system:GetBodyTypeSuffix(ItemID.new(), player, nil)
  end)
  if not ok or suffix == nil then return 0, 'UNKNOWN: body query unavailable' end
  local value = tostring(suffix):lower()
  if value == 'female' or value == 'w' or value == 'woman' then return 1, 'Female ('..value..')' end
  if value == 'male' or value == 'm' or value == 'man' then return 2, 'Male ('..value..')' end
  return 0, 'UNKNOWN: '..value
end
local function detectPhone()
  -- Read the source-backed, tri-state REDscript phone bridge; no method-name probes.
  local ok, state=pcall(function() return Game.GetPlayer():NLSRebornNotificationPhoneState() end)
  if not ok then return false,false,'call_failed',nil end
  if state==0 then return true,false,'observed_clear',0 end
  if state==1 then return true,true,'observed_active',1 end
  if state==-1 then return false,false,'bridge_unknown',-1 end
  return false,false,'invalid_return',type(state)=='number' and state or nil
end
local combatKnown,combatActive,vehicleKnown,vehicleActive,phoneKnown,phoneActive = false,false,false,false,false,false
local phoneBridgeStatus,phoneRawState='not_sampled',nil
local autosavePhoneBridgeStatus,autosavePhoneRawState,autosavePhoneSource='not_sampled',nil,'none'
local function readAutosavePhone(player)
  if not player then return false,false,'player_unavailable',nil,'none' end
  local ok,state=pcall(function() return player:NLSRebornAutosavePhoneState() end)
  if ok and state==0 then return true,false,'observed_clear',0,'phone_manager' end
  if ok and state==1 then return true,true,'observed_active',1,'phone_manager' end
  -- Fallback is deliberately one-way: the notification bridge may prove an
  -- active StartCall, but a clear result there is not strong enough to prove
  -- that no incoming/other phone call is active. Unknown therefore stays safe.
  local fallbackOK,fallback=pcall(function() return player:NLSRebornNotificationPhoneState() end)
  if fallbackOK and fallback==1 then return true,true,'observed_active',1,'notification_active_fallback' end
  if not ok then return false,false,'call_failed',nil,'phone_manager' end
  if state==-1 then return false,false,'bridge_unknown',-1,'phone_manager' end
  return false,false,'invalid_return',type(state)=='number' and state or nil,'phone_manager'
end
local configStatus = 'Not saved this session'
local nativeUI = nil
local nativeStatus = 'Native Settings UI not detected'
local function log(s) print('[NLS Reborn] ' .. tostring(s)) end
local validateMainSettings
local function loadConfig()
  local ok, data = pcall(configStore.load, file, validateMainSettings)
  if ok and type(data) == 'table' then
    if type(data.mode) == 'number' and data.mode >= 0 and data.mode <= 3 then mode = math.floor(data.mode) end
    if type(data.allowCombat) == 'boolean' then allowCombat = data.allowCombat end
    if type(data.allowVehicle) == 'boolean' then allowVehicle = data.allowVehicle end
    if type(data.notificationsEnabled) == 'boolean' then notificationsEnabled = data.notificationsEnabled end
    if type(data.statusNotificationsEnabled)=='boolean' then statusNotificationsEnabled=data.statusNotificationsEnabled end
    if type(data.diagnosticDetails) == 'boolean' then diagnosticDetails = data.diagnosticDetails end
    if type(data.deferredEnabled) == 'boolean' then deferredEnabled = data.deferredEnabled end
    if type(data.guardianEnabled) == 'boolean' then guardianEnabled = data.guardianEnabled end
    if boundedInteger(data.deferredTTL,1,120) then deferredTTL=data.deferredTTL end
    if boundedInteger(data.deferredCooldownSeconds,0,600) then deferredCooldownSeconds=data.deferredCooldownSeconds end
    if type(data.autosaveEnabled)=='boolean' then autosaveEnabled=data.autosaveEnabled end
    if boundedInteger(data.autosaveIntervalSeconds,60,1800) then autosaveOptions.intervalSeconds=data.autosaveIntervalSeconds end
    if boundedInteger(data.autosaveCooldownSeconds,30,600) then autosaveOptions.cooldownSeconds=data.autosaveCooldownSeconds end
    if type(data.autosaveExploration)=='boolean' then autosaveOptions.exploration=data.autosaveExploration end
    if type(data.autosavePostCombat)=='boolean' then autosaveOptions.postCombat=data.autosavePostCombat end
    if type(data.autosaveVehicleExit)=='boolean' then autosaveOptions.vehicleExit=data.autosaveVehicleExit end
    if type(data.autosaveQuestMilestone)=='boolean' then autosaveOptions.questMilestone=data.autosaveQuestMilestone end
    if type(data.autosaveApartmentEntry)=='boolean' then autosaveOptions.apartmentEntry=data.autosaveApartmentEntry end
    -- Legacy dfBlock* values are intentionally ignored; those obsolete restrictions are removed.
    for _,option in ipairs(dfNotificationOptions) do
      if type(data[option.key]) == 'boolean' then dfNotifications[option.key] = data[option.key] end
    end
    log('Configuration loaded')
  else log('No valid saved config; using safe defaults') end
end
local function currentSettings()
  return {mode=mode,allowCombat=allowCombat,allowVehicle=allowVehicle,
    notificationsEnabled=notificationsEnabled,statusNotificationsEnabled=statusNotificationsEnabled,diagnosticDetails=diagnosticDetails,
    deferredEnabled=deferredEnabled,guardianEnabled=guardianEnabled,deferredTTL=deferredTTL,
    deferredCooldownSeconds=deferredCooldownSeconds,autosaveEnabled=autosaveEnabled,
    autosaveIntervalSeconds=autosaveOptions.intervalSeconds,autosaveCooldownSeconds=autosaveOptions.cooldownSeconds,
    autosaveExploration=autosaveOptions.exploration,autosavePostCombat=autosaveOptions.postCombat,
    autosaveVehicleExit=autosaveOptions.vehicleExit,autosaveQuestMilestone=autosaveOptions.questMilestone,autosaveApartmentEntry=autosaveOptions.apartmentEntry,
    dfNotifyVehicleSleep=dfNotifications.dfNotifyVehicleSleep,dfNotifyAddiction=dfNotifications.dfNotifyAddiction,
    dfNotifyStarvation=dfNotifications.dfNotifyStarvation,dfNotifyDehydration=dfNotifications.dfNotifyDehydration}
end
-- Main configs predate named presets: validate every present known field while
-- retaining partial legacy objects, ignored obsolete keys and mode flooring; obsolete tone is ignored.
-- This boundary is independent of the optional profiles module.
validateMainSettings=function(settings)
  if type(settings)~='table' or getmetatable(settings)~=nil then return nil,'invalid_settings' end
  for key in pairs(settings) do
    if type(key)~='string' then return nil,'invalid_settings' end
  end
  local ranges={mode={0,3},deferredTTL={1,120},deferredCooldownSeconds={0,600},
    autosaveIntervalSeconds={60,1800},autosaveCooldownSeconds={30,600}}
  for key,default in pairs(currentSettings()) do
    local value=settings[key]
    if value~=nil then
      local range=ranges[key]
      if range then
        if type(value)~='number' or value~=value or value<range[1] or value>range[2] or
          ((key~='mode') and value~=math.floor(value)) then return nil,'invalid_settings' end
      elseif type(default)~='boolean' or type(value)~='boolean' then return nil,'invalid_settings' end
    end
  end
  return true
end
local function saveConfig()
  local ok, accepted = pcall(configStore.save, file, currentSettings(), validateMainSettings)
  if not ok or accepted ~= true then
    recordFailure('write_failed')
    configStatus = 'Runtime settings changed; configuration write failed: ' .. tostring(accepted)
    log(configStatus)
    return false
  end
  configStatus = 'Configuration written'
  return true
end
-- Both menus are views over currentSettings and the single validated mutation path below.
local setUISetting
local function syncNative()
  if nativeUI then nativeUI:sync(); nativeStatus=nativeUI.status end
end
local setDeferredEnabled,setAutosaveEnabled
local function registerNativeSettings()
  if not uiCatalog or type(uiCatalog.valid)~='function' or not nativeUIFactory or type(nativeUIFactory.new)~='function' then
    nativeStatus='UI modules unavailable; save runtime unchanged'
    return
  end
  if not nativeUI then
    local ok,value=pcall(nativeUIFactory.new,uiCatalog,currentSettings,function(key,value) return setUISetting(key,value) end,log)
    if not ok or type(value)~='table' or type(value.register)~='function' then
      nativeStatus='Native UI adapter failed to initialize; runtime unchanged';return
    end
    nativeUI=value
  end
  nativeUI:register(GetMod)
  nativeStatus=nativeUI.status
end
local sampleState
local function apply()
  attempts = attempts + 1
  local ok, player = pcall(function() return Game.GetPlayer() end)
  if not ok or not player then
    message = 'Player not available'; failures = failures + 1; return
  end
  -- A menu can open before the periodic sample after loading another character.
  if player ~= lastPlayer then sampleState(player) end
  local success, err = pcall(function()
    player:NLSRebornSetMode(mode)
    player:NLSRebornDeferredSetEnabled(deferredEnabled)
    -- Optional lane failure must not prevent the established manual bridge.
    pcall(function() player:NLSRebornAutosaveSetEnabled(autosaveEnabled and autosavePolicy~=nil and autosaveState~=nil) end)
    player:NLSRebornSetOptions(allowCombat, allowVehicle)
    player:NLSRebornSetObservedState(combatKnown,combatActive,vehicleKnown,vehicleActive)
    player:NLSRebornSetContext(context, body, safetyBlock)
    player:NLSRebornSetNotificationsEnabled(notificationsEnabled)
    player:NLSRebornSetDFNotifications(dfNotifications.dfNotifyVehicleSleep, dfNotifications.dfNotifyAddiction,
      dfNotifications.dfNotifyStarvation, dfNotifications.dfNotifyDehydration)
    local expectedDFMask = (dfNotifications.dfNotifyVehicleSleep and 1 or 0) +
      (dfNotifications.dfNotifyAddiction and 2 or 0) + (dfNotifications.dfNotifyStarvation and 4 or 0) +
      (dfNotifications.dfNotifyDehydration and 8 or 0)
    if player:NLSRebornGetDFNotificationMask() ~= expectedDFMask then error('Dark Future notification readback mismatch') end
    local actual = player:NLSRebornGetMode()
    if actual ~= mode then error('Mode readback mismatch: ' .. tostring(actual)) end
    local actualEnabled = player:NLSRebornGetNotificationsEnabled()
    if actualEnabled ~= notificationsEnabled then error('Notification toggle readback mismatch') end
  end)
  if success then
    successes = successes + 1
    message = 'Bridge OK: ' .. names[mode+1]
    if lastApplied ~= mode then log(message) end
    lastApplied = mode
    lastPlayer = player
  else
    failures = failures + 1
    recordFailure('bridge_unavailable')
    message = 'Bridge failed: ' .. tostring(err)
    log(message)
  end
end
local function currentQueuePlayer()
  local ok,p=pcall(function() return Game.GetPlayer() end)
  return ok and p or nil
end
local function clearDeferred(reason, player)
  local had=deferredState.pending~=nil
  local noticeSession,noticeSerial,noticeOrigin=deferredSession,deferredGameSerial,deferredOrigin
  if not had and player then
    local ok,pending,source,serial=pcall(function()
      return player:NLSRebornDeferredIsPending(),player:NLSRebornDeferredGetSource(),player:NLSRebornDeferredGetSerial()
    end)
    if ok and pending==true and (source==1 or source==2 or source==3) then
      noticeSerial=serial;noticeOrigin=source==3 and 'autosave' or 'game'
    end
  end
  if noticeOrigin=='game' or noticeOrigin=='autosave' then
    statusNotice(reason=='Expired without save' and 'expired' or reason:find('Error:',1,true)==1 and 'error' or 'cancelled',noticeSession,noticeSerial)
  end
  autosaveQueuedReason=nil;autosaveQueuedSerial=nil;autosaveQueuedSession=nil
  if had or deferredOrigin=='game' or deferredOrigin=='autosave' or deferredOrigin=='preview' then
    local phase=reason=='Expired without save' and 'Expired' or reason:find('Error:',1,true)==1 and 'Error' or 'Cancelled'
    local cause=reason
    lastQueueOutcomeState,lastQueueOutcomeReason=phase,reason
    guardianCall('close',deferredSession or 0,deferredOrigin=='preview' and 0 or deferredGameSerial,phase,cause)
  end
  deferred.cancel(deferredState)
  combatEvents:clear()
  deferredOrigin=nil; deferredGameSerial=nil; deferredUnlockStable=0
  deferredGate=reason
  if had or reason=='Disabled' or reason=='Expired without save' or reason:find('Error:',1,true)==1 then deferredStatus=reason; deferredEvent=reason end
  if player then pcall(function() player:NLSRebornDeferredCancel() end) end
end
setDeferredEnabled=function(value)
  deferredEnabled=not not value
  local player=currentQueuePlayer()
  local autoPending=false
  if player then
    local ok,source,pending=pcall(function() return player:NLSRebornDeferredGetSource(),player:NLSRebornDeferredIsPending() end)
    autoPending=ok and source==3 and pending==true
  end
  if not deferredEnabled and deferredOrigin~='autosave' and not autoPending then clearDeferred('Disabled',player) end
  if player then pcall(function() player:NLSRebornDeferredSetEnabled(deferredEnabled) end) end
  lastApplied=-1
end
setAutosaveEnabled=function(value)
  autosaveEnabled=not not value
  configureAutosave()
  local player=currentQueuePlayer()
  if not autosaveEnabled and deferredOrigin=='autosave' then clearDeferred('Autosave disabled',player) end
  if player then pcall(function() player:NLSRebornAutosaveSetEnabled(autosaveEnabled and autosavePolicy~=nil and autosaveState~=nil) end) end
end
-- UI values are validated here before any setting, queue or file state changes.
setUISetting=function(key,value)
  if not uiCatalog or type(uiCatalog.valid)~='function' or not uiCatalog.valid(key,value) then return false end
  if currentSettings()[key]==value then return true end
  local bridgeChanged=false
  if key=='mode' then mode=value;bridgeChanged=true
  elseif key=='notificationsEnabled' then notificationsEnabled=value;bridgeChanged=true
  elseif key=='statusNotificationsEnabled' then statusNotificationsEnabled=value
  elseif key=='diagnosticDetails' then diagnosticDetails=value
  elseif key=='deferredEnabled' then setDeferredEnabled(value)
  elseif key=='guardianEnabled' then setGuardianEnabled(value)
  elseif key=='deferredTTL' then deferredTTL=value
  elseif key=='deferredCooldownSeconds' then deferredCooldownSeconds=value
  elseif key=='autosaveEnabled' then setAutosaveEnabled(value)
  elseif dfNotifications[key]~=nil then dfNotifications[key]=value;bridgeChanged=true
  else
    local optionKeys={autosaveIntervalSeconds='intervalSeconds',autosaveCooldownSeconds='cooldownSeconds',
      autosaveExploration='exploration',autosavePostCombat='postCombat',autosaveVehicleExit='vehicleExit',
      autosaveQuestMilestone='questMilestone',autosaveApartmentEntry='apartmentEntry'}
    local option=optionKeys[key]
    if not option then return false end
    autosaveOptions[option]=value;configureAutosave()
  end
  local persisted=saveConfig()
  syncNative()
  if bridgeChanged then lastApplied=-1;apply() end
  return persisted
end
local function loadPreset(label)
  if not profileBank or not profilesModule then profileStatus='Profile module unavailable'; return end
  local ok,value,code=pcall(function() return profileBank:get(label) end)
  if not ok or type(value)~='table' then recordFailure(code or 'read_failed');profileStatus='Preset not applied: '..tostring(code or 'read_failed');return end
  local valid,settings=pcall(profilesModule.validate,value)
  if not valid or type(settings)~='table' then recordFailure('invalid_settings');profileStatus='Preset not applied: invalid_settings';return end
  -- Persistence failure must preserve the existing runtime and pending request.
  local persisted,accepted=pcall(configStore.save,file,settings,validateMainSettings)
  if not persisted or accepted~=true then recordFailure('write_failed');profileStatus='Preset not applied: write_failed';return end
  configStatus='Configuration written'
  clearDeferred('Profile applied',currentQueuePlayer())
  mode,allowCombat,allowVehicle=settings.mode,settings.allowCombat,settings.allowVehicle
  notificationsEnabled,diagnosticDetails=settings.notificationsEnabled,settings.diagnosticDetails
  statusNotificationsEnabled=settings.statusNotificationsEnabled==true
  deferredTTL,deferredCooldownSeconds=settings.deferredTTL,settings.deferredCooldownSeconds
  for _,option in ipairs(dfNotificationOptions) do dfNotifications[option.key]=settings[option.key] end
  autosaveOptions.intervalSeconds,autosaveOptions.cooldownSeconds=settings.autosaveIntervalSeconds,settings.autosaveCooldownSeconds
  autosaveOptions.exploration,autosaveOptions.postCombat,autosaveOptions.vehicleExit=settings.autosaveExploration,settings.autosavePostCombat,settings.autosaveVehicleExit
  autosaveOptions.questMilestone=settings.autosaveQuestMilestone
  autosaveOptions.apartmentEntry=settings.autosaveApartmentEntry==true
  setGuardianEnabled(settings.guardianEnabled)
  setDeferredEnabled(settings.deferredEnabled);setAutosaveEnabled(settings.autosaveEnabled)
  profileSelected=true;lastApplied=-1;syncNative();apply()
  profileStatus='Named settings preset applied'
end
local function exportSupportReport()
  if not supportReport or type(supportReport.build)~='function' then reportStatus='Report module unavailable';return end
  local player=currentQueuePlayer()
  lastDarkFutureSnapshot={}
  if player then
    sampleState(player)
    sampleDarkFuture(player)
  else
    combatKnown,combatActive,vehicleKnown,vehicleActive,phoneKnown,phoneActive=false,false,false,false,false,false
    phoneBridgeStatus,phoneRawState='not_sampled',nil
    body=0;bodyStatus='UNKNOWN';context=0
  end
  local function read(fn)
    local ok,value=pcall(fn);if ok then return value end
    return nil
  end
  local pending=read(function() return player:NLSRebornDeferredIsPending() end)
  local source=read(function() return player:NLSRebornDeferredGetSource() end)
  local paused=read(function() return player:NLSRebornPausedState() end)
  local menu=read(function() return player:NLSRebornMenuState() end)
  local pausedValue,inMenuValue=nil,nil
  if paused==0 and menu==0 then pausedValue=false elseif paused==1 or menu==1 then pausedValue=true end
  if menu==0 then inMenuValue=false elseif menu==1 then inMenuValue=true end
  local a=read(function() return autosavePolicy.status(autosaveState) end) or {enabled=autosaveEnabled,status='disabled'}
  local g=read(function() return guardian:report() end) or {enabled=guardianEnabled}
  local df={}
  for _,field in ipairs({'lifecycle','enabled','valid','inMenu'}) do df[field]=lastDarkFutureSnapshot[field] end
  local diagnosticDF=read(function() return player:NLSRebornDiagnosticDFState() end)
  df.vehicleSleep=read(function() return diagnosticDF.vehicleSleep end)
  df.addiction=read(function() return diagnosticDF.addiction end)
  df.starvation=read(function() return diagnosticDF.starvation end)
  df.dehydration=read(function() return diagnosticDF.dehydration end)
  local observerEvidence={
    guardian=read(function() return guardianBridge:diagnostics() end),
    quest=read(function() return questEvents:diagnostics() end)}
  local lockEvidence={known=false,overflow=false,codes={}}
  local rawLocks=read(function() return player:NLSRebornSaveLockSummary() end)
  if rawLocks=='unlocked' then lockEvidence.known=true
  elseif rawLocks=='overflow' then lockEvidence.overflow=true
  elseif type(rawLocks)=='string' and #rawLocks<=512 and rawLocks:match('^locked|') then
    local allowed={Nothing=true,Combat=true,Scene=true,Quest=true,Script=true,Boundary=true,MainMenu=true,
      LoadingScreen=true,PlayerStateMachine=true,PlayerState=true,Tier=true,NotEnoughSlots=true,
      NotEnoughSpace=true,PlayerOnMovingPlatform=true,Unknown=true}
    local valid=true
    for code in rawLocks:sub(8):gmatch('[^|]+') do
      if not allowed[code] or #lockEvidence.codes>=16 then valid=false;break end
      lockEvidence.codes[#lockEvidence.codes+1]=code
      if code=='Unknown' then valid=false end
    end
    lockEvidence.known=valid and #lockEvidence.codes>0 and rawLocks=='locked|'..table.concat(lockEvidence.codes,'|')
  end
  local gate=deferredGate
  local phase=deferredState.pending and 'Waiting' or deferredStatus:find('Submitted',1,true) and 'Submitted' or
    deferredStatus=='Expired without save' and 'Expired' or deferredStatus:find('Error:',1,true)==1 and 'Error' or
    deferredStatus:find('Cancelled',1,true) and 'Cancelled' or 'Unknown'
  local currentPhase=deferredState.pending and 'Waiting' or 'Idle'
  local gameVersion=read(function() return GetSingleton('inkMenuScenario'):GetSystemRequestsHandler():GetGameVersion() end)
  -- Collect only on explicit support export. Version APIs cannot affect save policy.
  local versionSnapshot={}
  local dependencySample=type(dependencyVersions)=='table' and getmetatable(dependencyVersions)==nil and rawget(dependencyVersions,'sample') or nil
  if type(dependencySample)=='function' then
    local ok,value=pcall(dependencySample,{
      cet=function()
        if type(GetVersion)~='function' then return nil end
        return GetVersion()
      end,
      codeware=function()
        if Codeware==nil then return nil end
        return Codeware.Version()
      end,
      nativeSettings=function()
        if type(GetMod)~='function' then return nil end
        local native=GetMod('nativeSettings')
        if type(native)~='table' or getmetatable(native)~=nil then return nil end
        return rawget(native,'version')
      end})
    if ok and type(value)=='table' and getmetatable(value)==nil then versionSnapshot=value end
  end
  local snapshot={build=VERSION,gameBuild=gameVersion,versions=versionSnapshot.versions,dependencyEvidence=versionSnapshot.evidence,settings=currentSettings(),
    facts={q000_done=read(function() return Game.GetQuestsSystem():GetFactStr('q000_done') end),
      q001_started=read(function() return Game.GetQuestsSystem():GetFactStr('q001_started') end)},
    sensors={combatKnown=combatKnown,combatActive=combatActive,vehicleKnown=vehicleKnown,vehicleActive=vehicleActive,
      phoneKnown=phoneKnown,phoneActive=phoneActive,phoneBridgeStatus=phoneBridgeStatus,phoneRawState=phoneRawState,
      autosavePhoneBridgeStatus=autosavePhoneBridgeStatus,autosavePhoneRawState=autosavePhoneRawState,autosavePhoneSource=autosavePhoneSource,paused=pausedValue,inMenu=inMenuValue},
    context=player and context or nil,body=player and body or nil,observers=observerEvidence,locks=lockEvidence,
    checkpointAttempt={serial=read(function() return player:NLSRebornCheckpointGetSerial() end),
      source=read(function() return player:NLSRebornCheckpointGetSource() end),
      result=read(function() return player:NLSRebornCheckpointGetResult() end),
      locks=read(function() return player:NLSRebornCheckpointGetLocks() end),
      combat=read(function() return player:NLSRebornCheckpointGetCombat() end),
      mounted=read(function() return player:NLSRebornCheckpointGetMounted() end)},
    statusNotifications=read(function() return statusEmitter:status() end),
    queue={pending=pending,source=source==1 and 'manual' or source==2 and 'quicksave' or source==3 and 'autosave' or 'unknown',
      serial=read(function() return player:NLSRebornDeferredGetSerial() end),session=deferredSession,gate=gate,state=phase,currentState=currentPhase,lastOutcomeState=lastQueueOutcomeState,lastOutcomeReason=lastQueueOutcomeReason,origin=deferredOrigin,
      retention=deferredState.pending and deferredState.pending.retention or 'none',eventDriver=combatEvents:diagnostics(),
      expiresIn=deferredState.pending and deferredState.pending.expires and math.max(0,math.ceil(deferredState.pending.expires-deferredClock)) or nil},
    darkFuture=df,notificationPool=read(function() return player:NLSRebornGetNotificationDiagnostics() end),
    configWriteStatus=configStatus=='Configuration written' and 'written' or configStatus:find('Save failed:',1,true)==1 and 'failed' or 'not_written_this_session',
    profileSelected=profileSelected,guardian=g,completion=read(function() return completionTracker:report() end),autosave=a,errors=supportFailures}
  local exportOK,accepted=pcall(function() return configStore.save('support-report.json',supportReport.build(snapshot)) end)
  local exported=exportOK and accepted==true
  if not exported then recordFailure('report_failed') end
  reportStatus=exported and 'Local support-report.json written' or 'Report export failed'
end
registerForEvent('onInit', function()
  loadConfig()
  combatEvents:register(ObserveAfter,ObserveBefore)
  configureAutosave()
  refreshProfileLabels()
  setGuardianEnabled(guardianEnabled)
  if guardianBridge then pcall(function() guardianBridge:register() end) end
  if questEvents then pcall(function() questEvents:register() end) end
  local initialPlayer=currentQueuePlayer()
  if initialPlayer then
    pcall(function() initialPlayer:NLSRebornSetStatusNotificationsEnabled(false) end)
    pcall(function() initialPlayer:NLSRebornDeferredCancel() end)
  end
  registerNativeSettings()
  deferredStatus = deferredEnabled and 'Live queue enabled' or 'Disabled'
  log('v' .. VERSION .. ' loaded')
end)
registerForEvent('onOverlayOpen', function() show = true; apply() end)
registerForEvent('onOverlayClose', function() show = false;combatEvents:signal(deferredSession,'overlay_closed') end)
registerForEvent('onShutdown', function()
  clearDeferred('Session shutdown',currentQueuePlayer())
  combatEvents:shutdown()
end)
-- Observe through CET using protected calls. Missing game APIs are UNKNOWN, never false.
-- Read-only base quest facts, extracted from game quest definitions.
local function checkPrologue()
  -- q000_done is the verified completion fact. q001_started can be zero on
  -- a post-introduction save; keep it diagnostic-only, never a second gate.
  local ok,done=pcall(function() return Game.GetQuestsSystem():GetFactStr('q000_done') end)
  local rescueOK,rescue=pcall(function() return Game.GetQuestsSystem():GetFactStr('q001_started') end)
  local detail='q000_done='..(ok and type(done)=='number' and tostring(done) or 'UNKNOWN')..
    ' q001_started='..(rescueOK and type(rescue)=='number' and tostring(rescue) or 'UNKNOWN')..' (diagnostic only)'
  if not ok or type(done)~='number' then return false,detail end
  return done>0,detail
end
local function notifyActivation(player)
  if not prologueActive then return end
  local ok,result=pcall(function()
    local qs=Game.GetQuestsSystem()
    if qs:GetFactStr('nlsr_activation_notice_v081')>0 then return 'already shown' end
    player:NLSRebornShowActivation()
    qs:SetFactStr('nlsr_activation_notice_v081',1)
    return 'shown'
  end)
  activationNoticeStatus=ok and result or ('failed: '..tostring(result))
end

sampleState = function(player)
  local okCombat, combat = pcall(function() return player:IsInCombat() end)
  combatKnown = okCombat and type(combat) == 'boolean'
  combatActive = combatKnown and combat or false
  local okVehicle, vehicle = pcall(function() return player:NLSRebornMountedState() end)
  vehicleKnown = okVehicle and (vehicle==0 or vehicle==1)
  vehicleActive = vehicleKnown and vehicle==1
  phoneKnown,phoneActive,phoneBridgeStatus,phoneRawState = detectPhone()
  body, bodyStatus = detectBody(player)
  local crouchOk,crouch=pcall(function() return player:IsCrouching() end)
  context=(phoneKnown and phoneActive) and 5 or
    combatActive and vehicleActive and 3 or combatActive and 1 or vehicleActive and 2 or
    (crouchOk and crouch==true) and 4 or 0
  prologueActive,prologueStatus=checkPrologue()
  safetyBlock=not prologueActive
  if safetyBlock then context=7 end
  phoneStatus = phoneKnown and (phoneActive and 'ACTIVE' or 'inactive') or
    ('UNKNOWN ('..tostring(phoneBridgeStatus)..(phoneRawState~=nil and ', raw='..tostring(phoneRawState) or '')..')')
  sensorStatus = 'Combat: '..(combatKnown and tostring(combatActive) or 'UNKNOWN') ..
    ' | Vehicle: '..(vehicleKnown and tostring(vehicleActive) or 'UNKNOWN')
end
local function runAutosave(player,session,delta)
  if not autosavePolicy or not autosaveState then return end
  if not autosaveEnabled then autosaveStatus='Disabled'; return end
  local bridgeOK=pcall(function() player:NLSRebornAutosaveSetEnabled(autosaveEnabled) end)
  local pausedOK,paused=pcall(function() return player:NLSRebornPausedState() end)
  local menuOK,menu=pcall(function() return player:NLSRebornMenuState() end)
  local pausedValue=nil
  if pausedOK and paused==0 and menuOK and menu==0 then pausedValue=false
  elseif (pausedOK and paused==1) or (menuOK and menu==1) then pausedValue=true end
  local combatOK,combat=pcall(function() return player:IsInCombat() end)
  local mountedOK,mounted=pcall(function() return player:NLSRebornMountedState() end)
  local phoneOK,phoneActiveNow,phoneStatusNow,phoneRawNow,phoneSourceNow=readAutosavePhone(player)
  local phone=phoneOK and (phoneActiveNow and 1 or 0) or phoneRawNow
  autosavePhoneBridgeStatus,autosavePhoneRawState,autosavePhoneSource=phoneStatusNow,phoneRawNow,phoneSourceNow
  local nativeOK,native=pcall(function() return player:NLSRebornDeferredNativeUnlocked() end)
  local pendingOK,pending=pcall(function() return player:NLSRebornDeferredIsPending() end)
  local known=bridgeOK and nativeOK and type(native)=='boolean' and pendingOK and type(pending)=='boolean'
  local ready=known and native==true and pausedValue==false and combatOK and combat==false and
    mountedOK and mounted==0 and phoneOK and phone==0 and prologueActive and session~=nil
  if ready and type(delta)=='number' and delta>=0 and delta<=1 then autosaveStable=autosaveStable+math.min(delta,0.25)
  else autosaveStable=0 end
  local apartmentOK,apartment=true,nil
  if autosaveOptions.apartmentEntry then apartmentOK,apartment=pcall(function() return player:NLSRebornApartmentState() end) end
  local freshMilestone=false
  if questEvents then
    local uninterrupted=known and prologueActive and session~=nil and pausedValue==false and
      combatOK and combat==false and mountedOK and mounted==0 and phoneOK and phone==0 and
      type(delta)=='number' and delta==delta and delta>=0 and delta<=1
    if autosaveOptions.questMilestone and uninterrupted then
      local drained,events=pcall(function() return questEvents:drain(session) end)
      freshMilestone=drained and type(events)=='table' and #events>0
      if not drained then pcall(function() questEvents:clear() end) end
    else pcall(function() questEvents:clear() end) end
  end
  local ok,result=pcall(autosavePolicy.tick,autosaveState,delta,{
    session=session,playerReady=player~=nil,introComplete=prologueActive,
    bridgeReady=known,nativeUnlocked=nativeOK and native==true,stableReady=autosaveStable>=2,questMilestone=freshMilestone,
    apartmentKnown=apartmentOK and (apartment==0 or apartment==1),apartmentInside=apartment==1,
    paused=pausedValue,
    combatKnown=combatOK and type(combat)=='boolean',combatActive=combat==true,
    vehicleKnown=mountedOK and (mounted==0 or mounted==1),vehicleActive=mounted==1,
    phoneKnown=phoneOK,phoneActive=phoneActiveNow,
    queueBusy=(pendingOK and pending==true) or deferredState.pending~=nil
  },function(reason,expectedSession)
    if expectedSession~=deferredSession or not player or not autosaveEnabled then return false end
    local accepted,queued=pcall(function() return player:NLSRebornAutosaveQueue() end)
    if accepted and queued==true then
      local metaOK,serial=pcall(function() return player:NLSRebornDeferredGetSerial() end)
      if reason=='apartment_entry' and (not metaOK or not boundedInteger(serial,1,2147483647)) then
        pcall(function() player:NLSRebornAutosaveSetEnabled(false) end)
        return false
      end
      autosaveQueuedReason=reason;autosaveQueuedSerial=metaOK and serial or nil;autosaveQueuedSession=expectedSession
      deferredEvent='Autosave checkpoint queued: '..tostring(reason)
    end
    return accepted and queued==true
  end)
  if not ok then
    recordFailure('scheduler_unavailable')
    autosaveStable=0;autosaveStatus='Scheduler error; no checkpoint requested'
    pcall(autosavePolicy.reset,autosaveState,session,'runtime_error')
  else
    local statusOK,status=pcall(autosavePolicy.status,autosaveState)
    local state=statusOK and type(status)=='table' and status.status or result
    autosaveStatus=state=='queue_request_accepted' and 'Automatic checkpoint request queued' or tostring(state)
  end
end
local function autosaveInterrupted(player,delta)
  if type(delta)~='number' or delta~=delta or delta<0 or delta>1 then return true end
  local ok,safe=pcall(function()
    local native=player:NLSRebornDeferredNativeUnlocked()
    if autosaveOptions.apartmentEntry then
      local apartment=player:NLSRebornApartmentState()
      if apartment~=0 and apartment~=1 then return false end
      if autosaveQueuedReason=='apartment_entry' and autosaveQueuedSession==deferredSession and
        autosaveQueuedSerial==deferredGameSerial and apartment~=1 then return false end
    end
    local phoneOK,phoneActiveNow=readAutosavePhone(player)
    return type(native)=='boolean' and player:NLSRebornPausedState()==0 and player:NLSRebornMenuState()==0 and
      phoneOK and not phoneActiveNow and player:IsInCombat()==false and player:NLSRebornMountedState()==0
  end)
  return not ok or safe~=true
end
local elapsed = 0
registerForEvent('onUpdate', function(delta)
  local validDelta=type(delta)=='number' and delta==delta and delta>=0 and delta<math.huge
  if not validDelta or delta>1 then combatEvents:interrupt();deferredUnlockStable=0 end
  delta=validDelta and delta or 0
  deferredClock = deferredClock + delta
  local okQueuePlayer, queuePlayer = pcall(function() return Game.GetPlayer() end)
  if not okQueuePlayer then queuePlayer=nil end
  local session=nil
  if queuePlayer then
    local okToken, token=pcall(function() return queuePlayer:NLSRebornDeferredSession(nextSession) end)
    if okToken and type(token)=='number' and token>0 then
      session=token
      if token>=nextSession then nextSession=token+1 end
    end
  end
  combatEvents:bind(session)
  local statusQueueReady=configureStatus(queuePlayer,session)
  if guardianBridge then pcall(function() guardianBridge:drain(session or 0) end) end
  if not session then
    if deferredSession then guardianCall('bridge_gap',deferredSession,'bridge_unavailable') end
    if completionTracker and deferredSession then pcall(function() completionTracker:invalidate(deferredSession,'session_unavailable') end) end
    clearDeferred(queuePlayer and 'Bridge unavailable' or 'Player unavailable', nil)
    deferredSession=nil; deferredSeenSerial=-1;profileSelected=false
    deferredBridge=queuePlayer and 'Unavailable: check Reborn REDscript compilation' or 'Waiting for player'
  else
    if deferredSession==nil then
      pcall(function() queuePlayer:NLSRebornDeferredCancel() end)
    end
    if deferredSession and deferredSession~=session then
      guardianCall('bridge_gap',deferredSession,'session_changed')
      if completionTracker then pcall(function() completionTracker:invalidate(deferredSession,'session_changed') end) end
      profileSelected=false
      clearDeferred('Player session changed', nil)
      pcall(function() queuePlayer:NLSRebornDeferredCancel() end)
      deferredSeenSerial=-1; lastApplied=-1; lastPlayer=nil
    end
    deferredSession=session
    -- Refresh introduction facts before any release decision, never use a stale sample.
    prologueActive,prologueStatus=checkPrologue()
    safetyBlock=not prologueActive
    local okSerial, serial=pcall(function() return queuePlayer:NLSRebornDeferredGetSerial() end)
    local okPending, pending=pcall(function() return queuePlayer:NLSRebornDeferredIsPending() end)
    local bridgeOK=okSerial and okPending and type(serial)=='number' and type(pending)=='boolean'
    deferredBridge=bridgeOK and 'Connected' or 'Unavailable: check redscript compilation'
    if combatEvents.invalidated then
      clearDeferred('Session ended: '..combatEvents.lastWake,queuePlayer)
    elseif not bridgeOK then
      recordFailure('bridge_unavailable')
      clearDeferred('Bridge unavailable', queuePlayer)
    elseif not deferredEnabled and not autosaveEnabled then
      clearDeferred('Disabled', queuePlayer)
    elseif not prologueActive then
      clearDeferred('Prologue protected or facts unknown', queuePlayer)
    else
      -- An old request from a prior Lua lifetime is never adopted after a player gap.
      if pending and serial~=deferredSeenSerial then
        local okSource, source=pcall(function() return queuePlayer:NLSRebornDeferredGetSource() end)
        if okSource and ((source==1 or source==2) and deferredEnabled or source==3 and autosaveEnabled) then
          if deferredState.pending then
            guardianCall('close',deferredSession or 0,deferredOrigin=='preview' and 0 or deferredGameSerial,'Cancelled','replaced')
          end
          guardianCall('queued',nil,source==1 and 'manual' or source==2 and 'quicksave' or source==3 and 'autosave' or 'unknown',session,serial)
          if source==3 or statusQueueReady then statusNotice(source==3 and 'auto_queued' or 'queued',session,serial) end
          if source~=3 and autosavePolicy and autosaveState then
            pcall(autosavePolicy.reset,autosaveState,session,'player queue has priority')
          end
          deferredSeenSerial=serial; deferredGameSerial=serial
          deferred.request(deferredState,deferredClock,source==2 and 'quicksave' or source==3 and 'autosave' or 'manual',deferredTTL,source~=3 and 'session' or nil)
          combatEvents:arm(session,serial,deferredClock)
          deferredOrigin=source==3 and 'autosave' or 'game'; deferredUnlockStable=0
          deferredStatus='Pending: game request received'; deferredEvent='Game request #'..tostring(serial)
        else
          clearDeferred('Invalid request source', queuePlayer)
        end
      elseif (deferredOrigin=='game' or deferredOrigin=='autosave') and not pending then
        clearDeferred('Game request cleared', nil)
      end
      if deferredOrigin=='autosave' and autosaveInterrupted(queuePlayer,delta) then
        clearDeferred('Autosave interrupted by safety state',queuePlayer)
        if autosavePolicy and autosaveState then pcall(autosavePolicy.reset,autosaveState,session,'automatic queue interrupted') end
      elseif deferredState.pending then
        -- Player requests have no expiry. The callback only marks this work due;
        -- eligible samples and native dispatch remain on CET's update boundary.
        local isPlayer=deferredOrigin=='game'
        if not isPlayer or combatEvents:due(deferredClock) then
          local nativeUnlocked=false
          local reason='Preview: dry run'
          if deferredOrigin=='game' or deferredOrigin=='autosave' then
            local okCombat,activeCombat=pcall(function() return queuePlayer:IsInCombat() end)
            local okUnlocked,unlocked=pcall(function() return queuePlayer:NLSRebornDeferredNativeUnlocked() end)
            local pauseOK,paused=pcall(function() return queuePlayer:NLSRebornPausedState() end)
            local menuOK,inMenu=pcall(function() return queuePlayer:NLSRebornMenuState() end)
            if not okCombat or type(activeCombat)~='boolean' then reason='Waiting: combat state unknown'
            elseif activeCombat then reason='Waiting: combat active'
            elseif not pauseOK or not menuOK or (paused~=0 and paused~=1) or (inMenu~=0 and inMenu~=1) then reason='Waiting: pause/menu state unknown'
            elseif paused==1 or inMenu==1 then reason='Waiting: paused or menu open'
            elseif not okUnlocked or type(unlocked)~='boolean' then reason='Waiting: native permission unknown'
            elseif not unlocked then reason='Waiting: native save lock'
            else nativeUnlocked=true;reason='Combat clear and native unlocked: stabilization' end
            if deferredOrigin=='autosave' then
              local readyOK,ready=pcall(function() return queuePlayer:NLSRebornAutosaveReady() end)
              nativeUnlocked=nativeUnlocked and readyOK and ready==true
            end
          end
          local stable=false
          if isPlayer then
            stable=combatEvents:sample(deferredClock,nativeUnlocked,reason)
            deferredUnlockStable=combatEvents.stable
          else
            if nativeUnlocked then deferredUnlockStable=deferredUnlockStable+math.min(delta,0.25)
            else deferredUnlockStable=0 end
            stable=deferredUnlockStable>=2
          end
          local cooldownClear=deferredClock-deferredLastDispatch>=deferredCooldownSeconds
          local completionClear,completionReason=true,nil
          if completionTracker and (deferredOrigin=='game' or deferredOrigin=='autosave') then
            local okCompletion,clear,why=pcall(function() return completionTracker:can_dispatch(session) end)
            completionClear=okCompletion and clear==true
            completionReason=why
          end
          if nativeUnlocked and stable and cooldownClear and not completionClear then
            deferredGate='Waiting: previous save completion unknown'
          else
            deferredGate=nativeUnlocked and stable and not cooldownClear and 'Waiting: dispatch cooldown' or reason
          end
          guardianCall('waiting',session,deferredOrigin=='preview' and 0 or deferredGameSerial,
            deferredOrigin=='preview' and 'preview' or deferredGate)
          local dispatchMetadataBefore=nil
          local outcome=deferred.tick(deferredState,deferredClock,{
            playerReady=deferredOrigin=='game' or deferredOrigin=='autosave',introComplete=prologueActive,
            nativeSavingUnlocked=nativeUnlocked and stable and cooldownClear and completionClear and not combatEvents.invalidated,
            enginePermissionOnly=true
          },function()
            -- Native code rechecks combat/locks/intro/serial. There is no engine
            -- retry after acceptance or an unknown dispatch outcome.
            dispatchMetadataBefore=latestSaveFingerprint()
            guardianCall('executing',session,deferredGameSerial)
            local beforeOK,before=pcall(function() return queuePlayer:NLSRebornCheckpointGetSerial() end)
            local okDispatch,submitted=pcall(function() return queuePlayer:NLSRebornDeferredDispatch(deferredGameSerial) end)
            if okDispatch and submitted==false and beforeOK and boundedInteger(before,0,2147483647) then
              local readOK,pendingNow,serialNow,attemptNow=pcall(function()
                return queuePlayer:NLSRebornDeferredIsPending(),queuePlayer:NLSRebornDeferredGetSerial(),queuePlayer:NLSRebornCheckpointGetSerial()
              end)
              if readOK and pendingNow==true and serialNow==deferredGameSerial and attemptNow==before then
                -- REDscript left the matching intent pending and never entered
                -- the checkpoint helper. Recheck permission, not an engine retry.
                combatEvents:interrupt()
                deferredGate='Waiting: native permission changed before dispatch'
                guardianCall('preflight_wait',session,deferredGameSerial)
                return 'preflight_wait'
              end
            end
            return okDispatch and submitted==true
          end)
          if outcome=='expired' then clearDeferred('Expired without save',queuePlayer)
          elseif outcome=='request_submitted' then
            if completionTracker then
              pcall(function() completionTracker:submitted(session,deferredGameSerial,deferredOrigin or 'unknown',dispatchMetadataBefore) end)
            end
            guardianCall('submitted',session,deferredGameSerial)
            statusNotice('submitted',session,deferredGameSerial)
            deferredLastDispatch=deferredClock
            if deferredOrigin=='game' and autosavePolicy and autosaveState then
              pcall(autosavePolicy.reset,autosaveState,session,'player checkpoint submitted')
            end
            deferredStatus='Submitted (save completion unconfirmed)';deferredEvent='Submitted'
            lastQueueOutcomeState,lastQueueOutcomeReason='Submitted','Submitted (write unverified)'
            deferredOrigin=nil;deferredGameSerial=nil;deferredUnlockStable=0;deferredGate='Idle'
            autosaveQueuedReason=nil;autosaveQueuedSerial=nil;autosaveQueuedSession=nil
            combatEvents:clear()
          elseif outcome=='request_failed' then recordFailure('dispatch_rejected');clearDeferred('Error: deferred dispatch rejected',queuePlayer) end
        end
      else deferredUnlockStable=0; deferredGate='Idle' end
    end
  end
  if not combatEvents.invalidated then runAutosave(queuePlayer,session,delta) end
  if statusBridgeReady and queuePlayer then
    local info=statusCall('status')
    if type(info)=='table' and type(info.pending)=='number' and info.pending>0 then
      local freshBody=detectBody(queuePlayer)
      local outcome=statusCall('drain',deferredClock,freshBody,function(text)
        local ok,accepted=pcall(function() return queuePlayer:NLSRebornStatusNotify(text) end)
        return ok and accepted==true
      end)
      if outcome then statusRuntime=tostring(outcome)..'; request/file evidence remain separate' end
    end
  end
  local okPlayer, currentPlayer = pcall(function() return Game.GetPlayer() end)
  if okPlayer and currentPlayer then
    if currentPlayer ~= lastPlayer then secondsSincePlayer = 0 end
    secondsSincePlayer = secondsSincePlayer + math.max(0, delta or 0)
  else
    secondsSincePlayer = 0
  end
  elapsed = elapsed + (delta or 0)
  if elapsed < 2 then return end
  elapsed = 0
  local ok, player = pcall(function() return Game.GetPlayer() end)
  if not ok or not player then lastPlayer = nil; sampleDarkFuture(nil); return end
  local success, actual = pcall(function() return player:NLSRebornGetMode() end)
  sampleState(player)
  sampleDarkFuture(player)
  notifyActivation(player)
  -- Immersion also needs current prologue, body and context at the existing cadence.
  if mode == 1 or mode == 3 or mode == 2 or player ~= lastPlayer or lastApplied == -1 or (success and actual ~= mode) then apply() end
end)
-- Explicit UI actions, not drawing callbacks that own gameplay state.
local function previewQueue()
  if not deferredEnabled then return end
  local player=currentQueuePlayer()
  local readOK,pending=pcall(function() return player:NLSRebornDeferredIsPending() end)
  if deferredOrigin=='game' or deferredOrigin=='autosave' or (readOK and pending==true) then
    deferredEvent='Dry run skipped: game request pending';return
  end
  guardianCall('close',deferredSession or 0,0,'Cancelled','replaced')
  guardianCall('preview',deferredSession or 0)
  deferred.request(deferredState,deferredClock,'manual',deferredTTL)
  deferredOrigin='preview';deferredUnlockStable=0
  deferredStatus='Pending: dry-run request';deferredEvent='Preview request'
end
local function saveProfile()
  if not profileBank then profileStatus='Profile module unavailable';return end
  local ok,accepted,code=pcall(function() return profileBank:save(profileLabel,currentSettings()) end)
  if not ok or accepted~=true then recordFailure(code or 'write_failed') end
  profileStatus=ok and accepted==true and 'Named preset written' or ('Preset save refused: '..tostring(code or 'write_failed'))
  refreshProfileLabels()
end
local function guardianDetails()
  local result={available=guardian~=nil,status=guardianStatus,observers='Unavailable',summary='Unavailable',rows={}}
  if guardianBridge then
    local ok,value=pcall(function() return guardianBridge:status() end)
    if ok and type(value)=='string' then result.observers=value end
  end
  if completionTracker then
    local ok,value=pcall(function() return completionTracker:report() end)
    if ok and type(value)=='table' then
      local current=type(value.current)=='table' and value.current or nil
      local last=type(value.last)=='table' and value.last or nil
      result.rows[#result.rows+1]=current and ('Save completion: in-flight session '..tostring(current.session)..' serial '..tostring(current.serial)..' | write Unknown') or 'Save completion: no Reborn request in flight'
      if last then
        result.rows[#result.rows+1]='Last completion evidence | success='..tostring(last.completion_success)..' | write='..tostring(last.write_status)..' | reload='..tostring(last.reload_status)
      end
    end
  end
  if guardian then
    local ok,value=pcall(function() return guardian:summary() end)
    if ok and type(value)=='string' then result.summary=value end
    local recentOK,recent=pcall(function() return guardian:latest() end)
    if recentOK and type(recent)=='table' then
      for index=1,12 do
        local record=recent[index]
        if type(record)=='table' then
          result.rows[#result.rows+1]=tostring(record.id)..' | '..tostring(record.source)..' | '..tostring(record.phase)..
            ' | reason: '..tostring(record.reason)..' | observed age: '..tostring(record.observed_age_seconds or 'unknown')..' s'..
            (record.awaiting_write_evidence==true and ' | Accepted, write NOT verified' or '')
        end
      end
    end
    local reportOK,report=pcall(function() return guardian:report() end)
    if reportOK and type(report)=='table' then
      local hints=type(report.uncorrelated_hints)=='table' and report.uncorrelated_hints or {}
      result.rows[#result.rows+1]='Completion callbacks: '..tostring(#hints)..' retained, uncorrelated; none confirms a specific request.'
      for index=math.max(1,#hints-3),#hints do
        local hint=hints[index]
        result.rows[#result.rows+1]='Uncorrelated callback | session '..tostring(hint.session)..' | '..
          tostring(hint.origin)..' | '..tostring(hint.outcome)
      end
    end
  end
  return result
end
local function exportGuardian()
  if not guardian then return end
  local ok,accepted=pcall(function()
    local report=guardian:report()
    report.rebornBuild=VERSION;report.gameBuild='unknown';report.frameworkVersions='unknown'
    return configStore.save('guardian-report.json',report)
  end)
  guardianStatus=ok and accepted==true and 'Local guardian-report.json written' or 'Report export failed; save policy unchanged'
  if not ok or accepted~=true then recordFailure('report_failed') end
end
local function diagnosticRows()
  local player=currentQueuePlayer()
  local dfOK,dfLastCheck=pcall(function() return player:NLSRebornGetDFPolicyStatus() end)
  local categoryOK,category=pcall(function() return player:NLSRebornGetNotificationCategory() end)
  local poolOK,pool=pcall(function() return player:NLSRebornGetNotificationDiagnostics() end)
  local categoryNames={[0]='Exploration',[1]='Combat',[2]='Vehicle',[3]='Vehicle combat',[4]='Stealth',[5]='Phone call',[7]='Prologue Protection',[12]='Prologue Protection / Corpo call'}
  return {{'Bridge counters',string.format('Attempts %d | OK %d | Failed %d',attempts,successes,failures)},
    {'Sensors',sensorStatus},{'Phone',phoneStatus},{'Autosave phone bridge',autosavePhoneBridgeStatus..' | source='..autosavePhoneSource..(autosavePhoneRawState~=nil and ' | raw='..tostring(autosavePhoneRawState) or '')},{'Safety block',tostring(safetyBlock)},
    {'Body detection',bodyStatus},{'Shuffle seed',shuffleSeed},{'Activation notice',activationNoticeStatus},
    {'Queue bridge',deferredBridge},{'Combat event driver',string.format('Requested %d | Observed %d | Unavailable %d | Checks %d | Wake %s',combatEvents.requested,combatEvents.observed,combatEvents.unavailable,combatEvents.checks,combatEvents.lastWake)},{'Notification context',categoryOK and categoryNames[category] or 'Unknown'},
    {'Last selected pool',poolOK and tostring(pool) or 'Unknown'},
    {'Last Immersion context read',dfOK and tostring(dfLastCheck) or 'Unknown'},
    {'Dark Future query error',darkFutureError or 'None reported'},
    {'Legacy combat/vehicle option keys','Retained for config compatibility; no longer grant a lock exception'},
    {'Validation','Offline checks only. In-game rendering, save creation, reload and progression remain unverified'}}
end
local function overlayView()
  local pending=deferredState.pending~=nil
  if not pending then
    local player=currentQueuePlayer()
    local ok,value=pcall(function() return player:NLSRebornDeferredIsPending() end)
    pending=ok and value==true
  end
  local questStatus='Unavailable'
  if questEvents then
    local ok,value=pcall(function() return questEvents:status() end)
    if ok and type(value)=='string' then questStatus=value end
  end
  return {title=title,version=VERSION,settings=currentSettings(),bridge=message,intro=prologueStatus,
    configStatus=configStatus,nativeStatus=nativeStatus,queuePending=pending,
    queueStatus=pending and (deferredOrigin=='preview' and 'Pending (dry run)' or deferredOrigin=='autosave' and 'Automatic request pending' or 'Player request pending') or 'Idle',
    queueGate=deferredGate,queueEvent=deferredEvent,queueLastOutcome=lastQueueOutcomeReason,queueLastOutcomeState=lastQueueOutcomeState,
    queueRetention=deferredState.pending and deferredState.pending.retention or 'none',
    queueRemaining=deferredState.pending and deferredState.pending.expires and tostring(math.max(0,math.ceil(deferredState.pending.expires-deferredClock))) or 'No expiry (current session)',
    autosave=autosaveStatus,questObserver=questStatus,darkFuture=darkFutureStatus,
    statusRuntime=statusRuntime,profileLabel=profileLabel,profileLabels=profileLabels,
    profileStatus=profileStatus,reportStatus=reportStatus}
end
local overlay=nil
if overlayFactory and type(overlayFactory.new)=='function' and uiCatalog then
  local created,value=pcall(overlayFactory.new,uiCatalog,{
    change=setUISetting,preview=previewQueue,retryBridge=apply,exportSupport=exportSupportReport,
    cancel=function() clearDeferred('Cancelled by user',currentQueuePlayer());deferredStatus='Cancelled by user';deferredEvent='Cancelled by user' end,
    setProfileLabel=function(value) profileLabel=value end,saveProfile=saveProfile,
    loadProfile=function(label) if label then profileLabel=label end;loadPreset(profileLabel) end,
    refreshProfiles=refreshProfileLabels,guardianDetails=guardianDetails,exportGuardian=exportGuardian,
    diagnostics=diagnosticRows,uiError=function(err) log('Overlay presentation error: '..err) end,
    logSnapshot=function()
      log(VERSION..' | mode='..names[mode+1]..' | prologue='..prologueStatus)
      log('Dark Future: '..darkFutureStatus)
      if darkFutureError then log('Dark Future query error: '..darkFutureError) end
      local ok,value=pcall(function() return currentQueuePlayer():NLSRebornGetDFPolicyStatus() end)
      if ok then log('Last Immersion save check: '..tostring(value)) end
    end})
  if created and type(value)=='table' and type(value.draw)=='function' then overlay=value
  else log('Overlay adapter unavailable; runtime unchanged') end
end
registerForEvent('onDraw',function()
  if not show then return end
  if overlay then overlay:draw(ImGui,overlayView())
  else
    local visible=ImGui.Begin(title)
    if visible then
      ImGui.Text(VERSION..' | UI modules unavailable')
      ImGui.TextWrapped('Install the complete matching package. Save runtime is not controlled by this error panel.')
      ImGui.TextWrapped(message)
    end
    ImGui.End()
  end
end)
