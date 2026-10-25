-- Independent public-runtime controls. Actual init/modules, explicit external
-- Game/CET/REDscript/storage boundaries; not game, compiler or frame-time proof.
local root=assert(arg[1],'release root required')
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local statusDir=arg[2] and arg[2]..'/' or dir -- optional staging source, final package needs no override
local n=0
local function check(value,label)n=n+1;assert(value,label)end
local function eq(a,b,label)check(a==b,(label or 'value')..': '..tostring(a)..' != '..tostring(b))end
local function copy(value)
  if type(value)~='table' then return value end
  local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function fixture(options)
  options=options or {}
  local h={events={},present=true,done=1,nativeUnlocked=true,paused=0,menu=0,phone=0,
    combat=false,mounted=0,apartment=0,suffix=options.suffix or 'female',native={},files={},texts={},calls={},
    announcements={},button=nil,buttonSeen=false,throwNotify=options.throwNotify==true}
  local function count(key)h.calls[key]=(h.calls[key]or 0)+1 end
  h.files['config.json']={mode=3,tone=options.tone or 1,notificationsEnabled=options.master~=false,
    diagnosticDetails=false,deferredEnabled=options.deferred==true,autosaveEnabled=options.autosave==true,
    autosaveApartmentEntry=options.apartment==true,statusNotificationsEnabled=options.status==true,deferredTTL=options.ttl or 30,
    autosaveExploration=false,autosavePostCombat=false,autosaveVehicleExit=false,autosaveQuestMilestone=false}
  local p={session=0,pending=false,serial=0,source=0,manual=false,auto=false,
    statusEnabled=false,mode=1,tone=1,notifications=true,cancels=0,dispatches=0,
    nlsRebornDFVehicleSleepState=-1,nlsRebornDFAddictionState=-1,
    nlsRebornDFStarvationState=-1,nlsRebornDFDehydrationState=-1}
  h.player=p
  function p:NLSRebornDeferredSession(candidate)count('session');if self.session==0 then self.session=candidate end;return self.session end
  function p:NLSRebornDeferredCancel()count('cancel');self.pending=false;self.cancels=self.cancels+1 end
  function p:NLSRebornDeferredSetEnabled(v)count('manual_write');self.manual=v;if not v and self.source~=3 then self.pending=false end end
  function p:NLSRebornAutosaveSetEnabled(v)count('auto_write');self.auto=v;if not v and self.source==3 then self.pending=false end end
  function p:NLSRebornDeferredGetSerial()count('serial');return self.serial end
  function p:NLSRebornDeferredIsPending()count('pending');return self.pending end
  function p:NLSRebornDeferredGetSource()count('source');return self.source end
  function p:NLSRebornDeferredNativeUnlocked()count('native');return h.nativeUnlocked and h.done>0 end
  function p:NLSRebornPausedState()count('paused');return h.paused end
  function p:NLSRebornMenuState()count('menu');return h.menu end
  function p:NLSRebornMountedState()count('mounted');return h.mounted end
  function p:NLSRebornApartmentState()count('apartment');return h.apartment end
  function p:NLSRebornNotificationPhoneState()count('phone');return h.phone end
  function p:NLSRebornGetNotificationDiagnostics()count('notification_diagnostic');return 'No checkpoint notification selected' end
  function p:NLSRebornAutosaveReady()
    return self.auto and h.nativeUnlocked and h.done>0 and h.paused==0 and h.menu==0 and
      h.phone==0 and h.combat==false and h.mounted==0
  end
  function p:NLSRebornAutosaveQueue()
    count('auto_queue')
    if self.pending or not self:NLSRebornAutosaveReady() then return false end
    self.serial=self.serial+1;self.source=3;self.pending=true;return true
  end
  function p:NLSRebornDeferredDispatch(serial)
    count('dispatch_attempt')
    if not self.pending or serial~=self.serial or not h.nativeUnlocked or h.done<=0 or
      not ((self.source==3 and self.auto) or (self.source~=3 and self.manual)) then return false end
    self.pending=false;self.dispatches=self.dispatches+1;return true
  end
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
  function p:NLSRebornSetStatusNotificationsEnabled(v)count('status_write');self.statusEnabled=v end
  function p:NLSRebornGetStatusNotificationsEnabled()count('status_read');return self.statusEnabled end
  function p:NLSRebornStatusNotify(text)
    count('status_emit')
    if h.throwNotify then error('controlled UI boundary failure')end
    if not self.notifications or not self.statusEnabled then return false end
    h.announcements[#h.announcements+1]=text;return true
  end
  function p:NLSRebornSetDFNotifications(a,b,c,d)self.mask=(a and 1 or 0)+(b and 2 or 0)+(c and 4 or 0)+(d and 8 or 0)end
  function p:NLSRebornGetDFNotificationMask()return self.mask or 15 end
  function p:NLSRebornGetDFPolicyStatus()return 'unknown' end
  function p:NLSRebornEnsureDFStateInitialized()end
  function p:NLSRebornGetNotificationCategory()return 0 end
  function p:NLSRebornShowActivation()count('activation')end
  function p:IsInCombat()count('combat');return h.combat end
  function p:IsCrouching()return false end
  local env=setmetatable({}, {__index=_G})
  env.print=function()end
  env.registerForEvent=function(name,cb)h.events[name]=cb end
  env.ItemID={new=function()return {}end}
  env.Game={GetPlayer=function()count('player');return h.present and p or nil end,
    GetQuestsSystem=function()return {GetFactStr=function(_,key)return key=='q000_done' and h.done or 1 end,SetFactStr=function()end}end,
    GetScriptableSystemsContainer=function()return {Get=function()return {GetBodyTypeSuffix=function()return h.suffix end}end}end}
  env.GetSingleton=function()return {GetSystemRequestsHandler=function()return {GetGameVersion=function()return '2.31'end}end}end
  env.io={open=function()count('fs_open');return nil,'missing',2 end}
  env.ObserveBefore=function()count('observe_register')end
  env.ObserveAfter=function()count('observe_register')end
  local ns={addTab=function()end,addSubcategory=function()end}
  ns.addSwitch=function(_,label,_,value,_,callback)h.native[label]={value=value,callback=callback};return label end
  ns.addSelectorString=function(_,label,_,labels,value,_,callback)h.native[label]={value=value,callback=callback,labels=labels};return label end
  ns.setOption=function(label,value)h.native[label].value=value;h.native[label].callback(value)end
  env.GetMod=function(name)return name=='nativeSettings' and ns or nil end
  env.ImGui={Begin=function()return true end,End=function()end,Separator=function()end,SameLine=function()end,
    Text=function(value)h.texts[#h.texts+1]=value end,TextWrapped=function(value)h.texts[#h.texts+1]=value end,
    RadioButton=function()return false end,InputText=function(_,value)return value,false end,
    Button=function(label)if h.button==label then h.buttonSeen=true;h.button=nil;return true end;return false end}
  local cache={}
  env.require=function(name)
    if name=='config_store' then return {
      load=function(path)count('fs_load');return copy(h.files[path])end,
      save=function(path,value)count('fs_save');h.files[path]=copy(value);return true end}end
    if name=='dark_future' then return {sample=function()return {}end,describe=function()return 'unknown'end}end
    if cache[name]then return cache[name]end
    local sourceDir=(name=='status_messages' or name=='status_message_library') and statusDir or dir
    local module=assert(loadfile(sourceDir..name..'.lua','t',env))();cache[name]=module;return module
  end
  assert(loadfile(dir..'init.lua','t',env))();h.events.onInit();h.events.onUpdate(0);h.events.onOverlayOpen()
  function h:draw()self.texts={};self.events.onDraw()end
  function h:click(label)self.button=label;self.buttonSeen=false;self:draw();return self.buttonSeen end
  function h:press(label)check(self:click(label),'public control exists: '..label)end
  function h:contains(text)for _,line in ipairs(self.texts)do if tostring(line):find(text,1,true)then return true end end;return false end
  function h:step(delta)self.events.onUpdate(delta or .25)end
  function h:frames(count,delta)for _=1,count do self:step(delta)end end
  function h:inject(source)self.player.serial=self.player.serial+1;self.player.source=source;self.player.pending=true;return self.player.serial end
  return h
end
local function budget()
  local h=fixture({deferred=false,autosave=false,status=false,apartment=false})
  local before=copy(h.calls)
  h:frames(10000,1/60)
  for _=1,100 do h:draw()end
  for _,key in ipairs({'apartment','status_emit','status_read','status_write'})do
    eq(h.calls[key]or 0,before[key]or 0,'default OFF 10k frames: zero optional Game boundary '..key)
  end
  for _,key in ipairs({'fs_open','fs_load','fs_save'})do eq(h.calls[key]or 0,before[key]or 0,'normal update/draw frames no filesystem boundary '..key)end
  print('BUDGET default_OFF_frames=10000 draw_frames=100 apartment_calls=0 status_calls=0 filesystem_calls=0')
end
if arg[3]=='budget-only' then budget();print('PASS independent default-OFF call budget assertions='..n);return end

-- One automatic request can be cancelled without enabling unrelated manual work
-- or disabling the scheduler. The real queue source, not only a toggle, controls UI.
do
  local h=fixture({autosave=true,deferred=false,status=false})
  h.nativeUnlocked=false;h:inject(3);h:step()
  check(h.player.pending,'automatic checkpoint queue is pending')
  h:press('Cancel queued request##nls_cancel')
  eq(h.player.pending,false,'single automatic request cancelled')
  eq(h.player.auto,true,'autosave remains enabled after single cancellation')
  eq(h.native['Smart Autosave (preview)'].value,true,'automatic option still on')
  eq(h.native['Deferred Save (preview)'].value,false,'manual queue option still off')
end

-- Fresh export observes present evidence now, not the previous periodic sample.
do
  local h=fixture({status=false})
  h.combat=true;h.mounted=1;h.phone=1
  h:press('Export support report##nls_support_export')
  local r=h.files['support-report.json'];check(r~=nil,'explicit report written')
  eq(r.context.combat,'active','export samples current combat')
  eq(r.context.vehicle,'active','export samples current mounted state')
  eq(r.context.phone,'active','export samples current phone')
  h.present=false;h:step(2)
  h:press('Export support report##nls_support_export')
  r=h.files['support-report.json']
  eq(r.context.combat,'unknown','known player loss invalidates combat evidence')
  eq(r.context.vehicle,'unknown','known player loss invalidates vehicle evidence')
  eq(r.context.phone,'unknown','known player loss invalidates phone evidence')
  eq(r.autosave.checkpoint_submission,'Unknown','report does not invent submission')
  eq(r.autosave.completion,'Unknown','report does not invent write/reload')
end

-- Notification success and failure are presentation boundaries; neither enters
-- checkpoint permission, request serial, source or once-only dispatch behavior.
local outcome={}
for _,case in ipairs({{name='off',status=false},{name='on',status=true},{name='throw',status=true,throwNotify=true}})do
  local h=fixture({deferred=true,status=case.status,throwNotify=case.throwNotify})
  h.nativeUnlocked=false;local serial=h:inject(1);h:step()
  h.nativeUnlocked=true;h:frames(12)
  eq(h.player.dispatches,1,'one checkpoint dispatch with status '..case.name)
  eq(h.player.pending,false,'queue consumed with status '..case.name)
  eq(h.player.serial,serial,'presentation cannot allocate checkpoint serials '..case.name)
  h:frames(50);eq(h.player.dispatches,1,'no delayed duplicate from status '..case.name)
  outcome[case.name]={dispatches=h.player.dispatches,serial=h.player.serial,source=h.player.source,
    attempts=h.calls.dispatch_attempt or 0,uiAttempts=h.calls.status_emit or 0,messages=#h.announcements}
end
eq(outcome.off.uiAttempts,0,'status OFF sends nothing')
check(outcome.on.uiAttempts>0 and outcome.on.messages>0,'status ON uses separate presentation bridge')
check(outcome.throw.uiAttempts>0 and outcome.throw.messages==0,'throwing UI bridge attempted but isolated')
for _,name in ipairs({'on','throw'})do
  for _,key in ipairs({'dispatches','serial','source','attempts'})do eq(outcome[name][key],outcome.off[key],'policy parity '..name..'/'..key)end
end

-- The existing notification master switch must override the independent status
-- option; disabling just presentation cannot discard or prevent a real request.
do
  local h=fixture({deferred=true,status=true,master=false})
  h.nativeUnlocked=false;h:inject(1);h:step();h.nativeUnlocked=true;h:frames(14)
  eq(h.player.dispatches,1,'notification master OFF does not block saving')
  eq(#h.announcements,0,'notification master OFF suppresses status text')
end

-- Actual integration uses the selected tone/profile and clears undisplayed
-- terminal messages when the master switch is turned off, preventing replay.
do
  local L=assert(loadfile(statusDir..'status_message_library.lua'))()
  local function inPool(kind,tone,body,text)
    for _,entry in ipairs(L.get(kind,tone,body))do if entry==text then return true end end
    return false
  end
  local h=fixture({deferred=true,status=true,tone=2,suffix='male'})
  h.nativeUnlocked=false;h:inject(1);h:step();h:frames(9)
  check(#h.announcements>=1,'enabled queued request shown')
  check(inPool('queued',2,2,h.announcements[1]),'runtime uses selected unhinged/male pool')
  h.native['Tone'].callback(1)
  h:inject(1);h:step();h:frames(9)
  check(inPool('queued',0,2,h.announcements[#h.announcements]),'runtime honors Professional tone change')

  local off=fixture({deferred=true,status=true,ttl=1})
  off.nativeUnlocked=false;off:inject(1);off:step();off:frames(4)
  check(not off.player.pending,'short real request expired before next display interval')
  local displayed=#off.announcements
  off.native['Enable notifications'].callback(false);off:step()
  off:frames(12)
  off.native['Enable notifications'].callback(true);off:frames(12)
  eq(#off.announcements,displayed,'master disable clears undisplayed old status rather than replaying')
end

-- Controlled call budgets are logical evidence only. Existing game polling is
-- allowed; default-OFF features must not add apartment samples/status emission,
-- and normal draw/update frames must never read or write profile/config files.
do
  budget()
end
print('PASS independent runtime polish: '..n..' assertions; actual modules/external boundaries, not game/performance evidence')
