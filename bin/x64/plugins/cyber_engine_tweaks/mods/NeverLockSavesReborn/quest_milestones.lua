-- Optional journal milestone transport. This module never requests a save.
-- Observer callbacks copy bounded scalar evidence only. Resolution is on drain.
local M={}
local CAPACITY,DEDUP_CAPACITY=64,128
local CLASSES={gameJournalQuest='quest',gameJournalQuestObjective='objective'}
local function integer(v,max)
  return type(v)=='number' and v==v and v%1==0 and v>0 and v<=max
end
local function validSession(v) return integer(v,2147483647) end
local function validHash(v) return integer(v,4294967295) end
local function countValue(value)
  if type(value)~='number' or value~=value or value==math.huge or value==-math.huge then return 0 end
  return math.min(2147483647,math.max(0,math.floor(value)))
end
local function scalarName(v)
  -- CET CName.value resolves to a string without a gameplay-system call.
  -- tostring(CName) is a formatted expression, so it must not be used here.
  if type(v)=='userdata' then
    local ok,value=pcall(function() return v.value end)
    if not ok then return nil end
    v=value
  end
  if type(v)~='string' or #v>64 or CLASSES[v]==nil then return nil end
  return v
end

function M.new(api)
  api=type(api)=='table' and api or {}
  local result={}
  local buffer,count,overflow={},0,false
  local currentSession,dedupSession,armed=0,0,false
  local seen,seenCount={},0
  local attempted,requested,callbackSeen,unavailable=false,false,false,false
  local dropped,resolved,faults,saturated=0,0,0,0
  local epoch=0
  local function getApi(name)
    local ok,value=pcall(function() return api[name] end)
    return ok and type(value)=='function' and value or nil
  end
  local function resetState()
    buffer={};count=0;overflow=false;currentSession=0;armed=false
    -- Interruptions disarm intake but never forget completed hashes from the
    -- last known session. Only a different positive token can replace that set.
  end
  local function callback(_,hash,className)
    callbackSeen=true
    if not armed or not validSession(currentSession) then dropped=dropped+1;return end
    local name=scalarName(className)
    if not validHash(hash) or name==nil then dropped=dropped+1;return end
    if overflow then dropped=dropped+1;return end
    if count>=CAPACITY then
      -- Lost events make this batch ambiguous; never dispatch a partial batch.
      dropped=dropped+count+1;buffer={};count=0;overflow=true;return
    end
    count=count+1
    buffer[count]={hash=hash,className=name,session=currentSession}
  end

  function result.register()
    if attempted then return end
    attempted=true
    local observe=getApi('observe')
    if observe==nil then unavailable=true;return end
    -- Registration returns void and missing target attachment may be silent.
    local ok=pcall(observe,'QuestTrackerGameController','OnStateChanges',function(...)
      local copied=pcall(callback,...)
      if not copied then dropped=dropped+1;faults=faults+1 end
      -- No observer return values: these observations cannot alter the game.
    end)
    requested=ok;unavailable=not ok
  end

  function result.clear()
    epoch=epoch+1
    dropped=dropped+count
    resetState()
  end

  function result.drain(first,second)
    -- Injected boundaries can reenter this transport. A nested drain or clear
    -- invalidates every unpublished result from the older invocation.
    epoch=epoch+1
    local drainEpoch=epoch
    local current=first==result and second or first
    local events,n,hadOverflow=buffer,count,overflow
    buffer={};count=0;overflow=false
    local enabled=getApi('enabled')
    local ok,value=false,nil
    if enabled~=nil then ok,value=pcall(enabled) end
    if epoch~=drainEpoch then dropped=dropped+n;return {} end
    if not ok or value~=true or not validSession(current) then
      dropped=dropped+n
      resetState()
      return {}
    end
    if dedupSession~=current then
      -- Old-session observations never acquire the identity of a new player.
      seen={};seenCount=0;dedupSession=current
    end
    currentSession=current;armed=true
    if hadOverflow then return {} end
    local fresh={}
    local resolve=getApi('resolve')
    for i=1,n do
      local event=events[i]
      if event.session~=current then
        dropped=dropped+1
      elseif seen[event.hash] then
        dropped=dropped+1
      elseif seenCount>=DEDUP_CAPACITY then
        -- Saturate rather than evict: replayed older callbacks stay suppressed.
        dropped=dropped+1;saturated=saturated+1
      elseif resolve==nil then
        dropped=dropped+1
      else
        local callOK,evidence=pcall(resolve,event.hash,event.className)
        local readOK,accepted=pcall(function()
          return callOK and type(evidence)=='table' and evidence.defined==true and
            evidence.succeeded==true and evidence.kind==CLASSES[event.className]
        end)
        local enabledOK,enabledValue=false,nil
        if enabled~=nil then enabledOK,enabledValue=pcall(enabled) end
        local stillEnabled=enabledOK and enabledValue==true
        if epoch~=drainEpoch or not stillEnabled then
          dropped=dropped+n-i+1
          if epoch==drainEpoch then resetState() end
          return {}
        end
        if callOK and readOK and accepted==true then
          seen[event.hash]=true;seenCount=seenCount+1;resolved=resolved+1
          fresh[#fresh+1]={hash=event.hash,className=event.className,
            kind=CLASSES[event.className],session=current,
            key='journal:'..tostring(current)..':'..tostring(event.hash)}
        else
          dropped=dropped+1
          if not callOK or not readOK then faults=faults+1 end
        end
      end
    end
    return fresh
  end

  function result.status()
    local attachment=unavailable and 'unavailable' or callbackSeen and 'callback observed' or
      requested and 'requested/unconfirmed' or 'not registered'
    return attachment..'; '..(armed and 'armed' or 'off/unknown')..
      '; buffered '..count..'/'..CAPACITY..'; dedup '..seenCount..'/'..DEDUP_CAPACITY..
      '; completed observations '..resolved..'; dropped '..dropped..
      '; saturation drops '..saturated..'; resolver faults '..faults
  end
  function result.diagnostics()
    return {attempted=attempted,requested=requested,callbackObserved=callbackSeen,
      unconfirmed=requested and not callbackSeen,unavailable=unavailable,armed=armed,
      buffered=countValue(count),capacity=CAPACITY,overflow=overflow,
      dedupCount=countValue(seenCount),dedupCapacity=DEDUP_CAPACITY,
      resolved=countValue(resolved),dropped=countValue(dropped),
      saturated=countValue(saturated),faults=countValue(faults)}
  end
  return result
end
return M
