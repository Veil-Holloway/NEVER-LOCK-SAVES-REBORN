-- Public API tests; the disk boundary uses real config_store and a CET-JSON double.
local dir=assert(arg[1], 'module directory required')
local fixture=assert(arg[2], 'isolated fixture directory required')
local storePath=assert(arg[3], 'actual config_store.lua required')
local M=dofile(dir..'/profiles.lua')
local n=0
local function eq(a,b,label) n=n+1;assert(a==b,label..': '..tostring(a)..' != '..tostring(b)) end
local function cp(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=cp(x) end;return t end
local function put(path,text) local f=assert(io.open(path,'w'));assert(f:write(text));assert(f:close()) end
local function raw(path) local f=io.open(path,'r');if not f then return nil end;local t=f:read('*a');assert(f:close());return t end
local function exists(path) local f,_,code=io.open(path,'r');if f then assert(f:close());return true end;if code==2 then return false end;return nil end
local records,counter={},0
local jsonBoundary={encode=function(t) counter=counter+1;local text='{"boundary_fixture":'..counter..'}';records[text]=cp(t);return text end,
 decode=function(text) assert(records[text],'invalid JSON fixture');return cp(records[text]) end}
local env=setmetatable({json=jsonBoundary},{__index=_G})
local store=assert(loadfile(storePath,'t',env))()
local path=fixture..'/profile-settings.json'
for _,s in ipairs({'','.bak','.tmp'}) do os.remove(path..s) end
local bank=M.new(store,path,exists)
eq(bank:load(),true,'missing bank is safe empty state')
eq(#bank:list(),0,'no automatic profile exists')
local old={mode=3,tone=2,allowCombat=true}
local migrated=M.migrate_legacy({mode=3,tone=2,allowCombat=true,dfBlockAddiction=true,unknown='private'})
eq(migrated.mode,3,'legacy mode preserved');eq(migrated.dfBlockAddiction,nil,'legacy restriction never revived')
eq(migrated.guardianEnabled,false,'old config gains safe tracking default')
eq(migrated.autosaveEnabled,false,'old config gains scheduler off default')
eq(migrated.autosaveQuestMilestone,false,'old config cannot enable new quest trigger')
eq(M.validate({autosaveQuestMilestone=true}).autosaveQuestMilestone,true,'explicit quest trigger preset accepted')
eq(M.validate({autosaveQuestMilestone='true'}),nil,'quest trigger cannot coerce string')
eq(M.validate({mode=4}),nil,'mode bounds');eq(M.validate({mode=1.5}),nil,'integer mode');eq(M.validate({autosaveIntervalSeconds=0/0}),nil,'NaN refused')
eq(M.validate({autosaveCooldownSeconds=math.huge}),nil,'infinite interval refused')
eq(M.validate({deferredCooldownSeconds=-1}),nil,'negative queue cooldown refused');eq(M.validate({deferredCooldownSeconds=601}),nil,'queue cooldown cap')
eq(M.validate({deferredCooldownSeconds=600}).deferredCooldownSeconds,600,'queue cooldown bound supported')
eq(M.validate({notificationsEnabled='false'}),nil,'Boolean strings refused');eq(M.validate({privatePath='secret'}),nil,'unknown settings refused')
eq(bank:save('V_Corpo',old),true,'first explicit profile save')
eq(#bank:list(),1,'one named preset');eq(bank:list()[1],'V_Corpo','exact label retained')
local saved=assert(bank:get('V_Corpo'));eq(saved.mode,3,'preset preserves mode');eq(saved.allowCombat,true,'preset preserves combat setting');eq(saved.autosaveEnabled,false,'preset cannot implicitly enable autosaves')
saved.mode=0;eq(bank:get('V_Corpo').mode,3,'returned settings cannot mutate bank')
local diskBefore=raw(path)
for _,label in ipairs({'','../escape','x/y','white space','punctuation.','bad\nlabel',string.rep('a',33)}) do
 eq(bank:save(label,old),nil,'unsafe label rejected');eq(raw(path),diskBefore,'unsafe label leaves file bytes unchanged')
end
eq(bank:save('V_Corpo',{mode=1,guardianEnabled='yes'}),nil,'invalid field refuses entire update');eq(raw(path),diskBefore,'invalid update preserves valid bank')
local again=M.new(store,path,exists);eq(again:load(),true,'new manager reloads persisted bank');eq(again:get('V_Corpo').mode,3,'restart settings preserved')
eq(again:get('OtherCharacter'),nil,'unrelated label never falls back to someone else')
eq(again:save('z', {mode=0}),true,'second named preset');eq(again:list()[1],'V_Corpo','labels sorted deterministically')
eq(again:save('A',{mode=1}),true,'third named preset');eq(again:list()[1],'A','sorted A before others')
for i=4,16 do eq(again:save('Profile'..i,{mode=i%4}),true,'bounded bank accepts slot '..i) end
diskBefore=raw(path);eq(again:save('Overflow',{mode=2}),nil,'17th profile refused');eq(raw(path),diskBefore,'bank overflow leaves bytes unchanged')
eq(again:save('A',{mode=2}),true,'existing label replacement allowed at capacity');eq(again:get('A').mode,2,'replacement exact label only')
local realSave=store.save;store.save=function() error('/private/player/save/password') end
diskBefore=raw(path);local ok,code=again:save('A',{mode=0});eq(ok,nil,'write failure surfaced');eq(code,'write_failed','write error text redacted');eq(raw(path),diskBefore,'write failure preserves disk state');store.save=realSave
put(path,'corrupt');put(path..'.bak','also corrupt');diskBefore=raw(path)
eq(again:load(),nil,'corrupt bank refused');eq(again:get('A'),nil,'stale cached profile never applied after corruption');eq(again:save('New',{mode=1}),nil,'corrupt bank never silently overwritten');eq(raw(path),diskBefore,'corrupt primary preserved for recovery')
for _,s in ipairs({'','.bak','.tmp'}) do os.remove(path..s) end
put(path..'.tmp','interrupted');eq(bank:save('New',{mode=1}),nil,'interrupted initial bank refuses overwrite');eq(raw(path..'.tmp'),'interrupted','interrupted bytes preserved')
os.remove(path..'.tmp')
local uncertain=M.new(store,path,function() return nil end);eq(uncertain:save('New',{mode=1}),nil,'unknown file existence refuses creation')
eq(raw(path),nil,'uncertain existence creates no file')
eq(M.validate_bank({schema_version=2,profiles={}}),nil,'unknown bank schema refused')
eq(M.validate_bank({schema_version=1,profiles={a={mode=1},b={mode='bad'}}}),nil,'one invalid entry refuses whole bank')
eq(M.validate_bank({schema_version=1,profiles={},private='secret'}),nil,'unknown bank metadata refused')
local m,err=M.migrate_legacy({mode='3'});eq(m,nil,'malformed legacy mode not coerced');eq(err,'invalid_settings','malformed legacy code stable')
print('PASS profiles: '..n..' public-boundary assertions; real config_store file replacement, JSON boundary double')
