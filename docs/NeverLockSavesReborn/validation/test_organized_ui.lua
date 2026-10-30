-- Actual UI modules; ImGui and Native Settings are controlled boundaries.
local root=assert(arg[1]);local dir=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
local catalog=assert(loadfile(dir..'settings_ui.lua'))()
local overlay=assert(loadfile(dir..'overlay_ui.lua'))()
local native=assert(loadfile(dir..'native_settings_ui.lua'))()
local n=0
local function check(value,label)n=n+1;assert(value,label)end
local function settings()local values={};for _,o in ipairs(catalog.options)do values[o.key]=o.default end;return values end
for _,o in ipairs(catalog.options)do
  check(catalog.valid(o.key,o.default),'default valid '..o.key)
  check(not catalog.valid(o.key,nil),'nil invalid '..o.key)
  check(not catalog.valid(o.key,{}),'table invalid '..o.key)
  if o.kind=='int' then for _,v in ipairs({o.min-1,o.max+1,1/0,0/0,o.min+.5})do check(not catalog.valid(o.key,v),'invalid integer '..o.key)end end
end
check(not catalog.valid('invented',true),'unknown key rejected')
check(catalog.get('allowCombat')==nil and catalog.get('allowVehicle')==nil,'no active bypass controls')
local pageNames={'Overview','Saving','Autosave','Messages','Presets','Diagnostics'}
local function fixture()
  local h={tab='Overview',begins=0,ends=0,tabBegins=0,tabEnds=0,itemBegins=0,itemEnds=0,changes={},calls={},texts={},controls={},buttons={},collapsed=false}
  h.values=settings()
  local actions=setmetatable({change=function(k,v)h.changes[#h.changes+1]={k,v};h.values[k]=v end,
    guardianDetails=function()return {status='off',available=true,rows={}}end,
    diagnostics=function()return {{'Example','unknown'}}end}, {__index=function(_,k)return function(...)h.calls[k]=(h.calls[k]or 0)+1;if h.throw==k then error('injected action failure')end end end})
  local function labelKey(label)return label:match('##nls_setting_(.+)')end
  h.ui={Begin=function()h.begins=h.begins+1;return not h.collapsed end,End=function()h.ends=h.ends+1 end,
    Text=function(t)h.texts[#h.texts+1]=t end,TextWrapped=function(t)h.texts[#h.texts+1]=t end,Separator=function()end,
    BeginTabBar=function()h.tabBegins=h.tabBegins+1;return true end,EndTabBar=function()h.tabEnds=h.tabEnds+1 end,
    BeginTabItem=function(name)if name==h.tab then h.itemBegins=h.itemBegins+1;return true end;return false end,
    EndTabItem=function()h.itemEnds=h.itemEnds+1 end,CollapsingHeader=function()return true end,
    Checkbox=function(label,value)local key=labelKey(label);if key then h.controls[key]=true end;if h.edit==key then h.edit=nil;return not value,true end;return value,false end,
    SliderInt=function(label,value,low,high)local key=labelKey(label);h.controls[key]=true;check(low<=high,'slider bounds');if h.edit==key then h.edit=nil;return h.editValue,true end;return value,false end,
    RadioButton=function(label,active)if h.radio==label then h.radio=nil;return true end;return false end,
    IsItemDeactivatedAfterEdit=function()return h.deactivated==true end,
    InputText=function(_,v)return v,false end,
    Button=function(label)h.buttons[label]=true;if h.press==label then h.press=nil;return true end;return false end}
  h.instance=overlay.new(catalog,actions)
  function h:draw()self.instance:draw(self.ui,{title='Reborn',version='TEST',settings=self.values,profileLabels={},profileLabel='Default',queuePending=self.pending,queueRemaining='30',queueStatus=self.pending and 'Player request pending' or 'Idle',queueGate='Idle',queueEvent='None',queueLastOutcomeState='Unknown',queueLastOutcome='No completed request in this runtime',queueRetention='none',autosave='Disabled',questObserver='Unavailable',darkFuture='Unavailable',nativeStatus='Unavailable',toneStatus='Unknown',statusRuntime='Disabled',profileStatus='None',reportStatus='None',bridge='Ready',intro='Complete',configStatus='Configuration written'})end
  function h:balanced()return self.begins==self.ends and self.tabBegins==self.tabEnds and self.itemBegins==self.itemEnds end
  return h
end
for _,page in ipairs(pageNames)do
  local h=fixture();h.tab=page;h:draw();check(h:balanced(),'balanced '..page)
  check(#h.changes==0,'drawing never changes settings '..page)
  check(h.calls.preview==nil and h.calls.cancel==nil and h.calls.exportSupport==nil,'drawing never queues/cancels/exports '..page)
end
local h=fixture();h.tab='Saving';h:draw();check(h.controls.deferredEnabled and not h.controls.autosaveEnabled,'saving page only saving controls')
h.edit='deferredEnabled';h:draw();check(#h.changes==1 and h.values.deferredEnabled==true,'checkbox routes one change')
h.edit='deferredTTL';h.editValue=55;h:draw();check(#h.changes==1,'slider drag draft not disk action')
for _=1,20 do h:draw()end;check(#h.changes==1,'no repeated draft writes')
h.press='Apply##nls_apply_deferredTTL';h:draw();check(#h.changes==2 and h.values.deferredTTL==55,'explicit commit once')
h.edit='deferredTTL';h.editValue=70;h:draw();h.values.deferredTTL=80;h:draw();check(h.instance.drafts.deferredTTL==nil,'external settings invalidate draft')
h.edit='deferredTTL';h.editValue=71;h.deactivated=true;h:draw();h:draw();check(#h.changes==3 and h.values.deferredTTL==71,'deactivation one write')
h.deactivated=false;h.edit='deferredTTL';h.editValue=72;h:draw();h.press='Discard edit##nls_discard_deferredTTL';h:draw();check(h.values.deferredTTL==71 and not h.instance.drafts.deferredTTL,'discard no write')
h.pending=true;h.press='Cancel queued request##nls_cancel_saving';h:draw();check(h.calls.cancel==1,'cancel explicit action')
h.collapsed=true;local before=h.tabBegins;h:draw();check(h:balanced()and h.tabBegins==before,'collapsed Begin still End')
for _,case in ipairs({{'Presets','Save current preset##nls_profile_save','saveProfile'}, {'Diagnostics','Export support report##nls_support_export','exportSupport'}})do
  local q=fixture();q.tab=case[1];q.throw=case[3];q.press=case[2];q:draw();check(q:balanced(),'action failure unwinds stacks');check(q.calls.uiError==1,'error observable once');q.press=case[2];q:draw();check(q.calls.uiError==1,'same error not spammed')
end
local q=fixture();q.ui.BeginTabBar=nil;q.ui.BeginTabItem=nil;q:draw();check(q:balanced(),'no tab binding fallback balanced');check(q.controls.deferredEnabled and q.controls.autosaveEnabled,'fallback retains grouped controls')
local q=fixture();q.tab='Diagnostics';q.pending=true;q.values.deferredEnabled=true;q.press='Queue dry-run test##nls_queue';q:draw();check(q.calls.preview==1,'dry run action explicit')
q.values.diagnosticDetails=false;q:draw();check(q.calls.logSnapshot==nil,'hidden debug action not run')

local function nativeFixture(range,options)
  options=options or {};local values=settings();local calls=0;local seen={};local registrations=0;local logs={}
  local adapter;local api={addTab=function()registrations=registrations+1 end,addSubcategory=function()end}
  local function add(label,kind,value,default,cb)
    seen[label]={kind=kind,value=value,default=default,callback=cb};if options.callbackOnRegister then cb(value)end
    if options.nilHandle then return nil end;return label
  end
  api.addSwitch=function(_,label,_,v,d,cb)return add(label,'bool',v,d,cb)end
  api.addSelectorString=function(_,label,_,choices,v,d,cb)return add(label,'selector',v,d,cb)end
  if range then api.addRangeInt=function(_,label,_,low,high,step,v,d,cb)check(step==1 and low<=v and v<=high,'range arguments');return add(label,'range',v,d,cb)end end
  api.setOption=function(handle,v)seen[handle].value=v;seen[handle].callback(v)end
  adapter=native.new(catalog,function()if options.throwRead then error('read failed')end;return values end,
    function(key,v)calls=calls+1;values[key]=v;adapter:sync()end,function(s)logs[#logs+1]=s end)
  adapter:register(function(name)check(name=='nativeSettings','exact dependency');return api end)
  return {adapter=adapter,values=values,seen=seen,options=options,calls=function()return calls end,registrations=function()return registrations end,api=api}
end
for _,range in ipairs({false,true})do
  local f=nativeFixture(range,{callbackOnRegister=true});check(f.calls()==0,'registration callbacks suppressed')
  f.adapter:sync();check(f.calls()==0,'setOption feedback suppressed')
  f.adapter:register(function()return f.api end);check(f.registrations()==1,'repeated onInit no duplicate registration')
  for _,o in ipairs(catalog.options)do
    local c=f.seen[o.label];check(c~=nil,'registered '..o.key)
    local raw
    if o.kind=='bool' then raw=not o.default elseif o.kind=='enum' then raw=1 else raw=o.max end
    local expected=raw
    if o.kind=='enum' then expected=0 elseif o.kind=='int' and not range then raw=o.max-o.min+1;expected=o.max end
    local before=f.calls();c.callback(raw);check(f.calls()==before+1 and f.values[o.key]==expected,'callback mapping '..o.key)
    local wantDefault=o.default
    if o.kind=='enum' then wantDefault=wantDefault+1 elseif o.kind=='int' and not range then wantDefault=wantDefault-o.min+1 end
    check(c.default==wantDefault,'documented default '..o.key)
    local before=f.calls();c.callback({});check(f.calls()==before,'invalid callback refused '..o.key)
  end
  f.options.throwRead=true;f.adapter:sync();check(not f.adapter.syncing and f.adapter.status:find('read failed'),'read error releases sync guard')
  f.options.throwRead=false;f.adapter:sync();check(not f.adapter.syncing,'subsequent sync recovers')
end
local f=nativeFixture(true,{nilHandle=true});check(f.adapter.failed and not f.adapter.api,'missing handle reported unavailable')
local before=f.calls();for _,c in pairs(f.seen)do c.callback(true)end;check(f.calls()==before,'partial registration callbacks inert')
local f=native.new(catalog,settings,function()error('unexpected')end,function()end);f:register(function()return nil end);check(not f.registered and not f.api,'absent Native Settings optional')
print('PASS '..n..' actual-module UI assertions. Headless boundary doubles; no live ImGui/CET rendering.')
