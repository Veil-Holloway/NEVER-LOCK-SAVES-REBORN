-- Event-queue migration: original fixture retained unchanged; see TEST-MIGRATION-COMBAT-EVENTS.md.
-- Approved UI migration: actual UI modules; retired bypass controls absent. Historical assertions retained otherwise.
-- Executes the shipped CET entry point with doubles only at external boundaries.
-- These checks validate Lua integration, not game APIs, save creation or reloads.
local releaseRoot = arg[1] or '.'
local initPath = releaseRoot..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/init.lua'
local modDir = assert(initPath:match('^(.*)/init%.lua$'), 'pass a release root directory')
local checks = 0

local function equal(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local function copy(value)
  if type(value) ~= 'table' then return value end
  local result = {}
  for k,v in pairs(value) do result[k] = copy(v) end
  return result
end

local function newPlayer()
  local player = {writes=0, mode=0, tone=0, combat=false, mounted=nil, crouching=false, activations=0}
  function player:NLSRebornDeferredSetEnabled(value) self.deferred=value end
  function player:NLSRebornSetMode(value) self.mode=value; self.writes=self.writes+1 end
  function player:NLSRebornSetOptions(combat, vehicle) self.allowCombat=combat; self.allowVehicle=vehicle end
  function player:NLSRebornSetObservedState(ck,ca,vk,va) self.observed={ck,ca,vk,va} end
  function player:NLSRebornSetContext(context, body, safety) self.context=context; self.body=body; self.safety=safety end
  function player:NLSRebornSetShuffleSeed(value) self.seed=value end
  function player:NLSRebornSetTone(value) self.tone=value end
  function player:NLSRebornSetNotificationsEnabled(value) self.notifications=value end
  function player:NLSRebornSetDFNotifications(vehicleSleep,addiction,starvation,dehydration)
    self.dfPolicies={vehicleSleep,addiction,starvation,dehydration}
  end
  function player:NLSRebornGetDFNotificationMask()
    local mask=0
    for index,value in ipairs(self.dfPolicies or {}) do if value then mask=mask+2^(index-1) end end
    return mask
  end
  function player:NLSRebornGetDFPolicyStatus() return 'boundary policy diagnostics' end
  function player:NLSRebornGetMode() return self.mode end
  function player:NLSRebornGetTone() return self.tone end
  function player:NLSRebornGetNotificationsEnabled() return self.notifications end
  function player:NLSRebornShowActivation() self.activations=self.activations+1 end
  function player:IsInCombat() return self.combat end
  function player:GetMountedVehicle() return self.mounted end
  function player:NLSRebornMountedState() return self.mounted and 1 or 0 end
  function player:IsCrouching() return self.crouching end
  return player
end

local function harness(config, options)
  options = options or {}
  local h = {events={}, config=copy(config), saved=nil, saves=0, logs={}, texts={}, native={},buttons={},
    facts={q000_done=1,q001_started=1}, player=newPlayer(), dfQueries=0, pending=nil}
  local env = setmetatable({}, {__index=_G})
  env._G = env
  env.print = function(...) h.logs[#h.logs+1]=table.concat({...}, ' ') end
  env.registerForEvent = function(name, callback)
    assert(not h.events[name], 'duplicate event: '..name)
    h.events[name]=callback
  end
  env.json = {
    loadfile=function(path) equal(path, 'config.json', 'config load path'); return copy(h.config) end,
    dumpfile=function(path, data)
      equal(path, 'config.json', 'config save path')
      h.saved=copy(data); h.saves=h.saves+1
    end
  }
  local ns = {}
  function ns.addTab() end
  function ns.addSubcategory() end
  local function addOption(label, current, callback)
    local option={label=label,value=current,callback=callback}
    h.native[label]=option
    return option
  end
  function ns.addSelectorString(_,label,_,_,current,_,callback) return addOption(label,current,callback) end
  function ns.addSwitch(_,label,_,current,_,callback) return addOption(label,current,callback) end
  function ns.setOption(option,value)
    option.value=value
    -- Deliberately invoke callbacks even for equal values to check loop suppression.
    option.callback(value)
  end
  env.GetMod = function(name)
    if name=='nativeSettings' and not options.noNative then return ns end
    return nil
  end
  local quests = {}
  function quests:GetFactStr(name)
    if options.questError then error('quest boundary unavailable') end
    return h.facts[name] or 0
  end
  function quests:SetFactStr(name,value) h.facts[name]=value end
  local systems = {}
  function systems:Get(name)
    if name=='PuppetStateSystem' then
      return {GetBodyTypeSuffix=function() return options.bodySuffix or 'female' end}
    end
    h.dfQueries=h.dfQueries+1
    if options.dfError then error('Dark Future boundary unavailable') end
    if options.dfService then return options.dfService end
    return nil -- optional Dark Future absent; no invented gameplay behavior.
  end
  env.Game = {
    GetPlayer=function() return h.player end,
    GetQuestsSystem=function() return quests end,
    GetScriptableSystemsContainer=function() return systems end,
    GetPhoneSystem=function() return {IsInCall=function() return false end} end
  }
  env.ItemID={new=function() return {} end}
  local function consume(label)
    if h.pending and label:find(h.pending,1,true) then h.pending=nil; return true end
    return false
  end
  env.ImGui={
    Begin=function() return true end, End=function() end,
    Text=function(value) h.texts[#h.texts+1]=tostring(value) end,
    TextWrapped=function(value) h.texts[#h.texts+1]=tostring(value) end,
    Separator=function() end, SameLine=function() end,
    Button=function(label) h.buttons[#h.buttons+1]=label; return consume(label) end,
    RadioButton=function(label) return consume(label) end
  }
  local modules = {}
  env.require = function(name)
    if name=='combat_events' then return assert(loadfile(modDir..'/combat_events.lua','t',env))() end
    if name=='deferred_save' then return assert(loadfile(modDir..'/deferred_save.lua','t',env))() end
    if name=='config_store' then
      return {
        load=function(path) equal(path,'config.json','config load path'); return copy(h.config) end,
        save=function(path,data) equal(path,'config.json','config save path');h.saved=copy(data);h.saves=h.saves+1;return true end
      }
    end
    if name=='settings_ui' or name=='native_settings_ui' or name=='overlay_ui' then return assert(loadfile(modDir..'/'..name..'.lua','t',env))() end
    if name~='dark_future' then return require(name) end
    if options.moduleCase=='missing' then error('adapter file unavailable') end
    if options.moduleCase=='bad-type' then return 'invalid adapter export' end
    if options.moduleCase=='missing-methods' then return {} end
    if options.moduleCase=='sample-error' then
      return {sample=function() error('sample failed') end,describe=function() return 'unreachable' end}
    end
    if options.moduleCase=='describe-error' then
      return {sample=function() return {} end,describe=function() error('describe failed') end}
    end
    if options.moduleCase=='bad-snapshot' then
      return {sample=function() return false end,describe=function() return 'invalid' end}
    end
    if options.moduleCase=='misleading-state' then
      return {sample=function() return {status='READABLE',valid=true,safetyBlock=false,mode=2} end,
        describe=function() return 'READABLE: diagnostics only' end}
    end
    if modules[name] == nil then
      modules[name]=assert(loadfile(modDir..'/dark_future.lua','t',env))()
    end
    return modules[name]
  end
  assert(loadfile(initPath,'t',env))()
  for _,event in ipairs({'onInit','onOverlayOpen','onOverlayClose','onUpdate','onDraw'}) do
    assert(type(h.events[event])=='function', 'missing CET event: '..event)
  end
  function h:tick(seconds) self.events.onUpdate(seconds or 2) end
  function h:click(label)
    local aliases={['##nls_notifications']='##nls_setting_notificationsEnabled',['##nls_diagnostics']='##nls_setting_diagnosticDetails',
      ['##nls_dfNotifyVehicleSleep']='##nls_setting_dfNotifyVehicleSleep',['##nls_deferred']='##nls_setting_deferredEnabled'}
    local toneIndex=label:match('^##nls_tone_(%d)$')
    if toneIndex then label='##nls_setting_tone_'..(tonumber(toneIndex)+1)else label=aliases[label] or label end
    self.events.onOverlayOpen()
    self.pending=label
    self.events.onDraw()
    assert(self.pending==nil, 'UI control not found: '..label)
  end
  function h:select(label,value)
    local option=assert(self.native[label], 'native control not found: '..label)
    option.value=value
    option.callback(value)
  end
  h.events.onInit()
  return h
end

local modes={'Vanilla','Immersion','Unrestricted','Smart'}
for mode=0,3 do
  local h=harness({mode=mode,allowCombat=true,allowVehicle=false,tone=2,notificationsEnabled=false,diagnosticDetails=false})
  h:tick()
  equal(h.player.mode,mode,'persisted mode bridge '..mode)
  equal(h.player.allowCombat,true,'persisted combat option '..mode)
  equal(h.player.allowVehicle,false,'persisted vehicle option '..mode)
  equal(h.player.notifications,false,'persisted notification switch '..mode)
  equal(h.player.safety,false,'completed introduction '..mode)
  equal(h.saves,0,'loading existing config never rewrites it '..mode)
  equal(h.native['Save Mode'].value,mode+1,'native mode selector offset '..mode)
  equal(h.native.Tone,nil,'tone control absent after legacy config load')
end
print('PASS: all four modes and RC5 persisted settings bridge through actual init.lua')

local h=harness(nil)
h:tick()
equal(h.player.mode,1,'safe default Immersion')
equal(h.player.notifications,true,'default notifications')
for mode=0,3 do
  local before=h.saves
  h:click(modes[mode+1])
  equal(h.player.mode,mode,'CET mode change '..mode)
  equal(h.saved.mode,mode,'CET mode persisted '..mode)
  equal(h.native['Save Mode'].value,mode+1,'CET mode synchronizes native '..mode)
  equal(h.saves,before+1,'native callback recursion suppressed '..mode)
end
equal(h.native.Tone,nil,'tone control removed')
h:click('##nls_notifications')
equal(h.player.notifications,false,'CET notification bridge')
equal(h.native['Enable notifications'].value,false,'CET notification synchronizes native')
equal(h.native['Smart: combat saves'],nil,'retired combat exception not exposed')
equal(h.native['Smart: vehicle saves'],nil,'retired vehicle exception not exposed')
equal(h.player.allowCombat,false,'legacy combat config preserved without active switch')
equal(h.player.allowVehicle,false,'legacy vehicle config preserved without active switch')
h:click('##nls_diagnostics')
equal(h.native['Detailed diagnostics'].value,false,'CET diagnostics synchronizes native')
local expected={guardianEnabled=true,deferredEnabled=true,mode=true,allowCombat=true,allowVehicle=true,notificationsEnabled=true,diagnosticDetails=true,
  dfNotifyVehicleSleep=true,dfNotifyAddiction=true,dfNotifyStarvation=true,dfNotifyDehydration=true,
  deferredTTL=true,deferredCooldownSeconds=true,autosaveEnabled=true,autosaveIntervalSeconds=true,
  autosaveCooldownSeconds=true,autosaveExploration=true,autosavePostCombat=true,autosaveVehicleExit=true,autosaveQuestMilestone=true,
  statusNotificationsEnabled=true,autosaveApartmentEntry=true}
local keys=0
for key in pairs(h.saved) do assert(expected[key],'unexpected config key: '..key); keys=keys+1 end
equal(keys,22,'all active keys retained; obsolete tone omitted')
print('PASS: CET controls persist and synchronize Native Settings without callback loops')

for mode=0,3 do
  h:select('Save Mode',mode+1)
  h:tick()
  equal(h.player.mode,mode,'Native mode reaches runtime '..mode)
  equal(h.saved.mode,mode,'Native mode persisted '..mode)
end
equal(h.native.Tone,nil,'tone control removed')
h:select('Enable notifications',true); h:tick()
equal(h.player.notifications,true,'Native notifications reach runtime')
h:tick() -- legacy option is retained, not exposed as an exception
equal(h.player.allowCombat,false,'Native combat reaches runtime')
h:tick() -- legacy option is retained, not exposed as an exception
equal(h.player.allowVehicle,false,'Native vehicle reaches runtime')
h:select('Detailed diagnostics',true)
equal(h.saved.diagnosticDetails,true,'Native diagnostics persisted')
print('PASS: Native Settings callbacks preserve selector offsets and reach CET runtime bridge')

for _,options in ipairs({{}, {dfError=true}, {noNative=true}, {dfError=true,questError=true}}) do
  local probe=harness({mode=2,tone=2,notificationsEnabled=true},options)
  probe.facts.q000_done=0; probe.facts.q001_started=0
  probe:tick()
  equal(probe.player.mode,2,'optional integration failure preserves selected mode')
  equal(probe.player.safety,true,'optional integration failure never lifts intro guard')
  equal(probe.player.context,7,'protected introduction notification context')
  probe.events.onOverlayOpen(); probe.events.onDraw()
  local writes=probe.player.writes
  probe.player=nil; probe:tick()
  probe.events.onDraw()
  probe.player=newPlayer(); probe:tick()
  equal(probe.player.mode,2,'replacement player receives persisted mode')
  equal(probe.player.safety,true,'replacement player intro guard')
  assert(probe.player.writes>0 and writes>0,'bridge ran for both player identities')
end
print('PASS: absent/erroring Dark Future boundary and absent Native Settings preserve bridge and introduction guard')

for _,fault in ipairs({'missing','bad-type','missing-methods','sample-error','describe-error','bad-snapshot','misleading-state'}) do
  for _,mode in ipairs({1,2,3}) do
    local probe=harness({mode=mode,tone=1,notificationsEnabled=true},{moduleCase=fault})
    probe.facts.q000_done=0; probe.facts.q001_started=0
    probe:tick()
    equal(probe.player.mode,mode,'adapter fault preserves mode: '..fault)
    equal(probe.player.safety,true,'adapter fault preserves intro: '..fault)
    equal(probe.player.context,7,'adapter fault preserves intro messages: '..fault)
    probe.events.onOverlayOpen(); probe.events.onDraw()
    equal(probe.saves,0,'adapter fault never writes configuration: '..fault)
    if fault~='misleading-state' then
      assert(table.concat(probe.texts,'\n'):find('UNKNOWN',1,true),'fault surfaced as UNKNOWN: '..fault)
    end
  end
end
print('PASS: missing/malformed/throwing adapters never alter mode, introduction policy, messages, or configuration')

local invalidService={state={value='Running'},Settings={mainSystemEnabled=true}}
function invalidService:IsValidGameState() return false end
function invalidService:GetSleepingInVehicle() return true end
function invalidService:IsInAnyMenu() return true end
for mode=0,3 do
  local probe=harness({mode=mode},{dfService=invalidService})
  invalidService.player=probe.player
  probe:tick()
  equal(probe.player.mode,mode,'DF gameplay-invalid state does not change selected mode '..mode)
  equal(probe.player.safety,false,'DF gameplay-invalid state does not change completed intro '..mode)
  equal(probe.saves,0,'DF diagnostics never change persistent settings '..mode)
  probe.events.onOverlayOpen(); probe.events.onDraw()
  assert(table.concat(probe.texts,'\n'):find('gameplayValid=false',1,true),'verified adapter diagnostic visible')
  local logCount=#probe.logs
  probe:click('##nls_darkfuture')
  equal(#probe.logs,logCount+3,'on-demand compatibility snapshot logs mode, DF state and policy diagnostics '..mode)
  equal(probe.saves,0,'logging snapshot never changes configuration '..mode)
  equal(probe.player.mode,mode,'logging snapshot never changes save mode '..mode)
  probe.player=nil; probe:tick()
  probe.texts={}; probe.events.onDraw()
  local display=table.concat(probe.texts,'\n')
  assert(display:find('WAITING: no player',1,true),'no-player adapter status reset')
  assert(not display:find('gameplayValid=false',1,true),'stale DF gameplay state cleared on player loss')
end
print('PASS: actual adapter snapshots stay diagnostic-only, log on demand, and reset on player loss')

for _,attachment in ipairs({'missing','stale'}) do
  local service={state={value='Running'},Settings={mainSystemEnabled=true},queries=0}
  if attachment=='stale' then service.player=newPlayer() end
  function service:IsValidGameState() self.queries=self.queries+1; return false end
  function service:GetSleepingInVehicle() self.queries=self.queries+1; return false end
  function service:IsInAnyMenu() self.queries=self.queries+1; return false end
  local probe=harness({mode=3},{dfService=service})
  probe:tick()
  equal(service.queries,0,attachment..' DF player attachment never calls gameplay getters')
  equal(probe.player.mode,3,attachment..' DF player attachment preserves mode')
  equal(probe.player.safety,false,attachment..' DF player attachment preserves intro state')
  probe.events.onOverlayOpen(); probe.events.onDraw()
  assert(table.concat(probe.texts,'\n'):find('WAITING: Dark Future player attachment',1,true),
    attachment..' player attachment surfaced as WAITING')
  service.player=probe.player; probe:tick()
  equal(service.queries,3,'matching DF player enables the three verified gameplay queries')
  probe.player=newPlayer(); probe:tick()
  equal(service.queries,3,'player replacement rejects stale DF attachment without getters')
  equal(probe.player.mode,3,'replacement player bridge survives DF attachment delay')
  service.player=probe.player; probe:tick()
  equal(service.queries,6,'new matching DF attachment restores gameplay sampling')
end
print('PASS: missing/stale DF player attachments skip gameplay getters and recover after matching attachment')

local cadence=harness({mode=3})
cadence:tick(1)
equal(cadence.player.writes,0,'no sampling before two-second tick')
cadence:tick(1)
equal(cadence.player.writes,1,'bridge runs on two-second sample')
cadence.player.combat=true; cadence.player.mounted={}
cadence:tick()
equal(cadence.player.context,3,'combined combat/vehicle notification context')
equal(cadence.player.observed[1],true,'combat sensor known')
equal(cadence.player.observed[2],true,'combat sensor active')
equal(cadence.player.observed[3],true,'vehicle sensor known')
equal(cadence.player.observed[4],true,'vehicle sensor active')
equal(cadence.player.activations,1,'activation notice once per save fact')
print('PASS: existing sampling cadence, sensor bridge, and activation notice fact retained')

local function findNative(h,needle)
  for label,option in pairs(h.native) do
    if label:lower():find(needle,1,true) then return label,option end
  end
  error('new native policy control missing: '..needle)
end
local function findButton(h,needle)
  h.buttons={}; h.events.onOverlayOpen(); h.events.onDraw()
  for _,label in ipairs(h.buttons) do
    if label:lower():find(needle,1,true) then return label end
  end
  error('new CET policy button missing: '..needle)
end
local policies={
  {key='dfNotifyVehicleSleep',needle='sleep'},
  {key='dfNotifyAddiction',needle='addiction'},
  {key='dfNotifyStarvation',needle='starvation'},
  {key='dfNotifyDehydration',needle='dehydration'}
}
local upgraded=harness({mode=1,tone=2,notificationsEnabled=false})
upgraded:tick()
equal(upgraded.player:NLSRebornGetDFNotificationMask(),15,'legacy config enables all four Immersion notification categories by default')
equal(upgraded.player.mode,1,'legacy config preserves selected Immersion mode')
equal(upgraded.player.notifications,false,'legacy config preserves old notification setting')
equal(upgraded.saves,0,'legacy config migration does not rewrite on load')
for index,policy in ipairs(policies) do
  local _,option=findNative(upgraded,policy.needle)
  equal(option.value,true,'default Native policy enabled: '..policy.key)
end
for mask=0,15 do
  for index,policy in ipairs(policies) do
    local enabled=math.floor(mask/2^(index-1))%2==1
    local label=findNative(upgraded,policy.needle)
    upgraded:select(label,enabled)
  end
  upgraded:tick()
  equal(upgraded.player:NLSRebornGetDFNotificationMask(),mask,'Native notification combination reaches runtime '..mask)
  for index,policy in ipairs(policies) do
    equal(upgraded.saved[policy.key],math.floor(mask/2^(index-1))%2==1,'notification combination persists '..mask..' '..policy.key)
  end
  equal(upgraded.player.mode,1,'notification switches preserve mode '..mask)
  equal(upgraded.player.safety,false,'notification switches do not alter intro gate '..mask)
end
for index,policy in ipairs(policies) do
  local label=findButton(upgraded,policy.needle)
  local before=upgraded.saves
  upgraded:click(label)
  local _,option=findNative(upgraded,policy.needle)
  equal(upgraded.saved[policy.key],false,'CET policy toggle persists: '..policy.key)
  equal(option.value,false,'CET policy toggle synchronizes Native: '..policy.key)
  equal(upgraded.saves,before+1,'policy Native callback recursion suppressed: '..policy.key)
end
equal(upgraded.player:NLSRebornGetDFNotificationMask(),0,'four CET policy toggles reach runtime')
local reloaded=harness(upgraded.saved); reloaded:tick()
equal(reloaded.player:NLSRebornGetDFNotificationMask(),0,'all disabled policies survive fresh Lua initialization')
equal(reloaded.player.notifications,false,'new policy persistence retains existing notification switch')
reloaded.player.NLSRebornGetDFPolicyStatus=function() error('diagnostics getter unavailable') end
reloaded.events.onOverlayOpen(); reloaded.events.onDraw()
equal(reloaded.player.mode,1,'optional policy diagnostics failure preserves bridge')
equal(reloaded.player:NLSRebornGetDFNotificationMask(),0,'optional policy diagnostics failure preserves options')
print('PASS: 16 Immersion notification combinations, legacy config defaults, CET/Native sync, and persistence round trips')
for _,legacyValue in ipairs({false,true}) do
  local legacy=harness({mode=1,tone=2,notificationsEnabled=false,
    dfBlockVehicleSleep=legacyValue,dfBlockAddiction=legacyValue,
    dfBlockStarvation=legacyValue,dfBlockDehydration=legacyValue})
  legacy:tick()
  equal(legacy.player:NLSRebornGetDFNotificationMask(),15,'obsolete blocking keys never become notification settings')
  equal(legacy.player.mode,1,'obsolete blocking keys leave selected mode unchanged')
  equal(legacy.player.notifications,false,'obsolete blocking keys leave global notifications unchanged')
  legacy:click('##nls_dfNotifyVehicleSleep')
  equal(legacy.saved.dfNotifyVehicleSleep,false,'new notification choice persists independently of obsolete keys')
  for _,key in ipairs({'dfBlockVehicleSleep','dfBlockAddiction','dfBlockStarvation','dfBlockDehydration'}) do
    equal(legacy.saved[key],nil,'obsolete blocking key dropped on next explicit config write: '..key)
  end
end
local mixed=harness({mode=1,dfBlockVehicleSleep=true,dfBlockAddiction=true,
  dfBlockStarvation=true,dfBlockDehydration=true,dfNotifyVehicleSleep=false,
  dfNotifyAddiction=false,dfNotifyStarvation=false,dfNotifyDehydration=false})
mixed:tick()
equal(mixed.player:NLSRebornGetDFNotificationMask(),0,'new notification keys take precedence over obsolete blocking keys')
print('PASS: obsolete dfBlock settings are ignored and never migrated into blocking or notification policy')
for mode=0,3 do
  local options={bodySuffix='male'}
  local replacement=harness({mode=mode,tone=2,notificationsEnabled=false},options)
  replacement:tick()
  equal(replacement.player.safety,false,'completed character before replacement '..mode)
  equal(replacement.player.body,2,'previous character body '..mode)
  replacement.player=newPlayer()
  replacement.facts.q000_done=0
  replacement.facts.q001_started=0
  options.bodySuffix='female'
  replacement.events.onOverlayOpen()
  equal(replacement.player.mode,mode,'early overlay retains selected mode '..mode)
  equal(replacement.player.safety,true,'early overlay samples new character introduction '..mode)
  equal(replacement.player.context,7,'early overlay applies protected introduction context '..mode)
  equal(replacement.player.body,1,'early overlay samples new character body '..mode)
  equal(replacement.player.notifications,false,'early overlay preserves notification setting '..mode)
end
print('PASS: early overlay after character replacement uses fresh introduction and body state in every mode')

-- Fresh v0.10.4a checks beyond the adapted historical fixture.
local dq=harness({mode=1,deferredEnabled=true})
dq:tick()
equal(dq.player.deferred,true,'deferred persisted true reaches runtime')
equal(dq.native['Deferred Save'].value,true,'deferred persisted true reaches Native UI')
local old=dq.saves
dq:select('Deferred Save',false)
equal(dq.player.deferred,false,'Native deferred disable immediate bridge')
equal(dq.saved.deferredEnabled,false,'Native deferred disable persists')
equal(dq.saves,old+1,'Native deferred disable suppresses recursive callback')
dq:click('##nls_deferred')
equal(dq.player.deferred,true,'CET deferred enable immediate bridge')
equal(dq.native['Deferred Save'].value,true,'CET deferred enable syncs Native')
equal(dq.saved.deferredEnabled,true,'CET deferred enable persists')
local dqRestart=harness(dq.saved);dqRestart:tick()
equal(dqRestart.player.deferred,true,'deferred survives fresh Lua initialization boundary')
local bad=harness({mode=500,tone=-4,allowCombat='true',allowVehicle=0,notificationsEnabled='false',diagnosticDetails=0,deferredEnabled='true',dfNotifyVehicleSleep=0})
bad:tick()
equal(bad.player.mode,1,'invalid mode retains safe default')
equal(bad.player.allowCombat,false,'invalid combat bool ignored')
equal(bad.player.allowVehicle,false,'invalid vehicle bool ignored')
equal(bad.player.notifications,true,'invalid notification bool ignored')
equal(bad.player.deferred,false,'invalid deferred bool ignored')
equal(bad.player:NLSRebornGetDFNotificationMask(),15,'invalid DF bool retains notification default')
for _,bodySuffix in ipairs({'unknown','custom',42}) do
 local b=harness({mode=1},{bodySuffix=bodySuffix});b:tick()
 equal(b.player.body,0,'unrecognized body remains neutral fallback: '..tostring(bodySuffix))
end
for mode=0,3 do
 for _,rescue in ipairs({0,1}) do
  local b=harness({mode=mode});b.facts.q000_done=1;b.facts.q001_started=rescue;b:tick()
  equal(b.player.safety,false,'positive intro completion independent of diagnostic rescue '..mode..'/'..rescue)
 end
 local b=harness({mode=mode});b.facts.q000_done=0;b.facts.q001_started=1;b:tick()
 equal(b.player.safety,true,'rescue flag cannot bypass incomplete intro '..mode)
end
print('PASS: fresh deferred synchronization, invalid config fields, neutral body and completion-gate checks')
print('RESULT: '..checks..' Lua integration assertions passed')
print('Scope: executes release Lua with external boundary doubles; no game compilation, saving, or reload evidence.')
