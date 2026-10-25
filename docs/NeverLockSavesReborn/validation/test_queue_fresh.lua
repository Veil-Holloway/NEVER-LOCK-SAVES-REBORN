-- Fresh audit: actual shipped Lua, with external CET/Game/REDscript boundaries doubled.
-- Does not compile REDscript, launch the game, create saves, or verify reloads.
local root=assert(arg[1], 'baseline root required')
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local checks=0
local function check(v,msg) checks=checks+1; assert(v,msg) end
local queue=dofile(dir..'deferred_save.lua')
local safe={playerReady=true,introComplete=true,nativeSavingUnlocked=true,scriptedTransition=false,loading=false}
local function clone(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
-- Requirements-derived pure policy boundaries, using actual module.
for _,source in ipairs({'manual','quicksave'}) do
 local s=queue.new(); local dispatched=0
 check(s.pending==nil and s.lastResult=='idle','new queue idle')
 local a=queue.request(s,0,source,30); check(a==1 and s.pending.source==source,'request records source/serial')
 for _,key in ipairs({'playerReady','introComplete','nativeSavingUnlocked','scriptedTransition','loading'}) do
  for _,bad in ipairs({'unknown','wrong'}) do
   local state=clone(safe); if bad=='unknown' then state[key]=nil else state[key]=not safe[key] end
   check(queue.tick(s,1,state,function() dispatched=dispatched+1; return true end)=='waiting','unsafe or unknown waits: '..key)
   check(s.pending~=nil and dispatched==0,'waiting retains request without callback')
  end
 end
 check(queue.tick(s,2,safe,nil)=='waiting','missing dispatch waits')
 check(queue.tick(s,2,safe,function() dispatched=dispatched+1; return true end)=='request_submitted','safe dispatch accepted')
 check(s.pending==nil and dispatched==1,'one dispatch consumes pending')
 check(queue.tick(s,3,safe,function() dispatched=dispatched+1; return true end)=='idle' and dispatched==1,'no duplicate after dispatch')
end
for _,outcome in ipairs({'false','throw','nil'}) do
 local s=queue.new(); queue.request(s,0,'manual',30)
 check(queue.tick(s,1,safe,function() if outcome=='throw' then error('injected failure') elseif outcome=='false' then return false end end)=='request_failed','failure surfaced: '..outcome)
 check(s.pending==nil,'failure consumes request rather than retrying')
end
local s=queue.new(); queue.request(s,0,'manual',30); local first=s.pending.id; queue.request(s,4,'quicksave',30)
check(s.pending.id>first and s.pending.source=='quicksave' and s.pending.expires==34,'replacement uses latest source and TTL')
check(queue.tick(s,34,safe,function() error('expired request callback') end)=='expired','expiry wins even over safety')
check(s.pending==nil,'expiry clears pending')
queue.request(s,0,'manual',30); check(queue.cancel(s)==true and s.pending==nil,'cancellation clears pending'); check(queue.cancel(s)==false,'idle cancellation idempotent')
queue.request(s,0,'manual',30); local reentrant=0
queue.tick(s,1,safe,function() reentrant=reentrant+1; check(queue.tick(s,1,safe,function() reentrant=reentrant+1 end)=='idle','callback sees removed pending'); return true end)
check(reentrant==1,'reentrant dispatch cannot duplicate')
for _,bad in ipairs({0,-1,121,math.huge,0/0}) do check(not pcall(queue.request,queue.new(),0,'manual',bad),'invalid TTL rejected') end
-- Current explicit engine-only scope allows missing independent transition/loading sensors.
s=queue.new();queue.request(s,0,'manual',30)
check(queue.tick(s,1,{playerReady=true,introComplete=true,nativeSavingUnlocked=true,enginePermissionOnly=true},function() return true end)=='request_submitted','explicit engine permission mode')

local function fixture(opts)
 opts=opts or {}; local f={events={},facts={q000_done=1,q001_started=0},calls={},text={},button=nil,unlocked=false,playerPresent=true,dispatchFault=false,bridgeFault=false,questFault=false}
 if opts.done~=nil then f.facts.q000_done=opts.done end
 if opts.rescue~=nil then f.facts.q001_started=opts.rescue end
 local p={mode=0,tone=0,notifications=true,pending=false,serial=0,source=0,session=0,enabled=false,blocked=true,mask=15}
 f.player=p; f.current=p
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
 env.GetMod=function() return nil end
 env.require=function(name)
  if name=='deferred_save' then return dofile(dir..'deferred_save.lua') end
  if name=='config_store' then return {load=function() return {mode=opts.mode or 3,deferredEnabled=true} end,save=function() end} end
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
 function f:queue(source) p.serial=p.serial+1;p.source=source or 1;p.pending=true end
 function f:contains(fragment) self.text={};self.events.onDraw();for _,t in ipairs(self.text)do if t:find(fragment,1,true)then return true end end return false end
 return f
end
-- Exact screenshot completion gate across all modes, and failed diagnostic reads.
for mode=0,3 do
 local f=fixture{mode=mode};check(f.player.blocked==false,'q000=1/q001=0 releases protection mode '..mode)
 f.rescueFault=true;f:tick(2);check(f.player.blocked==false,'rescue diagnostic failure cannot veto completion')
end
for _,done in ipairs({0,-1}) do local f=fixture{done=done,rescue=1};check(f.player.blocked,'unfinished completion stays protected') end
local f=fixture();f.questFault=true;f:tick(2);check(f.player.blocked,'unreadable completion protected')
-- Actual shipped coordinator semantics against a REDscript-shaped boundary.
for source=1,2 do
 local f=fixture();f:queue(source);f:tick(.25);check(f.player.pending and (f.calls.dispatch or 0)==0,'locked request retained')
 f.unlocked=true;f:tick(.25,7);check((f.calls.dispatch or 0)==0,'does not dispatch before full stability')
 f:tick(.25);check(f.calls.dispatch==1 and f.calls.source==source,'eligible request dispatches once after stability')
 f:tick(.25,12);check(f.calls.dispatch==1,'coordinator never repeats consumed dispatch')
 check(f:contains('Submitted (save completion unconfirmed)'),'submission UI does not claim completion')
end
f=fixture();f:queue(1);f.unlocked=true;f:tick(.25,5);f.unlocked=false;f:tick(.25);f.unlocked=true;f:tick(.25,7)
check((f.calls.dispatch or 0)==0,'relock resets stability');f:tick(.25);check(f.calls.dispatch==1,'relocked request recovers')
f=fixture();f:queue(1);f.unlocked=true;f:tick(5);check((f.calls.dispatch or 0)==0,'long frame cannot satisfy stability');f:tick(.25,7);check(f.calls.dispatch==1,'seven later quarter-second samples finish capped stability')
f=fixture();f:queue(1);f.unlocked=true;f:tick(.25,5);f:queue(2);f:tick(.25,7);check((f.calls.dispatch or 0)==0,'replacement resets stability');f:tick(.25);check(f.calls.dispatch==1 and f.calls.source==2 and f.calls.serial==2,'replacement dispatch uses latest source/serial')
f=fixture();f:queue();f:tick(.25);f:tick(30);check(f.player.pending==false and (f.calls.dispatch or 0)==0,'expiry cancels both bridge and Lua');check(f:contains('Expired without save'),'expiry displayed')
f=fixture();f:queue();f:tick(.25);f:press('Cancel queued request##nls_cancel');f.unlocked=true;f:tick(.25,9);check(not f.player.pending and (f.calls.dispatch or 0)==0,'user cancellation clears both halves')
f=fixture();f:queue();f:tick(.25);f:press('Disable Deferred Save##nls_deferred');f.unlocked=true;f:tick(.25,9);check(not f.player.enabled and not f.player.pending and (f.calls.dispatch or 0)==0,'disable clears both halves')
f=fixture();f.unlocked=true;f:press('Queue test request (30s)##nls_queue');f:tick(.25,12);check((f.calls.dispatch or 0)==0 and f:contains('Pending (dry run)'),'dry run remains queued without dispatch');f:tick(30);check((f.calls.dispatch or 0)==0 and f:contains('Expired without save'),'dry run expires without dispatch')
f=fixture();f:queue();f:tick(.25);f:press('Queue test request (30s)##nls_queue');check(f:contains('Dry run skipped: game request pending'),'dry run cannot replace real request');f.unlocked=true;f:tick(.25,8);check(f.calls.dispatch==1,'real request retained despite preview attempt')
f=fixture();f:queue();f:tick(.25);f.playerPresent=false;f:tick(.25);f.playerPresent=true;f.unlocked=true;f:tick(.25,12);check((f.calls.dispatch or 0)==0 and not f.player.pending,'player loss cancels stale request rather than adopting it')
f=fixture();f:queue();f:tick(.25);f.player.session=99;f.unlocked=true;f:tick(.25,12);check((f.calls.dispatch or 0)==0 and not f.player.pending,'session change clears pending request')
f=fixture();f:queue();f:tick(.25);f.bridgeFault=true;f:tick(.25);f.bridgeFault=false;f.unlocked=true;f:tick(.25,12);check((f.calls.dispatch or 0)==0 and not f.player.pending,'bridge loss prevents stale dispatch')
f=fixture();f:queue();f:tick(.25);f.facts.q000_done=0;f.unlocked=true;f:tick(.25,12);check((f.calls.dispatch or 0)==0 and not f.player.pending,'fresh incomplete intro cancels pending before dispatch')
f=fixture();f:queue();f:tick(.25);f.questFault=true;f.unlocked=true;f:tick(.25,12);check((f.calls.dispatch or 0)==0 and not f.player.pending,'fresh unknown intro cancels pending before dispatch')
f=fixture();f:queue();f.unlocked=true;f.dispatchFault=true;f:tick(.25,8);check((f.calls.dispatch or 0)==0 and not f.player.pending and f:contains('Error: deferred dispatch rejected'),'dispatch failure visible and clears both halves')
f=fixture();f.facts.q000_done=0;f:tick(.25);check(f.player.blocked==false and f:contains('Safety block: true'),'REPRO precondition: fresh local intro protection differs from stale REDscript bridge before periodic apply');f:tick(2);check(f.player.blocked==true,'periodic apply eventually catches up cached protection')
print('PASS '..checks..' fresh queue assertions; actual deferred_save.lua and init.lua; external Game/CET/REDscript boundary simulations only')
