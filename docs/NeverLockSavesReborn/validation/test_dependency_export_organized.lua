-- UI-migrated fixture; original source and mutation tests preserved.
-- Independent actual-init/report/collector integration. CET/Game/UI/store are boundaries.
local root=assert(arg[1],'release root required')
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local checks,fixtures=0,0
local function check(value,label)checks=checks+1;assert(value,label)end
local function clone(value)
 if type(value)~='table' then return value end
 local out={};for k,v in pairs(value)do out[k]=clone(v)end;return out
end
local PRIVATE='PRIVATE_VERSION_SECRET_5482'
local keys={'cet','codeware','nativeSettings','redscript','red4ext','darkFuture'}
local sources={cet='cet_get_version',codeware='codeware_version',nativeSettings='native_settings_version',redscript='none',red4ext='none',darkFuture='none'}
local function privateFree(value,depth)
 depth=depth or 0;check(depth<=8,'bounded output depth')
 if type(value)=='table' then
  check(getmetatable(value)==nil,'report tables plain')
  local count=0;for k,v in pairs(value)do count=count+1;check(type(k)=='string' or type(k)=='number','plain output keys');privateFree(v,depth+1)end
  check(count<=32,'bounded object/array fields')
 elseif type(value)=='string' then check(#value<=160 and not value:find(PRIVATE,1,true),'private/raw API text absent and string bounded')
 elseif type(value)=='number' then check(value==value and value~=math.huge and value~=-math.huge,'finite output number')
 else check(type(value)=='boolean','JSON-compatible output scalar')end
end
local function fixture(options)
 fixtures=fixtures+1;options=options or {}
 local h={events={},texts={},native={},files={['config.json']={mode=3,tone=1,deferredEnabled=true,guardianEnabled=true}},saves={},calls={cet=0,codeware=0,nativeLookup=0},values={cet='v1.37.1-5-gabc123',codeware='1.18.0',nativeSettings=1.97},errors={},button=nil,poisonCalls=0,coercions=0}
 local env=setmetatable({}, {__index=_G});h.env=env
 env.print=function()end;env.registerForEvent=function(name,callback)h.events[name]=callback end
 local player={session=0,pending=false,serial=0,source=0,mode=1,tone=1,notifications=true,cancels=0}
 h.player=player
 function player:NLSRebornDeferredSession(candidate)if self.session==0 then self.session=candidate end;return self.session end
 function player:NLSRebornDeferredCancel()self.pending=false;self.cancels=self.cancels+1 end
 function player:NLSRebornDeferredSetEnabled(v)self.manual=v end
 function player:NLSRebornAutosaveSetEnabled(v)self.auto=v end
 function player:NLSRebornDeferredGetSerial()return self.serial end
 function player:NLSRebornDeferredIsPending()return self.pending end
 function player:NLSRebornDeferredGetSource()return self.source end
 function player:NLSRebornDeferredNativeUnlocked()return false end
 function player:NLSRebornPausedState()return 0 end
 function player:NLSRebornMenuState()return 0 end
 function player:NLSRebornMountedState()return 0 end
 function player:NLSRebornNotificationPhoneState()return 0 end
 function player:NLSRebornAutosaveReady()return false end
 function player:NLSRebornDeferredDispatch()error('unexpected save dispatch in diagnostic fixture')end
 function player:NLSRebornSetMode(v)self.mode=v end
 function player:NLSRebornGetMode()return self.mode end
 function player:NLSRebornSetOptions(a,b)self.allowCombat=a;self.allowVehicle=b end
 function player:NLSRebornSetObservedState()end
 function player:NLSRebornSetContext()end
 function player:NLSRebornSetShuffleSeed()end
 function player:NLSRebornSetTone(v)self.tone=v end
 function player:NLSRebornGetTone()return self.tone end
 function player:NLSRebornSetNotificationsEnabled(v)self.notifications=v end
 function player:NLSRebornGetNotificationsEnabled()return self.notifications end
 function player:NLSRebornSetDFNotifications(a,b,c,d)self.mask=(a and 1 or 0)+(b and 2 or 0)+(c and 4 or 0)+(d and 8 or 0)end
 function player:NLSRebornGetDFNotificationMask()return self.mask or 15 end
 function player:NLSRebornSetStatusNotificationsEnabled(v)self.status=v end
 function player:NLSRebornGetStatusNotificationsEnabled()return self.status==true end
 function player:NLSRebornGetNotificationDiagnostics()return 'No checkpoint notification selected' end
 function player:NLSRebornGetDFPolicyStatus()return 'unknown' end
 function player:NLSRebornGetNotificationCategory()return 0 end
 function player:NLSRebornShowActivation()end
 function player:NLSRebornSaveLockSummary()return 'locked|Quest' end
 function player:NLSRebornDiagnosticDFState()return {vehicleSleep=-1,addiction=-1,starvation=-1,dehydration=-1}end
 function player:IsInCombat()return false end
 function player:IsCrouching()return false end
 env.Game={GetPlayer=function()return options.activePlayer and player or nil end,
  GetQuestsSystem=function()return {GetFactStr=function()return 1 end}end,
  GetScriptableSystemsContainer=function()return {Get=function()return {GetBodyTypeSuffix=function()return 'male'end}end}end}
 env.ItemID={new=function()return {}end}
 env.GetSingleton=function(name)
  check(name=='inkMenuScenario','unchanged exact game-version entry')
  return {GetSystemRequestsHandler=function()return {GetGameVersion=function()return '2.31'end}end}
 end
 env.GetVersion=function()h.calls.cet=h.calls.cet+1;if h.errors.cet then error(PRIVATE)end;return h.values.cet end
 env.Codeware={Version=function()h.calls.codeware=h.calls.codeware+1;if h.errors.codeware then error(PRIVATE)end;return h.values.codeware end}
 env.io={open=function()return nil,'missing',2 end}
 local ns={version=1.97,addTab=function()end,addSubcategory=function()end}
 ns.addSwitch=function(_,label,_,value,_,callback)h.native[label]={value=value,callback=callback};return label end
 ns.addSelectorString=function(_,label,_,labels,value,_,callback)h.native[label]={value=value,callback=callback};return label end
 ns.setOption=function(label,value)if h.native[label]then h.native[label].value=value;h.native[label].callback(value)end end
 h.nativeExport=ns
 env.GetMod=function(name)
  check(name=='nativeSettings','only source-backed CET module lookup')
  h.calls.nativeLookup=h.calls.nativeLookup+1
  if h.errors.nativeSettings then error(PRIVATE)end
  local value=h.nativeExport
  if type(value)=='table' and getmetatable(value)==nil then value.version=h.values.nativeSettings end
  return value
 end
 env.ImGui={Begin=function()return true end,End=function()end,Separator=function()end,SameLine=function()end,
  Text=function(v)h.texts[#h.texts+1]=tostring(v)end,TextWrapped=function(v)h.texts[#h.texts+1]=tostring(v)end,
  RadioButton=function(label,selected)if selected then if label:find('##nls_setting_mode',1,true)then h.selectedMode=label:gsub('##.*','')end end;return false end,
  Button=function(label)if label==h.button then h.button=nil;return true end;return false end}
 local cache={};h.cache=cache
 env.require=function(name)
  if name=='guardian_bridge' or name=='quest_milestones' then error('optional observer omitted from focused diagnostic fixture')end
  if name=='dependency_versions' and options.collector then
   local kind=options.collector
   if kind=='missing' then error('optional collector missing '..PRIVATE)end
   if kind=='not_table' then return function()end end
   if kind=='no_method' then return {}end
   if kind=='poisoned' then return setmetatable({}, {__index=function()h.poisonCalls=h.poisonCalls+1;error(PRIVATE)end})end
   if kind=='throws' then return {sample=function()error(PRIVATE)end}end
   if kind=='bad_result' then return {sample=function()return PRIVATE end}end
   if kind=='meta_result' then return {sample=function()return setmetatable({versions={cet='1.37.1'}},{__index=function()error(PRIVATE)end})end}end
   error('unexpected collector fixture')
  end
  if name=='config_store' then return {load=function(path)return clone(h.files[path])end,save=function(path,value)h.saves[path]=(h.saves[path]or 0)+1;h.files[path]=clone(value);return true end}end
  if cache[name]then return cache[name]end
  local loaded=assert(loadfile(dir..name..'.lua','t',env))();cache[name]=loaded;return loaded
 end
 function h:draw(label)
  self.texts={};self.button=label;self.selectedMode=nil
  local ok,err=pcall(self.events.onDraw)
  check(ok,'actual draw/export must not throw: '..tostring(err))
  if label then check(self.button==nil,'public UI action occurred: '..label)end
 end
 function h:line(prefix)for _,line in ipairs(self.texts)do if line:sub(1,#prefix)==prefix then return line end end end
 function h:export()
  local before=self.saves['support-report.json']or 0
  self:draw('Export support report##nls_support_export');self:draw()
  check(self.saves['support-report.json']==before+1,'each explicit support export writes one report')
  check(self:line('Support report:')=='Support report: Local support-report.json written','report UI acknowledges local export')
  return self.files['support-report.json']
 end
 assert(loadfile(dir..'init.lua','t',env))()
 check(h.calls.cet==0 and h.calls.codeware==0 and h.calls.nativeLookup==0,'module loading performs no dependency reads')
 h.events.onInit();h.events.onOverlayOpen();h:draw()
 return h
end
local function evidence(report,key,status,source)
 local row=report.dependency_evidence and report.dependency_evidence[key]
 check(type(row)=='table','fixed evidence row exists '..key)
 check(row.status==status,'expected evidence status '..key..' '..status)
 check(row.source==(source or sources[key]),'component maps to fixed source '..key)
end
-- Intended baseline failure: actual preRC3 exports Unknown despite available APIs.
local h=fixture();local before=clone(h.calls)
local report=h:export()
check(report.dependencies.cet=='1.37.1-5-gabc123' and report.dependencies.codeware=='1.18.0' and report.dependencies.nativeSettings=='1.97','NLSR-DEPENDENCY-EXPORT: available version APIs were not sampled by actual support export')
check(h.calls.cet==before.cet+1 and h.calls.codeware==before.codeware+1 and h.calls.nativeLookup==before.nativeLookup+1,'one call per supported version API at export')
check(report.dependency_evidence.scope=='on_demand_runtime_self_report' and report.dependency_evidence.compatibility=='unverified','self-report scope never claims compatibility')
for _,key in ipairs({'cet','codeware','nativeSettings'})do evidence(report,key,'observed')end
for _,key in ipairs({'redscript','red4ext','darkFuture'})do check(report.dependencies[key]=='unknown','unsupported version remains unknown '..key);evidence(report,key,'not_supported')end
check(report.game_build=='2.31','existing game-version read preserved')
local old=clone(report)
h.values.cet='v1.38.0';h.values.codeware='1.19.0';h.values.nativeSettings=2
report=h:export();check(report.dependencies.cet=='1.38.0' and report.dependencies.codeware=='1.19.0' and report.dependencies.nativeSettings=='2','each export samples current values without cache or invented package precision')
check(old.dependencies.cet=='1.37.1-5-gabc123','export snapshots do not alias later samples')
-- Warmed UI/update and the separate Guardian export must not sample dependency APIs.
local counts=clone(h.calls);local settingsSaves=h.saves['config.json']or 0
for _=1,1000 do h.events.onUpdate(.05)end
for _=1,100 do h:draw()end
h:draw('Export Guardian report##nls_guardian_export')
check((h.saves['guardian-report.json']or 0)==1,'separate Guardian report was exercised')
check(h.calls.cet==counts.cet and h.calls.codeware==counts.codeware and h.calls.nativeLookup==counts.nativeLookup,'no additional version reads from updates/draws/Guardian export')
check((h.saves['config.json']or 0)==settingsSaves,'diagnostic collection does not persist settings')
-- Actual dry-run work and selected policy survive explicit diagnostic collection.
h:draw('Queue dry-run test##nls_queue');h:draw();local queued=h:line('Queue:');check(queued and queued:find('Pending (dry run)',1,true),'dry-run queue seeded through real UI')
local mode=h.selectedMode;report=h:export();check(h:line('Queue:')==queued and h.selectedMode==mode,'support export preserves exact pending work and selected mode')
check(report.settings.effective.mode==3 and report.settings.effective.tone==nil,'effective settings retain active values and discard tone')
-- The full active-player update path is also free of continuous version polling.
local active=fixture({activePlayer=true});local ac=clone(active.calls)
for _=1,1000 do active.events.onUpdate(.05)end
for _=1,100 do active:draw()end
active:draw('Export Guardian report##nls_guardian_export')
check(active.calls.cet==ac.cet and active.calls.codeware==ac.codeware and active.calls.nativeLookup==ac.nativeLookup,'active-player updates/draws/Guardian export do not poll version APIs')
local policy={mode=active.player.mode,tone=active.player.tone,allowCombat=active.player.allowCombat,allowVehicle=active.player.allowVehicle,pending=active.player.pending,serial=active.player.serial,manual=active.player.manual,auto=active.player.auto}
local configWrites=active.saves['config.json']or 0
local ar=active:export()
check(ar.dependencies.cet=='1.37.1-5-gabc123','active-player support export samples supported versions')
for k,v in pairs(policy)do check(active.player[k]==v,'active-player diagnostic export preserves policy/queue field '..k)end
check((active.saves['config.json']or 0)==configWrites,'active-player diagnostic export does not write settings')
-- Each throwing supported reader leaves others available and raw errors private.
for _,key in ipairs({'cet','codeware','nativeSettings'})do
 local f=fixture();f.errors[key]=true;local r=f:export()
 check(r.dependencies[key]=='unknown','throwing getter remains unknown '..key);evidence(r,key,'read_failed')
 for _,other in ipairs({'cet','codeware','nativeSettings'})do if other~=key then check(r.dependencies[other]~='unknown','other getter survives single fault '..other)end end
 privateFree(r)
end
-- Missing supported interfaces are unavailable without suppressing report writing.
for _,key in ipairs({'cet','codeware','nativeSettings'})do
 local f=fixture()
 if key=='cet' then f.env.GetVersion=false elseif key=='codeware' then f.env.Codeware=nil else f.nativeExport=nil end
 local r=f:export();check(r.dependencies[key]=='unknown','missing interface unknown '..key);evidence(r,key,'unavailable')
end
-- Source-specific scalar formats and adversarial objects never leak or coerce.
local invalid={cet={'v1.2.3 '..PRIVATE,'v1.2.3\n'..PRIVATE,'https://host/'..PRIVATE,{},false,math.huge},codeware={'v1.18.0','1.2.3/'..PRIVATE,'1.2.3:'..PRIVATE,{},false,123},nativeSettings={'1.97',0/0,math.huge,-math.huge,-1,1000001,{}}}
for key,values in pairs(invalid)do
 for _,value in ipairs(values)do
  local f=fixture();f.values[key]=value;local r=f:export();check(r.dependencies[key]=='unknown','invalid value remains unknown '..key);evidence(r,key,'invalid');privateFree(r)
 end
end
for _,key in ipairs({'cet','codeware','nativeSettings'})do
 local f=fixture();local poison=setmetatable({}, {__tostring=function()f.coercions=f.coercions+1;error(PRIVATE)end})
 f.values[key]=poison;local r=f:export();check(r.dependencies[key]=='unknown' and f.coercions==0,'arbitrary version object never stringified '..key)
end
local n=fixture();n.nativeExport=setmetatable({}, {__index=function()n.poisonCalls=n.poisonCalls+1;error(PRIVATE)end})
report=n:export();check(report.dependencies.nativeSettings=='unknown' and n.poisonCalls==0,'native version lookup rejects nonplain export without invoking metamethod');evidence(report,'nativeSettings','unavailable')
-- Optional collector faults retain a useful ordinary report with Unknown versions.
for _,kind in ipairs({'missing','not_table','no_method','poisoned','throws','bad_result','meta_result'})do
 local f=fixture({collector=kind});local c=clone(f.calls);local r=f:export()
 for _,key in ipairs(keys)do check(r.dependencies[key]=='unknown','collector fault retains unknown '..kind..' '..key);evidence(r,key,'not_sampled','none')end
 check(f.calls.cet==c.cet and f.calls.codeware==c.codeware and f.calls.nativeLookup==c.nativeLookup,'faulty collector does not read APIs '..kind)
 check(f.poisonCalls==0,'malformed collector index metamethod not invoked '..kind)
 privateFree(r)
end
-- Independently exercise the pure collector's fixed supported-reader boundary.
local collector=assert(loadfile(dir..'dependency_versions.lua'))()
local unsupportedReads=0
local sampled=collector.sample({cet=function()return 'v2.0.0'end,codeware=function()return '2.1.0'end,nativeSettings=function()return 2.34 end,
 redscript=function()unsupportedReads=unsupportedReads+1;error(PRIVATE)end,red4ext=function()unsupportedReads=unsupportedReads+1;error(PRIVATE)end,darkFuture=function()unsupportedReads=unsupportedReads+1;error(PRIVATE)end,extra=function()error(PRIVATE)end})
check(unsupportedReads==0,'unsupported or extra readers are never invoked')
local versionCount,evidenceCount=0,0;for _ in pairs(sampled.versions)do versionCount=versionCount+1 end;for _ in pairs(sampled.evidence)do evidenceCount=evidenceCount+1 end
check(versionCount==6 and evidenceCount==6,'collector output has exactly six fixed components')
for _,key in ipairs({'redscript','red4ext','darkFuture'})do check(sampled.versions[key]=='unknown' and sampled.evidence[key].status=='not_supported' and sampled.evidence[key].source=='none','unsupported input cannot supply fabricated version '..key)end
local metamethods=0
local malicious=setmetatable({}, {__metatable='opaque',__index=function()metamethods=metamethods+1;error(PRIVATE)end,__pairs=function()metamethods=metamethods+1;error(PRIVATE)end})
sampled=collector.sample(malicious)
check(metamethods==0,'malformed reader table invokes no metamethods')
for _,key in ipairs({'cet','codeware','nativeSettings'})do check(sampled.versions[key]=='unknown' and sampled.evidence[key].status=='unavailable','malformed readers remain unavailable '..key)end
print('PASS independent dependency export runtime: '..checks..' assertions across '..fixtures..' actual-init fixtures; CET/Game/UI/store boundaries doubled')
