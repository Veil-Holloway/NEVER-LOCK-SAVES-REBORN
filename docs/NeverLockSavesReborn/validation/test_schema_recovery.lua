-- Actual config_store/profile modules; real temporary files, JSON and failing OS boundaries doubled.
local moduleDir,fixture=assert(arg[1]),assert(arg[2])
local P=dofile(moduleDir..'/profiles.lua')
local n=0
local function eq(a,b,label)n=n+1;assert(a==b,label..': expected '..tostring(b)..', got '..tostring(a))end
local function cp(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=cp(x)end;return out end
local realIO,realOS=io,os
local path=fixture..'/profile-settings.json'
local blobs={BAD_SCHEMA1={schema_version=1,profiles={V_Main={mode='bad'}}},GOOD_B={schema_version=1,profiles={V_Main={mode=3,tone=2}}},GOOD_C={schema_version=1,profiles={V_Main={mode=1,tone=0}}},FUTURE={schema_version=2,profiles={}}}
local encodeCalls=0
local jsonBoundary={decode=function(text)assert(blobs[text],'invalid JSON fixture');return cp(blobs[text])end,encode=function(value)
 encodeCalls=encodeCalls+1
 local valid=P.validate_bank(value);assert(valid,'unsupported incoming fixture')
 local text='OUT_'..tostring(valid.profiles.V_Main.mode)..'_'..tostring(valid.profiles.V_Main.tone)
 blobs[text]=cp(valid);return text
end}
local env=setmetatable({json=jsonBoundary,io=realIO,os=realOS},{__index=_G})
local S=assert(loadfile(moduleDir..'/config_store.lua','t',env))()
local function put(p,text)local f=assert(realIO.open(p,'w'));assert(f:write(text));assert(f:close())end
local function raw(p)local f=realIO.open(p,'r');if not f then return nil end;local text=f:read('*a');f:close();return text end
local function exists(p)local f,_,code=realIO.open(p,'r');if f then f:close();return true end;if code==2 then return false end;return nil end
local function reset(primary,backup)
 env.io,env.os,env.json=realIO,realOS,jsonBoundary
 for _,suffix in ipairs({'','.bak','.tmp'})do realOS.remove(path..suffix)end
 if primary then put(path,primary)end;if backup then put(path..'.bak',backup)end
end
local function valid(v)return P.validate_bank(v)end
reset('BAD_SCHEMA1','GOOD_B')
local recovered=S.load(path,valid)
eq(recovered and recovered.profiles.V_Main.mode,3,'validated schema1 backup recovered behind valid-JSON invalid primary')
eq(raw(path),'BAD_SCHEMA1','recovery read preserves primary bytes');eq(raw(path..'.bak'),'GOOD_B','recovery read preserves backup bytes')
local bank=P.new(S,path,exists)
eq(bank:load(),true,'profile API recovers valid backup')
eq(bank:get('V_Main').mode,3,'recovered preset usable')
local failInstall=setmetatable({rename=function(a,b)if a==path..'.tmp' then return nil,'injected install failure'end;return realOS.rename(a,b)end},{__index=realOS})
env.os=failInstall
local accepted,code=bank:save('V_Main',{mode=1,tone=0})
eq(accepted,nil,'failed replacement refused');eq(code,'write_failed','failed replacement code bounded')
eq(raw(path..'.bak'),'GOOD_B','failed replacement preserves only validated backup')
eq(P.validate_bank(S.load(path,valid)).profiles.V_Main.mode,3,'validated backup still usable after failed install')
env.os=realOS
eq(bank:save('V_Main',{mode=1,tone=0}),true,'retry installs valid bank')
eq(raw(path..'.bak'),'GOOD_B','recovered write leaves prior validated backup intact')
eq(bank:get('V_Main').mode,1,'new primary installed')
put(path,'BAD_SCHEMA1')
eq(bank:get('V_Main').mode,3,'later semantic corruption recovers original backup')
reset('BAD_SCHEMA1','BAD_SCHEMA1')
local bad=P.new(S,path,exists);eq(bad:load(),nil,'both-invalid bank refused');eq(bad:save('V_Main',{mode=1}),nil,'both-invalid bank never overwritten')
eq(raw(path),'BAD_SCHEMA1','both-invalid primary preserved');eq(raw(path..'.bak'),'BAD_SCHEMA1','both-invalid backup preserved')
reset('GOOD_B','GOOD_C')
eq(S.load(path,valid).profiles.V_Main.mode,3,'valid primary beats backup')
eq(S.save(path,blobs.GOOD_C,valid),true,'normal validated save')
eq(raw(path..'.bak'),'GOOD_B','normal validated primary rotates to backup')
reset('GOOD_B','GOOD_C')
local ioCalls=0
env.io=setmetatable({open=function(...)ioCalls=ioCalls+1;return realIO.open(...)end},{__index=realIO})
encodeCalls=0
eq(pcall(S.save,path,blobs.BAD_SCHEMA1,valid),false,'incoming invalid data refused');eq(ioCalls,0,'incoming validation before any IO')
eq(encodeCalls,0,'incoming validation before encoder call')
eq(raw(path),'GOOD_B','invalid incoming data leaves primary');eq(raw(path..'.bak'),'GOOD_C','invalid incoming data leaves backup')
env.io=realIO
local throwing=function()error('private schema detail')end
eq(S.load(path,throwing),nil,'throwing validator rejects both candidates')
eq(pcall(S.save,path,blobs.GOOD_C,throwing),false,'throwing validator prevents write')
eq(raw(path),'GOOD_B','throwing validation preserves primary');eq(raw(path..'.bak'),'GOOD_C','throwing validation preserves backup')
eq(S.load(path,17),nil,'nonfunction validator rejects both read candidates')
encodeCalls=0;eq(pcall(S.save,path,blobs.GOOD_C,17),false,'nonfunction validator prevents write');eq(encodeCalls,0,'nonfunction validator rejected before encoding')
reset('BAD_SCHEMA1','GOOD_B')
env.os=setmetatable({remove=function(p)if p==path then return nil,'invalid-primary removal failure'end;return realOS.remove(p)end},{__index=realOS})
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'failed invalid-primary removal surfaces')
eq(raw(path),'BAD_SCHEMA1','failed removal preserves invalid primary');eq(raw(path..'.bak'),'GOOD_B','failed removal preserves validated backup')
reset('BAD_SCHEMA1','GOOD_B')
env.io=setmetatable({open=function(p,mode)if p==path..'.tmp' then return nil,'injected temporary open failure'end;return realIO.open(p,mode)end},{__index=realIO})
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'failed temporary open surfaces')
eq(raw(path),'BAD_SCHEMA1','failed temporary open preserves primary');eq(raw(path..'.bak'),'GOOD_B','failed temporary open preserves backup')
reset('BAD_SCHEMA1','GOOD_B')
local legacy=S.load(path)
eq(legacy.profiles.V_Main.mode,'bad','legacy unvalidated load retains historical table acceptance')
reset('FUTURE','GOOD_B')
local future,reason=S.load(path,valid)
eq(future,nil,'future primary never downgraded to older backup');eq(reason,'unsupported_schema','future schema refusal explicit')
local futureBank=P.new(S,path,exists)
local futureOK,futureCode=futureBank:load()
eq(futureOK,nil,'profile API refuses future schema');eq(futureCode,'unsupported_schema','profile API preserves future schema code')
eq(futureBank:save('V_Main',{mode=1}),nil,'future bank cannot be replaced by preset save')
local writes=0
env.io=setmetatable({open=function(p,mode)if mode=='w'then writes=writes+1 end;return realIO.open(p,mode)end},{__index=realIO})
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'direct validated save refuses future primary')
eq(writes,0,'future refusal before any file write');eq(raw(path),'FUTURE','future primary bytes preserved');eq(raw(path..'.bak'),'GOOD_B','older backup bytes preserved')
eq(raw(path..'.tmp'),nil,'future refusal creates no temporary file')
reset('GOOD_B','FUTURE')
eq(S.load(path,valid).profiles.V_Main.mode,3,'valid current primary is readable despite future backup')
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'future backup cannot be silently deleted by rotation')
eq(raw(path),'GOOD_B','current primary preserved with future backup');eq(raw(path..'.bak'),'FUTURE','future backup preserved');eq(raw(path..'.tmp'),nil,'future backup refusal creates no temp')
reset('BAD_SCHEMA1','FUTURE')
local unsupported,unsupportedCode=S.load(path,valid)
eq(unsupported,nil,'invalid current primary does not accept future backup');eq(unsupportedCode,'unsupported_schema','future backup code explicit')
reset('GOOD_B','GOOD_C')
local priorEncode=jsonBoundary.encode
env.json={decode=jsonBoundary.decode,encode=function()error('encoder failure')end}
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'encoder fault refuses validated save');eq(raw(path),'GOOD_B','encoder fault keeps primary');eq(raw(path..'.bak'),'GOOD_C','encoder fault keeps backup')
reset('BAD_SCHEMA1','GOOD_B')
env.io=setmetatable({open=function(p,mode)
 if p==path..'.tmp' then return {write=function()return nil,'write fault'end,close=function()return true end}end
 return realIO.open(p,mode)
end},{__index=realIO})
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'write fault before replacing recovered primary');eq(raw(path),'BAD_SCHEMA1','write fault keeps original primary');eq(raw(path..'.bak'),'GOOD_B','write fault keeps validated backup')
reset('BAD_SCHEMA1','GOOD_B')
env.io=setmetatable({open=function(p,mode)
 if p==path..'.tmp' then return {write=function()return true end,close=function()return nil,'close fault'end}end
 return realIO.open(p,mode)
end},{__index=realIO})
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'close fault before replacing recovered primary');eq(raw(path),'BAD_SCHEMA1','close fault keeps original primary');eq(raw(path..'.bak'),'GOOD_B','close fault keeps validated backup')
reset('GOOD_B','GOOD_C')
env.os=setmetatable({rename=function(a,b)
 if a==path..'.tmp' or a==path..'.bak'then return nil,'install and rollback failure'end
 return realOS.rename(a,b)
end},{__index=realOS})
eq(pcall(S.save,path,blobs.GOOD_C,valid),false,'install and rollback failure surfaced')
eq(raw(path..'.bak'),'GOOD_B','valid prior primary remains recoverable as backup after rollback failure')
eq(S.load(path,valid).profiles.V_Main.mode,3,'validation recovers after failed rollback')
reset('BAD_SCHEMA1','GOOD_B')
for round=1,3 do
 eq(bank:get('V_Main').mode,3,'repeated recovery sees original valid backup '..round)
 eq(bank:save('V_Main',{mode=1,tone=0}),true,'repeated validated recovery save succeeds '..round)
 eq(raw(path..'.bak'),'GOOD_B','repeated recovery preserves original backup '..round)
 put(path,'BAD_SCHEMA1')
end
eq(bank:get('V_Main').mode,3,'third repeated corruption remains recoverable')
print('PASS schema-aware recovery: '..n..' assertions; actual config_store/profile IO; JSON/failure boundary doubles')
