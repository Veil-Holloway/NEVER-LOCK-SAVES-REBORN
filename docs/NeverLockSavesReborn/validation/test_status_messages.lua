-- Pure production module tests. No CET/Game/IO boundary or save completion.
local dir=assert(arg[1],'status module directory required')
package.path=dir..'/?.lua;'..package.path
local M=require('status_messages')
local L=require('status_message_library')
local n=0
local function check(v,label)n=n+1;assert(v,label)end
local function eq(a,b,label)check(a==b,(label or 'value')..': '..tostring(a)..' != '..tostring(b))end
local kinds={'queued','auto_queued','submitted','expired','cancelled','error'}
local function ready(seed,tone)
 local s=M.new(seed or 12345);assert(s:configure(true,tone or 0));s:reset(1);return s
end
local function accepted(s,kind,serial,time,body)
 local message
 eq(s:enqueue(kind,1,serial,time),true,'valid observed event accepted')
 eq(s:drain(time,body or 0,function(text)message=text;return true end),'emitter_accepted','UI bridge acceptance distinct')
 check(type(message)=='string','accepted message')
 return message
end
local inventory=L.inventory()
eq(inventory.pools,54,'event/tone/body pool inventory');eq(inventory.entries,1080,'entry inventory');eq(inventory.distinct_texts,360,'neutral body variants counted honestly')
for _,kind in ipairs(kinds)do
 for tone=0,2 do for body=0,2 do
  local pool=L.get(kind,tone,body);eq(#pool,20,'twenty entries per applicable pool')
  local seen={}
  for _,message in ipairs(pool)do
   check(type(message)=='string' and #message<=190,'bounded message text')
   check(not seen[message],'unique entries in pool');seen[message]=true
   check(message:lower():find('request',1,true)~=nil,'every status identifies request scope')
   for _,bad in ipairs({'saved successfully','save is complete','progress is safe','save was written','successfully reloaded'})do
    check(not message:lower():find(bad,1,true),'no unsupported completion claim')
   end
   if kind=='submitted' or kind=='error' then check(message:lower():find('unconfirmed',1,true)~=nil,'uncertainty explicit')end
   if tone==2 then check(message:lower():find('fuck',1,true) or message:lower():find('shit',1,true) or message:lower():find('damn',1,true),'profane tone remains profane')end
  end
 end end
end
eq(L.get('arbitrary',0,0),nil,'unsupported event rejected')
local s=M.new(44);eq(s:status().enabled,false,'default OFF');s:reset(1)
eq(s:enqueue('queued',1,1,0),false,'disabled intake ignored')
local calls=0;eq(s:drain(0,0,function()calls=calls+1;return true end),'disabled','disabled drain inert')
eq(calls,0,'disabled emits nothing');eq(s:status().accepted,0,'disabled accepted count unchanged')
local original=s:status().rng_state;s:configure(false,2);eq(s:status().rng_state,original,'disabled tone change does not shuffle')
eq(s:configure('true',0),false,'strict Boolean config');eq(s:configure(true,3),false,'strict tone config')
eq(s:configure(true,0),true,'explicit opt-in')
eq(s:enqueue('queued',1,0,0),false,'dry run serial excluded')
eq(s:enqueue('queued',0,1,0),false,'unknown session excluded')
eq(s:enqueue('queued',2,1,0),false,'other session cannot be adopted')
eq(s:enqueue('madeup',1,1,0),false,'unknown event excluded')
eq(s:enqueue('queued',1,1,0),true,'real queue accepted')
eq(s:enqueue('queued',1,1,0),false,'same event deduplicated')
eq(s:enqueue('submitted',1,1,0),true,'terminal replaces pending queue')
eq(s:status().pending,1,'coalesced single pending event')
local text
s:drain(0,0,function(v)text=v;return true end)
check(text:lower():find('submitted',1,true) or text:lower():find('sent',1,true) or text:lower():find('dispatched',1,true),'coalesced terminal selected')
eq(s:enqueue('queued',1,1,3),false,'late queue cannot regress terminal')
eq(s:enqueue('error',1,1,3),false,'terminal request never produces second terminal')
local a,b=ready(91),ready(91)
a:enqueue('queued',1,1,0);b:enqueue('queued',1,1,0)
local rng=a:status().rng_state
eq(a:drain(0,0,function()return false end),'emitter_failed','rejected UI handoff')
eq(a:status().rng_state,rng,'failed emit never advances RNG');eq(a:status().accepted,0,'failed emit never advances accepted sequence')
eq(a:drain(0.5,0,function()error('must throttle')end),'throttled','failure attempts throttled')
local left,right
a:drain(2,0,function(v)left=v;return true end);b:drain(2,0,function(v)right=v;return true end)
eq(left,right,'failed attempt leaves first choice unchanged')
eq(a:status().rng_state,b:status().rng_state,'failed attempt leaves RNG stream unchanged')
local bodyA,bodyB=ready(123),ready(123)
eq(accepted(bodyA,'queued',1,0,1),accepted(bodyB,'queued',1,0,1),'matching initial body stream')
accepted(bodyA,'queued',2,3,2)
eq(accepted(bodyA,'queued',3,6,1),accepted(bodyB,'queued',2,6,1),'body pool progress is independent')
local neutralA,neutralB=ready(77),ready(77)
neutralA:enqueue('queued',1,1,0);neutralB:enqueue('queued',1,1,0)
local unknownText,neutralText
neutralA:drain(0,'unsupported body',function(v)unknownText=v;return true end)
neutralB:drain(0,0,function(v)neutralText=v;return true end)
eq(unknownText,neutralText,'unknown body uses neutral profile')
local literal=ready(88);literal:enqueue('queued',1,1,0)
eq(literal:drain(0,0,function()return 1 end),'emitter_failed','truthy number is not bridge acceptance')
eq(literal:status().accepted,0,'truthy result cannot advance cycle')
local throwing=ready(44);throwing:enqueue('queued',1,1,0)
eq(throwing:drain(0,0,function()error('private implementation detail')end),'emitter_failed','throw isolated')
eq(throwing:status().accepted,0,'throw no sequence advancement');eq(throwing:status().pending,1,'throw retains bounded pending event')
local expire=ready();expire:enqueue('queued',1,1,0)
eq(expire:drain(10,0,function()error('expired event must not emit')end),'idle','TTL exact boundary expires')
eq(expire:status().pending,0,'expired buffer clears')
local backwards=ready();backwards:enqueue('queued',1,1,10)
eq(backwards:drain(9,0,function()error('backward clock')end),'invalid_clock','backward clock invalidates pending')
eq(backwards:status().pending,0,'clock invalidation clears events')
eq(backwards:enqueue('queued',1,2,0/0),false,'NaN time refused')
local bounded=ready();for serial=1,400 do bounded:enqueue('queued',1,serial,0)end
eq(bounded:status().pending,16,'pending work bounded');check(bounded:status().dropped>=384,'capacity drops counted')
eq(bounded:enqueue('queued',1,1,0),false,'evicted old serial cannot replay')
local priority=ready();priority:enqueue('queued',1,1,0);priority:enqueue('error',1,2,0)
local priorityText;priority:drain(0,0,function(v)priorityText=v;return true end)
check(priorityText:lower():find('error',1,true),'error priority over queue notice')
local important=ready()
for serial=1,16 do important:enqueue('error',1,serial,0)end
eq(important:enqueue('queued',1,17,0),false,'low-priority intake cannot displace full high-priority buffer')
local errors=0
for index=1,16 do
 important:drain(index*0.5,0,function(v)if v:lower():find('error',1,true)then errors=errors+1 end;return true end)
end
eq(errors,4,'all available throttled slots preserve higher-priority errors')
local reset=ready();reset:enqueue('queued',1,1,0);reset:reset(2)
eq(reset:status().pending,0,'session reset drops old events');eq(reset:enqueue('queued',1,2,1),false,'old session cannot enter')
eq(reset:enqueue('queued',2,1,1),true,'new session permits independent serial range')
local reentrant=ready();reentrant:enqueue('queued',1,1,0);local before=reentrant:status().rng_state
eq(reentrant:drain(0,0,function()eq(reentrant:drain(0,0,function()error('reentrant emit')end),'busy','recursive drain blocked');reentrant:configure(false,0);return true end),'interrupted','disable during emit prevents unpublished commit')
eq(reentrant:status().rng_state,before,'interrupted selection never advances RNG');eq(reentrant:status().accepted,0,'interrupted sequence not committed')
local all=ready(123)
local serial,time=0,0
for _,kind in ipairs(kinds)do for tone=0,2 do for body=0,2 do
 all:configure(true,tone)
 local previous
 for cycle=1,3 do
  local seen={}
  for index=1,20 do
   serial=serial+1;time=time+3
   local message=accepted(all,kind,serial,time,body)
   check(not seen[message],'no repeat inside twenty-message cycle');seen[message]=true
   if index==1 and previous then check(message~=previous,'no adjacent repeat across cycle boundary')end
   previous=message
  end
 end
end end end
local copy=L.get('queued',0,0);copy[1]='modified outside module'
check(L.get('queued',0,0)[1]~='modified outside module','library consumers cannot mutate source pools')
print('PASS status messages: '..n..' assertions; 54 pools, 1080 entries, pure Lua only; UI acceptance is not save evidence.')
