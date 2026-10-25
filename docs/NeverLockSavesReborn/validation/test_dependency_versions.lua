-- Pure collector contract. API calls are explicit functions, never game globals.
local path=assert(arg[1],'collector path required')
local loaded=loadfile(path)
assert(loaded,'NLSR-DEPENDENCY-VERSIONS: pure source-backed collector must be supplied')
local module=loaded()
local checks=0
local function eq(a,b,label)checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function check(v,label)checks=checks+1;assert(v,label)end
local keys={'cet','codeware','nativeSettings','redscript','red4ext','darkFuture'}
local sources={cet='cet_get_version',codeware='codeware_version',nativeSettings='native_settings_version'}
local function shape(result)
 local outer=0;for k in pairs(result)do check(k=='versions' or k=='evidence','exact outer key');outer=outer+1 end;eq(outer,2,'exact outer size')
 local vc,ec=0,0;for _ in pairs(result.versions)do vc=vc+1 end;for _ in pairs(result.evidence)do ec=ec+1 end;eq(vc,6,'exact version key count');eq(ec,6,'exact evidence key count')
 for _,key in ipairs(keys)do
  eq(type(result.versions[key]),'string','version string '..key)
  local count=0;for k in pairs(result.evidence[key])do check(k=='status' or k=='source','exact row key');count=count+1 end;eq(count,2,'exact evidence row size')
  eq(result.evidence[key].source,sources[key] or 'none','source mapping '..key)
 end
end
local empty=module.sample(nil);shape(empty)
for _,key in ipairs(keys)do eq(empty.versions[key],'unknown','empty unknown '..key);eq(empty.evidence[key].status,sources[key] and 'unavailable' or 'not_supported','empty status '..key)end
local called={cet=0,codeware=0,nativeSettings=0,unsupported=0,extra=0}
local readers={cet=function()called.cet=called.cet+1;return 'v1.37.1-2-gabcdef'end,
 codeware=function()called.codeware=called.codeware+1;return '1.18.0'end,
 nativeSettings=function()called.nativeSettings=called.nativeSettings+1;return 1.97 end}
for _,key in ipairs({'redscript','red4ext','darkFuture'})do readers[key]=function()called.unsupported=called.unsupported+1;error('PRIVATE')end end
readers.extra=function()called.extra=called.extra+1;error('PRIVATE')end
local good=module.sample(readers);shape(good)
eq(good.versions.cet,'1.37.1-2-gabcdef','CET optional prefix and git suffix')
eq(good.versions.codeware,'1.18.0','Codeware exact string')
eq(good.versions.nativeSettings,'1.97','Native numeric API declaration')
for _,key in ipairs({'cet','codeware','nativeSettings'})do eq(called[key],1,'one read per sample '..key);eq(good.evidence[key].status,'observed','observed '..key)end
eq(called.unsupported,0,'unsupported readers never invoked');eq(called.extra,0,'unknown readers never invoked')
local function one(key,raw)
 local value=module.sample({[key]=function()return raw end})
 return value.versions[key],value.evidence[key].status
end
local sharedValid={'0','1','1.2','1.2.3','12.345.678','1.37.1-2-gabcdef','1.2.3+build_abc','1_2+dev','1-alpha','1'..string.rep('a',39)}
for _,key in ipairs({'cet','codeware'})do
 for _,value in ipairs(sharedValid)do local version,status=one(key,value);eq(version,value,'safe full version '..key);eq(status,'observed','safe observed '..key)end
end
for _,value in ipairs(sharedValid)do local version,status=one('cet','v'..value);eq(version,value,'strip one lowercase v');eq(status,'observed','prefixed observed')end
local badStrings={'','v','V1.2.3','vv1.2.3','v 1.2.3',' 1.2.3','1.2.3 ','1.2.3\n','1.2.3\r','1.2.3\0','1.2.3/private','1.2.3\\PRIVATE','1.2.3:PRIVATE','https://PRIVATE/1.2.3','PRIVATE1.2.3','+1','-1','.1','1=PRIVATE','1@PRIVATE','1#PRIVATE','1,97',string.rep('1',41),'1.2.3é'}
for _,key in ipairs({'cet','codeware'})do
 for _,value in ipairs(badStrings)do local version,status=one(key,value);eq(version,'unknown','unsafe text stripped '..key);eq(status,'invalid','unsafe text invalid '..key)end
end
local version,status=one('codeware','v1.2.3');eq(version,'unknown','Codeware no guessed v stripping');eq(status,'invalid','Codeware v invalid')
local badTypes={false,true,0,1.97,{},function()end,io.stdout}
for _,key in ipairs({'cet','codeware'})do for _,value in ipairs(badTypes)do local v,s=one(key,value);eq(v,'unknown','wrong string type '..key);eq(s,'invalid','wrong string type invalid '..key)end end
local nativeValid={{0,'0'},{-0.0,'0'},{1,'1'},{1.97,'1.97'},{0.0001,'0.0001'},{999999,'999999'},{1000000,'1000000'}}
for _,row in ipairs(nativeValid)do local v,s=one('nativeSettings',row[1]);eq(v,row[2],'controlled numeric format');eq(s,'observed','numeric observed')end
local nativeInvalid={false,true,'1.97','v1.97',{},function()end,io.stdout,-1,1000000.1,math.huge,-math.huge,0/0,0.00001}
for _,value in ipairs(nativeInvalid)do local v,s=one('nativeSettings',value);eq(v,'unknown','invalid numeric stripped');eq(s,'invalid','invalid numeric status')end
for _,key in ipairs({'cet','codeware','nativeSettings'})do local v,s=one(key,nil);eq(v,'unknown','nil remains unknown');eq(s,'unavailable','nil unavailable')end
-- Do not inspect or invoke arbitrary object behavior on inputs/results/errors.
local hits=0
local hostile=setmetatable({}, {__index=function()hits=hits+1;error('PRIVATE')end,__pairs=function()hits=hits+1;error('PRIVATE')end,__tostring=function()hits=hits+1;return'PRIVATE'end,__call=function()hits=hits+1;return'1.2.3'end})
for _,input in ipairs({hostile,setmetatable({cet=function()error('must not be read')end},{__metatable=false}),false,0,'PRIVATE',function()end,io.stdout})do
 local result=module.sample(input);shape(result)
 for _,key in ipairs({'cet','codeware','nativeSettings'})do eq(result.evidence[key].status,'unavailable','malformed readers unavailable');eq(result.versions[key],'unknown','malformed readers unknown')end
end
for _,key in ipairs({'cet','codeware','nativeSettings'})do
 local callable=module.sample({[key]=hostile});eq(callable.evidence[key].status,'unavailable','callable table is not a reader')
 local v,s=one(key,hostile);eq(v,'unknown','hostile result not exposed');eq(s,'invalid','hostile result invalid')
 local thrown=module.sample({[key]=function()error(hostile)end});eq(thrown.evidence[key].status,'read_failed','object error isolated');eq(thrown.versions[key],'unknown','object error hidden')
end
eq(hits,0,'zero hostile metamethod invocations')
for _,failed in ipairs({'cet','codeware','nativeSettings'})do
 local rs={cet=function()return'v1.37.1'end,codeware=function()return'1.18.0'end,nativeSettings=function()return 1.97 end}
 rs[failed]=function()error('PRIVATE PATH C:/Users/PRIVATE')end
 local value=module.sample(rs)
 for _,key in ipairs({'cet','codeware','nativeSettings'})do eq(value.evidence[key].status,key==failed and 'read_failed' or 'observed','per-reader failure isolation')end
end
local nested
local outer=module.sample({cet=function()nested=module.sample({cet=function()return'v2.3.4'end});return'v1.2.3'end,codeware=function()return'1.0'end})
eq(outer.versions.cet,'1.2.3','outer reentrant value');eq(nested.versions.cet,'2.3.4','nested reentrant value');eq(outer.versions.codeware,'1.0','subsequent outer independent read')
for n=1,50 do
 local value=module.sample({cet=function()return 'v1.'..n end})
 eq(value.versions.cet,'1.'..n,'fresh version each explicit call')
 value.versions.cet='PRIVATE';value.evidence.cet.source='PRIVATE'
 local nextValue=module.sample({cet=function()return 'v1.'..n end})
 eq(nextValue.versions.cet,'1.'..n,'no output alias/cache');eq(nextValue.evidence.cet.source,sources.cet,'no evidence alias')
end
local function privateAbsent(v)
 if type(v)=='table'then for k,x in pairs(v)do check(type(k)~='string' or not k:find('PRIVATE',1,true),'private output key absent');privateAbsent(x)end
 elseif type(v)=='string'then check(not v:find('PRIVATE',1,true),'private output value absent')end
end
privateAbsent(module.sample({cet=function()error(hostile)end,codeware=function()return hostile end,nativeSettings=function()return 'PRIVATE'end,unknown='PRIVATE'}))
print('PASS dependency versions: '..checks..' assertions')
