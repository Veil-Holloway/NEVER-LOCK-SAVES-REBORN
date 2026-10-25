-- Fresh tests of the shipped config_store; real filesystem, CET JSON boundary double.
local root=assert(arg[1],'pass release root')
local dir=assert(arg[2],'pass isolated filesystem fixture directory')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': expected '..tostring(b)..', got '..tostring(a)) end
local realIO,realOS=io,os
local goodA='{"mode":1,"tone":1}'
local goodB='{"mode":3,"tone":2}'
local goodC='{"mode":0,"tone":0}'
local known={[goodA]={mode=1,tone=1},[goodB]={mode=3,tone=2},[goodC]={mode=0,tone=0}}
local jsonBoundary={
 decode=function(text) local t=known[text];assert(t,'invalid JSON boundary fixture');return {mode=t.mode,tone=t.tone} end,
 encode=function(t) local text='{"mode":'..t.mode..',"tone":'..t.tone..'}';assert(known[text],'unsupported JSON boundary fixture');return text end
}
local env=setmetatable({json=jsonBoundary,io=realIO,os=realOS},{__index=_G})
local store=assert(loadfile(root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/config_store.lua','t',env))()
local path=dir..'/config.json'
local function put(p,t) local f=assert(realIO.open(p,'w'));assert(f:write(t));assert(f:close()) end
local function raw(p) local f=realIO.open(p,'r');if not f then return nil end;local s=f:read('*a');f:close();return s end
local function reset(primary,backup)
 env.io,env.os,env.json=realIO,realOS,jsonBoundary
 for _,suffix in ipairs({'','.bak','.tmp'}) do realOS.remove(path..suffix) end
 if primary then put(path,primary) end;if backup then put(path..'.bak',backup) end
end
reset();eq(store.load(path),nil,'missing config stays missing')
reset(goodA,goodB);eq(store.load(path).mode,1,'valid primary wins')
reset('broken JSON',goodB);eq(store.load(path).mode,3,'backup recovers corrupt primary')
reset(nil,goodB);eq(store.load(path).mode,3,'backup recovers missing primary')
reset(goodA,goodB);eq(store.save(path,{mode=0,tone=0}),true,'ordinary save acknowledged');eq(raw(path),goodC,'new primary installed');eq(raw(path..'.bak'),goodA,'prior primary backed up')
reset(goodA,goodB);env.json={encode=function() error('injected encoder fault') end};eq(pcall(store.save,path,{mode=0,tone=0}),false,'encode failure surfaced');eq(raw(path),goodA,'encoder fault preserves primary');eq(raw(path..'.bak'),goodB,'encoder fault preserves backup')
reset(goodA,goodB);env.io=setmetatable({open=function(p,m) if p==path..'.tmp' then return nil,'injected access error' end;return realIO.open(p,m) end},{__index=realIO});eq(pcall(store.save,path,{mode=0,tone=0}),false,'temp open failure surfaced');eq(raw(path),goodA,'temp failure preserves primary');eq(raw(path..'.bak'),goodB,'temp failure preserves backup')
reset(goodA,goodB);env.io=setmetatable({open=function(p,m) if p==path..'.tmp' then return {write=function() return nil,'injected write error' end,close=function() return true end} end;return realIO.open(p,m) end},{__index=realIO});eq(pcall(store.save,path,{mode=0,tone=0}),false,'temp write failure surfaced');eq(raw(path),goodA,'write failure preserves primary');eq(raw(path..'.bak'),goodB,'write failure preserves backup')
reset(goodA,goodB);env.os=setmetatable({remove=function(p) if p==path..'.bak' then return nil,'injected backup access error' end;return realOS.remove(p) end},{__index=realOS});eq(pcall(store.save,path,{mode=0,tone=0}),false,'backup delete failure surfaced');eq(raw(path),goodA,'backup delete failure preserves primary');eq(raw(path..'.bak'),goodB,'backup delete failure preserves backup')
reset(goodA,goodB);env.os=setmetatable({rename=function(a,b) if a==path..'.tmp' then return nil,'injected install failure' end;return realOS.rename(a,b) end},{__index=realOS});eq(pcall(store.save,path,{mode=0,tone=0}),false,'install failure surfaced');eq(raw(path),goodA,'install failure restores valid primary');eq(store.load(path).mode,1,'restored primary remains loadable')
print('PASS config_store: '..checks..' real-disk/failure assertions; JSON is an external-boundary double')
-- Critical regression: a recovered backup must not be destroyed by a failed save.
reset('broken JSON',goodB);eq(store.load(path).mode,3,'recovered backup before save')
env.os=setmetatable({rename=function(a,b) if a==path..'.tmp' then return nil,'injected install failure' end;return realOS.rename(a,b) end},{__index=realOS})
eq(pcall(store.save,path,{mode=0,tone=0}),false,'failed replacement reports failure')
local recovered=store.load(path)
print('RECOVERY-REGRESSION primary='..tostring(raw(path))..' backup='..tostring(raw(path..'.bak'))..' load='..tostring(recovered and recovered.mode))
local failedReplacementPreserved=recovered and recovered.mode==3
reset('broken JSON',goodB);eq(store.load(path).mode,3,'recovered backup before successful save')
eq(store.save(path,{mode=0,tone=0}),true,'replacement succeeds after backup recovery')
local bakText=raw(path..'.bak')
put(path,'corrupted again')
local secondRecovery=store.load(path)
print('SUCCESS-REGRESSION backup='..tostring(bakText)..' second recovery='..tostring(secondRecovery and secondRecovery.mode))
assert(failedReplacementPreserved and secondRecovery and secondRecovery.mode==3,'NLSR-CONFIG-RECOVERY: saving after backup recovery destroys the only prior valid configuration')

reset('broken JSON',goodB)
env.os=setmetatable({remove=function(p) if p==path then return nil,'injected invalid-primary removal failure' end;return realOS.remove(p) end},{__index=realOS})
eq(pcall(store.save,path,{mode=0,tone=0}),false,'invalid-primary removal failure surfaced')
eq(raw(path),'broken JSON','failed removal leaves invalid primary untouched')
eq(raw(path..'.bak'),goodB,'failed removal preserves valid backup bytes')
eq(store.load(path).mode,3,'valid backup still recovers after removal failure')
reset('broken JSON',goodB)
for round=1,3 do
 eq(store.load(path).mode,3,'recovery round '..round..' loads known-good backup')
 eq(store.save(path,{mode=0,tone=0}),true,'recovery round '..round..' save succeeds')
 eq(raw(path..'.bak'),goodB,'recovery round '..round..' preserves known-good backup')
 eq(raw(path),goodC,'recovery round '..round..' installs new primary')
 put(path,'corrupted again')
end
eq(store.load(path).mode,3,'repeated corruption retains recovery')
eq(store.save(path,{mode=0,tone=0}),true,'post-loop recovery save succeeds')
eq(store.save(path,{mode=1,tone=1}),true,'later normal save succeeds')
eq(raw(path),goodA,'later normal primary is latest setting')
eq(raw(path..'.bak'),goodC,'normal save resumes rotation of valid prior primary')
print('PASS all '..checks..' config_store assertions, including recovered-backup preservation')
