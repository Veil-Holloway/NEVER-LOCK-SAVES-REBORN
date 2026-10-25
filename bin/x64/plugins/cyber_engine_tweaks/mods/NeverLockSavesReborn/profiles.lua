-- Explicit named settings presets. Identity is manual: never auto-select a character.
-- File operations are supplied by config_store and an existence boundary callback.
local M={}
local defaults={mode=1,allowCombat=false,allowVehicle=false,tone=1,
  notificationsEnabled=true,diagnosticDetails=true,deferredEnabled=false,
  guardianEnabled=false,statusNotificationsEnabled=false,autosaveApartmentEntry=false,
  dfNotifyVehicleSleep=true,dfNotifyAddiction=true,
  dfNotifyStarvation=true,dfNotifyDehydration=true,deferredTTL=30,deferredCooldownSeconds=0,
  autosaveEnabled=false,autosaveExploration=true,autosavePostCombat=true,
  autosaveVehicleExit=true,autosaveQuestMilestone=false,autosaveIntervalSeconds=300,autosaveCooldownSeconds=60}
local ranges={mode={0,3},tone={0,2},deferredTTL={1,120},deferredCooldownSeconds={0,600},
  autosaveIntervalSeconds={60,1800},autosaveCooldownSeconds={30,600}}
local function plain(value) return type(value)=='table' and getmetatable(value)==nil end
local function integer(value,low,high)
  return type(value)=='number' and value==value and value>=low and value<=high and value==math.floor(value)
end
local function labelOK(value)
  return type(value)=='string' and #value>=1 and #value<=32 and value:match('^[A-Za-z0-9_-]+$')~=nil
end
local function copy(settings) local result={};for key,value in pairs(settings) do result[key]=value end;return result end
function M.defaults() return copy(defaults) end
function M.validate(settings)
  if not plain(settings) then return nil,'invalid_settings' end
  local result=copy(defaults)
  for key,value in pairs(settings) do
    if defaults[key]==nil then return nil,'invalid_settings' end
    local range=ranges[key]
    if range then
      if not integer(value,range[1],range[2]) then return nil,'invalid_settings' end
    elseif type(value)~='boolean' then return nil,'invalid_settings' end
    result[key]=value
  end
  return result
end
-- Explicit migration only; obsolete restrictions/unknown external keys are ignored.
function M.migrate_legacy(settings)
  if not plain(settings) then return nil,'invalid_settings' end
  local known={}
  for key in pairs(defaults) do if settings[key]~=nil then known[key]=settings[key] end end
  return M.validate(known)
end
function M.validate_bank(value)
  if plain(value) and type(value.schema_version)=='number' and value.schema_version>1 then return nil,'unsupported_schema' end
  if not plain(value) or value.schema_version~=1 or not plain(value.profiles) then return nil,'invalid_bank' end
  for key in pairs(value) do if key~='schema_version' and key~='profiles' then return nil,'invalid_bank' end end
  local result={schema_version=1,profiles={}}
  local count=0
  for label,settings in pairs(value.profiles) do
    count=count+1
    if count>16 or not labelOK(label) then return nil,'invalid_bank' end
    local valid=M.validate(settings)
    if not valid then return nil,'invalid_bank' end
    result.profiles[label]=valid
  end
  return result
end
function M.new(store,path,exists)
  assert(type(store)=='table' and type(store.load)=='function' and type(store.save)=='function','config_store boundary required')
  assert(type(path)=='string' and #path>0 and #path<=256,'profile bank path required')
  local bank=nil
  local api={}
  local function missing()
    if type(exists)~='function' then return false end
    for _,suffix in ipairs({'','.bak','.tmp'}) do
      local ok,value=pcall(exists,path..suffix)
      if not ok or value~=false then return false end
    end
    return true
  end
  function api:load()
    bank=nil -- A read failure must not leave stale settings available for application.
    local ok,value,loadCode=pcall(store.load,path,M.validate_bank)
    if not ok then return nil,'read_failed' end
    if value==nil then
      if loadCode=='unsupported_schema' then return nil,loadCode end
      if missing() then bank={schema_version=1,profiles={}};return true,'empty' end
      return nil,loadCode=='invalid_bank' and 'invalid_bank' or 'unreadable_bank'
    end
    local validated,validationCode=M.validate_bank(value)
    if not validated then return nil,validationCode or 'invalid_bank' end
    bank=validated
    return true,'loaded'
  end
  function api:list()
    if not self:load() then return {} end
    local labels={};for label in pairs(bank.profiles) do labels[#labels+1]=label end
    table.sort(labels)
    return labels
  end
  function api:get(label)
    if not labelOK(label) then return nil,'invalid_label' end
    local ok,code=self:load();if not ok then return nil,code end
    if not bank.profiles[label] then return nil,'profile_not_found' end
    return copy(bank.profiles[label])
  end
  function api:save(label,settings)
    if not labelOK(label) then return nil,'invalid_label' end
    local valid=M.validate(settings);if not valid then return nil,'invalid_settings' end
    local ok,code=self:load();if not ok then return nil,code end
    local nextBank=assert(M.validate_bank(bank))
    if not nextBank.profiles[label] then
      local count=0;for _ in pairs(nextBank.profiles) do count=count+1 end
      if count>=16 then return nil,'bank_full' end
    end
    nextBank.profiles[label]=valid
    local wrote,accepted=pcall(store.save,path,nextBank,M.validate_bank)
    if not wrote or accepted~=true then return nil,'write_failed' end
    bank=nextBank
    return true,'saved'
  end
  return api
end
return M
