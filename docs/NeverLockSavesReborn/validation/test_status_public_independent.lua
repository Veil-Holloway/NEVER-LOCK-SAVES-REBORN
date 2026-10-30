-- Independent public-event tests of final production status selection.
-- Pure Lua; UI handoff evidence never establishes checkpoint/file completion.
local dir=assert(arg[1],'module directory required')
package.path=dir..'/?.lua;'..package.path
local M=require('status_messages')
local L=require('status_message_library')
local n=0
local function check(value,label)n=n+1;assert(value,label)end
local function eq(a,b,label)check(a==b,(label or 'value')..': '..tostring(a)..' != '..tostring(b))end
local kinds={'queued','auto_queued','submitted','expired','cancelled','error'}
local function state(seed,tone)
  local s=M.new(seed or 771);eq(s:configure(true,tone or 0),true,'explicit presentation opt-in');s:reset(1);return s
end
local function emit(s,kind,serial,time,body)
  eq(s:enqueue(kind,1,serial,time),true,'observed event accepted')
  local result
  eq(s:drain(time,body,function(text)result=text;return true end),'emitter_accepted','UI handoff only')
  check(type(result)=='string','bounded text selected');return result
end
local function contains(pool,text)for _,entry in ipairs(pool)do if entry==text then return true end end;return false end

-- Each applicable pool has twenty unique entries, two full cycles and no repeat
-- across its boundary. Expected membership comes from the published library,
-- not the engine's private bag/index representation.
for _,kind in ipairs(kinds)do for tone=0,0 do for body=0,2 do
  local s=state(1009,tone);local pool=L.get(kind,body)
  eq(#pool,20,'twenty entries per event/tone/body pool')
  local distinct={};for _,text in ipairs(pool)do check(not distinct[text],'pool unique');distinct[text]=true end
  local seen,previous={},nil
  for serial=1,42 do
    local text=emit(s,kind,serial,(serial-1)*2,body)
    check(contains(pool,text),'selected text belongs to applicable published pool')
    if serial==21 or serial==41 then seen={}end
    check(not seen[text],'no repeat before twenty-entry cycle is exhausted')
    check(text~=previous,'no immediate/cycle-boundary repetition')
    seen[text]=true;previous=text
  end
end end end

-- A refused or throwing UI boundary cannot advance the bag, RNG or accepted
-- sequence. The same next message must be offered after bounded retry.
for _,fault in ipairs({'false','throw','truthy'})do
  local a,b=state(412,1),state(412,1)
  a:enqueue('submitted',1,1,0);b:enqueue('submitted',1,1,0)
  local rng=a:status().rng_state
  local function failing()
    if fault=='throw'then error('controlled external UI failure')end
    return fault=='truthy' and 'true' or false
  end
  eq(a:drain(0,2,failing),'emitter_failed','failure isolated '..fault)
  eq(a:status().accepted,0,'failed handoff not accepted '..fault)
  eq(a:status().rng_state,rng,'failed handoff retains RNG '..fault)
  eq(a:drain(1,2,function()error('throttled call must not run')end),'throttled','attempt retry bounded '..fault)
  local left,right
  a:drain(2,2,function(text)left=text;return true end)
  b:drain(2,2,function(text)right=text;return true end)
  eq(left,right,'same choice retained after failure '..fault)
  eq(a:status().accepted,1,'only successful retry advances '..fault)
end

-- Queued work superseded before presentation must never leak later as stale
-- Queued. A terminal is selected from its own pool, not simply the oldest event.
for _,terminal in ipairs({'submitted','expired','cancelled','error'})do
  local s=state(31,0)
  eq(s:enqueue('queued',1,5,0),true,'initial queue observation')
  eq(s:enqueue(terminal,1,5,.25),true,'terminal coalesces queue')
  local output={}
  s:drain(.25,0,function(text)output[#output+1]=text;return true end)
  eq(#output,1,'one coalesced status')
  check(contains(L.get(terminal,0),output[1]),'terminal pool selected')
  eq(s:enqueue('queued',1,5,3),false,'late queue cannot reverse terminal')
  eq(s:drain(3,0,function()error('stale queue event must be gone')end),'idle','no deferred stale queue')
end

-- Disable drops pending presentation without touching any game policy. Events
-- arriving while disabled cannot shuffle a pool or allocate display sequence.
do
  local s=state(99,2);s:enqueue('queued',1,1,0)
  local rng=s:status().rng_state
  eq(s:configure(false,2),true,'presentation disabled')
  for serial=2,1000 do eq(s:enqueue('error',1,serial,serial),false,'disabled intake ignored')end
  eq(s:drain(1000,0,function()error('disabled UI callback must not run')end),'disabled','disabled emits nothing')
  eq(s:status().accepted,0,'disabled sequence unchanged')
  eq(s:status().rng_state,rng,'disabled state does not shuffle')
  eq(s:status().pending,0,'disable clears pending presentation')
end

-- Unavailable bodies use neutral selection. Different body bags advance
-- independently even when their editorial text is deliberately neutral.
do
  local a,b=state(381,0),state(381,0)
  eq(emit(a,'cancelled',1,0,99),emit(b,'cancelled',1,0,0),'unknown body has neutral fallback')
  local left,right=state(815,1),state(815,1)
  eq(emit(left,'queued',1,0,0),emit(right,'queued',1,0,0),'same seed initial neutral selection')
  for serial=2,21 do emit(left,'queued',serial,serial*2,1)end
  eq(emit(left,'queued',22,44,0),emit(right,'queued',2,44,0),'feminine bag cannot advance neutral bag')
end

-- Session change invalidates old pending observations; a display cannot create
-- a new epoch itself or promote a state to a file-written/reloaded claim.
do
  local s=state(122,0);s:enqueue('queued',1,1,0);s:reset(2)
  eq(s:status().pending,0,'new session drops pending display')
  eq(s:enqueue('submitted',1,1,2),false,'old session refused')
  eq(s:enqueue('written',2,1,2),false,'written event unsupported')
  eq(s:enqueue('reloaded',2,1,2),false,'reload event unsupported')
  eq(s:drain(2,0,function()error('old session cannot display')end),'idle','nothing stale after reset')
end
do
  local s=state(407,0)
  for serial=1,16 do eq(s:enqueue('error',1,serial,0),true,'bounded high-priority error intake')end
  local accepted,reason=s:enqueue('queued',1,17,0)
  eq(accepted,false,'low-priority new queue cannot displace all-error buffer')
  eq(reason,'capacity_priority','priority refusal explicit')
  eq(s:status().pending,16,'higher priority pending count preserved')
  local text;s:drain(0,0,function(value)text=value;return true end)
  check(contains(L.get('error',0),text),'preserved error selected after low-priority refusal')
end
print('PASS independent status public contract: '..n..' assertions; selection and UI handoff only')
