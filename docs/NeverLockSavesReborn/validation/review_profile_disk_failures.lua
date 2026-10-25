-- Real config_store file replacements; only CET JSON and failing OS operations doubled.
local dir=assert(arg[1],'profiles module dir required')
local config=assert(arg[2],'config_store.lua required')
local fixture=assert(arg[3],'existing isolated fixture dir required')
local M=dofile(dir..'/profiles.lua')
local n=0
local function eq(a,b,label) n=n+1;assert(a==b,label..': '..tostring(a)..' != '..tostring(b)) end
local function clone(x) if type(x)~='table' then return x end;local r={};for k,v in pairs(x) do r[k]=clone(v) end;return r end
local path=fixture..'/independent-bank.json'
local fault=nil
local textMap,counter={},0
local jsonBoundary={encode=function(value)
 if fault=='encode' then error('private encoder failure') end
 counter=counter+1;local text='{"fixture_id":'..counter..'}';textMap[text]=clone(value);return text
end,decode=function(text) assert(textMap[text],'bad JSON fixture');return clone(textMap[text]) end}
local ioBoundary={open=function(name,mode)
 if name==path..'.tmp' and mode=='w' then
  if fault=='open' then return nil,'private disk failure' end
  local real,err=io.open(name,mode);if not real then return nil,err end
  if fault=='write' then return {write=function() return nil,'private write failure' end,close=function() return real:close() end} end
  if fault=='close' then return {write=function(_,text) return real:write(text) end,close=function() real:close();return nil,'private close failure' end} end
  return real
 end
 return io.open(name,mode)
end}
local osBoundary={remove=os.remove,rename=function(source,dest)
 if fault=='rotate' and source==path then return nil,'private rotate failure' end
 if (fault=='install' or fault=='install_restore') and source==path..'.tmp' then return nil,'private install failure' end
 if fault=='install_restore' and source==path..'.bak' then return nil,'private restore failure' end
 return os.rename(source,dest)
end}
local env=setmetatable({json=jsonBoundary,io=ioBoundary,os=osBoundary},{__index=_G})
local store=assert(loadfile(config,'t',env))()
local function exists(name) local f,_,code=io.open(name,'r');if f then assert(f:close());return true end;if code==2 then return false end;return nil end
local function raw(name) local f=io.open(name,'r');if not f then return nil end;local value=f:read('*a');f:close();return value end
for _,kind in ipairs({'encode','open','write','close','rotate','install','install_restore'}) do
 fault=nil
 for _,suffix in ipairs({'','.bak','.tmp'}) do os.remove(path..suffix) end
 local api=M.new(store,path,exists)
 eq(api:save('V',{mode=3,tone=2,autosaveEnabled=false}),true,'seed real disk for '..kind)
 local original=assert(raw(path))
 fault=kind
 local ok,reason=api:save('V',{mode=0,tone=0,autosaveEnabled=true})
 eq(ok,nil,'disk failure refuses update '..kind);eq(reason,'write_failed','failure reason sanitized '..kind)
 fault=nil
 local current=api:get('V')
 eq(type(current),'table','original settings recoverable '..kind)
 eq(current.mode,3,'mode never partially updated '..kind)
 eq(current.tone,2,'tone never partially updated '..kind)
 eq(current.autosaveEnabled,false,'scheduler never partially enabled '..kind)
 if kind=='install_restore' then
  eq(raw(path),nil,'failed rollback leaves no claimed primary')
  eq(raw(path..'.bak'),original,'last valid backup preserved for load')
 else
  eq(raw(path),original,'old primary bytes preserved '..kind)
 end
end
for _,suffix in ipairs({'','.bak','.tmp'}) do os.remove(path..suffix) end
print('PASS independent profile disk failures: '..n..' assertions; seven actual replacement/IO boundaries')
