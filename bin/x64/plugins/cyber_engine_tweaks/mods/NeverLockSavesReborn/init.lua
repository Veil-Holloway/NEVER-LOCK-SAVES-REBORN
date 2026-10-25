-- Never Lock Saves Reborn v1.0.0-vehicle-diagnostic.2 Release Candidate
-- Persistent UI settings, runtime bridge, and diagnostics.
-- Smart permits only explicit combat locks with combat opt-in; mounted combat also needs vehicle opt-in.
-- DF switches control contextual messages only. Optional scheduler defaults OFF.
local title = 'Never Lock Saves: Reborn'
local deferred = require('deferred_save')
local deferredState = deferred.new()
local deferredEnabled = false
local deferredClock = 0
local deferredStatus = 'Disabled'
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
local statusAppliedEnabled,statusAppliedTone=nil,nil
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
    return questModule.new({observe=ObserveAfter,
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
  if not guardianEnabled and guardianBridge then pcall(function() guardianBridge:clear() end) end
end
local guardianLoaded,value=pcall(function()
  local factory=require('guardian')
  assert(type(factory)=='table' and type(factory.new)=='function','Guardian module unavailable')
  local stampOK,stamp=pcall(function() return os.time() end)
  local runId='R'..tostring(stampOK and type(stamp)=='number' and math.floor(stamp) or 0)..'-'..tostring(math.random(100000,999999))
  return factory.new(runId)
end)
if guardianLoaded and type(value)=='table' then guardian=value; guardianStatus='Tracking disabled' end
if guardian then
  local ok,bridge=pcall(function()
    local factory=require('guardian_bridge')
    assert(type(factory)=='table' and type(factory.new)=='function','Guardian observer module unavailable')
    return factory.new(guardian,{enabled=function() return guardianEnabled end,
      session=function() return deferredSession or 0 end,ObserveBefore=ObserveBefore,ObserveAfter=ObserveAfter})
  end)
  if ok and type(bridge)=='table' then guardianBridge=bridge end
end

-- Native save-lock gating is experimental; no independent loading/transition sensor.

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
local tone = 1
local notificationsEnabled = true
local diagnosticDetails = true
local toneNames = {"Professional", "Sarcastic", "Unhinged"}
local show = false
local lastApplied = -1
local lastPlayer = nil
local message = 'Waiting for player'
local attempts, successes, failures = 0, 0, 0
local names = {'Vanilla', 'Immersion', 'Unrestricted (experimental)', 'Smart (experimental)'}
local file = 'config.json'
local configStore = require('config_store')
local profilesModule=optional('profiles')
local supportReport=optional('support_report')
local dependencyVersions=optional('dependency_versions')
local profileBank=nil
local profileLabel='Default'
local profileLabels={}
local profileSelected=false
local profileStatus='Named presets; automatic character identity unavailable'
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
  if statusAppliedEnabled==wanted and statusAppliedTone==tone then return previouslyActive and statusBridgeReady end
  local accepted=statusCall('configure',wanted,tone)
  local active=wanted and accepted==true
  if player then
    local ok,value=pcall(function()
      player:NLSRebornSetStatusNotificationsEnabled(active)
      return player:NLSRebornGetStatusNotificationsEnabled()
    end)
    active=active and ok and value==true
    if not ok or value~=active then pcall(function() player:NLSRebornSetStatusNotificationsEnabled(false) end) end
  else active=false end
  statusAppliedEnabled=wanted;statusAppliedTone=tone;statusBridgeReady=active
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
  if ok and (state==0 or state==1) then return true,state==1 end
  return false,false -- unknown never selects a phone pool
end
local combatKnown,combatActive,vehicleKnown,vehicleActive,phoneKnown,phoneActive = false,false,false,false,false,false
local configStatus = 'Not saved this session'
local nativeSettings, nativeOptions = nil, {}
local nativeStatus = 'Native Settings UI not detected'
local syncingNative = false
local toneStatus = 'Not yet verified'
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
    if type(data.tone) == 'number' and data.tone >= 0 and data.tone <= 2 then tone = math.floor(data.tone) end
    -- Legacy dfBlock* values are intentionally ignored; those obsolete restrictions are removed.
    for _,option in ipairs(dfNotificationOptions) do
      if type(data[option.key]) == 'boolean' then dfNotifications[option.key] = data[option.key] end
    end
    log('Configuration loaded')
  else log('No valid saved config; using safe defaults') end
end
local function currentSettings()
  return {mode=mode,allowCombat=allowCombat,allowVehicle=allowVehicle,tone=tone,
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
-- retaining partial legacy objects, ignored obsolete keys and mode/tone flooring.
-- This boundary is independent of the optional profiles module.
validateMainSettings=function(settings)
  if type(settings)~='table' or getmetatable(settings)~=nil then return nil,'invalid_settings' end
  for key in pairs(settings) do
    if type(key)~='string' then return nil,'invalid_settings' end
  end
  local ranges={mode={0,3},tone={0,2},deferredTTL={1,120},deferredCooldownSeconds={0,600},
    autosaveIntervalSeconds={60,1800},autosaveCooldownSeconds={30,600}}
  for key,default in pairs(currentSettings()) do
    local value=settings[key]
    if value~=nil then
      local range=ranges[key]
      if range then
        if type(value)~='number' or value~=value or value<range[1] or value>range[2] or
          ((key~='mode' and key~='tone') and value~=math.floor(value)) then return nil,'invalid_settings' end
      elseif type(default)~='boolean' or type(value)~='boolean' then return nil,'invalid_settings' end
    end
  end
  return true
end
local function saveConfig()
  local ok, err = pcall(function() configStore.save(file,currentSettings(),validateMainSettings) end)
  if not ok then
    recordFailure('write_failed')
    configStatus = 'Save failed: ' .. tostring(err)
    log(configStatus)
  else
    configStatus = 'Configuration written'
  end
end
-- Native Settings UI is optional. Keep CET and native menu synchronized.
local function syncNative()
  if not nativeSettings or syncingNative then return end
  syncingNative = true
  local values = {mode=mode+1, tone=tone+1, notifications=notificationsEnabled,statusNotifications=statusNotificationsEnabled,
    diagnostics=diagnosticDetails, deferred=deferredEnabled, guardian=guardianEnabled, combat=allowCombat, vehicle=allowVehicle,
    autosave=autosaveEnabled,autosaveExploration=autosaveOptions.exploration,autosavePostCombat=autosaveOptions.postCombat,autosaveVehicleExit=autosaveOptions.vehicleExit,autosaveQuestMilestone=autosaveOptions.questMilestone,autosaveApartmentEntry=autosaveOptions.apartmentEntry,
    deferredTTL=deferredTTL,deferredCooldownSeconds=deferredCooldownSeconds+1,
    autosaveIntervalSeconds=autosaveOptions.intervalSeconds-59,autosaveCooldownSeconds=autosaveOptions.cooldownSeconds-29}
  for _,option in ipairs(dfNotificationOptions) do values[option.key] = dfNotifications[option.key] end
  for key,value in pairs(values) do
    if nativeOptions[key] then
      local ok,err=pcall(function() nativeSettings.setOption(nativeOptions[key], value) end)
      if not ok then log('Native option sync failed ('..key..'): '..tostring(err)) end
    end
  end
  syncingNative = false
end
local function changeSetting(key,value)
  if key == 'mode' then mode = math.max(0,math.min(3,value))
  elseif key == 'tone' then tone = math.max(0,math.min(2,value))
  elseif key == 'notifications' then notificationsEnabled = not not value
  elseif key == 'diagnostics' then diagnosticDetails = not not value
  else return end
  saveConfig()
  syncNative()
  -- apply is called by the event handler below; declared later in this file.
end
local setDeferredEnabled,setAutosaveEnabled
local function registerNativeSettings()
  if type(GetMod) ~= 'function' then return end
  local ok,ns=pcall(function() return GetMod('nativeSettings') end)
  if not ok or not ns then return end
  local success,err=pcall(function()
    nativeSettings=ns
    ns.addTab('/nlsreborn', 'Never Lock Saves: Reborn')
    ns.addSubcategory('/nlsreborn/save', 'Save Policy')
    ns.addSubcategory('/nlsreborn/notifications', 'Notifications')
    ns.addSubcategory('/nlsreborn/immersion', 'Dark Future Context Notifications')
    for _,option in ipairs(dfNotificationOptions) do
      local key = option.key
      nativeOptions[key] = ns.addSwitch('/nlsreborn/immersion', option.label,
        option.help, dfNotifications[key], true, function(v)
          if syncingNative then return end
          dfNotifications[key] = not not v
          saveConfig(); syncNative(); lastApplied=-1
        end)
    end
    nativeOptions.mode=ns.addSelectorString('/nlsreborn/save', 'Save Mode',
      'Immersion passes normal save requests and attempts the existing checkpoint fallback in the four observed DF states. Test on disposable saves.',
      {'Vanilla','Immersion','Unrestricted (experimental)','Smart (experimental)'},mode+1,2,function(v)
        if syncingNative then return end
        changeSetting('mode',v-1)
        -- Runtime bridge is retried on the next update tick.
        lastApplied=-1
      end)
    nativeOptions.deferred=ns.addSwitch('/nlsreborn/save', 'Deferred Save (preview)',
      'Memory-only queue for eligible Smart/Immersion requests. Unrestricted attempts immediately. Native gate and stable window remain; completion unverified.',
      deferredEnabled, false, function(v)
        if syncingNative then return end
        setDeferredEnabled(v)
        saveConfig(); syncNative()
      end)
    nativeOptions.autosave=ns.addSwitch('/nlsreborn/save','Smart Autosave (preview)',
      'Opt-in scheduled checkpoint requests. Existing native autosaves remain unchanged. Save completion is unconfirmed.',
      autosaveEnabled,false,function(v)
        if syncingNative then return end
        setAutosaveEnabled(v);saveConfig();syncNative()
      end)
    for _,option in ipairs({{'autosaveExploration','Exploration interval','exploration'},
      {'autosavePostCombat','After combat','postCombat'},{'autosaveVehicleExit','After vehicle exit','vehicleExit'},
      {'autosaveQuestMilestone','Verified quest milestone','questMilestone'},
      {'autosaveApartmentEntry',"V's original apartment area entry",'apartmentEntry'}}) do
      local key,label,setting=option[1],option[2],option[3]
      nativeOptions[key]=ns.addSwitch('/nlsreborn/save',label,
        'Requires Smart Autosave and verified paused/native/intro/phone/sensor readiness.',autosaveOptions[setting],setting~='questMilestone' and setting~='apartmentEntry',function(v)
          if syncingNative then return end
          autosaveOptions[setting]=not not v;configureAutosave();saveConfig();syncNative()
        end)
    end
    local numeric={
      {'deferredTTL','Queue expiry (seconds)',1,120,function() return deferredTTL end,function(v) deferredTTL=v end},
      {'deferredCooldownSeconds','Queue dispatch cooldown (seconds)',0,600,function() return deferredCooldownSeconds end,function(v) deferredCooldownSeconds=v end},
      {'autosaveIntervalSeconds','Autosave interval (seconds)',60,1800,function() return autosaveOptions.intervalSeconds end,function(v) autosaveOptions.intervalSeconds=v;configureAutosave() end},
      {'autosaveCooldownSeconds','Autosave cooldown (seconds)',30,600,function() return autosaveOptions.cooldownSeconds end,function(v) autosaveOptions.cooldownSeconds=v;configureAutosave() end}}
    for _,option in ipairs(numeric) do
      local key,label,low,high,get,set=option[1],option[2],option[3],option[4],option[5],option[6]
      local labels={};for value=low,high do labels[#labels+1]=tostring(value) end
      nativeOptions[key]=ns.addSelectorString('/nlsreborn/save',label,
        'Whole seconds; changes never confirm that a save was written.',labels,get()-low+1,get()-low+1,function(index)
          if syncingNative or not boundedInteger(index,1,#labels) then return end
          set(index+low-1);saveConfig();syncNative()
        end)
    end
    nativeOptions.guardian=ns.addSwitch('/nlsreborn/save', 'Save Guardian request ledger',
      'Optional bounded request tracking. Submitted does not mean a written or reloadable save.',
      guardianEnabled, false, function(v)
        if syncingNative then return end
        setGuardianEnabled(v); saveConfig(); syncNative()
      end)
    nativeOptions.combat=ns.addSwitch('/nlsreborn/save', 'Smart: combat saves',
      'Smart fallback requires every native lock reason to be Combat and fresh combat state. Other reasons refuse.',allowCombat,false,function(v)
        if syncingNative then return end
        allowCombat=not not v; saveConfig(); syncNative(); lastApplied=-1
      end)
    nativeOptions.vehicle=ns.addSwitch('/nlsreborn/save', 'Smart: vehicle saves',
      'Allow the combat-only Smart exception while mounted. No vehicle-only native lock override is inferred.',allowVehicle,false,function(v)
        if syncingNative then return end
        allowVehicle=not not v; saveConfig(); syncNative(); lastApplied=-1
      end)
    nativeOptions.tone=ns.addSelectorString('/nlsreborn/notifications', 'Tone',
      'Voice of the checkpoint request notification.',
      {'Professional','Sarcastic','Unhinged'},tone+1,2,function(v)
        if syncingNative then return end
        changeSetting('tone',v-1)
        lastApplied=-1
      end)
    nativeOptions.notifications=ns.addSwitch('/nlsreborn/notifications','Enable notifications',
      'Show contextual save/checkpoint request messages. Notifications never control save permission or confirm success.',
      notificationsEnabled,true,function(v)
        if syncingNative then return end
        changeSetting('notifications',v)
        lastApplied=-1
      end)
    nativeOptions.statusNotifications=ns.addSwitch('/nlsreborn/notifications','Queue status notifications',
      'Optional tone/body-aware queue lifecycle messages. Request submission never confirms a written save.',
      statusNotificationsEnabled,false,function(v)
        if syncingNative then return end
        statusNotificationsEnabled=not not v;saveConfig();syncNative()
      end)
    nativeOptions.diagnostics=ns.addSwitch('/nlsreborn/notifications','Detailed diagnostics',
      'Show bridge counters in the CET overlay.',diagnosticDetails,true,function(v)
        if syncingNative then return end
        changeSetting('diagnostics',v)
      end)
    nativeStatus='Native Settings UI connected'
  end)
  if not success then
    nativeStatus='Native Settings UI setup failed: '..tostring(err)
    nativeSettings=nil
    nativeOptions={}
    log(nativeStatus)
  end
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
    player:NLSRebornSetShuffleSeed(shuffleSeed)
    player:NLSRebornSetTone(tone)
    player:NLSRebornSetNotificationsEnabled(notificationsEnabled)
    player:NLSRebornSetDFNotifications(dfNotifications.dfNotifyVehicleSleep, dfNotifications.dfNotifyAddiction,
      dfNotifications.dfNotifyStarvation, dfNotifications.dfNotifyDehydration)
    local expectedDFMask = (dfNotifications.dfNotifyVehicleSleep and 1 or 0) +
      (dfNotifications.dfNotifyAddiction and 2 or 0) + (dfNotifications.dfNotifyStarvation and 4 or 0) +
      (dfNotifications.dfNotifyDehydration and 8 or 0)
    if player:NLSRebornGetDFNotificationMask() ~= expectedDFMask then error('Dark Future notification readback mismatch') end
    local actual = player:NLSRebornGetMode()
    if actual ~= mode then error('Mode readback mismatch: ' .. tostring(actual)) end
    local actualTone = player:NLSRebornGetTone()
    if actualTone ~= tone then error('Tone readback mismatch: expected ' .. tostring(tone) .. ', got ' .. tostring(actualTone)) end
    local actualEnabled = player:NLSRebornGetNotificationsEnabled()
    if actualEnabled ~= notificationsEnabled then error('Notification toggle readback mismatch') end
    toneStatus = 'Verified: ' .. toneNames[tone+1]
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
    toneStatus = 'Not verified'
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
    guardianCall('close',deferredSession or 0,deferredOrigin=='preview' and 0 or deferredGameSerial,phase,cause)
  end
  deferred.cancel(deferredState)
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
  mode,allowCombat,allowVehicle,tone=settings.mode,settings.allowCombat,settings.allowVehicle,settings.tone
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
  profileStatus='Named preset applied; character identity remains manual'
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
    deferredStatus=='Expired without save' and 'Expired' or deferredStatus:find('Error:',1,true)==1 and 'Error' or 'Unknown'
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
  local snapshot={build='1.0.0-vehicle-diagnostic.2',gameBuild=gameVersion,versions=versionSnapshot.versions,dependencyEvidence=versionSnapshot.evidence,settings=currentSettings(),
    facts={q000_done=read(function() return Game.GetQuestsSystem():GetFactStr('q000_done') end),
      q001_started=read(function() return Game.GetQuestsSystem():GetFactStr('q001_started') end)},
    sensors={combatKnown=combatKnown,combatActive=combatActive,vehicleKnown=vehicleKnown,vehicleActive=vehicleActive,
      phoneKnown=phoneKnown,phoneActive=phoneActive,paused=pausedValue,inMenu=inMenuValue},
    context=player and context or nil,body=player and body or nil,observers=observerEvidence,locks=lockEvidence,
    checkpointAttempt={serial=read(function() return player:NLSRebornCheckpointGetSerial() end),
      source=read(function() return player:NLSRebornCheckpointGetSource() end),
      result=read(function() return player:NLSRebornCheckpointGetResult() end),
      locks=read(function() return player:NLSRebornCheckpointGetLocks() end),
      combat=read(function() return player:NLSRebornCheckpointGetCombat() end),
      mounted=read(function() return player:NLSRebornCheckpointGetMounted() end)},
    statusNotifications=read(function() return statusEmitter:status() end),
    queue={pending=pending,source=source==1 and 'manual' or source==2 and 'quicksave' or source==3 and 'autosave' or 'unknown',
      serial=read(function() return player:NLSRebornDeferredGetSerial() end),session=deferredSession,gate=gate,state=phase,origin=deferredOrigin,
      expiresIn=deferredState.pending and math.max(0,math.ceil(deferredState.pending.expires-deferredClock)) or 0},
    darkFuture=df,notificationPool=read(function() return player:NLSRebornGetNotificationDiagnostics() end),
    configWriteStatus=configStatus=='Configuration written' and 'written' or configStatus:find('Save failed:',1,true)==1 and 'failed' or 'not_written_this_session',
    profileSelected=profileSelected,guardian=g,autosave=a,errors=supportFailures}
  local exported=pcall(function() configStore.save('support-report.json',supportReport.build(snapshot)) end)
  if not exported then recordFailure('report_failed') end
  reportStatus=exported and 'Local support-report.json written' or 'Report export failed'
end
registerForEvent('onInit', function()
  loadConfig()
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
  deferredStatus = deferredEnabled and 'Live queue enabled (experimental)' or 'Disabled'
  log('v1.0.0-vehicle-diagnostic.2 Release Candidate loaded; experimental native save-lock gate required')
end)
registerForEvent('onOverlayOpen', function() show = true; apply() end)
registerForEvent('onOverlayClose', function() show = false end)
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
  phoneKnown,phoneActive = detectPhone()
  body, bodyStatus = detectBody(player)
  local crouchOk,crouch=pcall(function() return player:IsCrouching() end)
  context=(phoneKnown and phoneActive) and 5 or
    combatActive and vehicleActive and 3 or combatActive and 1 or vehicleActive and 2 or
    (crouchOk and crouch==true) and 4 or 0
  prologueActive,prologueStatus=checkPrologue()
  safetyBlock=not prologueActive
  if safetyBlock then context=7 end
  phoneStatus = phoneKnown and (phoneActive and 'ACTIVE' or 'inactive') or 'UNKNOWN'
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
  local phoneOK,phone=pcall(function() return player:NLSRebornNotificationPhoneState() end)
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
    phoneKnown=phoneOK and (phone==0 or phone==1),phoneActive=phone==1,
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
    return type(native)=='boolean' and player:NLSRebornPausedState()==0 and player:NLSRebornMenuState()==0 and
      player:NLSRebornNotificationPhoneState()==0 and player:IsInCombat()==false and player:NLSRebornMountedState()==0
  end)
  return not ok or safe~=true
end
local elapsed = 0
registerForEvent('onUpdate', function(delta)
  deferredClock = deferredClock + math.max(0, delta or 0)
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
  local statusQueueReady=configureStatus(queuePlayer,session)
  if guardianBridge then pcall(function() guardianBridge:drain(session or 0) end) end
  if not session then
    if deferredSession then guardianCall('bridge_gap',deferredSession,'bridge_unavailable') end
    clearDeferred(queuePlayer and 'Bridge unavailable' or 'Player unavailable', nil)
    deferredSession=nil; deferredSeenSerial=-1;profileSelected=false
    deferredBridge=queuePlayer and 'Unavailable: check Reborn REDscript compilation' or 'Waiting for player'
  else
    if deferredSession==nil then
      pcall(function() queuePlayer:NLSRebornDeferredCancel() end)
    end
    if deferredSession and deferredSession~=session then
      guardianCall('bridge_gap',deferredSession,'session_changed')
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
    if not bridgeOK then
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
          guardianCall('queued',nil,source==1 and 'manual' or source==3 and 'autosave' or 'unknown',session,serial)
          if source==3 or statusQueueReady then statusNotice(source==3 and 'auto_queued' or 'queued',session,serial) end
          if source~=3 and autosavePolicy and autosaveState then
            pcall(autosavePolicy.reset,autosaveState,session,'player queue has priority')
          end
          deferredSeenSerial=serial; deferredGameSerial=serial
          deferred.request(deferredState,deferredClock,source==2 and 'quicksave' or source==3 and 'autosave' or 'manual',deferredTTL)
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
        local nativeUnlocked=false
        if deferredOrigin=='game' or deferredOrigin=='autosave' then
          local okUnlocked, unlocked=pcall(function() return queuePlayer:NLSRebornDeferredNativeUnlocked() end)
          nativeUnlocked=okUnlocked and unlocked==true
          if deferredOrigin=='autosave' then
            local readyOK,ready=pcall(function() return queuePlayer:NLSRebornAutosaveReady() end)
            nativeUnlocked=nativeUnlocked and readyOK and ready==true
          end
        end
        deferredGate=deferredOrigin=='preview' and 'Preview: dry run' or
          not nativeUnlocked and 'Waiting: native save lock or unknown' or 'Native unlocked: stabilization'
        if nativeUnlocked then deferredUnlockStable=deferredUnlockStable+math.min(math.max(0,delta or 0),0.25)
        else deferredUnlockStable=0 end
        guardianCall('waiting',session,deferredOrigin=='preview' and 0 or deferredGameSerial,
          deferredOrigin=='preview' and 'preview' or nativeUnlocked and 'stabilizing' or 'native_lock_or_unknown')
        local outcome=deferred.tick(deferredState,deferredClock,{
          playerReady=deferredOrigin=='game' or deferredOrigin=='autosave', introComplete=prologueActive,
          nativeSavingUnlocked=nativeUnlocked and deferredUnlockStable>=2 and deferredClock-deferredLastDispatch>=deferredCooldownSeconds,
          enginePermissionOnly=true
        },function()
          -- REDscript rechecks the native lock, intro facts and request serial immediately.
          guardianCall('executing',session,deferredGameSerial)
          local okDispatch, submitted=pcall(function() return queuePlayer:NLSRebornDeferredDispatch(deferredGameSerial) end)
          return okDispatch and submitted==true
        end)
        if outcome=='expired' then clearDeferred('Expired without save', queuePlayer)
        elseif outcome=='request_submitted' then
          guardianCall('submitted',session,deferredGameSerial)
          statusNotice('submitted',session,deferredGameSerial)
          deferredLastDispatch=deferredClock
          if deferredOrigin=='game' and autosavePolicy and autosaveState then
            pcall(autosavePolicy.reset,autosaveState,session,'player checkpoint submitted')
          end
          deferredStatus='Submitted (save completion unconfirmed)'; deferredEvent='Submitted'
          deferredOrigin=nil; deferredGameSerial=nil; deferredUnlockStable=0; deferredGate='Idle'
          autosaveQueuedReason=nil;autosaveQueuedSerial=nil;autosaveQueuedSession=nil
        elseif outcome=='request_failed' then recordFailure('dispatch_rejected');clearDeferred('Error: deferred dispatch rejected', queuePlayer) end
      else deferredUnlockStable=0; deferredGate='Idle' end
    end
  end
  runAutosave(queuePlayer,session,delta)
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
registerForEvent('onDraw', function()
  if not show then return end
  local visible = ImGui.Begin(title)
  if visible then
    ImGui.Text('v1.0.0-vehicle-diagnostic.2 Release Candidate | Runtime policy')
    ImGui.TextWrapped('Native menu: '..nativeStatus)
    ImGui.Separator()
    for i=0,3 do
      if ImGui.RadioButton(names[i+1], mode == i) then
        mode = i; saveConfig(); syncNative(); apply()
      end
    end
    ImGui.Separator()
    ImGui.Text('Checkpoint request notification tone:')
    ImGui.Text('Selected: ' .. toneNames[tone+1])
    for i=0,2 do
      local label = (tone == i and '[SELECTED] ' or '') .. toneNames[i+1] .. '##nls_tone_' .. tostring(i)
      if ImGui.Button(label) then
        tone = i
        saveConfig()
        syncNative()
        apply()
      end
      if i < 2 then ImGui.SameLine() end
    end
    ImGui.TextWrapped('Tone bridge: ' .. toneStatus)
    ImGui.TextWrapped('Config: ' .. configStatus)
    ImGui.Text('Save-request notifications: ' .. (notificationsEnabled and 'ON' or 'OFF'))
    if ImGui.Button((notificationsEnabled and 'Disable' or 'Enable') .. ' notifications##nls_notifications') then
      notificationsEnabled = not notificationsEnabled
      saveConfig()
      syncNative()
      apply()
    end
    ImGui.Text('Queue status notifications: '..(statusNotificationsEnabled and 'ON' or 'OFF'))
    if ImGui.Button((statusNotificationsEnabled and 'Disable' or 'Enable')..' queue status notifications##nls_status_notifications') then
      statusNotificationsEnabled=not statusNotificationsEnabled;saveConfig();syncNative()
    end
    ImGui.TextWrapped('Status channel: '..statusRuntime)
    ImGui.Text('Detailed diagnostics: ' .. (diagnosticDetails and 'ON' or 'OFF'))
    if ImGui.Button((diagnosticDetails and 'Hide' or 'Show') .. ' diagnostics##nls_diagnostics') then
      diagnosticDetails = not diagnosticDetails
      saveConfig()
      syncNative()
    end
    ImGui.Separator()
    ImGui.Text('Dark Future context notifications (Immersion):')
    for _,option in ipairs(dfNotificationOptions) do
      ImGui.Text(option.label..': '..(dfNotifications[option.key] and 'ON' or 'OFF'))
      if ImGui.Button('Toggle '..option.label..'##nls_'..option.key) then
        dfNotifications[option.key] = not dfNotifications[option.key]
        saveConfig(); syncNative(); apply()
      end
    end
    ImGui.TextWrapped('The four DF states never add a Reborn save restriction. These switches control messages only; native autosaves are unchanged.')
    ImGui.TextWrapped('Messages report save/checkpoint requests, not confirmed save success.')
    ImGui.Separator()
    ImGui.Text('Deferred Save (experimental): '..(deferredEnabled and 'ON' or 'OFF'))
    if ImGui.Button((deferredEnabled and 'Disable' or 'Enable')..' Deferred Save##nls_deferred') then
      setDeferredEnabled(not deferredEnabled)
      saveConfig(); syncNative()
    end
    if deferredEnabled then
      if ImGui.Button('Queue test request ('..tostring(deferredTTL)..'s)##nls_queue') then
        if deferredOrigin~='game' and deferredOrigin~='autosave' then
          guardianCall('close',deferredSession or 0,0,'Cancelled','replaced')
          guardianCall('preview',deferredSession or 0)
          deferred.request(deferredState, deferredClock, 'manual', deferredTTL)
          deferredOrigin='preview'; deferredUnlockStable=0
          deferredStatus='Pending: dry-run request'; deferredEvent='Preview request'
        else deferredEvent='Dry run skipped: game request pending' end
      end
    end
    local sharedPending=deferredState.pending~=nil
    if not sharedPending then
      local player=currentQueuePlayer()
      local ok,pending=pcall(function() return player:NLSRebornDeferredIsPending() end)
      sharedPending=ok and pending==true
    end
    if sharedPending then
      if ImGui.Button('Cancel queued request##nls_cancel') then
        clearDeferred('Cancelled by user',currentQueuePlayer())
        deferredStatus='Cancelled by user'; deferredEvent='Cancelled by user'
      end
    end
    ImGui.TextWrapped('Manual deferred lane: '..(deferredEnabled and 'Enabled' or 'Disabled')..' | Automatic lane: '..(autosaveEnabled and 'Enabled' or 'Disabled'))
    ImGui.TextWrapped('Shared queue state: '..(sharedPending and (deferredOrigin=='preview' and 'Pending (dry run)' or deferredOrigin=='autosave' and 'Automatic request pending' or 'Save request pending') or deferredStatus))
    ImGui.TextWrapped('Bridge: '..deferredBridge..' | Gate: '..deferredGate)
    ImGui.TextWrapped('Last event: '..deferredEvent)
    ImGui.TextWrapped('Queue: '..(deferredState.pending and ('pending #'..deferredState.pending.id..' | expires in '..tostring(math.max(0,math.ceil(deferredState.pending.expires-deferredClock)))..'s') or 'empty'))
    ImGui.TextWrapped('Live queue is opt-in. Real blocked save requests may dispatch when native saving unlocks; preview requests never dispatch. This does not prove quest safety or save completion.')
    ImGui.Separator()
    ImGui.TextWrapped('Queue expiry: '..tostring(deferredTTL)..'s | dispatch cooldown: '..tostring(deferredCooldownSeconds)..'s')
    for _,choice in ipairs({15,30,60,120}) do
      if ImGui.Button('Expiry '..choice..'s##nls_ttl_'..choice) then deferredTTL=choice;saveConfig();syncNative() end
      if choice~=120 then ImGui.SameLine() end
    end
    for _,choice in ipairs({0,15,30,60}) do
      if ImGui.Button('Queue cooldown '..choice..'s##nls_cooldown_'..choice) then deferredCooldownSeconds=choice;saveConfig();syncNative() end
      if choice~=60 then ImGui.SameLine() end
    end
    ImGui.Separator()
    ImGui.Text('Smart Autosave (preview): '..(autosaveEnabled and 'ON' or 'OFF'))
    if ImGui.Button((autosaveEnabled and 'Disable' or 'Enable')..' Smart Autosave##nls_autosave') then
      setAutosaveEnabled(not autosaveEnabled);saveConfig();syncNative()
    end
    ImGui.TextWrapped('Scheduler: '..autosaveStatus..' | interval '..autosaveOptions.intervalSeconds..'s | cooldown '..autosaveOptions.cooldownSeconds..'s')
    if questEvents then
      local ok,status=pcall(function() return questEvents:status() end)
      if ok and type(status)=='string' then ImGui.TextWrapped('Quest milestone observer: '..status) end
    end
    for _,option in ipairs({{'exploration','Exploration interval'},{'postCombat','After combat'},{'vehicleExit','After vehicle exit'},{'questMilestone','Verified quest milestone'},{'apartmentEntry',"V's original apartment area entry"}}) do
      local key,label=option[1],option[2]
      if ImGui.Button(label..': '..(autosaveOptions[key] and 'ON' or 'OFF')..'##nls_auto_'..key) then
        autosaveOptions[key]=not autosaveOptions[key];configureAutosave();saveConfig();syncNative()
      end
    end
    for _,choice in ipairs({60,120,300,600,1800}) do
      if ImGui.Button('Interval '..choice..'s##nls_auto_interval_'..choice) then autosaveOptions.intervalSeconds=choice;configureAutosave();saveConfig();syncNative() end
      if choice~=1800 then ImGui.SameLine() end
    end
    for _,choice in ipairs({30,60,120,300,600}) do
      if ImGui.Button('Autosave cooldown '..choice..'s##nls_auto_cooldown_'..choice) then autosaveOptions.cooldownSeconds=choice;configureAutosave();saveConfig();syncNative() end
      if choice~=600 then ImGui.SameLine() end
    end
    ImGui.TextWrapped('Automatic requests yield to player requests. Pauses, menus, unknown sensors, sessions and long frames reset scheduling. Native autosave slots remain game-managed; checkpoint submission does not confirm completion.')
    ImGui.Separator()
    ImGui.TextWrapped('Intro protection: vanilla until q000_done is positive. q001_started is diagnostic only. Later phone calls are experimental.')
    ImGui.TextWrapped('Prologue: '..prologueStatus..' | introduction complete: '..tostring(prologueActive))
    ImGui.TextWrapped('Activation notice: '..activationNoticeStatus)
    ImGui.TextWrapped(sensorStatus)
    ImGui.TextWrapped('Phone: ' .. phoneStatus)
    ImGui.TextWrapped('Safety block: ' .. tostring(safetyBlock))
    ImGui.TextWrapped('Body detection: '..bodyStatus)
    ImGui.Text('Shuffle seed: '..tostring(shuffleSeed))
    ImGui.Text('Combat exception (Smart Mode only): ' .. (allowCombat and 'ON' or 'OFF'))
    if ImGui.Button('Toggle combat exception##nls_combat') then allowCombat = not allowCombat; saveConfig(); syncNative(); apply() end
    ImGui.Text('Vehicle exception (Smart Mode only): ' .. (allowVehicle and 'ON' or 'OFF'))
    if ImGui.Button('Toggle vehicle exception##nls_vehicle') then allowVehicle = not allowVehicle; saveConfig(); syncNative(); apply() end
    ImGui.Separator()
    if ImGui.Button('Retry bridge') then apply() end
    ImGui.TextWrapped('Bridge: ' .. message)
    if diagnosticDetails then
      ImGui.Text(string.format('Bridge attempts: %d | OK: %d | Failed: %d', attempts, successes, failures))
      ImGui.Text('Runtime notifications: ' .. (notificationsEnabled and 'Enabled' or 'Disabled'))
    end
    ImGui.TextWrapped('Smart only permits native Combat lock reasons with explicit options. Unrestricted retains its experimental fallback.')
    ImGui.TextWrapped('A checkpoint request is not proof of a valid save. Verify reload and quest progression.')
    ImGui.Separator()
    ImGui.TextWrapped('Immersion permits requests in vehicle sleep, addiction, starvation and dehydration. Native locks use the existing checkpoint-request fallback when a DF context is known.')
    ImGui.TextWrapped('Dark Future: '..darkFutureStatus)
    if diagnosticDetails then
      if darkFutureError then ImGui.TextWrapped('Dark Future query error: '..darkFutureError) end
      local dfOK, dfLastCheck = pcall(function() return Game.GetPlayer():NLSRebornGetDFPolicyStatus() end)
      local categoryOK,category=pcall(function() return Game.GetPlayer():NLSRebornGetNotificationCategory() end)
      local poolOK,pool=pcall(function() return Game.GetPlayer():NLSRebornGetNotificationDiagnostics() end)
      local categoryNames={[0]='Exploration',[1]='Combat',[2]='Vehicle',[3]='Vehicle combat',[4]='Stealth',[5]='Phone call',[7]='Prologue Protection',[12]='Prologue Protection / Corpo call'}
      ImGui.TextWrapped('Notification context: '..(categoryOK and categoryNames[category] or 'UNKNOWN')..' | mode: '..names[mode+1]..' | save protection: '..tostring(safetyBlock)..' | phone: '..phoneStatus)
      ImGui.TextWrapped('Last selected pool: '..(poolOK and tostring(pool) or 'UNKNOWN'))
      ImGui.TextWrapped('Last Immersion save check: '..(dfOK and tostring(dfLastCheck) or 'UNKNOWN'))
      ImGui.TextWrapped('Context states: -1 UNKNOWN, 0 inactive/disabled, 1 active. Context: 8 sleep, 11 dehydration, 10 starvation, 9 addiction.')
      ImGui.TextWrapped('Compatibility is source-reviewed; in-game validation is still required. State samples refresh every two seconds.')
      if ImGui.Button('Log compatibility snapshot##nls_darkfuture') then
        log('v1.0.0-vehicle-diagnostic.2 Release Candidate | mode='..names[mode+1]..' | prologue='..prologueStatus)
        log('Dark Future: '..darkFutureStatus)
        if darkFutureError then log('Dark Future query error: '..darkFutureError) end
        if dfOK then log('Last Immersion save check: '..tostring(dfLastCheck)) end
      end
    end
    ImGui.TextWrapped('Smart rejects mixed, scene, quest, script, loading and unknown lock reasons. Vehicle opt-in permits mounted combat only.')
    ImGui.Separator()
    ImGui.Text('Save Guardian request ledger: '..(guardianEnabled and 'ON' or 'OFF'))
    if ImGui.Button((guardianEnabled and 'Disable' or 'Enable')..' Guardian##nls_guardian') then
      setGuardianEnabled(not guardianEnabled); saveConfig(); syncNative()
    end
    ImGui.TextWrapped('Guardian: '..guardianStatus)
    if guardianBridge then
      local ok,value=pcall(function() return guardianBridge:status() end)
      if ok and type(value)=='string' then ImGui.TextWrapped(value) end
    end
    if guardian then
      local ok,value=pcall(function() return guardian:summary() end)
      if ok and type(value)=='string' then ImGui.TextWrapped(value) end
      local recentOK,recent=pcall(function() return guardian:latest() end)
      if recentOK and type(recent)=='table' then
        for index=1,12 do
          local rowOK,row=pcall(function()
            local record=recent[index]
            if type(record)~='table' then return nil end
            return tostring(record.id)..' | '..tostring(record.source)..' | '..tostring(record.phase)
          end)
          if rowOK and row then ImGui.TextWrapped(row) end
        end
      end
      if ImGui.Button('Export Guardian report##nls_guardian_export') then
        local exported=pcall(function()
          local report=guardian:report()
          report.rebornBuild='1.0.0-vehicle-diagnostic.2'
          report.gameBuild='unknown'; report.frameworkVersions='unknown'
          configStore.save('guardian-report.json',report)
        end)
        guardianStatus=exported and 'Local guardian-report.json written' or 'Report export failed; save policy unchanged'
      end
    end
    ImGui.TextWrapped('Guardian records requests. Written and reloaded stay unknown without independent evidence. Engine result hints are unassociated.')
    ImGui.TextWrapped('Optional closed-game backup/recovery tool is under tools/NLSRSaveGuardian. It is separate from in-game request tracking.')
    ImGui.Separator()
    ImGui.TextWrapped('Named settings presets (manual selection):')
    if type(ImGui.InputText)=='function' then
      local label,changed=ImGui.InputText('Preset name##nls_profile_name',profileLabel,33)
      if changed and type(label)=='string' then profileLabel=label:sub(1,32) end
    end
    if ImGui.Button('Save current preset##nls_profile_save') then
      if profileBank then
        local ok,accepted,code=pcall(function() return profileBank:save(profileLabel,currentSettings()) end)
        if not ok or accepted~=true then recordFailure(code or 'write_failed') end
        profileStatus=ok and accepted==true and 'Named preset written' or ('Preset save refused: '..tostring(code or 'write_failed'))
        refreshProfileLabels()
      else profileStatus='Profile module unavailable' end
    end
    ImGui.SameLine()
    if ImGui.Button('Load named preset##nls_profile_load') then loadPreset(profileLabel) end
    if ImGui.Button('Refresh preset list##nls_profile_refresh') then refreshProfileLabels() end
    if profileBank then
      if type(profileLabels)=='table' then
        for index=1,16 do
          local label=profileLabels[index]
          if type(label)=='string' then
            if ImGui.Button('Load '..label..'##nls_profile_'..index) then profileLabel=label;loadPreset(label) end
          end
        end
      end
    end
    ImGui.TextWrapped('Preset: '..profileStatus)
    ImGui.TextWrapped('Presets do not detect a character or playthrough. Apply the correct preset explicitly after loading another character.')
    if ImGui.Button('Export support report##nls_support_export') then exportSupportReport() end
    ImGui.TextWrapped('Support report: '..reportStatus)
    ImGui.TextWrapped('The report is a bounded local snapshot. Installed framework versions and independent save/reload evidence remain unknown unless measured.')
    ImGui.TextWrapped('Apartment trigger covers only the original Little China apartment area. Other safehouses, automatic in-game backups and automatic playthrough identity remain unavailable.')
  end
  ImGui.End()
end)
