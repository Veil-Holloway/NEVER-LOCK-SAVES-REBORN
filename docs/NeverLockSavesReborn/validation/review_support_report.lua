-- Independent adversarial malformed inputs; output can only contain bounded scalars.
local dir=assert(arg[1],'module directory required')
package.path=dir..'/?.lua;'..package.path
local M=require('support_report')
local n=0
local function eq(actual,expected,label)
 n=n+1;assert(actual==expected,label..': '..tostring(actual)..' != '..tostring(expected))
end
local function scalarTree(value,depth,seen)
 depth=depth or 0;seen=seen or {}
 assert(depth<=8,'output depth bounded')
 local kind=type(value)
 assert(kind=='table' or kind=='string' or kind=='number' or kind=='boolean','output is JSON compatible')
 if kind=='table' then
  assert(getmetatable(value)==nil,'no output metatable')
  assert(not seen[value],'no output cycles');seen[value]=true
  local count=0
  for k,v in pairs(value) do count=count+1;assert(type(k)=='string' or type(k)=='number','safe keys');scalarTree(v,depth+1,seen) end
  assert(count<=32,'object/array bound')
  seen[value]=nil
 elseif kind=='number' then assert(value==value and value~=math.huge and value~=-math.huge,'finite JSON number')
 elseif kind=='string' then assert(#value<=160,'string bounds') end
end
local poison=setmetatable({secret='do not export'}, {__index=function() error('getter ran') end,__pairs=function() error('pairs ran') end,__len=function() error('len ran') end})
local values={false,true,0,-1,0/0,math.huge,-math.huge,'/private/SECRET',function() error('executed') end,poison}
for _,field in ipairs({'versions','facts','sensors','queue','darkFuture','guardian','autosave','errors','settings'}) do
 for _,value in ipairs(values) do
  local ok,result=pcall(M.build,{[field]=value})
  eq(ok,true,'malformed nested field never throws '..field)
  scalarTree(result)
 end
end
local nested={guardian={records={}},errors={}}
for i=1,5000 do
 nested.guardian.records[i]={source=poison,phase=poison,reason=poison,id=poison,serial=poison,session=poison}
 nested.errors[i]=poison
end
local result=M.build(nested)
eq(#result.guardian.records,12,'records bounded after malformed rows')
eq(#result.latest_failures,8,'errors bounded after malformed values')
for _,row in ipairs(result.guardian.records) do
 eq(row.id,'unknown','bad ID redacted');eq(row.source,'unknown','bad source redacted')
 eq(row.write_status,'Unknown','never promotes write');eq(row.reload_status,'Unknown','never promotes reload')
end
scalarTree(result)
local cycle={};cycle.queue=cycle;cycle.guardian=cycle;cycle.records=cycle;cycle.errors=cycle;cycle.settings=cycle
local ok,r=pcall(M.build,cycle)
eq(ok,true,'cyclic malformed input finite');scalarTree(r)
local sparse={guardian={records={}},errors={}}
sparse.guardian.records[1000000]={id='/private',phase='Verified'}
sparse.errors[1000000]='/private'
local report=M.build(sparse)
eq(#report.guardian.records<=12,true,'sparse record count bounded')
eq(#report.latest_failures<=8,true,'sparse error count bounded')
scalarTree(report)
local root=setmetatable({build='2.31'},{__metatable='opaque'})
eq(M.build(root).reborn_build,'unknown','opaque root metatable rejected')
for _,text in ipairs({'2.31\nsecret','2.31 /home/private','2.31:token','2.31\\Users\\private','2.31\000secret'}) do
 eq(M.build({build=text,versions={cet=text}}).reborn_build,'unknown','version punctuation redacted')
 eq(M.build({build=text,versions={cet=text}}).dependencies.cet,'unknown','dependency punctuation redacted')
end
local effective={mode=2,autosaveEnabled=true}
local input={settings=effective,guardian={records={{phase='Submitted',id='R1-2:G1:2:3'}}}}
local out=M.build(input)
effective.mode=0;input.guardian.records[1].phase='Error'
eq(out.settings.effective.mode,2,'effective report does not alias input')
eq(out.guardian.records[1].phase,'Submitted','guardian report does not alias input')
print('PASS independent support report: '..n..' assertions; recursive output shape/finite scalars verified')
