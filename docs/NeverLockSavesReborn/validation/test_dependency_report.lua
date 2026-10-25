-- Actual report module; plain scalar fixtures and hostile tables, no game or IO.
local dir=assert(arg[1],'module directory required')
package.path=dir..'/?.lua;'..package.path
package.loaded.support_report=nil
local report=require('support_report')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(v,label)checks=checks+1;assert(v,label)end
local function build(extra)local s={build='0.14.0-preRC4',settings={}};for k,v in pairs(extra or {})do s[k]=v end;return report.build(s)end
local first=build({versions={cet='1.37.1'}})
check(type(first.dependency_evidence)=='table','NLSR-DEPENDENCY-EVIDENCE: report must identify provenance of dependency observations')
eq(first.schema_version,1,'schema remains one')
eq(first.dependencies.cet,'1.37.1','legacy flat CET version preserved')
eq(first.dependencies.codeware,'unknown','Codeware fixed key added')
eq(first.dependency_evidence.scope,'on_demand_runtime_self_report','observation scope')
eq(first.dependency_evidence.compatibility,'unverified','no compatibility inference')
local keys={'cet','codeware','nativeSettings','redscript','red4ext','darkFuture'}
local source={cet='cet_get_version',codeware='codeware_version',nativeSettings='native_settings_version'}
for _,key in ipairs(keys)do
 eq(type(first.dependencies[key]),'string','fixed flat key '..key)
 eq(first.dependency_evidence[key].status,'not_sampled','absent evidence '..key)
 eq(first.dependency_evidence[key].source,'none','absent source '..key)
end
local function row(s,sourceID)return {status=s,source=sourceID}end
local input={versions={cet='1.37.1-2-gabc',codeware='1.18.0',nativeSettings='1.97',redscript='0.5.29'},dependencyEvidence={
 cet=row('observed',source.cet),codeware=row('observed',source.codeware),nativeSettings=row('observed',source.nativeSettings),
 redscript=row('not_supported','none'),red4ext=row('not_supported','none'),darkFuture=row('not_supported','none')}}
local r=build(input)
for _,key in ipairs(keys)do
 eq(r.dependency_evidence[key].status,source[key] and 'observed' or 'not_supported','valid evidence '..key)
 eq(r.dependency_evidence[key].source,source[key] or 'none','valid source '..key)
end
eq(r.dependencies.redscript,'0.5.29','legacy version not converted into API evidence')
for _,key in ipairs({'cet','codeware','nativeSettings'})do
 for _,status in ipairs({'observed','unavailable','invalid','read_failed'})do
  local value=build({versions={[key]='1.2.3'},dependencyEvidence={[key]=row(status,source[key])}})
  eq(value.dependency_evidence[key].status,status,'supported status '..key..'/'..status)
  eq(value.dependency_evidence[key].source,source[key],'supported source '..key)
 end
 for _,badSource in ipairs({'none','unknown','cet_get_version','codeware_version','native_settings_version','https://private.invalid/PRIVATE','C:/Users/PRIVATE'})do
  if badSource~=source[key] then
   local value=build({versions={[key]='1.2.3'},dependencyEvidence={[key]=row('observed',badSource)}})
   eq(value.dependency_evidence[key].status,'not_sampled','bad component mapping '..key)
   eq(value.dependency_evidence[key].source,'none','bad source stripped '..key)
  end
 end
 local unknown=build({versions={[key]='PRIVATE'},dependencyEvidence={[key]=row('observed',source[key])}})
 eq(unknown.dependency_evidence[key].status,'not_sampled','observed needs a valid corresponding version '..key)
 eq(unknown.dependencies[key],'unknown','unsafe version stripped '..key)
 for _,status in ipairs({'not_supported','PRIVATE','written','compatible','PASS'})do
  local value=build({versions={[key]='1.2.3'},dependencyEvidence={[key]=row(status,'none')}})
  eq(value.dependency_evidence[key].status,'not_sampled','unsupported known API state '..key)
  eq(value.dependency_evidence[key].source,'none','unsafe state strips source '..key)
 end
end
for _,key in ipairs({'redscript','red4ext','darkFuture'})do
 for _,status in ipairs({'observed','unavailable','invalid','read_failed'})do
  for _,sourceID in ipairs({'none','cet_get_version','codeware_version','native_settings_version'})do
   local value=build({versions={[key]='1.2.3'},dependencyEvidence={[key]=row(status,sourceID)}})
   eq(value.dependency_evidence[key].status,'not_sampled','unsupported cannot become measured '..key)
   eq(value.dependency_evidence[key].source,'none','unsupported source removed '..key)
  end
 end
end
local hits=0
local hostile=setmetatable({}, {__index=function()hits=hits+1;error('PRIVATE')end,__pairs=function()hits=hits+1;error('PRIVATE')end,__tostring=function()hits=hits+1;error('PRIVATE')end})
for _,extra in ipairs({{dependencyEvidence=hostile},{dependencyEvidence={cet=hostile}},{dependencyEvidence={cet={status=hostile,source=hostile}}},{versions=hostile,dependencyEvidence=input.dependencyEvidence},{dependencyEvidence='PRIVATE'},{dependencyEvidence=false}})do
 local value=build(extra)
 for _,key in ipairs(keys)do
  if extra.dependencyEvidence~=input.dependencyEvidence then eq(value.dependency_evidence[key].status,'not_sampled','malformed provenance defaults')end
 end
end
eq(hits,0,'no report metamethod callbacks')
local evidence={cet={status='observed',source=source.cet,raw_error='PRIVATE',path='PRIVATE'}}
local many={versions={cet='1.2.3',codeware='1.2.3',unknown='PRIVATE'},dependencyEvidence=evidence}
for i=1,10000 do many.dependencyEvidence['extra'..i]={raw='PRIVATE'} end
local bounded=build(many)
local count=0;for k in pairs(bounded.dependency_evidence)do count=count+1 end
eq(count,8,'exact six rows plus scope/compatibility')
local function assertNoPrivate(v)
 if type(v)=='table'then for k,x in pairs(v)do check(type(k)~='string' or not k:find('PRIVATE',1,true),'private key absent');assertNoPrivate(x)end
 elseif type(v)=='string'then check(not v:find('PRIVATE',1,true),'private value absent')end
end
assertNoPrivate(bounded)
eq(bounded.dependency_evidence.cet.raw_error,nil,'extra errors absent')
eq(bounded.dependency_evidence.cet.path,nil,'extra path absent')
local rowKeys=0;for _ in pairs(bounded.dependency_evidence.cet)do rowKeys=rowKeys+1 end;eq(rowKeys,2,'exact row fields')
bounded.dependency_evidence.cet.status='PRIVATE';bounded.dependencies.cet='PRIVATE'
local fresh=build(many);eq(fresh.dependency_evidence.cet.status,'observed','returned evidence detached');eq(fresh.dependencies.cet,'1.2.3','returned values detached')
-- Non-version report evidence must stay independent.
eq(fresh.guardian.enabled,'unknown','other unknown evidence retained')
eq(fresh.autosave.completion,'Unknown','no save completion inference')
print('PASS dependency report: '..checks..' assertions')
