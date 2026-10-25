-- CET provides json.encode/decode and sandboxed io/os; no loadfile/dumpfile helpers.
local M={}
local function accepted(value,validator)
  if validator==nil then return true end
  local ok,valid,code=pcall(validator,value)
  if ok and valid~=nil and valid~=false then return true end
  if ok and (code=='unsupported_schema' or code=='invalid_bank') then return nil,code end
  return nil,'Invalid configuration schema'
end
local function read(path,validator)
  local f,err=io.open(path,'r')
  if not f then return nil,err end
  local text,readError=f:read('*a')
  local closed,closeError=f:close()
  if not text or not closed then return nil,readError or closeError end
  local ok,value=pcall(json.decode,text)
  if ok and type(value)=='table' then
    local valid,code=accepted(value,validator)
    if valid then return value end
    return nil,code
  end
  return nil,'Invalid JSON configuration'
end
function M.load(path,validator)
  local data,code=read(path,validator)
  if data then return data end
  -- A newer schema is not corruption and must never be silently downgraded.
  if code=='unsupported_schema' then return nil,code end
  -- Recover an interrupted replacement; never execute config as Lua.
  return read(path..'.bak',validator)
end
function M.save(path,data,validator)
  local valid=accepted(data,validator)
  assert(valid,'Configuration schema validation failed')
  if validator~=nil then
    local _,primaryCode=read(path,validator)
    local _,backupCode=read(path..'.bak',validator)
    assert(primaryCode~='unsupported_schema' and backupCode~='unsupported_schema','Unsupported configuration schema; migration required')
  end
  -- Encode before opening any file, preserving the existing config on encoder errors.
  local text=json.encode(data)
  assert(type(text)=='string','JSON encoder did not return text')
  local temp=path..'.tmp'
  local f,err=io.open(temp,'w')
  assert(f,err)
  local ok,writeError=f:write(text)
  local closed,closeError=f:close()
  assert(ok and closed,writeError or closeError or 'Configuration write failed')
  local old=io.open(path,'r')
  if old then
    assert(old:close())
    local primary,primaryCode=read(path,validator)
    local backup,backupCode=read(path..'.bak',validator)
    assert(primaryCode~='unsupported_schema' and backupCode~='unsupported_schema','Unsupported configuration schema; migration required')
    if not primary and backup then
      -- A recovered configuration must keep its only validated recovery copy.
      -- The replacement is fully written above; leave the backup intact if
      -- installing it fails, rather than rotating corrupt primary bytes over it.
      assert(os.remove(path))
      old=nil
    else
      local backup=io.open(path..'.bak','r')
      if backup then assert(backup:close()); assert(os.remove(path..'.bak')) end
      assert(os.rename(path,path..'.bak'))
    end
  end
  local moved,moveError=os.rename(temp,path)
  if not moved then
    if old then
      local restored,restoreError=os.rename(path..'.bak',path)
      assert(restored,'Config install failed: '..tostring(moveError)..'; recovery failed: '..tostring(restoreError))
    end
    error(moveError or 'Configuration replacement failed')
  end
  return true
end
return M
