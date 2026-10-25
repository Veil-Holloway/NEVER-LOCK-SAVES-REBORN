-- Optional pure request-status notices. No Game/CET/IO calls or save policy.
-- Only a literal-true UI bridge handoff commits a shuffle choice. That handoff
-- says nothing about actual visibility, file writes, reloads or progression.
local library=require('status_message_library')
local M={}
local MAX=2147483647
local TTL,COOLDOWN,PENDING_CAPACITY,HISTORY_CAPACITY=10,2,16,128
local priority={queued=1,auto_queued=1,cancelled=2,submitted=3,expired=4,error=5}
local transitions={queued={submitted=true,expired=true,cancelled=true,error=true},
  auto_queued={submitted=true,expired=true,cancelled=true,error=true}}
local function integer(v,low,high)
  return type(v)=='number' and v==v and v>=low and v<=high and v==math.floor(v)
end
local function clock(v)
  return type(v)=='number' and v==v and v>=0 and v<=1000000000000
end
local function increment(v,by) return math.min(MAX,v+(by or 1)) end
local function random(state,limit)
  -- Park-Miller/Schrage keeps intermediates exact in both Lua5.1 doubles and
  -- Lua5.3 integer hosts. It never consumes the process-wide math.random state.
  local high=math.floor(state/127773)
  local value=16807*(state-high*127773)-2836*high
  if value<=0 then value=value+2147483647 end
  return value,(value%limit)+1
end

function M.new(seed)
  local rng=integer(seed,1,2147483646) and seed or 1
  local enabled,tone,session=false,0,0
  local pending,count,sequence={},0,0
  local history,historyOrder,highWater={},{},0
  local bags={}
  local lastClock,lastAttempt=nil,nil
  local epoch,draining=0,false
  local accepted,failed,dropped,suppressed=0,0,0,0
  local lastPool,lastKind='none','none'
  local api={}
  local function discard()
    dropped=increment(dropped,count)
    pending={};count=0
  end
  local function advance(now)
    if not clock(now) or (lastClock~=nil and now<lastClock) then
      discard();epoch=epoch+1;lastClock=clock(now) and now or nil;lastAttempt=nil
      return false
    end
    lastClock=now
    for serial,event in pairs(pending) do
      if now-event.created>=TTL then
        pending[serial]=nil;count=count-1;dropped=increment(dropped)
      end
    end
    return true
  end
  local function trimPending(kind)
    if count<PENDING_CAPACITY then return true end
    local worst
    for serial,event in pairs(pending) do
      if not worst or priority[event.kind]<priority[worst.kind] or
          (priority[event.kind]==priority[worst.kind] and event.sequence<worst.sequence) then worst=event end
    end
    if worst and priority[kind]<priority[worst.kind] then dropped=increment(dropped);return false end
    if worst then pending[worst.serial]=nil;count=count-1;dropped=increment(dropped) end
    return true
  end
  local function choice(key)
    local old=bags[key]
    local nextBag={order={},index=1,last=nil}
    local nextRng=rng
    if old then
      nextBag.index=old.index;nextBag.last=old.last
      for i,value in ipairs(old.order) do nextBag.order[i]=value end
    end
    if not old or nextBag.index>20 then
      for i=1,20 do nextBag.order[i]=i end
      for i=20,2,-1 do
        local j
        nextRng,j=random(nextRng,i)
        nextBag.order[i],nextBag.order[j]=nextBag.order[j],nextBag.order[i]
      end
      if nextBag.order[1]==nextBag.last then
        nextBag.order[1],nextBag.order[2]=nextBag.order[2],nextBag.order[1]
      end
      nextBag.index=1
    end
    local index=nextBag.order[nextBag.index]
    nextBag.index=nextBag.index+1;nextBag.last=index
    return index,nextBag,nextRng
  end
  function api:configure(value,voice)
    if type(value)~='boolean' or not integer(voice,0,2) then return false,'invalid_configuration' end
    if value~=enabled or voice~=tone then
      discard();epoch=epoch+1
      enabled=value;tone=voice
    end
    return true
  end
  function api:reset(value)
    local nextSession=integer(value,1,MAX) and value or 0
    discard();epoch=epoch+1;lastClock=nil;lastAttempt=nil
    if nextSession~=session then history={};historyOrder={};highWater=0 end
    session=nextSession
    return true
  end
  function api:enqueue(kind,current,serial,now)
    if not enabled then return false,'disabled' end
    if not priority[kind] or not integer(current,1,MAX) or current~=session or not integer(serial,1,MAX) then
      suppressed=increment(suppressed);return false,'invalid_event'
    end
    if not advance(now) then return false,'invalid_clock' end
    local previous=history[serial]
    if previous then
      if not transitions[previous] or transitions[previous][kind]~=true then
        suppressed=increment(suppressed);return false,'duplicate_or_regression'
      end
    elseif serial<=highWater then
      -- Eviction never makes a stale serial look like fresh work.
      suppressed=increment(suppressed);return false,'stale_serial'
    else
      highWater=serial
      historyOrder[#historyOrder+1]=serial
      if #historyOrder>HISTORY_CAPACITY then
        local expired=table.remove(historyOrder,1)
        history[expired]=nil
      end
    end
    history[serial]=kind
    epoch=epoch+1
    if pending[serial]==nil then
      if not trimPending(kind) then return false,'capacity_priority' end
      count=count+1
    end
    sequence=sequence+1
    pending[serial]={kind=kind,session=current,serial=serial,created=now,sequence=sequence}
    return true
  end
  function api:drain(now,body,emit)
    if draining then return 'busy' end
    if not enabled then return 'disabled' end
    if not advance(now) then return 'invalid_clock' end
    if count==0 then return 'idle' end
    if lastAttempt~=nil and now-lastAttempt<COOLDOWN then return 'throttled' end
    if type(emit)~='function' then return 'emitter_unavailable' end
    if not integer(body,0,2) then body=0 end
    local event
    for _,candidate in pairs(pending) do
      if not event or priority[candidate.kind]>priority[event.kind] or
          (priority[candidate.kind]==priority[event.kind] and candidate.sequence<event.sequence) then event=candidate end
    end
    local key=event.kind..'/'..tone..'/'..body
    local loaded,pool=pcall(library.get,event.kind,tone,body)
    lastAttempt=now
    if not loaded or type(pool)~='table' or #pool~=20 then failed=increment(failed);return 'emitter_failed' end
    local index,nextBag,nextRng=choice(key)
    if type(pool[index])~='string' then failed=increment(failed);return 'emitter_failed' end
    local generation=epoch
    draining=true
    local ok,value=pcall(emit,pool[index])
    draining=false
    if epoch~=generation or not enabled or pending[event.serial]~=event or session~=event.session then return 'interrupted' end
    if not ok or value~=true then failed=increment(failed);return 'emitter_failed' end
    bags[key]=nextBag;rng=nextRng
    pending[event.serial]=nil;count=count-1
    accepted=increment(accepted);lastPool=key;lastKind=event.kind;epoch=epoch+1
    return 'emitter_accepted'
  end
  function api:status()
    return {enabled=enabled,tone=tone,session=session,pending=count,pending_capacity=PENDING_CAPACITY,
      tracked_requests=#historyOrder,history_capacity=HISTORY_CAPACITY,serial_high_water=highWater,
      accepted=accepted,failed=failed,dropped=dropped,suppressed=suppressed,
      last_pool=lastPool,last_kind=lastKind,rng_state=rng,
      acceptance_scope='ui_bridge_handoff_only',ui_visibility='unknown',
      write_status='Unknown',reload_status='Unknown',ttl_seconds=TTL,throttle_seconds=COOLDOWN}
  end
  return api
end
return M
