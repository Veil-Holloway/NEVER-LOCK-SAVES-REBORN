-- UI migration fixture: actual new UI modules, new control IDs, next-frame status snapshots. Historical fixture preserved.
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
    native={},files={},loads={},saves={},texts={},button=nil,buttonSeen=false,failWrite=false,canCreate=true,
    apartment=0,dispatches=0,notices={},statusSetCalls=0,locks='unlocked',dfSample={vehicleSleep=-1,addiction=-1,starvation=-1,dehydration=-1}}
  h.files['config.json']=copy(options.config or {mode=3,tone=1,deferredEnabled=true,autosaveEnabled=false})
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
  function p:NLSRebornAutosavePhoneState()return h.phone end
  function p:NLSRebornGetNotificationDiagnostics()return 'No checkpoint notification selected' end
  function p:NLSRebornAutosaveReady()return self.auto and self:NLSRebornDeferredNativeUnlocked() and h.paused==0 and h.menu==0 and self:NLSRebornAutosavePhoneState()==0 and h.combat==false and h.mounted==0 end
  function p:NLSRebornAutosaveQueue()
    if self.pending or not self:NLSRebornAutosaveReady() then return false end
    self.serial=self.serial+1;self.source=3;self.pending=true;return true
  end
  function p:NLSRebornDeferredDispatch(serial)
    if not self.pending or serial~=self.serial or not self:NLSRebornDeferredNativeUnlocked() then return false end
    if self.source==3 and not self:NLSRebornAutosaveReady() or self.source~=3 and not self.manual then return false end
    self.pending=false;h.dispatches=h.dispatches+1;return true
  end
  function p:NLSRebornSetStatusNotificationsEnabled(value)h.statusSetCalls=h.statusSetCalls+1;self.statusFlag=value end
  function p:NLSRebornGetStatusNotificationsEnabled()return self.statusFlag==true end
  function p:NLSRebornStatusNotify(text)
    if h.emitThrows then error('injected optional UI failure') end
    if not self.statusFlag or not self.notifications or h.rejectStatus then return false end
    h.notices[#h.notices+1]=text;return true
  end
  function p:NLSRebornApartmentState()return h.apartment end
  function p:NLSRebornSaveLockSummary()if h.lockThrows then error('unknown boundary')end;return h.locks end
  function p:NLSRebornDiagnosticDFState()return h.dfSample end
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
    if name=='status_messages' and options.statusFault=='missing' then error('optional module missing') end
    if name=='status_messages' and options.statusFault=='throwing' then return {new=function()
      return {configure=function()error('optional module failure')end,reset=function()end}
    end}end
    if name=='config_store' then return {
      load=function(path)h.loads[path]=(h.loads[path]or 0)+1;return copy(h.files[path])end,
      save=function(path,value)h.saves[path]=(h.saves[path]or 0)+1;if h.failWrite then error('injected IO failure')end;h.files[path]=copy(value);return true end}end
    if name=='dark_future' then return {sample=function()return {}end,describe=function()return 'unknown'end}end
    if name=='guardian' or name=='guardian_bridge' or name=='quest_milestones' then error('optional module absent in focused fixture')end
    if cache[name]then return cache[name]end
    local loaded=assert(loadfile(dir..name..'.lua','t',env))()
    if name=='status_messages' then
      local factory=loaded.new
      loaded.new=function(seed)local engine=factory(seed);h.statusEngine=engine;return engine end
    end
    cache[name]=loaded
    return loaded
  end
  assert(loadfile(dir..'init.lua','t',env))();h.events.onInit();h.events.onUpdate(0);h.events.onOverlayOpen()
  function h:draw()self.texts={};self.events.onDraw()end
  function h:press(label)self.button=label;self.buttonSeen=false;self:draw();check(self.buttonSeen,'button exists '..label);self:draw()end
  function h:contains(text)for _,line in ipairs(self.texts)do if tostring(line):find(text,1,true)then return true end end;return false end
  function h:step()self.events.onUpdate(.25)end
  function h:advance(seconds)for _=1,math.floor(seconds*4)do self:step()end end
  function h:queue(source)self.player.serial=self.player.serial+1;self.player.source=source;self.player.pending=true end
  return h
end

-- Public UI regression: automatic lane remains cancellable without manual deferral.
do
  local h=fixture({config={mode=3,tone=1,deferredEnabled=false,autosaveEnabled=true}})
  h.unlocked=false;h:queue(3)
  h:step();check(h.player.pending,'automatic request remains pending under known native lock')
  h:press('Cancel queued request##nls_cancel_overview')
  check(not h.player.pending,'shared cancel clears automatic request')
  check(h.player.auto==true,'single cancellation keeps automatic lane enabled')
  check(h.native['Smart Autosave'].value==true,'autosave option remains enabled')
end
-- On-demand report samples current values rather than old overlay samples.
do
  local h=fixture()
  h.combat=true;h.mounted=1;h.phone=1;h.menu=1;h.locks='locked|Combat|Quest'
  h.dfSample={vehicleSleep=1,addiction=0,starvation=-1,dehydration=1}
  h:press('Export support report##nls_support_export')
  local r=h.files['support-report.json']
  check(r.context.combat=='active' and r.context.vehicle=='active' and r.context.phone=='active','report reads fresh sensor state')
  check(r.context.in_menu==true,'report exposes fresh menu observation')
  check(r.native_locks.known==true and r.native_locks.reason_codes[1]=='Combat' and r.native_locks.reason_codes[2]=='Quest','bounded readonly lock evidence retained')
  check(r.dark_future.vehicle_sleep==1 and r.dark_future.dehydration==1,'fresh DF read separate from cached policy fields')
  h.present=false
  h:press('Export support report##nls_support_export')
  r=h.files['support-report.json']
  check(r.context.combat=='unknown' and r.context.vehicle=='unknown' and r.context.phone=='unknown','player loss clears stale report observations')
  check(r.dark_future.vehicle_sleep==-1 and r.dark_future.dehydration==-1,'player loss clears stale DF observations')
  check(r.context.category=='unknown' and r.context.body=='unknown','no player has no invented context/body')
end
-- New event/sensor features OFF add no continuous feature work or filesystem IO.
do
  local h=fixture()
  local sets=h.statusSetCalls;local loads=h.loads['profile-settings.json'];local saves=h.saves['config.json']
  local reads=0;h.player.NLSRebornApartmentState=function()reads=reads+1;return 0 end
  h:advance(30);for _=1,50 do h:draw()end
  check(reads==0,'disabled apartment option does not read apartment sensor')
  check(#h.notices==0,'defaultoff status does not emit')
  check(h.statusSetCalls==sets,'disabled status bridge is not rewritten every frame')
  check(h.loads['profile-settings.json']==loads and h.saves['config.json']==saves,'idle overlay/update performs no profile IO or config writes')
end
-- Apartment handoff retains its identity until the shared lane actually dispatches.
do
  local config={mode=3,tone=1,deferredEnabled=false,autosaveEnabled=true,autosaveExploration=false,
    autosavePostCombat=false,autosaveVehicleExit=false,autosaveQuestMilestone=false,
    autosaveApartmentEntry=true,autosaveCooldownSeconds=30}
  local h=fixture({config=config});h:advance(32)
  check(not h.player.pending and h.dispatches==0,'outside baseline does not schedule apartment entry')
  h.apartment=1;h:step();check(h.player.pending and h.player.source==3,'known entry hands a request to automatic lane')
  h.apartment=0;h:step();check(not h.player.pending,'leaving after handoff cancels that apartment request')
  h:advance(5);check(h.dispatches==0,'cancelled apartment handoff cannot dispatch after return to readiness')
  h:advance(32);h.apartment=1;h:step();check(h.player.pending,'later real entry may schedule again after cooldown')
  h.apartment=nil;h:step();check(not h.player.pending,'unknown apartment after handoff cancels request')
end
-- Module absence and faults preserve the existing manual queue path and notices.
for _,failure in ipairs({'missing','throwing'})do
  local h=fixture({statusFault=failure,config={mode=3,tone=1,deferredEnabled=true,statusNotificationsEnabled=true}})
  h.unlocked=false;h:queue(1);h:step()
  check(h.player.pending,'optional status failure preserves queued save request')
  check(h.player.statusFlag~=true,'failed status feature cannot suppress original generic queue notice')
  h.unlocked=true;h:advance(3)
  check(h.dispatches==1,'optional status failure preserves one manual checkpoint submission')
end
-- Real status engine is observational; queue, dispatched request and file evidence stay separate.
do
  local h=fixture({config={mode=3,tone=1,deferredEnabled=true,statusNotificationsEnabled=true}})
  h.unlocked=false;h:queue(1);h:step()
  check(h.player.statusFlag==true,'status bridge readback permits suppression only while engine active')
  check(#h.notices==1 and h.statusEngine:status().last_kind=='queued','adopted manual request emits queued status')
  check(h.dispatches==0,'queued notice does not dispatch a checkpoint')
  h.unlocked=true;h:advance(3)
  check(h.dispatches==1,'manual request submits once through original lane')
  check(#h.notices==2 and h.statusEngine:status().last_kind=='submitted','later submission has separate status')
  check(h.statusEngine:status().write_status=='Unknown' and h.statusEngine:status().reload_status=='Unknown','UI handoff cannot prove saved/reloaded')
  local state=h.statusEngine:status();local rng=state.rng_state;local notices=#h.notices
  h.native['Enable notifications'].callback(false);h:step();h.unlocked=false;h:queue(1);h:step();h:advance(1)
  check(h.player.pending,'master notification off does not block saving queue')
  check(h.player.statusFlag==false,'master notification off restores original bridge setting')
  check(#h.notices==notices and h.statusEngine:status().rng_state==rng,'disabled status neither emits nor advances RNG')
end
-- Failed UI handoff does not advance a message bag, block a checkpoint, or retry every frame.
do
  local h=fixture({config={mode=3,tone=1,deferredEnabled=true,statusNotificationsEnabled=true}})
  h.rejectStatus=true;h.unlocked=false
  local rng=h.statusEngine:status().rng_state
  h:queue(1);h:step();check(h.statusEngine:status().failed==1,'literal rejected emitter handoff is reported')
  check(h.statusEngine:status().rng_state==rng and #h.notices==0,'rejected emitter leaves pool/RNG unchanged')
  h:advance(1);check(h.statusEngine:status().failed==1,'failed handoffs are throttled')
  h.rejectStatus=false;h:advance(1.25)
  check(#h.notices==1 and h.statusEngine:status().last_kind=='queued','pending status may retry after throttle')
  h.unlocked=true;h.emitThrows=true;h:advance(3)
  check(h.dispatches==1,'throwing emitter never blocks checkpoint submission')
  check(h.statusEngine:status().write_status=='Unknown','throwing UI keeps write evidence unknown')
end
-- Literal malformed lock summaries never advertise complete known native evidence.
for _,raw in ipairs({'locked|Combat||Quest','locked|Combat|','locked|Unknown','locked|Combat|private/path'})do
  local h=fixture();h.locks=raw;h:press('Export support report##nls_support_export')
  check(h.files['support-report.json'].native_locks.known==false,'malformed/unknown lock record is unknown')
end
print('PASS '..checks..' runtime polish assertions; actual init with external boundaries doubled')
