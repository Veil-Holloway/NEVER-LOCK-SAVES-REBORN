-- Actual support report/profiles modules; no Game/CET/IO.
local dir=assert(arg[1],'module directory required')
package.path=dir..'/?.lua;'..package.path
local M=require('support_report')
local n=0
local function check(value,label)n=n+1;assert(value,label)end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' != '..tostring(b))end
local function snapshot()
 return {build='0.14.0-preRC2',settings={},sensors={inMenu=false},
  observers={guardian={attempted=true,requested=10,observed=2,unconfirmed=8,unavailable=0,
   buffered=3,capacity=128,overflow=false,dropped=1,ledgerFaults=2},
  quest={attempted=true,requested=true,callbackObserved=false,unconfirmed=true,unavailable=false,
   armed=true,buffered=1,capacity=64,overflow=false,dedupCount=7,dedupCapacity=128,resolved=7,
   dropped=0,saturated=0,faults=0}},locks={known=true,overflow=false,codes={'Combat','Quest'}}}
end
local s=snapshot();local r=M.build(s)
check(type(r.observers)=='table','structured observer evidence available')
eq(r.observers.guardian.requested,10,'request count retained')
eq(r.observers.guardian.observed,2,'callback observations retained')
eq(r.observers.guardian.unconfirmed,8,'unconfirmed distinct from requested')
eq(r.observers.guardian.ledger_faults,2,'bounded ledger fault count')
eq(r.observers.guardian.buffered,3,'observer buffer count retained')
eq(r.observers.guardian.capacity,128,'guardian capacity retained')
eq(r.observers.quest.requested,true,'journal requested registration')
eq(r.observers.quest.callback_observed,false,'unobserved registration stays unobserved')
eq(r.observers.quest.unconfirmed,true,'unconfirmed journal attachment remains explicit')
eq(r.observers.quest.dedup_count,7,'journal dedup count retained')
eq(r.observers.quest.saturated,0,'journal saturation drops retained')
eq(r.context.in_menu,false,'fresh explicit menu state retained')
eq(r.native_locks.known,true,'verified known reason summary')
eq(r.native_locks.overflow,false,'reason inventory not truncated')
eq(r.native_locks.reason_codes[1],'Combat','first enum reason retained')
eq(r.native_locks.reason_codes[2],'Quest','mixed reason remains visible')
eq(r.native_locks.max_reasons,16,'reason inventory bound explicit')
r.observers.quest.dedup_count=99;r.native_locks.reason_codes[1]='private'
eq(s.observers.quest.dedupCount,7,'output cannot mutate source counters')
eq(s.locks.codes[1],'Combat','output reason list is copied')
s=snapshot();s.observers.guardian.path='C:/private';s.observers.quest.save='private'
s.locks.path='C:/private';r=M.build(s)
eq(r.observers.guardian.path,nil,'extra observer fields dropped')
eq(r.observers.quest.save,nil,'extra journal fields dropped')
eq(r.native_locks.path,nil,'extra lock fields dropped')
for _,field in ipairs({'requested','observed','unconfirmed','unavailable','buffered','capacity','dropped','ledgerFaults'})do
 for _,bad in ipairs({-1,0/0,math.huge,2147483648,'private',true,{}})do
  s=snapshot();s.observers.guardian[field]=bad;r=M.build(s)
  local output=field=='ledgerFaults'and'ledger_faults'or field
  eq(r.observers.guardian[output],'unknown','invalid guardian count '..field)
 end
end
for _,field in ipairs({'attempted','requested','callbackObserved','unconfirmed','unavailable','armed','overflow'})do
 s=snapshot();s.observers.quest[field]='true';r=M.build(s)
 local output=field=='callbackObserved'and'callback_observed'or field
 if field~='unconfirmed'then eq(r.observers.quest[output],'unknown','journal Bool string refused '..field)end
end
for _,field in ipairs({'buffered','capacity','dedupCount','dedupCapacity','resolved','dropped','saturated','faults'})do
 s=snapshot();s.observers.quest[field]=math.huge;r=M.build(s)
 local names={dedupCount='dedup_count',dedupCapacity='dedup_capacity'}
 eq(r.observers.quest[names[field]or field],'unknown','invalid journal counter '..field)
end
for _,bad in ipairs({{},'private',true,math.huge})do
 s=snapshot();s.observers=bad;r=M.build(s)
 eq(r.observers.guardian.requested,'unknown','missing observer data not fabricated')
 eq(r.observers.quest.callback_observed,'unknown','missing quest observations not fabricated')
end
local poisoned=setmetatable({requested=10},{__index=function()error('private')end,__pairs=function()error('private')end})
s=snapshot();s.observers.guardian=poisoned;s.observers.quest=poisoned;r=M.build(s)
eq(r.observers.guardian.requested,'unknown','metatable observer ignored')
eq(r.observers.quest.requested,'unknown','metatable journal ignored')
s=snapshot();s.observers=setmetatable(s.observers,{__index=function()error('private')end});r=M.build(s)
eq(r.observers.guardian.requested,'unknown','metatable outer observer ignored')
for _,code in ipairs({'Nothing','Combat','Scene','Quest','Script','Boundary','MainMenu','LoadingScreen',
 'PlayerStateMachine','PlayerState','Tier','NotEnoughSlots','NotEnoughSpace','PlayerOnMovingPlatform'})do
 s=snapshot();s.locks.codes={code};r=M.build(s)
 eq(r.native_locks.reason_codes[1],code,'native known reason '..code)
 eq(r.native_locks.known,true,'known enum remains known '..code)
end
for _,bad in ipairs({'private/path','Combat Extra',999,{},true})do
 s=snapshot();s.locks.codes={'Combat',bad};r=M.build(s)
 eq(r.native_locks.reason_codes[1],'Combat','valid reason retained before invalid')
 eq(r.native_locks.reason_codes[2],'Unknown','invalid raw reason sanitized')
 eq(r.native_locks.known,false,'invalid reason cannot preserve known inventory')
end
s=snapshot();s.locks.codes={};r=M.build(s)
eq(r.native_locks.known,true,'empty known list can represent native unlocked')
eq(#r.native_locks.reason_codes,0,'empty reason list stays empty')
s=snapshot();s.locks.codes={'Unknown'};r=M.build(s)
eq(r.native_locks.known,false,'explicit Unknown cannot claim complete known reasons')
s=snapshot();s.locks.codes={};for i=1,20 do s.locks.codes[i]='Combat' end;r=M.build(s)
eq(#r.native_locks.reason_codes,16,'reason list truncated at16')
eq(r.native_locks.overflow,true,'reason truncation explicit')
eq(r.native_locks.known,false,'truncated reason list not complete')
s=snapshot();s.locks.codes={[2]='Quest'};r=M.build(s)
eq(r.native_locks.known,false,'sparse reason list not a complete inventory')
s=snapshot();s.locks.codes=setmetatable({'Combat'},{__len=function()error('private')end});r=M.build(s)
eq(r.native_locks.known,false,'metatable reason inventory cannot claim knowledge')
eq(#r.native_locks.reason_codes,0,'metatable inventory ignored')
for _,state in ipairs({'Written','Verified','Reloaded','Restored'})do
 s=snapshot();s.queue={state=state};s.guardian={records={{phase=state,write_status=state,reload_status=state}}};r=M.build(s)
 eq(r.queue.state,'unknown','queue cannot invent completion phase')
 eq(r.guardian.records[1].write_status,'Unknown','observer evidence never becomes written')
 eq(r.guardian.records[1].reload_status,'Unknown','observer evidence never becomes reloaded')
end
s=snapshot();s.sensors.inMenu='false';r=M.build(s)
eq(r.context.in_menu,'unknown','menu Bool strings refused')
s=snapshot();s.settings={statusNotificationsEnabled=true,autosaveApartmentEntry=true};r=M.build(s)
eq(r.settings.validation,'valid','new settings whitelist accepts actual schema')
eq(r.settings.effective.statusNotificationsEnabled,true,'status toggle is explicit Boolean')
eq(r.settings.effective.autosaveApartmentEntry,true,'apartment trigger toggle explicit Boolean')
s=snapshot();s.autosave={reason='apartment_entry'};s.errors={'unsupported_schema','C:/private/error','status_unavailable'};r=M.build(s)
eq(r.autosave.reason,'apartment_entry','source-backed apartment trigger reason preserved')
eq(r.latest_failures[1],'unsupported_schema','future profile schema refusal diagnosable')
eq(r.latest_failures[2],'unknown','raw failure text still excluded')
eq(r.latest_failures[3],'status_unavailable','optional status presentation failure diagnosable')
s=snapshot();s.statusNotifications={enabled=true,tone=2,session=8,pending=4,pending_capacity=16,
 tracked_requests=12,history_capacity=128,serial_high_water=99,accepted=7,failed=3,dropped=2,
 suppressed=4,last_pool='submitted/2/1',last_kind='submitted',ttl_seconds=10,throttle_seconds=2,
 rng_state=999,ui_visibility='displayed',write_status='Verified',reload_status='Verified',private='C:/private'}
r=M.build(s)
eq(r.status_notifications.enabled,true,'status engine effective enabled state')
eq(r.status_notifications.pending,4,'pending notices separate from disabled')
eq(r.status_notifications.accepted_ui_handoffs,7,'UI bridge handoffs explicitly named')
eq(r.status_notifications.failed,3,'failed presentation handoffs diagnosable')
eq(r.status_notifications.suppressed,4,'suppressed presentations counted')
eq(r.status_notifications.last_pool,'submitted/2/1','bounded known status pool retained')
eq(r.status_notifications.acceptance_scope,'ui_bridge_handoff_only','handoff scope fixed')
eq(r.status_notifications.ui_visibility,'unknown','handoff never becomes visibility proof')
eq(r.status_notifications.write_status,'Unknown','status handoff never becomes write proof')
eq(r.status_notifications.reload_status,'Unknown','status handoff never becomes reload proof')
eq(r.status_notifications.rng_state,nil,'internal RNG state omitted')
eq(r.status_notifications.private,nil,'raw status fields omitted')
for _,kind in ipairs({'queued','auto_queued','submitted','expired','cancelled','error'}) do
 s.statusNotifications.last_pool=kind..'/0/2';s.statusNotifications.last_kind=kind;r=M.build(s)
 eq(r.status_notifications.last_kind,kind,'known event enum '..kind)
 eq(r.status_notifications.last_pool,kind..'/0/2','known event pool '..kind)
end
for _,bad in ipairs({'private/path','submitted/3/0','submitted/0/3','written/0/0','none/0/0','submitted/0/0x',{},99}) do
 s.statusNotifications.last_pool=bad;r=M.build(s)
 eq(r.status_notifications.last_pool,'unknown','arbitrary pool rejected')
end
s.statusNotifications.pending=17;s.statusNotifications.tracked_requests=129;s.statusNotifications.accepted=math.huge
s.statusNotifications.ttl_seconds=11;s.statusNotifications.throttle_seconds=3;s.statusNotifications.last_kind='written';r=M.build(s)
for _,field in ipairs({'pending','tracked_requests','accepted_ui_handoffs','ttl_seconds','throttle_seconds','last_kind'}) do
 eq(r.status_notifications[field],'unknown','invalid status field '..field)
end
s.statusNotifications=setmetatable({enabled=true},{__index=function()error('private')end});r=M.build(s)
eq(r.status_notifications.enabled,'unknown','metatable status snapshot ignored')
print('PASS report observer/lock diagnostics: '..n..' bounded sanitization/evidence assertions')
