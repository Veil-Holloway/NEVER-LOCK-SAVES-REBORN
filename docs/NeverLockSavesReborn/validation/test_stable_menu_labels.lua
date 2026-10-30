local root=assert(arg[1]);local mod=root..'/bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/'
package.path=mod..'?.lua;'..package.path
local catalog=require('settings_ui');local n=0
local function check(v,label)n=n+1;assert(v,label)end
local expected={'Vanilla','Immersion','Unrestricted','Smart'}
for i,name in ipairs(expected)do check(catalog.modeNames[i]==name,'stable mode label '..i)end
local defaults=require('profiles').defaults()
for _,option in ipairs(catalog.options)do
 check(not option.label:lower():find('experimental',1,true),'no experimental menu label')
 check(not option.label:lower():find('preview',1,true),'no preview menu label')
 check(catalog.valid(option.key,defaults[option.key]),'unchanged valid persisted default '..option.key)
end
check(catalog.get('deferredEnabled').label=='Deferred Save','stable deferred switch')
check(catalog.get('autosaveEnabled').label=='Smart Autosave','stable autosave switch')
check(defaults.mode==1 and defaults.deferredEnabled==false and defaults.autosaveEnabled==false,'no default-policy change')
for _,name in ipairs({'settings_ui.lua','overlay_ui.lua','init.lua'})do
 local f=assert(io.open(mod..name,'rb'));local source=f:read('*a');f:close()
 check(not source:lower():find('(experimental)',1,true),'no experimental display suffix in '..name)
 check(not source:lower():find('(preview)',1,true),'no preview display suffix in '..name)
 if name=='overlay_ui.lua'then check(source:find(' | Stable',1,true)~=nil,'stable menu header')end
end
print('PASS stable labels: '..n..' assertions; menu text and unchanged config defaults')
