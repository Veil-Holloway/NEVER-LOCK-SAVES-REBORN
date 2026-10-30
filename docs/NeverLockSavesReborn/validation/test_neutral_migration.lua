local dir=assert(arg[1],'module directory required')
package.path=dir..'/?.lua;'..package.path
local presets=require('profiles')
local ui=require('settings_ui')
local status=require('status_messages')
local library=require('status_message_library')
local n=0
local function check(v,label)n=n+1;assert(v,label)end
check(ui.get('tone')==nil,'tone removed from shared CET/Native catalog')
check(presets.defaults().tone==nil,'no tone default')
for _,legacy in ipairs({0,1,2,-1,3,1.5,'Unhinged',{},false})do
 local settings=assert(presets.validate({mode=3,tone=legacy,notificationsEnabled=false,deferredTTL=91}))
 check(settings.tone==nil,'legacy tone discarded')
 check(settings.mode==3 and settings.notificationsEnabled==false and settings.deferredTTL==91,'active values preserved')
 local bank=assert(presets.validate_bank({schema_version=1,profiles={Existing={mode=2,tone=legacy}}}))
 check(bank.profiles.Existing.mode==2 and bank.profiles.Existing.tone==nil,'existing preset bank migrates without version reset')
end
local s=status.new(17);assert(s:configure(true));s:reset(1)
check(s:status().tone==nil,'status exposes no tone setting')
local kinds={'queued','auto_queued','submitted','expired','cancelled','error'}
for _,kind in ipairs(kinds)do
 local base=assert(library.get(kind,0))
 for body=1,2 do
  local pool=assert(library.get(kind,body))
  for i,text in ipairs(pool)do check(text==base[i],'status wording identical across body profiles')end
 end
 for _,text in ipairs(base)do
  for _,bad in ipairs({'fuck','shit','damn',"ma'am",'sir','paperwork'})do
   check(not text:lower():find(bad,1,true),'neutral status wording')
  end
 end
end
print('PASS neutral migration: '..n..' assertions; no game runtime or save evidence')
