-- Independently authored adversarial public-boundary checks.
local module=assert(arg[1],'profiles.lua path required')
local M=dofile(module)
local n=0
local function eq(actual,expected,label)
 n=n+1;assert(actual==expected,label..': '..tostring(actual)..' != '..tostring(expected))
end
local function clone(x) if type(x)~='table' then return x end;local r={};for k,v in pairs(x) do r[k]=clone(v) end;return r end
local disk=nil
local saves=0
local writesFail=false
local store={load=function() return clone(disk) end,
 save=function(_,value) saves=saves+1;if writesFail then error('private /path failure') end;disk=clone(value);return true end}
local api=M.new(store,'profile-settings.json',function() return false end)
for _,label in ipairs({'../outside','..','a/b','a\\b','C:drive','/abs','x\000y','line\nfeed',' space','space ',string.rep('x',33),'Ã©'}) do
 local before=saves
 local ok,code=api:save(label,{mode=2})
 eq(ok,nil,'label rejected');eq(code,'invalid_label','stable label error');eq(saves,before,'invalid label no write')
end
for _,key in ipairs({'mode','deferredTTL','deferredCooldownSeconds','autosaveIntervalSeconds','autosaveCooldownSeconds'}) do
 for _,value in ipairs({math.huge,-math.huge,0/0,-1,1.5,'1',true,{},function() end}) do
  local ok,reason=M.validate({[key]=value})
  eq(ok,nil,'malformed numeric field '..key);eq(reason,'invalid_settings','stable numeric error')
 end
end
local metatable=setmetatable({mode=3},{__index=function() error('should not run') end,__pairs=function() error('should not run') end})
eq(M.validate(metatable),nil,'settings metatable rejected before access')
eq(M.migrate_legacy(metatable),nil,'migration metatable rejected before access')
eq(M.validate_bank(setmetatable({},{__index=function() error('should not run') end})),nil,'root bank metatable rejected')
eq(M.validate_bank({schema_version=1,profiles=setmetatable({},{__pairs=function() error('should not run') end})}),nil,'profile-map metatable rejected')
eq(M.validate_bank({schema_version=1,profiles={A=metatable}}),nil,'nested settings metatable rejected')
for _,value in ipairs({0,2,math.huge,-math.huge,0/0,'1',true,{}}) do
 eq(M.validate_bank({schema_version=value,profiles={}}),nil,'invalid schema rejected')
end
eq(M.validate_bank({schema_version=1,profiles={[1]={mode=1}}}),nil,'array bank rejected')
eq(M.validate_bank({schema_version=1,profiles={A={mode=2},B={mode='2'}}}),nil,'whole mixed bank rejected')
local defaults=M.defaults();defaults.mode=0;defaults.guardianEnabled=true
eq(M.defaults().mode,1,'default object isolated');eq(M.defaults().guardianEnabled,false,'default telemetry off')
eq(api:save('V_Main',{mode=3,tone=2,autosaveEnabled=true}),true,'explicit bank save')
local before=clone(disk)
local read=assert(api:get('V_Main'));read.mode=0
eq(api:get('V_Main').mode,3,'get copy isolated')
writesFail=true
local ok,code=api:save('V_Main',{mode=1})
eq(ok,nil,'failed write not success');eq(code,'write_failed','private write message stripped')
eq(api:get('V_Main').mode,3,'failed write no new cached settings')
eq(disk.profiles.V_Main.mode,before.profiles.V_Main.mode,'failed write preserves provider data')
writesFail=false
disk={schema_version=1,profiles={V_Main={mode=1},Other={mode='bad'}}}
eq(api:get('V_Main'),nil,'corrupt sibling prevents partial bank application')
local oldSaves=saves
eq(api:save('A',{mode=1}),nil,'corrupt bank not overwritten');eq(saves,oldSaves,'corrupt bank not saved')
local cyclic={schema_version=1,profiles={}};cyclic.profiles.A=cyclic
eq(M.validate_bank(cyclic),nil,'cyclic malformed bank rejected')
local hidden=setmetatable({mode=3},{__metatable='opaque'})
eq(M.validate(hidden),nil,'opaque metatable rejected')
print('PASS independent profiles: '..n..' assertions')
