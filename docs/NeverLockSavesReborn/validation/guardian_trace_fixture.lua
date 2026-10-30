-- Guardian-enabled variant of the unchanged event fixture.
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
  local h={events={},observers={},dispatches=0,attempts=0,checkpointAttempts=0,readChecks=0,present=true,done=1,unlocked=true,paused=0,menu=0,phone=0,combat=false,mounted=0,
    native={},files={},loads={},saves={},texts={},button=nil,buttonSeen=false,failWrite=false,canCreate=true}
  h.files['config.json']={mode=3,tone=1,deferredEnabled=true,autosaveEnabled=false,deferredTTL=options.ttl or 30,statusNotificationsEnabled=false,guardianEnabled=true}
  local p={session=0,pending=false,serial=0,source=0,manual=false,auto=false,mode=1,tone=1,notifications=true,cancels=0}
  h.player=p
  setmetatable(p,{__index=function(t,k)if k=='nlsDeferredSerial'then return t.serial elseif k=='nlsDeferredPending'then return t.pending end end})
  function p:NLSRebornDeferredSession(candidate)if self.session==0 then self.session=candidate end return self.session end
  function p:NLSRebornDeferredCancel()self.pending=false;self.cancels=self.cancels+1 end
  function p:NLSRebornDeferredSetEnabled(v)self.manual=v;if not v and self.source~=3 then self.pending=false end end
  function p:NLSRebornAutosaveSetEnabled(v)self.auto=v;if not v and self.source==3 then self.pending=false end end
  function p:NLSRebornDeferredGetSerial()return self.serial end
  function p:NLSRebornDeferredIsPending()return self.pending end
  function p:NLSRebornDeferredGetSource()return self.source end
  function p:NLSRebornDeferredNativeUnlocked()h.readChecks=h.readChecks+1;return h.unlocked and h.done>0 end
  function p:NLSRebornPausedState()return h.paused end
  function p:NLSRebornMenuState()return h.menu end
  function p:NLSRebornMountedState()return h.mounted end
  function p:NLSRebornNotificationPhoneState()return h.phone end
  function p:NLSRebornGetNotificationDiagnostics()return 'No checkpoint notification selected' end
  function p:NLSRebornAutosaveReady()return self.auto and self:NLSRebornDeferredNativeUnlocked() and h.paused==0 and h.menu==0 and h.phone==0 and h.combat==false and h.mounted==0 end
  function p:NLSRebornAutosaveQueue()error('settings test must not request an automatic checkpoint')end
  function p:NLSRebornDeferredDispatch(serial)
    h.attempts=h.attempts+1
    if h.dispatchThrows then error('injected unknown outcome')end
    if h.relock then h.unlocked=false;return false end
    if h.reject then self.pending=false;h.checkpointAttempts=h.checkpointAttempts+1;return false end
    if not self.pending or self.serial~=serial or h.combat or not h.unlocked or h.done<=0 then return false end
    self.pending=false;h.checkpointAttempts=h.checkpointAttempts+1;h.dispatches=h.dispatches+1;return true
  end
  function p:NLSRebornCheckpointGetSerial()return h.checkpointAttempts end
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
  function p:IsInCombat()if h.unknownCombat then error("unknown combat")end;return h.combat end
  function p:IsCrouching()return false end
  local env=setmetatable({}, {__index=_G})
  env.print=function()end
  local function observe(owner,name,fn)
    if options.noEvents then error('observer unavailable')end
    h.observers[owner..'.'..name]=fn
  end
  env.ObserveAfter=observe;env.ObserveBefore=observe
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
    if name=='quest_milestones' then error('optional module absent in focused fixture')end
    if cache[name]then return cache[name]end
    if options.missingUI and (name=='overlay_ui' or name=='native_settings_ui' or name=='settings_ui') then error('optional UI unavailable')end
    local loaded=assert(loadfile(dir..name..'.lua','t',env))();cache[name]=loaded
    return loaded
  end
  assert(loadfile(dir..'init.lua','t',env))();h.events.onInit();h.events.onUpdate(0);h.events.onOverlayOpen()
  function h:draw()self.texts={};self.events.onDraw()end
  function h:press(label)self.button=label;self.buttonSeen=false;self:draw();check(self.buttonSeen,'button exists '..label);self:draw()end
  function h:contains(text)for _,line in ipairs(self.texts)do if tostring(line):find(text,1,true)then return true end end;return false end
  function h:step(dt)self.events.onUpdate(dt or .25)end
  function h:run(seconds,dt)dt=dt or .25;for _=1,math.ceil(seconds/dt)do self:step(dt)end end
  function h:queue(source)self.player.serial=self.player.serial+1;self.player.pending=true;self.player.source=source or 2 end
  function h:signal(name,player,value)local fn=self.observers['PlayerPuppet.'..name];if fn then fn(player or self.player,value)end end
  function h:report()self:press('Export support report##nls_support_export');return self.files['support-report.json']end
  return h
end

return {fixture=fixture,check=check,count=function()return checks end}
