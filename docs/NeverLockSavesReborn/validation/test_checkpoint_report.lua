local dir=assert(arg[1],'module directory required')
package.path=dir..'/?.lua;'..package.path
local report=require('support_report')
local n=0
local function eq(a,b,label) n=n+1;assert(a==b,label..': '..tostring(a)..' != '..tostring(b)) end
local function build(value)
  local row=report.build({checkpointAttempt=value}).checkpoint_attempt
  eq(type(row),'table','checkpoint_attempt section required')
  return row
end
local function valid(result)
  return {serial=7,source=2,result=result,locks='locked|Combat|PlayerStateMachine',combat=1,mounted=1,
    write_status='Verified',reload_status='Verified',secret='/private/token'}
end
local function unknownCompletion(row,label)
  eq(row.write_status,'Unknown',label..' write unconfirmed')
  eq(row.reload_status,'Unknown',label..' reload unconfirmed')
  eq(row.secret,nil,label..' arbitrary field omitted')
end
local empty=build(nil)
eq(empty.observation,'unknown','missing attempt unknown');eq(empty.serial,'unknown','missing serial unknown')
eq(empty.result,'unknown','missing result unknown');eq(empty.native_accepted,'unknown','missing acceptance unknown')
unknownCompletion(empty,'missing')
local idle=valid(0);idle.serial=0
idle=build(idle)
eq(idle.observation,'not_attempted','zero means no attempt');eq(idle.result,'not_attempted','zero result retained')
eq(idle.native_accepted,'unknown','zero is not accepted');eq(idle.source,'unknown','zero strips stale source')
eq(idle.native_locks.known,false,'zero strips stale locks');eq(#idle.native_locks.reason_codes,0,'zero no stale codes')
eq(idle.combat,'unknown','zero strips stale combat');eq(idle.mounted,'unknown','zero strips stale mount')
unknownCompletion(idle,'idle')
local expected={'native_accepted','native_rejected','service_unavailable','policy_blocked'}
for outcome=1,4 do
  for source=1,3 do
    local input=valid(outcome);input.source=source
    local row=build(input)
    eq(row.scope,'latest_mod_checkpoint_attempt','bounded history scope')
    eq(row.observation,'observed','consistent attempt observed');eq(row.serial,7,'serial retained')
    eq(row.source,({'manual','quicksave','autosave'})[source],'source retained')
    eq(row.result,expected[outcome],'result retained')
    if outcome==1 then eq(row.native_accepted,true,'accepted Boolean true')
    elseif outcome==2 then eq(row.native_accepted,false,'rejected Boolean false')
    else eq(row.native_accepted,'unknown','no native Boolean for uncalled boundary') end
    eq(row.native_locks.known,true,'complete allowed lock list')
    eq(row.native_locks.reason_codes[1],'Combat','first lock retained')
    eq(row.native_locks.reason_codes[2],'PlayerStateMachine','second lock retained')
    eq(row.combat,'active','combat snapshot retained');eq(row.mounted,'active','mount snapshot retained')
    unknownCompletion(row,'outcome '..outcome)
  end
end
local function invalid(field,value,label)
  local input=valid(1);input[field]=value
  local row=build(input)
  eq(row.observation,'unknown',label..' observation unknown');eq(row.result,'unknown',label..' result unknown')
  eq(row.native_accepted,'unknown',label..' cannot imply acceptance');eq(row.source,'unknown',label..' source unknown')
  eq(row.native_locks.known,false,label..' locks not attributed');unknownCompletion(row,label)
end
for _,value in ipairs({-1,0.5,2147483648,math.huge,-math.huge,'7',true,{}}) do invalid('serial',value,'bad serial') end
invalid('serial',0/0,'NaN serial');invalid('serial',nil,'missing serial')
for _,value in ipairs({0,4,-1,1.5,math.huge,'2',false,{}}) do invalid('source',value,'bad source') end
invalid('source',nil,'missing source')
for _,value in ipairs({0,5,-1,1.5,math.huge,'1',true,{}}) do invalid('result',value,'bad result') end
invalid('result',0/0,'NaN result');invalid('result',nil,'missing result')
invalid('serial',0,'zero serial with nonzero result')
local max=valid(1);max.serial=2147483647;eq(build(max).serial,2147483647,'max Int32 accepted')
local meta=setmetatable(valid(1),{__index=function() error('untrusted __index') end,__pairs=function() error('untrusted __pairs') end})
eq(build(meta).observation,'unknown','metatable attempt rejected')
local cases={
  {'unlocked',true,false,0},
  {'overflow',false,true,0},
  {'unknown',false,false,0},
  {'locked|Combat',true,false,1},
  {'locked|Unknown',false,false,1},
  {'locked|/private/token',false,false,1},
  {'locked|Combat|',false,false,1},
  {'locked||Combat',false,false,1},
  {'locked|',false,false,0},
  {'locked',false,false,0},
  {string.rep('x',513),false,false,0},
  {'locked|'..string.rep('Combat|',15)..'Combat',true,false,16},
  {'locked|'..string.rep('Combat|',16)..'Combat',false,true,16},
  {{},false,false,0},
  {true,false,false,0}
}
for index,case in ipairs(cases) do
  local input=valid(2);input.locks=case[1]
  local row=build(input)
  eq(row.observation,'observed','lock format does not erase native return')
  eq(row.native_accepted,false,'rejection preserved through lock sanitization')
  eq(row.native_locks.known,case[2],'lock known '..index)
  eq(row.native_locks.overflow,case[3],'lock overflow '..index)
  eq(#row.native_locks.reason_codes,case[4],'lock count '..index)
  eq(row.native_locks.max_reasons,16,'lock capacity fixed')
  for _,code in ipairs(row.native_locks.reason_codes) do
    n=n+1;assert(code=='Combat' or code=='Unknown','free-form lock leak')
  end
  unknownCompletion(row,'lock '..index)
end
for _,field in ipairs({'combat','mounted'}) do
  for _,case in ipairs({{0,'clear'},{1,'active'},{-1,'unknown'},{2,'unknown'},{'1','unknown'},{true,'unknown'},{{},'unknown'}}) do
    local input=valid(1);input[field]=case[1];eq(build(input)[field],case[2],field..' tri-state')
  end
end
local input=valid(1);local copy=build(input);input.serial=99;input.locks='unlocked'
eq(copy.serial,7,'snapshot isolated from input mutation');eq(copy.native_locks.reason_codes[1],'Combat','lock list isolated')
print('PASS checkpoint_report: '..n..' acceptance/rejection/bounding/sanitization assertions')
