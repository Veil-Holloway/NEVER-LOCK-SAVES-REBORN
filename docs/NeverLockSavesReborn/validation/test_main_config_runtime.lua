-- Independent actual-init/config_store tests. Real disk; CET/Game/UI/JSON are boundaries.
local root=assert(arg[1],'release root')
local disk=assert(arg[2],'isolated temp directory')
local moduleDir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local realIO,realOS=io,os
local checks,fixtureCount=0,0
local function check(value,message) checks=checks+1;assert(value,message) end
local function clone(v) if type(v)~='table' then return v end local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
local function objectJSON(v)
  local kind=type(v)
  if kind=='string' then return string.format('%q',v) end
  if kind=='boolean' then return tostring(v) end
  if kind=='number' then assert(v==v and v~=math.huge and v~=-math.huge);return tostring(v) end
  assert(kind=='table','JSON fixture supports plain objects and scalars')
  local keys={};for k in pairs(v)do assert(type(k)=='string');keys[#keys+1]=k end;table.sort(keys)
  local out={};for _,key in ipairs(keys)do out[#out+1]=string.format('%q',key)..':'..objectJSON(v[key]) end
  return '{'..table.concat(out,',')..'}'
end
local fixture
fixture=function(primary,backup,options)
  fixtureCount=fixtureCount+1;options=options or {}
  local prefix=disk..'/'..fixtureCount..'-'
  local f={events={},texts={},saves={},loads={},decoded={},failInstall=false,denyWrites=false,pressed=nil,mode=nil}
  local function mapped(path) assert(type(path)=='string' and not path:find('/',1,true));return prefix..path end
  function f:raw(path)local h=realIO.open(mapped(path),'r');if not h then return nil end;local b=h:read('*a');h:close();return b end
  function f:putRaw(path,bytes)local h=assert(realIO.open(mapped(path),'w'));assert(h:write(bytes));assert(h:close());return bytes end
  function f:put(path,value)local bytes=objectJSON(value);self.decoded[bytes]=clone(value);return self:putRaw(path,bytes) end
  if primary~=nil then f:put('config.json',primary) end
  if backup~=nil then f:put('config.json.bak',backup) end
  local env=setmetatable({}, {__index=_G})
  env.print=function()end
  env.io={open=function(path,mode)
    if f.denyWrites and path=='config.json.tmp' and mode=='w' then return nil,'injected denied write' end
    return realIO.open(mapped(path),mode)
  end}
  env.os=setmetatable({remove=function(path)return realOS.remove(mapped(path))end,rename=function(a,b)
    if f.failInstall and a=='config.json.tmp' and b=='config.json' then return nil,'injected installation failure' end
    return realOS.rename(mapped(a),mapped(b))
  end},{__index=realOS})
  env.json={decode=function(bytes)assert(f.decoded[bytes],'unregistered real JSON fixture');return clone(f.decoded[bytes])end,
    encode=function(value)local bytes=objectJSON(value);f.decoded[bytes]=clone(value);return bytes end}
  env.registerForEvent=function(name,callback)f.events[name]=callback end
  env.Game={GetPlayer=function()return nil end}
  env.GetMod=function()return nil end
  env.ImGui={Begin=function()return true end,End=function()end,Separator=function()end,SameLine=function()end,
    Text=function(value)f.texts[#f.texts+1]=tostring(value)end,TextWrapped=function(value)f.texts[#f.texts+1]=tostring(value)end,
    RadioButton=function(label,active)if active then f.mode=label end;return false end,
    Button=function(label)if label==f.pressed then f.pressed=nil;return true end;return false end,
    InputText=function(label,value)return options.presetLabel or value,options.presetLabel~=nil end}
  local cache={}
  env.require=function(name)
    if name=='guardian' or name=='guardian_bridge' or name=='quest_milestones' then error('observer boundary excluded from focused config fixture') end
    if cache[name]then return cache[name]end
    local loaded=assert(loadfile(moduleDir..name..'.lua','t',env))()
    if name=='config_store' then
      local underlying=loaded
      loaded={load=function(path,validator)f.loads[#f.loads+1]={path=path,validator=validator};return underlying.load(path,validator)end,
        save=function(path,data,validator)f.saves[#f.saves+1]={path=path,data=clone(data),validator=validator};return underlying.save(path,data,validator)end}
    end
    cache[name]=loaded;return loaded
  end
  f.modules=cache
  function f:draw(pressed)
    self.texts={};self.mode=nil;self.pressed=pressed;self.events.onDraw()
    if pressed then check(self.pressed==nil,'public UI action did not occur: '..pressed) end
  end
  function f:line(prefix)
    for _,value in ipairs(self.texts)do if value:sub(1,#prefix)==prefix then return value end end
  end
  function f:lastConfigSave()
    for i=#self.saves,1,-1 do if self.saves[i].path=='config.json' then return self.saves[i] end end
  end
  function f:configValidator()
    for _,row in ipairs(self.loads)do if row.path=='config.json' then return row.validator end end
  end
  if options.beforeInit then options.beforeInit(f) end
  assert(loadfile(moduleDir..'init.lua','t',env))();f.events.onInit();f.events.onOverlayOpen();f:draw()
  return f
end

-- Intended baseline failure: malformed known field must not mask the valid backup.
local recovered=fixture({mode='broken',tone=2},{mode=3,tone=0,allowCombat=true,deferredEnabled=true})
check(recovered.mode=='Smart (experimental)' and recovered:line('Selected:')=='Selected: Professional',
  'NLSR-MAIN-CONFIG-RECOVERY: invalid primary masked valid backup at actual init load')
check(recovered:raw('config.json')==objectJSON({mode='broken',tone=2}) and recovered:raw('config.json.bak')==objectJSON({mode=3,tone=0,allowCombat=true,deferredEnabled=true}),'recovery load must not rewrite either saved file')
local validator=recovered:configValidator()
check(type(validator)=='function','actual init must provide a main-settings validator')
local backupBytes=recovered:raw('config.json.bak')
recovered:draw('Disable notifications##nls_notifications')
local saved=recovered:lastConfigSave()
check(saved and saved.validator==validator,'saveConfig must pass the same validator used by loadConfig')
check(saved.data.mode==3 and saved.data.tone==0 and saved.data.allowCombat==true,'save uses recovered runtime values')
check(recovered:raw('config.json.bak')==backupBytes,'normal save must preserve sole validated backup')
local primaryBefore=recovered:raw('config.json');local bakBefore=recovered:raw('config.json.bak')
local writeOK=pcall(recovered.modules.config_store.save,'config.json',{mode='invalid-new-write'},validator)
check(not writeOK,'new semantically invalid write must be refused')
check(recovered:raw('config.json')==primaryBefore and recovered:raw('config.json.bak')==bakBefore and recovered:raw('config.json.tmp')==nil,'invalid write refused before filesystem mutation')

local booleanFields={'allowCombat','allowVehicle','notificationsEnabled','statusNotificationsEnabled','diagnosticDetails',
  'deferredEnabled','guardianEnabled','autosaveEnabled','autosaveExploration','autosavePostCombat','autosaveVehicleExit',
  'autosaveQuestMilestone','autosaveApartmentEntry','dfNotifyVehicleSleep','dfNotifyAddiction','dfNotifyStarvation','dfNotifyDehydration'}
local integerBounds={deferredTTL={1,120},deferredCooldownSeconds={0,600},autosaveIntervalSeconds={60,1800},autosaveCooldownSeconds={30,600}}
local function valid(value)local ok,result=pcall(validator,value);return ok and result~=nil and result~=false end
check(valid({}),'empty legacy object accepted')
check(valid({obsoleteSetting={legacy='ignored'},dfBlockVehicleSleep='obsolete-invalid-value'}),'unknown/obsolete string fields remain ignored')
check(valid({mode=1.9,tone=0.9}),'finite in-range legacy fractional selectors remain accepted')
check(valid({schema_version=2,mode=1}),'main config has no schema marker; unknown schema_version must stay ignored')
for _,value in ipairs({false,0,'object',function()end})do check(not valid(value),'non-object root rejected')end
check(not valid(setmetatable({mode=1},{})),'metatable root rejected')
check(not valid({[1]=true}),'non-string root key rejected')
for _,key in ipairs(booleanFields)do
  check(valid({[key]=true}) and valid({[key]=false}),'boolean endpoints accepted: '..key)
  for _,value in ipairs({0,1,'false',{},function()end,0/0,math.huge,-math.huge})do check(not valid({[key]=value}),'known boolean invalid value refused: '..key)end
  local f=fixture({mode=0,tone=2,[key]='invalid'},{mode=3,tone=0})
  check(f.mode=='Smart (experimental)' and f:line('Selected:')=='Selected: Professional','known boolean invalid primary falls back: '..key)
end
for key,bounds in pairs(integerBounds)do
  check(valid({[key]=bounds[1]}) and valid({[key]=bounds[2]}),'integer bounds accepted: '..key)
  for _,value in ipairs({bounds[1]-1,bounds[2]+1,bounds[1]+0.25,0/0,math.huge,-math.huge,'30',{},false})do
    check(not valid({[key]=value}),'invalid exact integer bound refused: '..key)
  end
  local f=fixture({mode=0,tone=2,[key]=bounds[1]+0.25},{mode=3,tone=0})
  check(f.mode=='Smart (experimental)' and f:line('Selected:')=='Selected: Professional','invalid numeric primary falls back: '..key)
end
for key,high in pairs({mode=3,tone=2})do
  for _,value in ipairs({0,high,0.25,high-0.25})do check(valid({[key]=value}),'legacy selector finite in-range accepted: '..key)end
  for _,value in ipairs({-0.1,high+0.1,0/0,math.huge,-math.huge,{},'1',false})do check(not valid({[key]=value}),'bad selector rejected: '..key)end
end
local legacy=fixture({mode=1.9,tone=0.9,obsoleteKey='ignored',dfBlockStarvation={old=true}},{mode=3,tone=2})
check(legacy.mode=='Immersion' and legacy:line('Selected:')=='Selected: Professional','healthy partial legacy primary preferred and selectors floor')
legacy:draw('Disable notifications##nls_notifications')
check(legacy:lastConfigSave().data.mode==1 and legacy:lastConfigSave().data.tone==0,'actual saved selectors retain old flooring behavior')
local partial=fixture({allowCombat=true},{mode=3,tone=0})
check(partial.mode=='Immersion' and partial:line('Selected:')=='Selected: Sarcastic','missing options keep existing defaults rather than taking backup')
partial:draw('Disable notifications##nls_notifications')
check(partial:lastConfigSave().data.allowCombat==true,'legacy partial option preserved')

-- Corruption/semantic corruption plus replacement failure retains the valid recovery file.
for _,malformed in ipairs({'semantic','syntax'})do
 local f=fixture({mode='broken',tone=2},{mode=3,tone=0,deferredEnabled=true})
 if malformed=='syntax' then f:putRaw('config.json','{truncated') end
 local before=f:raw('config.json.bak');f.failInstall=true
 f:draw('Disable notifications##nls_notifications');f:draw()
 check(f:raw('config.json.bak')==before,'failed replacement preserves sole valid backup: '..malformed)
 check(f:line('Config:') and f:line('Config:'):find('Save failed:',1,true),'UI reports failed installation: '..malformed)
end

-- Named preset application uses the same main-file validator and commits no runtime on failure.
local p=fixture({mode=3,tone=0,deferredEnabled=true},{mode=3,tone=0,deferredEnabled=true},{presetLabel='NEXT'})
p:put('profile-settings.json',{schema_version=1,profiles={NEXT={mode=0,tone=2,deferredEnabled=false}}})
p:draw('Queue test request (30s)##nls_queue')
local queued=p:line('Queue:');check(queued and queued:find('pending #1',1,true),'actual dry-run queue was seeded through UI')
p:put('config.json',{mode='broken',tone=2});local oldBackup=p:raw('config.json.bak');p.failInstall=true
p:draw('Load named preset##nls_profile_load');p:draw()
local presetSave=p:lastConfigSave()
check(presetSave and presetSave.validator==p:configValidator(),'preset application must use same main validator as load and save')
check(p.mode=='Smart (experimental)' and p:line('Selected:')=='Selected: Professional','failed preset persistence preserves mode and tone')
check(p:line('Queue:')==queued,'failed preset persistence preserves exact pending preview request')
check(p:raw('config.json.bak')==oldBackup,'failed preset install preserves valid backup')
check(p:line('Preset:')=='Preset: Preset not applied: write_failed','failed preset visibly rejected')

print('PASS independent main-config runtime: '..checks..' assertions across '..fixtureCount..' real-disk init fixtures')
