-- Actual init + config_store + profiles; real temp files. CET/Game/UI/JSON doubled.
local root=assert(arg[1],'release root required')
local disk=assert(arg[2],'isolated temp directory required')
local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local realIO,realOS=io,os
local checks,cases=0,0
local function check(v,label)checks=checks+1;assert(v,label)end
local function copy(v)if type(v)~='table' then return v end local r={};for k,x in pairs(v)do r[k]=copy(x)end return r end
local function fixture(options)
 options=options or {};cases=cases+1
 local h={events={},texts={},native={},present=options.player==true,unlocked=true,done=1,button=nil,mode=nil,loads={},saves={},failInstall=false}
 local prefix='case'..cases..'_'
 local function path(p)assert(type(p)=='string' and not p:find('/',1,true),'only fixture sandbox files');return disk..'/'..prefix..p end
 local records={}
 local function encode(v)
  local kind=type(v)
  if kind=='boolean' or kind=='number' then return tostring(v) end
  if kind=='string' then return string.format('%q',v) end
  assert(kind=='table','fixture supports JSON objects/scalars')
  local keys={};for k in pairs(v)do keys[#keys+1]=k end
  local array=#keys>0 and #keys==#v
  if array then for _,k in ipairs(keys)do if type(k)~='number' or k<1 or k>#keys or k~=math.floor(k)then array=false end end end
  if array then local items={};for i=1,#v do items[#items+1]=encode(v[i])end return '['..table.concat(items,',')..']' end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local chunks={};for _,k in ipairs(keys)do chunks[#chunks+1]=string.format('%q',tostring(k))..':'..encode(v[k])end
  return '{'..table.concat(chunks,',')..'}'
 end
 function h:put(name,value)
  local text=encode(value);records[text]=copy(value)
  local f=assert(realIO.open(path(name),'w'));assert(f:write(text));assert(f:close());return text
 end
 function h:raw(name)local f=realIO.open(path(name),'r');if not f then return nil end local s=f:read('*a');f:close();return s end
 function h:value(name)local s=self:raw(name);return s and copy(records[s]) or nil end
 h.primary=options.primary~=nil and h:put('config.json',options.primary) or nil
 h.backup=options.backup~=nil and h:put('config.json.bak',options.backup) or nil
 if options.bank then h:put('profile-settings.json',options.bank)end
 local p={session=0,pending=false,serial=0,source=0,manual=false,auto=false,mode=1,tone=1,notifications=true,cancels=0}
 h.player=p
 function p:NLSRebornDeferredSession(candidate)if self.session==0 then self.session=candidate end;return self.session end
 function p:NLSRebornDeferredCancel()self.pending=false;self.cancels=self.cancels+1 end
 function p:NLSRebornDeferredSetEnabled(v)self.manual=v;if not v and self.source~=3 then self.pending=false end end
 function p:NLSRebornAutosaveSetEnabled(v)self.auto=v;if not v and self.source==3 then self.pending=false end end
 function p:NLSRebornDeferredGetSerial()return self.serial end
 function p:NLSRebornDeferredIsPending()return self.pending end
 function p:NLSRebornDeferredGetSource()return self.source end
 function p:NLSRebornDeferredNativeUnlocked()return h.unlocked and h.done>0 end
 function p:NLSRebornPausedState()return 0 end
 function p:NLSRebornMenuState()return 0 end
 function p:NLSRebornMountedState()return 0 end
 function p:NLSRebornNotificationPhoneState()return 0 end
 function p:NLSRebornAutosaveReady()return false end
 function p:NLSRebornAutosaveQueue()error('test must not queue an autosave')end
 function p:NLSRebornDeferredDispatch()error('test must not dispatch a save')end
 function p:NLSRebornSetMode(v)self.mode=v end
 function p:NLSRebornGetMode()return self.mode end
 function p:NLSRebornSetOptions(a,b)self.combat=a;self.vehicle=b end
 function p:NLSRebornSetObservedState()end
 function p:NLSRebornSetContext()end
 function p:NLSRebornSetShuffleSeed()end
 function p:NLSRebornSetTone(v)self.tone=v end
 function p:NLSRebornGetTone()return self.tone end
 function p:NLSRebornSetNotificationsEnabled(v)self.notifications=v end
 function p:NLSRebornGetNotificationsEnabled()return self.notifications end
 function p:NLSRebornSetDFNotifications(a,b,c,d)self.mask=(a and 1 or 0)+(b and 2 or 0)+(c and 4 or 0)+(d and 8 or 0)end
 function p:NLSRebornGetDFNotificationMask()return self.mask or 15 end
 function p:NLSRebornSetStatusNotificationsEnabled()end
 function p:NLSRebornGetStatusNotificationsEnabled()return false end
 function p:NLSRebornGetDFPolicyStatus()return 'unknown' end
 function p:NLSRebornGetNotificationCategory()return 0 end
 function p:NLSRebornGetNotificationDiagnostics()return 'No checkpoint notification selected' end
 function p:NLSRebornShowActivation()end
 function p:IsInCombat()return false end
 function p:IsCrouching()return false end
 local env=setmetatable({}, {__index=_G})
 env.print=function()end
 env.registerForEvent=function(n,fn)h.events[n]=fn end
 env.json={decode=function(s)check(records[s]~=nil,'known JSON boundary fixture');return copy(records[s])end,
  encode=function(v)local s=encode(v);records[s]=copy(v);return s end}
 env.io={open=function(name,mode)
  if h.failOpen and name=='config.json.tmp' then return nil,'injected permission failure',13 end
  return realIO.open(path(name),mode)
 end}
 env.os=setmetatable({remove=function(name)return realOS.remove(path(name))end,
  rename=function(a,b)if h.failInstall and a=='config.json.tmp' then return nil,'injected replacement failure' end;return realOS.rename(path(a),path(b))end},{__index=realOS})
 env.Game={GetPlayer=function()return h.present and p or nil end,
  GetQuestsSystem=function()return {GetFactStr=function(_,k)return k=='q000_done' and h.done or 1 end,SetFactStr=function()end}end,
  GetScriptableSystemsContainer=function()return {Get=function()return {GetBodyTypeSuffix=function()return 'female'end}end}end}
 env.ItemID={new=function()return {}end}
 local ns={addTab=function()end,addSubcategory=function()end}
 ns.addSwitch=function(_,label,_,value,_,fn)h.native[label]={value=value,callback=fn};return label end
 ns.addSelectorString=function(_,label,_,labels,value,_,fn)h.native[label]={value=value,callback=fn};return label end
 ns.setOption=function(label,value)h.native[label].value=value;h.native[label].callback(value)end
 env.GetMod=function(name)return options.native and name=='nativeSettings' and ns or nil end
 env.ImGui={Begin=function()return true end,End=function()end,Separator=function()end,SameLine=function()end,
  Text=function(v)h.texts[#h.texts+1]=v end,TextWrapped=function(v)h.texts[#h.texts+1]=v end,
  RadioButton=function(label,active)if active then h.mode=label end;return false end,
  InputText=function(_,v)return options.label or v,options.label~=nil and options.label~=v end,
  Button=function(label)if h.button==label then h.button=nil;return true end;return false end}
 local cache={}
 env.require=function(name)
  if name=='guardian' or name=='guardian_bridge' or name=='quest_milestones' or (options.noProfiles and name=='profiles')then error('optional module excluded from focused fixture')end
  if cache[name]then return cache[name]end
  local value=assert(loadfile(dir..name..'.lua','t',env))()
  if name=='config_store'then
   local load,save=value.load,value.save
   value.load=function(name,validator)h.loads[#h.loads+1]={name=name,validator=validator};return load(name,validator)end
   value.save=function(name,data,validator)h.saves[#h.saves+1]={name=name,validator=validator};return save(name,data,validator)end
   h.store=value
  end
  cache[name]=value;return value
 end
 assert(loadfile(dir..'init.lua','t',env))();h.events.onInit();h.events.onOverlayOpen();h.events.onDraw()
 function h:draw()self.texts={};self.events.onDraw()end
 function h:press(label)self.button=label;self:draw();check(self.button==nil,'real UI button exists '..label);self:draw()end
 function h:contains(s)for _,line in ipairs(self.texts)do if tostring(line):find(s,1,true)then return true end end return false end
 function h:step()self.events.onUpdate(.25)end
 function h:validator()for _,row in ipairs(self.loads)do if row.name=='config.json'then return row.validator end end end
 function h:cleanup()for _,name in ipairs({'config.json','profile-settings.json','support-report.json','guardian-report.json'})do for _,suffix in ipairs({'','.bak','.tmp'})do realOS.remove(path(name..suffix))end end end
 return h
end
local good={mode=3,tone=0,allowCombat=true,deferredEnabled=true}
local allBooleans={'allowCombat','allowVehicle','notificationsEnabled','diagnosticDetails','deferredEnabled','guardianEnabled','statusNotificationsEnabled','autosaveEnabled','autosaveExploration','autosavePostCombat','autosaveVehicleExit','autosaveQuestMilestone','autosaveApartmentEntry','dfNotifyVehicleSleep','dfNotifyAddiction','dfNotifyStarvation','dfNotifyDehydration'}
-- Original reproduced gap, plus every recognized boolean and numeric family.
local invalid={{mode='broken'},{tone='broken'}}
for _,key in ipairs(allBooleans)do invalid[#invalid+1]={[key]='true'}end
for _,case in ipairs({{'mode',-1},{'mode',4},{'tone',-1},{'tone',3},
 {'deferredTTL',0},{'deferredTTL',121},{'deferredTTL',1.5},{'deferredCooldownSeconds',-1},{'deferredCooldownSeconds',601},{'deferredCooldownSeconds',.5},
 {'autosaveIntervalSeconds',59},{'autosaveIntervalSeconds',1801},{'autosaveIntervalSeconds',60.5},
 {'autosaveCooldownSeconds',29},{'autosaveCooldownSeconds',601},{'autosaveCooldownSeconds',30.5}})do invalid[#invalid+1]={[case[1]]=case[2]}end
for _,primary in ipairs(invalid)do
 local h=fixture{primary=primary,backup=good}
 check(h.mode=='Smart (experimental)' and h:contains('Selected: Professional'),'known invalid primary falls back to complete validated backup')
 check(h:raw('config.json')==h.primary and h:raw('config.json.bak')==h.backup,'recovery read changes no primary or backup bytes')
 h:press('Disable notifications##nls_notifications')
 check(h:raw('config.json.bak')==h.backup,'save after semantic recovery retains sole known-good backup')
 local v=h:value('config.json');check(v.mode==3 and v.tone==0 and v.notificationsEnabled==false,'real UI save persists recovered effective settings')
 check(type(h:validator())=='function' and h.saves[1].validator==h:validator(),'same main validator passed through load and UI save')
 h:cleanup()
end
-- Legacy objects keep unknown obsolete keys, defaults and existing finite flooring.
do
 local h=fixture{primary={mode=2.8,tone=1.9,dfBlockSleep=true,obsolete='ignored'},backup=good,native=true}
 check(h.mode=='Unrestricted (experimental)' and h:contains('Selected: Sarcastic'),'legacy mode/tone flooring retained')
 check(h:raw('config.json')==h.primary and h:raw('config.json.bak')==h.backup,'healthy partial primary wins without read repair')
 check(h.native['Queue expiry (seconds)'].value==30 and h.native['Autosave interval (seconds)'].value==241,'missing fields retain existing effective defaults')
 h:press('Disable notifications##nls_notifications');check(h:raw('config.json.bak')==h.primary,'healthy legacy primary normally rotates')
 h:cleanup()
end
do
 local h=fixture{primary={},backup=good};check(h.mode=='Immersion' and h:contains('Selected: Sarcastic'),'empty legacy object is valid default configuration');h:cleanup()
end
do
 local h=fixture{primary={notificationsEnabled=false,allowCombat=false,allowVehicle=false,mode=0,tone=0},backup=good}
 check(h.mode=='Vanilla' and h:contains('Save-request notifications: OFF'),'known false booleans remain valid');h:cleanup()
end
-- Invalid roots cannot mask the backup. Unknown string keys do not become restrictions.
for _,primary in ipairs({{[1]='array value'},setmetatable({mode=1},{})})do
 -- JSON decoding cannot create metatables; validate that root directly at the public store seam below.
 if getmetatable(primary)==nil then local h=fixture{primary=primary,backup=good};check(h.mode=='Smart (experimental)','nonempty array root rejected');h:cleanup()end
end
-- Validator protects incoming writes before any filesystem mutation.
do
 local h=fixture{primary={mode=1,tone=1},backup=good};local validator=h:validator()
 local before,bak=h:raw('config.json'),h:raw('config.json.bak')
 for _,value in ipairs({{mode='broken'},{tone=math.huge},{deferredTTL=1.5},{[1]=true},setmetatable({mode=1},{})})do
  check(pcall(h.store.save,'config.json',value,validator)==false,'invalid new settings refused')
  check(h:raw('config.json')==before and h:raw('config.json.bak')==bak and h:raw('config.json.tmp')==nil,'invalid write mutates no files')
 end
 h:cleanup()
end
-- Failed real replacement after semantic recovery cannot destroy the valid backup.
do
 local h=fixture{primary={mode='broken',tone=2},backup=good};h.failInstall=true
 h:press('Disable notifications##nls_notifications')
 check(h:contains('Save failed:'),'actual UI reports failed replacement')
 check(h:raw('config.json.bak')==h.backup,'failed replacement preserves known-good backup')
 check(h.store.load('config.json',h:validator()).mode==3,'backup remains recoverable after failed installation')
 h:cleanup()
end
-- Missing optional profiles cannot disable main config schema recovery.
do
 local h=fixture{primary={mode='broken'},backup=good,noProfiles=true};check(h.mode=='Smart (experimental)','main validator independent of optional profiles');h:cleanup()
end
-- Preset-application write failure preserves runtime/queued request AND validated config recovery.
do
 local h=fixture{primary={mode=3,tone=1,deferredEnabled=true},backup={mode=1,tone=0},player=true,label='Preset',
  bank={schema_version=1,profiles={Preset={mode=0,tone=2,deferredEnabled=true}}}}
 h:step();h.unlocked=false;h.player.serial=1;h.player.source=1;h.player.pending=true;h:step()
 local priorMode,priorTone,cancels=h.player.mode,h.player.tone,h.player.cancels
 check(h.player.pending and priorMode==3,'manual request pending before preset failure')
 h:put('config.json',{mode='broken',tone=2});h.backup=h:put('config.json.bak',good);h.failInstall=true
 h:press('Load named preset##nls_profile_load')
 check(h:contains('Preset not applied: write_failed'),'preset persistence failure visible')
 check(h.player.pending and h.player.mode==priorMode and h.player.tone==priorTone and h.player.cancels==cancels,'failed preset application preserves runtime and pending request')
 check(h:raw('config.json.bak')==h.backup,'preset failure preserves valid backup against schema-invalid primary')
 local last=h.saves[#h.saves];check(last.name=='config.json' and last.validator==h:validator(),'preset write uses same main-settings validator')
 h.failInstall=false;h:press('Load named preset##nls_profile_load')
 check(h.player.mode==0 and h.player.tone==2 and not h.player.pending,'successful preset persistence then applies and cancels old pending work')
 check(h:raw('config.json.bak')==h.backup,'successful preset application after recovery retains valid backup')
 h:cleanup()
end
print('PASS '..checks..' main-settings actual-init/real-disk assertions across '..cases..' cases; CET/Game/UI/JSON boundaries doubled')
