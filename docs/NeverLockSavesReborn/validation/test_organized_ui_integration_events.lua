-- Event-queue migration: original fixture retained unchanged; see TEST-MIGRATION-COMBAT-EVENTS.md.
-- Actual init.lua + profiles/report/scheduler modules. External CET/Game/REDscript
-- and file store are controlled boundaries; no game or save-file IO is performed.
local root=assert(arg[1],'release root required')
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function copy(value)
  if type(value)~='table' then return value end
  local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function fixture(options)
  options=options or {}
  local h={events={},present=true,done=1,unlocked=true,paused=0,menu=0,phone=0,combat=false,mounted=0,
    native={},files={},loads={},saves={},texts={},button=nil,buttonSeen=false,failWrite=false,canCreate=true}
  h.files['config.json']={mode=3,tone=1,deferredEnabled=true,autosaveEnabled=false}
  local p={session=0,pending=false,serial=0,source=0,manual=false,auto=false,mode=1,tone=1,notifications=true,cancels=0}
  h.player=p
  function p:NLSRebornDeferredSession(candidate)if self.session==0 then self.session=candidate end return self.session end
  function p:NLSRebornDeferredCancel()self.pending=false;self.cancels=self.cancels+1 end
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
  function p:NLSRebornGetNotificationDiagnostics()return 'No checkpoint notification selected' end
  function p:NLSRebornAutosaveReady()return self.auto and self:NLSRebornDeferredNativeUnlocked() and h.paused==0 and h.menu==0 and h.phone==0 and h.combat==false and h.mounted==0 end
  function p:NLSRebornAutosaveQueue()error('settings test must not request an automatic checkpoint')end
  function p:NLSRebornDeferredDispatch()error('settings test must not dispatch checkpoints')end
  function p:NLSRebornSetMode(v)self.mode=v end
  function p:NLSRebornGetMode()return self.mode end
  function p:NLSRebornSetOptions(a,b)self.allowCombat=a;self.allowVehicle=b end
  function p:NLSRebornSetObservedState()end
  function p:NLSRebornSetContext()end
  function p:NLSRebornSetShuffleSeed()end
  function p:NLSRebornSetTone(v)self.tone=v end
  function p:NLSRebornGetTone()return self.tone end
  function p:NLSRebornSetNotificationsEnabled(v)self.notifications=v end
  function p:NLSRebornGetNotificationsEnabled()return self.notifications end
  function p:NLSRebornSetDFNotifications(a,b,c,d)self.mask=(a and 1 or 0)+(b and 2 or 0)+(c and 4 or 0)+(d and 8 or 0)end
  function p:NLSRebornGetDFNotificationMask()return self.mask or 15 end
  function p:NLSRebornGetDFPolicyStatus()return 'unknown' end
  function p:NLSRebornGetNotificationCategory()return 0 end
  function p:NLSRebornShowActivation()end
  function p:IsInCombat()return h.combat end
  function p:IsCrouching()return false end
  local env=setmetatable({}, {__index=_G})
  env.print=function()end
  env.registerForEvent=function(n,cb)h.events[n]=cb end
  env.ItemID={new=function()return {}end}
  env.Game={GetPlayer=function()return h.present and p or nil end,
    GetQuestsSystem=function()return {GetFactStr=function(_,k)return k=='q000_done' and h.done or 1 end,SetFactStr=function()end}end,
    GetScriptableSystemsContainer=function()return {Get=function()return {GetBodyTypeSuffix=function()return 'female'end}end}end}
  env.GetSingleton=function(name)check(name=='inkMenuScenario','exact source-backed version entry');return {GetSystemRequestsHandler=function()return {GetGameVersion=function()return '2.31'end}end}end
  env.io={open=function()if h.canCreate then return nil,'missing',2 end;return nil,'permission denied',13 end}
  local ns={addTab=function()end,addSubcategory=function()end}
  ns.addSwitch=function(_,label,_,value,_,cb)h.native[label]={value=value,callback=cb};return label end
  ns.addSelectorString=function(_,label,_,labels,value,_,cb)h.native[label]={value=value,callback=cb,labels=labels};return label end
  ns.setOption=function(label,value)h.native[label].value=value;h.native[label].callback(value)end
  env.GetMod=function(name)return name=='nativeSettings' and ns or nil end
  env.ImGui={Begin=function()return true end,End=function()end,Separator=function()end,SameLine=function()end,
    Text=function(v)h.texts[#h.texts+1]=v end,TextWrapped=function(v)h.texts[#h.texts+1]=v end,RadioButton=function()return false end,
    InputText=function(_,value)if h.input then local new=h.input;h.input=nil;return new,true end;return value,false end,
    Button=function(label)if h.button==label then h.buttonSeen=true;h.button=nil;return true end;return false end}
  local cache={}
  env.require=function(name)
    if name=='config_store' then return {
      load=function(path)h.loads[path]=(h.loads[path]or 0)+1;return copy(h.files[path])end,
      save=function(path,value)if h.returnFalse then return false end;h.saves[path]=(h.saves[path]or 0)+1;if h.failWrite then error('injected IO failure')end;h.files[path]=copy(value);return true end}end
    if name=='dark_future' then return {sample=function()return {}end,describe=function()return 'unknown'end}end
    if name=='guardian' or name=='guardian_bridge' or name=='quest_milestones' then error('optional module absent in focused fixture')end
    if cache[name]then return cache[name]end
    if options.missingUI and (name=='overlay_ui' or name=='native_settings_ui' or name=='settings_ui') then error('optional UI unavailable')end
    local loaded=assert(loadfile(dir..name..'.lua','t',env))();cache[name]=loaded
    return loaded
  end
  assert(loadfile(dir..'init.lua','t',env))();h.events.onInit();h.events.onUpdate(0);h.events.onOverlayOpen()
  function h:draw()self.texts={};self.events.onDraw()end
  function h:press(label)self.button=label;self.buttonSeen=false;self:draw();check(self.buttonSeen,'button exists '..label);self:draw()end
  function h:contains(text)for _,line in ipairs(self.texts)do if tostring(line):find(text,1,true)then return true end end;return false end
  function h:step()self.events.onUpdate(.25)end
  return h
end

do
  local h=fixture()
  local before=h.loads['profile-settings.json']or 0
  for _=1,100 do h:draw()end
  check((h.loads['profile-settings.json']or 0)==before,'normal overlay frames never read preset bank')
  h:press('Refresh preset list##nls_profile_refresh')
  check((h.loads['profile-settings.json']or 0)==before+1,'explicit refresh reads preset bank once')
  h.input='Corpo';h:draw();h:press('Save current preset##nls_profile_save')
  check(h.files['profile-settings.json'].profiles.Corpo.mode==3,'explicit named preset stores selected mode')
  check(h.files['profile-settings.json'].profiles.Corpo.autosaveEnabled==false,'preset preserves explicit autosave off')
  check(h:contains('Named preset written'),'successful preset save reported')
  local settings=h.files['profile-settings.json'].profiles.Corpo
  settings.mode=1;settings.tone=2;settings.deferredTTL=91;settings.deferredCooldownSeconds=16
  h.unlocked=false;local p=h.player;p.serial=p.serial+1;p.source=1;p.pending=true;h:step()
  local cancelled=p.cancels;local oldmode=p.mode;local oldconfig=copy(h.files['config.json'])
  h.failWrite=true;h:press('Load named preset##nls_profile_load')
  check(h:contains('Preset not applied: write_failed'),'failed config persistence refused explicitly')
  check(p.mode==oldmode and p.pending and p.cancels==cancelled,'failed preset write preserves runtime and queued manual request')
  check(h.files['config.json'].mode==oldconfig.mode,'failed preset write preserves prior persisted config')
  h.failWrite=false;h:press('Load named preset##nls_profile_load')
  check(p.mode==1 and h.files['config.json'].tone==nil and not p.pending,'validated persisted preset then applies atomically and cancels old queued work')
  check(h.files['config.json'].deferredTTL==91 and h.files['config.json'].deferredCooldownSeconds==16,'custom bounded profile timings persist')
  check(h.native['Automatic / test expiry (seconds)'].value==91 and h.native['Queue dispatch cooldown (seconds)'].value==17,'custom timings synchronize Native selector offsets')
  h:press('Export support report##nls_support_export')
  local report=h.files['support-report.json']
  check(report and report.presets.selected==true and report.presets.scope=='manual_named_settings_only','support report identifies explicit manual preset selection honestly')
  check(report.game_build=='2.31','source-backed game version enters allowlisted support report')
  check(report.settings.effective.deferredTTL==91 and report.settings.config_write_status=='written','support report captures effective persisted timing')
  check(report.context.paused==false,'false paused state preserved in report')
  local sawWriteFailure=false;for _,code in ipairs(report.latest_failures)do if code=='write_failed'then sawWriteFailure=true end end
  check(sawWriteFailure,'bounded report includes earlier rejected profile write failure code')
  check(report.autosave.checkpoint_submission=='Unknown' and report.autosave.completion=='Unknown','support report never claims write/reload evidence')
  p.session=10;h:step();h:press('Export support report##nls_support_export')
  check(h.files['support-report.json'].presets.selected==false,'character session change clears explicit preset selection marker')
  local saved=h.saves['support-report.json'];h.failWrite=true;h:press('Export support report##nls_support_export')
  check(h:contains('Report export failed') and h.saves['support-report.json']==saved+1,'report export failure visible and bounded')
  h.failWrite=false;h:press('Export support report##nls_support_export')
  local failures=h.files['support-report.json'].latest_failures
  check(failures[#failures]=='report_failed' and #failures<=8,'later support export includes bounded earlier report failure code')
end
do
  local h=fixture();h.canCreate=false;h:press('Save current preset##nls_profile_save')
  check(h.files['profile-settings.json']==nil and h:contains('unreadable_bank'),'unknown file existence does not recreate bank')
end
do
  local h=fixture();h.input='Unsafe/Name';h:draw();h:press('Save current preset##nls_profile_save')
  check(h.files['profile-settings.json']==nil and h:contains('invalid_label'),'unsafe profile label refused before write')
end
do
  local h=fixture()
  for _,case in ipairs({{'Automatic / test expiry (seconds)',75,'deferredTTL',75},
    {'Queue dispatch cooldown (seconds)',42,'deferredCooldownSeconds',41},
    {'Autosave interval (seconds)',1,'autosaveIntervalSeconds',60},
    {'Autosave cooldown (seconds)',1,'autosaveCooldownSeconds',30}})do
    h.native[case[1]].callback(case[2]);check(h.files['config.json'][case[3]]==case[4],'Native timing index roundtrip '..case[1])
    check(h.native[case[1]].value==case[2],'Native timing callback loop suppressed '..case[1])
  end
  local writes=h.saves['config.json']
  h.native['Automatic / test expiry (seconds)'].callback(0);h.native['Autosave cooldown (seconds)'].callback(1/0)
  check(h.saves['config.json']==writes,'invalid Native timing selector values refused without writes')
end
do
  local h=fixture()
  local writes=h.saves['config.json'] or 0
  for _=1,50 do h:draw()end
  check((h.saves['config.json']or 0)==writes,'redraw makes no config writes')
  h.returnFalse=true
  h.native['Save Mode'].callback(1);h:draw()
  check(h.player.mode==0,'runtime setting still applies when persistence refuses')
  check(h:contains('configuration write failed'),'false persistence result never announces success')
  h.returnFalse=false
  h.native['Save Mode'].callback(3);h:draw()
  check(h.files['config.json'].mode==2,'next successful setting write persists')
  check(h.native['Save Mode'].value==3,'native enum offset synchronized')
end
do
  local h=fixture({missingUI=true});h:draw()
  check(h:contains('UI modules unavailable'),'missing UI degrades to error panel')
  check(h.player.mode==3,'missing UI does not stop runtime bridge')
end
print('PASS '..checks..' actual-init runtime settings/profile/report assertions; Game/CET/REDscript/disk boundaries are doubles')
