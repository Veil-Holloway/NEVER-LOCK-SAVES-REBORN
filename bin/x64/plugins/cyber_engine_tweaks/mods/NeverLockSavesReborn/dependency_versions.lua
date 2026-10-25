-- Pure on-demand dependency self-report adapter. No Game/IO/global API access.
-- Values identify what a loaded API reports, never compatibility or save safety.
local M={}
local keys={'cet','codeware','nativeSettings','redscript','red4ext','darkFuture'}
local sources={cet='cet_get_version',codeware='codeware_version',nativeSettings='native_settings_version'}
local function plain(value) return type(value)=='table' and getmetatable(value)==nil end
local function safeVersion(value)
  if type(value)=='string' and #value<=40 and value:match('^%d+[A-Za-z0-9._+-]*$') then return value end
end
local function normalize(key,value)
  if key=='cet' then
    if type(value)~='string' or #value>41 then return nil end
    if value:sub(1,1)=='v' then value=value:sub(2) end
    return safeVersion(value)
  elseif key=='codeware' then
    return safeVersion(value)
  end
  -- Native Settings exports a numeric declaration, not a three-part package ID.
  -- This controlled scalar format cannot invoke an arbitrary __tostring method.
  if type(value)~='number' or value~=value or value<0 or value>1000000 then return nil end
  if value==0 then return '0' end
  local text=string.format('%.14g',value)
  if #text<=40 and (text:match('^%d+$') or text:match('^%d+%.%d+$')) then return text end
end
function M.sample(readers)
  local input=plain(readers) and readers or {}
  local result={versions={},evidence={}}
  for _,key in ipairs(keys) do
    local source=sources[key]
    local value,status='unknown',source and 'unavailable' or 'not_supported'
    if source then
      local reader=rawget(input,key)
      if type(reader)=='function' then
        local ok,raw=pcall(reader)
        if not ok then status='read_failed'
        elseif raw~=nil then
          local normalized=normalize(key,raw)
          if normalized then value,status=normalized,'observed' else status='invalid' end
        end
      end
    end
    result.versions[key]=value
    result.evidence[key]={status=status,source=source or 'none'}
  end
  return result
end
return M
