-- Save Guardian observer transport. Callbacks copy bounded scalar evidence only.
-- They never mutate save policy, dispatch, perform IO, or call the ledger.
local M = {}
local CAPACITY, MAX_DEPTH = 128, 32
local function integer(v) return type(v)=='number' and v==v and v%1==0 and v>=0 and v<=2147483647 end
local function session(v) return integer(v) and v>0 end
local function countValue(value)
  if type(value)~='number' or value~=value or value==math.huge or value==-math.huge then return 0 end
  return math.min(2147483647,math.max(0,math.floor(value)))
end

function M.new(ledger, api)
  ledger=type(ledger)=='table' and ledger or {}
  api=type(api)=='table' and api or {}
  local result={}
  local buffer, count, overflow, overflowSession = {},0,false,0
  local calls, queues={},{}
  local attempted, requested, seen, unavailable, dropped, faults = false,0,{},0,0,0
  local targets={
    {'PauseMenuGameController','HandlePressToSaveGame','manual'},
    {'PauseMenuGameController','HandlePressToQuickSaveGame','pause_quicksave'},
    {'gameuiInGameMenuGameController','HandleQuickSave','gameplay_quicksave'}
  }
  local function invoke(name,...)
    local okMethod,method=pcall(function() return ledger[name] end)
    if not okMethod or type(method)~='function' then faults=faults+1;return nil end
    local ok,value=pcall(method,ledger,...)
    if not ok then faults=faults+1;return nil end
    return value
  end
  local function gap(s,reason)
    invoke('bridge_gap',session(s) and s or 0,reason)
    calls={};queues={}
  end
  local function append(event,key)
    local okEnabled,enabled=pcall(function() return api.enabled() end)
    -- Completion hints remain observable even when the optional Guardian ledger is off.
    -- Other request-trace events remain Guardian-only.
    if event.kind~='hint' and (not okEnabled or enabled~=true) then return end
    seen[key]=true
    local okSession,s=pcall(function() return api.session() end)
    event.session=okSession and session(s) and s or 0
    if overflow then dropped=dropped+1;return end
    if count>=CAPACITY then
      overflow=true;overflowSession=event.session;dropped=dropped+count+1
      buffer={};count=0;return
    end
    count=count+1;buffer[count]=event
  end
  local function fields(self)
    local ok,serial,pending=pcall(function() return self.nlsDeferredSerial,self.nlsDeferredPending end)
    if not ok or not integer(serial) or type(pending)~='boolean' then return nil,nil end
    return serial,pending
  end
  local function register(kind,class,method,callback)
    local key=kind..':'..class..'.'..method
    local okObserver,observer=pcall(function() return api[kind] end)
    if not okObserver or type(observer)~='function' then unavailable=unavailable+1;return end
    -- CET returns void and can log a missing target without throwing.
    local ok=pcall(observer,class,method,function(...)
      pcall(callback,key,...)
      -- Observer return values are deliberately not used or supplied.
    end)
    if ok then requested=requested+1 else unavailable=unavailable+1 end
  end
  function result.register()
    if attempted then return end
    attempted=true
    for _,target in ipairs(targets) do
      local class,method,source=target[1],target[2],target[3]
      register('ObserveBefore',class,method,function(key)
        append({kind='begin',source=source},key)
      end)
      register('ObserveAfter',class,method,function(key)
        append({kind='returned',source=source},key)
      end)
    end
    register('ObserveBefore','PlayerPuppet','NLSRebornDeferredQueue',function(key,self,source)
      local serial,pending=fields(self)
      append({kind='queue_before',source=source==1 and 'manual' or source==2 and 'quicksave' or 'unknown',serial=serial,pending=pending},key)
    end)
    register('ObserveAfter','PlayerPuppet','NLSRebornDeferredQueue',function(key,self,source)
      local serial,pending=fields(self)
      append({kind='queue_after',source=source==1 and 'manual' or source==2 and 'quicksave' or 'unknown',serial=serial,pending=pending},key)
    end)
    for _,class in ipairs({'PauseMenuGameController','gameuiInGameMenuGameController'}) do
      local origin=class=='PauseMenuGameController' and 'save_notification' or 'game_notification'
      register('ObserveAfter',class,'OnSavingComplete',function(key,self,success)
        local value=nil
        if type(success)=='boolean' then value=success end
        append({kind='hint',origin=origin,success=value},key)
      end)
    end
  end
  function result.clear()
    buffer={};count=0;overflow=false;overflowSession=0;calls={};queues={}
  end
  function result.status()
    local confirmed=0;for _ in pairs(seen) do confirmed=confirmed+1 end
    return 'REQUESTED '..requested..'; callback targets observed '..confirmed..
      '; unconfirmed '..math.max(0,requested-confirmed)..'; unavailable '..unavailable..
      '; buffered '..count..'; dropped '..dropped..'; ledger faults '..faults
  end
  function result.diagnostics()
    local observed=0;for _ in pairs(seen) do observed=observed+1 end
    return {attempted=attempted,requested=countValue(requested),observed=countValue(observed),
      unconfirmed=countValue(math.max(0,requested-observed)),unavailable=countValue(unavailable),
      buffered=countValue(count),capacity=CAPACITY,overflow=overflow,
      dropped=countValue(dropped),ledgerFaults=countValue(faults)}
  end
  function result.drain(first,second)
    local current=first==result and second or first
    local events,n=buffer,count;buffer={};count=0
    if overflow then
      local s=overflowSession;overflow=false;overflowSession=0
      gap(s,'observer buffer overflow; events discarded');return
    end
    for i=1,n do
      local event=events[i]
      if not session(current) or not session(event.session) or event.session~=current then
        dropped=dropped+1;gap(event.session,'session unavailable or changed; observer event discarded')
      elseif event.kind=='begin' then
        if #calls>=MAX_DEPTH then gap(current,'wrapper nesting limit reached')
        else calls[#calls+1]={id=invoke('begin',event.source,current),source=event.source,session=current} end
      elseif event.kind=='returned' then
        local call=calls[#calls]
        if not call or call.source~=event.source or call.session~=current then gap(current,'unmatched wrapper return')
        else calls[#calls]=nil;if call.id~=nil then invoke('returned',call.id) end end
      elseif event.kind=='queue_before' then
        if #queues>=MAX_DEPTH then gap(current,'queue observer nesting limit reached')
        else
          local call=calls[#calls]
          queues[#queues+1]={serial=event.serial,pending=event.pending,source=event.source,session=current,
            id=call and call.id or nil,wrapperSource=call and call.source or nil}
        end
      elseif event.kind=='queue_after' then
        local before=queues[#queues];queues[#queues]=nil
        if not before or before.session~=current or before.source~=event.source or event.source=='unknown' or
            not integer(before.serial) or type(before.pending)~='boolean' or not integer(event.serial) or type(event.pending)~='boolean' then
          gap(current,'unpaired or unknown queue evidence')
        elseif event.serial~=before.serial then
          if event.pending==true and event.serial>0 then
            if before.pending and before.serial>0 then invoke('close',current,before.serial,'Cancelled','replaced') end
            invoke('queued',before.id,before.wrapperSource or event.source,current,event.serial)
          else gap(current,'queue changed without a verified pending request') end
        end
      elseif event.kind=='hint' then
        local okCompletion,completion=pcall(function() return api.completion end)
        if okCompletion and type(completion)=='function' then pcall(completion,event.session,event.success,event.origin) end
        invoke('hint',event.origin,event.success,event.session)
      end
    end
  end
  return result
end
return M
