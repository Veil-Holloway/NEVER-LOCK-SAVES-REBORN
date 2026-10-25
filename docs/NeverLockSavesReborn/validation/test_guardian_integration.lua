-- Guardian integration: actual init.lua, deferred_save.lua, guardian.lua and guardian_bridge.lua.
-- Game/CET/REDscript observation and Native Settings/file boundaries are doubles.
-- No game compilation, checkpoints, write confirmation, save backup or reload is performed.
local root=assert(arg[1], 'release root required')
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local checks=0
local failures={}
local function check(v,msg) checks=checks+1;if not v then failures[#failures+1]=msg end end
local function fixture(opts)
 opts=opts or {}; local f={events={},facts={q000_done=1,q001_started=0},calls={},text={},button=nil,unlocked=false,playerPresent=true,dispatchFault=false,bridgeFault=false,questFault=false,observers={},native={},saved=nil,saveError=false,exportError=false}
 if opts.done~=nil then f.facts.q000_done=opts.done end
 if opts.rescue~=nil then f.facts.q001_started=opts.rescue end
 local p={mode=0,tone=0,notifications=true,pending=false,serial=0,source=0,session=0,enabled=false,blocked=true,mask=15}
 f.player=p; f.current=p
 setmetatable(p,{__index=function(t,k) if k=='nlsDeferredSerial' then return t.serial elseif k=='nlsDeferredPending' then return t.pending end end})
 function p:NLSRebornDeferredSession(candidate) if f.bridgeFault then error('bridge fault') end if self.session==0 then self.session=candidate end return self.session end
 function p:NLSRebornDeferredCancel() self.pending=false; f.calls.cancel=(f.calls.cancel or 0)+1 end
 function p:NLSRebornDeferredSetEnabled(v) self.enabled=v; if not v then self.pending=false end end
 function p:NLSRebornDeferredGetSerial() return self.serial end
 function p:NLSRebornDeferredIsPending() return self.pending end
 function p:NLSRebornDeferredGetSource() return self.source end
 function p:NLSRebornDeferredNativeUnlocked() return f.unlocked and not self.blocked and f.facts.q000_done>0 end
 function p:NLSRebornDeferredDispatch(serial)
  f.calls.dispatchAttempts=(f.calls.dispatchAttempts or 0)+1
  if f.dispatchFault then error('dispatch fault') end
  if not self.enabled or not self.pending or serial~=self.serial or not self:NLSRebornDeferredNativeUnlocked() then return false end
  self.pending=false; f.calls.dispatch=(f.calls.dispatch or 0)+1; f.calls.serial=serial;f.calls.source=self.source; return true
 end
 function p:NLSRebornSetMode(v) self.mode=v end function p:NLSRebornGetMode() return self.mode end
 function p:NLSRebornSetOptions() end function p:NLSRebornSetObservedState() end
 function p:NLSRebornSetContext(c,b,blocked) self.context=c;self.body=b;self.blocked=blocked end
 function p:NLSRebornSetShuffleSeed() end
 function p:NLSRebornSetTone(v) self.tone=v end function p:NLSRebornGetTone() return self.tone end
 function p:NLSRebornSetNotificationsEnabled(v) self.notifications=v end function p:NLSRebornGetNotificationsEnabled() return self.notifications end
 function p:NLSRebornSetDFNotifications(a,b,c,d) self.mask=(a and 1 or 0)+(b and 2 or 0)+(c and 4 or 0)+(d and 8 or 0) end
 function p:NLSRebornGetDFNotificationMask() return self.mask end
 function p:NLSRebornShowActivation() f.calls.activation=(f.calls.activation or 0)+1 end
 function p:NLSRebornNotificationPhoneState() return 0 end
 function p:NLSRebornGetNotificationCategory() return 0 end function p:NLSRebornGetNotificationDiagnostics() return 'test boundary' end function p:NLSRebornGetDFPolicyStatus() return 'test boundary' end
 function p:IsInCombat() return false end function p:GetMountedVehicle() return nil end function p:IsCrouching() return false end
 local env=setmetatable({}, {__index=_G})
 env.print=function() end
 env.registerForEvent=function(name,cb) f.events[name]=cb end
 env.ObserveBefore=opts.observers==false and nil or function(class,method,cb) f.observers['before:'..class..'.'..method]=cb end
 env.ObserveAfter=function(class,method,cb) f.observers['after:'..class..'.'..method]=cb end
 if opts.observers==false then env.ObserveBefore=false;env.ObserveAfter=false end
 if opts.native then
  local ns={}
  ns.addTab=function() end;ns.addSubcategory=function() end
  ns.addSwitch=function(_,label,_,value,_,cb) f.native[label]={value=value,callback=cb};return label end
  ns.addSelectorString=function(_,label,_,_,value,_,cb) f.native[label]={value=value,callback=cb};return label end
  ns.setOption=function(label,value) f.native[label].value=value; f.native[label].callback(value) end
  env.GetMod=function(name) if name=='nativeSettings' then return ns end end
 else env.GetMod=function() return nil end end
 env.require=function(name)
  if name=='deferred_save' then return dofile(dir..'deferred_save.lua') end
  if name=='guardian' then
   if opts.module=='missing' then error('injected missing module') end
   if opts.module=='throwing_factory' then return {new=function() error('injected module construction fault') end} end
   if opts.module=='malformed' then return {new=function() return 'malformed' end} end
   if opts.module=='malformed_table' then return {new=function() return {} end} end
   local factory=dofile(dir..'guardian.lua')
   return {new=function(id)
    f.ledger=factory.new(id)
    if opts.module=='malformed_latest' then f.ledger.latest=function() return {false} end end
    if opts.module=='throwing' then return setmetatable({}, {__index=function() return function() error('injected ledger method fault') end end}) end
    return f.ledger
   end}
  end
  if name=='guardian_bridge' then
   if opts.bridge=='missing' then error('injected missing observer bridge') end
   local factory=dofile(dir..'guardian_bridge.lua')
   return {new=function(ledger,api) f.transport=factory.new(ledger,api);return f.transport end}
  end
  if name=='config_store' then return {load=function() return opts.config or {mode=opts.mode or 3,deferredEnabled=true,guardianEnabled=opts.guardian~=false} end,save=function(path,value) if f.saveError or (path=='guardian-report.json' and f.exportError) then error('injected disk refusal') end f.saved=f.saved or {}; f.saved[path]=value end} end
  if name=='dark_future' then return {sample=function() return {} end,describe=function() return 'external diagnostic boundary' end} end
  error('unexpected module '..name)
 end
 env.ItemID={new=function() return {} end}
 env.Game={GetPlayer=function() return f.playerPresent and f.current or nil end,
  GetQuestsSystem=function() return {GetFactStr=function(_,k) if f.questFault and k=='q000_done' then error('facts unknown') end if f.rescueFault and k=='q001_started' then error('diagnostic unavailable') end return f.facts[k] or 0 end,SetFactStr=function(_,k,v) f.facts[k]=v end} end,
  GetScriptableSystemsContainer=function() return {Get=function() return {GetBodyTypeSuffix=function() return 'female' end} end} end}
 env.ImGui={Begin=function()return true end,End=function()end,Text=function(v)f.text[#f.text+1]=v end,TextWrapped=function(v)f.text[#f.text+1]=v end,Separator=function()end,SameLine=function()end,RadioButton=function()return false end,Button=function(label)if f.button==label then f.button=nil;return true end return false end}
 local loader=assert(loadfile(dir..'init.lua','t',env)); loader();f.events.onInit();f.events.onUpdate(0);f.events.onOverlayOpen()
 function f:tick(dt,n) for i=1,n or 1 do self.events.onUpdate(dt) end end
 function f:press(label) self.button=label;self.text={};self.events.onDraw();assert(self.button==nil,'button not found '..label) end
 function f:fire(kind,class,method,...)
  local cb=self.observers[kind..':'..class..'.'..method];if cb then check(cb(...)==nil,'observer returns no policy result') end
 end
 function f:queue(source,wrapper)
  local class,method
  if wrapper=='manual' then class='PauseMenuGameController';method='HandlePressToSaveGame'
  elseif wrapper=='pause_quicksave' then class='PauseMenuGameController';method='HandlePressToQuickSaveGame'
  elseif wrapper=='gameplay_quicksave' then class='gameuiInGameMenuGameController';method='HandleQuickSave' end
  if class then self:fire('before',class,method,{}) end
  self:fire('before','PlayerPuppet','NLSRebornDeferredQueue',p,source or 1)
  p.serial=p.serial+1;p.source=source or 1;p.pending=true
  self:fire('after','PlayerPuppet','NLSRebornDeferredQueue',p,source or 1)
  if class then self:fire('after',class,method,{}) end
 end
 function f:report() return self.ledger and self.ledger:report() end
 function f:last() local r=self:report();return r and r.records[#r.records] end
 function f:contains(fragment) self.text={};self.events.onDraw();for _,t in ipairs(self.text)do if t:find(fragment,1,true)then return true end end return false end
 return f
end
local function evidenceUnknown(f)
 local r=f:report();if not r then return end
 for _,record in ipairs(r.records) do
  check(record.write_status=='Unknown','write evidence stays Unknown')
  check(record.reload_status=='Unknown','reload evidence stays Unknown')
 end
end
local function phaseSeen(f,phase)
 local r=f:report();if not r then return false end
 for _,v in ipairs(r.transitions) do if v.phase==phase then return true end end
 return false
end
-- Recording off/on/faults must not alter a real request outcome.
for _,variant in ipairs({'off','on','missing','throwing_factory','throwing','malformed','malformed_table'}) do
 for _,scenario in ipairs({'submit','cancel','expire','relock','dispatch_error','preview'}) do
  local f=fixture{guardian=variant~='off',module=(variant~='off' and variant~='on') and variant or nil}
  if scenario=='preview' then
   f.unlocked=true;f:press('Queue test request (30s)##nls_queue');f:tick(.25,12);f:tick(30)
   check((f.calls.dispatch or 0)==0,'preview never dispatches with '..variant)
   check(not f.player.pending,'preview does not create REDscript request '..variant)
  else
   f:queue(1,'manual');f:tick(.25)
   if scenario=='cancel' then f:press('Cancel queued request##nls_cancel')
   elseif scenario=='expire' then f:tick(30)
   elseif scenario=='dispatch_error' then f.dispatchFault=true end
   f.unlocked=true
   if scenario=='relock' then f:tick(.25,5);f.unlocked=false;f:tick(.25);f.unlocked=true;f:tick(.25,7);check((f.calls.dispatch or 0)==0,'relock stability unchanged '..variant) end
   f:tick(.25,9)
   local expected=(scenario=='submit' or scenario=='relock') and 1 or 0
   check((f.calls.dispatch or 0)==expected,'policy parity '..variant..'/'..scenario)
   check(not f.player.pending,'request consumed/cancelled '..variant..'/'..scenario)
  end
  evidenceUnknown(f)
 end
end
-- Observer provenance, serial correlation and ordering through actual transport + ledger.
for _,origin in ipairs({'manual','pause_quicksave','gameplay_quicksave'}) do
 local f=fixture();local source=origin=='manual' and 1 or 2
 f:queue(source,origin);f:tick(.25)
 local record=f:last()
 check(record and record.source==origin,'source observed from exact wrapper '..origin)
 check(record and record.serial==1 and record.session==f.player.session,'serial/session correlation '..origin)
 check(record and record.first_observed=='Requested','begin callback genuinely observed '..origin)
 local trace=record and record.id
 f.unlocked=true;f:tick(.25,8)
 record=f:last()
 check(record and record.id==trace and record.phase=='Submitted','same trace submitted '..origin)
 check(phaseSeen(f,'Executing') and phaseSeen(f,'Submitted'),'executing precedes submission '..origin)
 if record then
  local executing,submitted
  for _,v in ipairs(f:report().transitions) do if v.trace_id==trace then if v.phase=='Executing' then executing=v.sequence elseif v.phase=='Submitted' then submitted=v.sequence end end end
  check(executing and submitted and executing<submitted,'ordered dispatch observations '..origin)
 end
 f:fire('after','PauseMenuGameController','OnSavingComplete',{},true)
 f:tick(.25)
 f:fire('after','gameuiInGameMenuGameController','OnSavingComplete',{},false)
 f:tick(.25)
 local hints=f:report().uncorrelated_hints
 check(#hints==2 and hints[1].outcome=='SuccessHint' and hints[2].outcome=='FailureHint','true and false engine hints remain distinct uncorrelated hints')
 check(f:last().phase=='Submitted','uncorrelated hint cannot confirm written save')
 evidenceUnknown(f)
end
-- Incomplete optional transport still adopts real queue evidence conservatively.
for _,variant in ipairs({'no_observers','missing_bridge'}) do
 local f=fixture{observers=variant~='no_observers',bridge=variant=='missing_bridge' and 'missing' or nil}
 f:queue(2);f:tick(.25)
 check(f:last() and f:last().first_observed=='Queued','queue adoption without wrapper observer '..variant)
 check(f:last() and f:last().source=='unknown','pause versus gameplay not guessed without wrapper evidence '..variant)
 f.unlocked=true;f:tick(.25,8)
 check(f.calls.dispatch==1 and f:last().phase=='Submitted','policy does not require observers '..variant)
 evidenceUnknown(f)
end
-- Replacements and terminal states must track actual coordinator results.
local f=fixture();f:queue(1,'manual');f:tick(.25);local old=f:last().id
f:queue(2,'gameplay_quicksave');f:tick(.25)
local report=f:report();local prior
for _,r in ipairs(report.records) do if r.id==old then prior=r end end
check(prior and prior.phase=='Cancelled' and prior.reason=='replaced','replacement closes exact prior trace')
check(f:last().id~=old and f:last().source=='gameplay_quicksave','replacement has distinct observed provenance')
f:press('Cancel queued request##nls_cancel')
check(f:last().phase=='Cancelled','user cancellation reaches ledger')
check((f.calls.dispatch or 0)==0,'cancellation never dispatches')
f=fixture();f:queue(1,'manual');f:tick(.25);f:tick(30)
check(f:last().phase=='Expired','REGRESSION: expiry ledger terminal phase despite tick consuming pending first')
check(f:last().reason=='expired','expiry retains explicit reason')
check((f.calls.dispatch or 0)==0 and not f.player.pending,'expiry save policy unaffected')
f=fixture();f:queue(1,'manual');f.unlocked=true;f.dispatchFault=true;f:tick(.25,8)
check(f:last().phase=='Error','REGRESSION: rejected dispatch ledger terminal phase despite tick consuming pending first')
check(f:last().reason=='dispatch_rejected','error reason explicit')
check((f.calls.dispatch or 0)==0 and not f.player.pending,'error clears actual queue')
f=fixture();f:press('Queue test request (30s)##nls_queue');f:tick(.25);f:tick(30)
check(f:last().phase=='Expired' and f:last().dry_run==true,'preview expiry terminal without dispatch')
check(not phaseSeen(f,'Executing') and not phaseSeen(f,'Submitted'),'preview never advances to executing/submitted')
-- Tracking switch is observation-only; it cannot cancel an actual request.
for _,native in ipairs({false,true}) do
 local f=fixture{native=native};f:queue(1,'manual');f:tick(.25)
 local cancels=f.calls.cancel
 if native then
  check(f.native['Save Guardian request ledger']~=nil,'Native Settings Guardian switch registered')
  f.native['Save Guardian request ledger'].callback(false)
 else f:press('Disable Guardian##nls_guardian') end
 check(f.player.pending and f.calls.cancel==cancels,'tracking disable cannot cancel real queue')
 check(f:last().phase=='Unknown' and f:last().reason=='tracking_stopped','tracking ends as unknown, not cancellation')
 check(f.saved and f.saved['config.json'].guardianEnabled==false,'tracking toggle persists through config store seam')
 f.unlocked=true;f:tick(.25,8)
 check(f.calls.dispatch==1,'request still submits while tracking off')
 if native then f.native['Save Guardian request ledger'].callback(true) else f:press('Enable Guardian##nls_guardian') end
 check(f.saved['config.json'].guardianEnabled==true,'tracking re-enable persists')
 check(f.calls.cancel==cancels,'re-enable cannot mutate actual queue')
 evidenceUnknown(f)
end
-- Saving a diagnostic report must report disk refusal honestly and never touch policy.
f=fixture();f:queue(1,'manual');f:tick(.25);f.exportError=true
local cancels=f.calls.cancel
f:press('Export Guardian report##nls_guardian_export')
check(f:contains('Report export failed; save policy unchanged'),'report export failure visible')
check(f.player.pending and f.calls.cancel==cancels,'report failure cannot cancel pending queue')
f.unlocked=true;f:tick(.25,8);check(f.calls.dispatch==1,'report failure cannot inhibit dispatch')
f=fixture();f:queue(1,'manual');f:tick(.25);f:press('Export Guardian report##nls_guardian_export')
check(f.saved and f.saved['guardian-report.json'] and f:contains('Local guardian-report.json written'),'successful report export explicitly acknowledged')
check(f.saved['guardian-report.json'].gameBuild=='unknown','unknown build metadata not invented')
check(f.saved['guardian-report.json'].records[1].write_status=='Unknown','export cannot invent written evidence')
f=fixture{module='malformed_latest'}
check(pcall(f.events.onDraw),'malformed optional latest-row data must not abort overlay rendering')
f:queue(1,'manual');f.unlocked=true;f:tick(.25,8);check(f.calls.dispatch==1,'malformed latest-row data cannot inhibit save policy')
-- Persisted tracking preference reloads without becoming a save-policy input.
f=fixture{native=true};f.native['Save Guardian request ledger'].callback(false)
local restarted=fixture{config=f.saved['config.json']}
check(restarted:report().enabled==false,'tracking opt-out survives restart through saved config seam')
restarted:queue(1,'manual');restarted.unlocked=true;restarted:tick(.25,8)
check(restarted.calls.dispatch==1 and #restarted:report().records==0,'persisted opt-out preserves save routing without tracking')
-- A normally returned save wrapper is only Delegated, never Written.
f=fixture();f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{});f:fire('after','PauseMenuGameController','HandlePressToSaveGame',{});f:tick(.25)
check(f:last().phase=='Delegated' and f:last().first_observed=='Requested','ordinary wrapper return proves delegation only')
evidenceUnknown(f)
-- Disabling observation before drain must not cancel an already queued game request.
f=fixture();f:queue(1,'manual');local before=f.calls.cancel;f:press('Disable Guardian##nls_guardian');f.unlocked=true;f:tick(.25,8)
check(f.calls.dispatch==1 and f.calls.cancel==before,'dropping buffered tracking evidence cannot cancel unadopted game queue')
if #failures>0 then
 print('FAIL '..#failures..' of '..checks..' Guardian integration assertions')
 for _,s in ipairs(failures) do print(' - '..s) end
 os.exit(1)
end
print('PASS '..checks..' Guardian integration assertions; actual shipped Lua/modules, external Game/CET/REDscript/NativeSettings/disk doubles only')
