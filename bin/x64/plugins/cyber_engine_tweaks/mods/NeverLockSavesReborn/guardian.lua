-- Save Guardian v0.11 foundation. Pure bounded observation; no game APIs or IO.
-- A callback return or submitted checkpoint is never evidence of a file write.
local M = {}
local instanceCounter = 0
local MAX_RECORDS, MAX_TRANSITIONS, MAX_HINTS = 64, 128, 16
local sources = {manual=true, pause_quicksave=true, gameplay_quicksave=true, autosave=true, unknown=true}
local phases = {Requested=true, Delegated=true, Queued=true, Waiting=true,
  Executing=true, Submitted=true, Blocked=true, Cancelled=true, Expired=true,
  Error=true, Unknown=true}
local active = {Requested=true, Delegated=true, Queued=true, Waiting=true, Executing=true}
local endings = {Blocked=true, Cancelled=true, Expired=true, Error=true, Unknown=true}
local reasons = {requested=true, queued=true, waiting=true, native_lock_or_unknown=true,
  stabilizing=true, cancelled_by_user=true, disabled=true, expired=true,
  dispatch_rejected=true, bridge_unavailable=true, player_unavailable=true,
  session_changed=true, replaced=true, tracking_stopped=true, preview=true,
  callback_returned=true, executing=true, submitted=true, blocked_intro=true, unknown=true}
local reasonAliases = {
  ['Waiting: native save lock or unknown']='native_lock_or_unknown',
  ['Native unlocked: stabilization']='stabilizing',
  ['Cancelled by user']='cancelled_by_user', ['Disabled']='disabled',
  ['Expired without save']='expired', ['Error: deferred dispatch rejected']='dispatch_rejected',
  ['Bridge unavailable']='bridge_unavailable', ['Player unavailable']='player_unavailable',
  ['Player session changed']='session_changed', ['Game request cleared']='unknown',
  ['Prologue protected or facts unknown']='blocked_intro', ['Preview: dry run']='preview'
}
local origins = {save_notification=true, game_notification=true,
  native_save_callback=true, unknown=true}
local function integer(value)
  return type(value)=='number' and value==value and value>=0 and
    value<=2147483647 and value==math.floor(value)
end
local function sessionValue(value) return integer(value) and value or 0 end
local function sourceValue(value) return sources[value] and value or 'unknown' end
local function reasonValue(value)
  return reasons[value] and value or reasonAliases[value] or 'unknown'
end
local function copy(value)
  if type(value)~='table' then return value end
  local result={}
  for key,item in pairs(value) do result[key]=copy(item) end
  return result
end

function M.new(runId)
  instanceCounter=instanceCounter+1
  local instance=instanceCounter
  local run=type(runId)=='string' and #runId>0 and #runId<=64 and
    runId:match('^[A-Za-z0-9_-]+$') and runId or 'local_'..tostring(instance)
  local enabled=false
  local counter, sequence=0,0
  local records, byId, pending, transitions, hints={},{},{},{},{}
  local droppedRecords,droppedTransitions,droppedHints,gaps=0,0,0,0
  local api={}
  local function key(session,serial) return tostring(session)..':'..tostring(serial) end
  local function transition(record,phase,reason)
    reason=reasonValue(reason)
    if record.phase==phase and record.reason==reason then return record.id end
    record.phase=phase; record.reason=reason
    -- Evidence fields are deliberately immutable throughout this implementation.
    record.write_status='Unknown'; record.reload_status='Unknown'
    sequence=sequence+1; record.last_sequence=sequence
    if #transitions>=MAX_TRANSITIONS then
      table.remove(transitions,1); droppedTransitions=droppedTransitions+1
    end
    transitions[#transitions+1]={sequence=sequence,trace_id=record.id,phase=phase,reason=reason}
    return record.id
  end
  local function create(source,session,phase,dryRun,reason)
    counter=counter+1
    local id=run..':G'..tostring(instance)..':'..tostring(session)..':'..tostring(counter)
    local record={id=id,source=sourceValue(source),session=session,first_observed=phase,
      dry_run=dryRun==true,write_status='Unknown',reload_status='Unknown'}
    if #records>=MAX_RECORDS then
      local removed=table.remove(records,1); byId[removed.id]=nil
      if removed.serial~=nil and pending[key(removed.session,removed.serial)]==removed.id then
        pending[key(removed.session,removed.serial)]=nil
      end
      droppedRecords=droppedRecords+1
    end
    records[#records+1]=record; byId[id]=record
    transition(record,phase,reason)
    return record
  end
  local function lookup(session,serial)
    if not integer(serial) then return nil end
    local id=pending[key(sessionValue(session),serial)]
    return id and byId[id] or nil
  end
  function api:set_enabled(value)
    local nextEnabled=value==true
    if enabled and not nextEnabled then
      for _,record in ipairs(records) do
        if active[record.phase] then transition(record,'Unknown','tracking_stopped') end
      end
      pending={}
    end
    enabled=nextEnabled
    return enabled
  end
  function api:begin(source,session)
    if not enabled then return nil end
    return create(source,sessionValue(session),'Requested',false,'requested').id
  end
  function api:returned(id)
    if not enabled then return nil end
    local record=byId[id]
    if record and record.phase=='Requested' then
      return transition(record,'Delegated','callback_returned')
    end
    return record and record.id or nil
  end
  function api:queued(id,source,session,serial)
    if not enabled or not integer(serial) or serial==0 then return nil end
    session=sessionValue(session)
    local existing=lookup(session,serial)
    if existing then return existing.id end
    local record=id and byId[id] or nil
    if record and (record.session~=session or record.dry_run or
      (record.phase~='Requested' and record.phase~='Delegated')) then record=nil end
    if not record then record=create(source,session,'Queued',false,'queued') end
    record.serial=serial; pending[key(session,serial)]=record.id
    return transition(record,'Queued','queued')
  end
  function api:waiting(session,serial,reason)
    if not enabled then return nil end
    local record=lookup(session,serial)
    if record and (record.phase=='Queued' or record.phase=='Waiting') then
      return transition(record,'Waiting',reason or 'waiting')
    end
    return nil
  end
  function api:executing(session,serial)
    if not enabled then return nil end
    local record=lookup(session,serial)
    if record and not record.dry_run and
      (record.phase=='Queued' or record.phase=='Waiting') then
      return transition(record,'Executing','executing')
    end
    return nil
  end
  function api:submitted(session,serial)
    if not enabled then return nil end
    local record=lookup(session,serial)
    if record and not record.dry_run and
      (record.phase=='Queued' or record.phase=='Waiting' or record.phase=='Executing') then
      pending[key(record.session,record.serial)]=nil
      return transition(record,'Submitted','submitted')
    end
    return nil
  end
  function api:close(session,serial,phase,reason)
    if not enabled or not endings[phase] then return nil end
    local record=lookup(session,serial)
    if not record then return nil end
    pending[key(record.session,record.serial)]=nil
    return transition(record,phase,reason)
  end
  function api:preview(session)
    if not enabled then return nil end
    session=sessionValue(session)
    local old=lookup(session,0)
    if old then transition(old,'Cancelled','replaced') end
    local record=create('unknown',session,'Queued',true,'preview')
    record.serial=0; pending[key(session,0)]=record.id
    return record.id
  end
  function api:hint(origin,success)
    if not enabled then return nil end
    if #hints>=MAX_HINTS then table.remove(hints,1); droppedHints=droppedHints+1 end
    hints[#hints+1]={origin=origins[origin] and origin or 'unknown',
      outcome=success==true and 'SuccessHint' or success==false and 'FailureHint' or 'Unknown',
      correlated=false,write_status='Unknown',reload_status='Unknown'}
    return true
  end
  function api:bridge_gap(session,reason)
    if not enabled then return nil end
    session=sessionValue(session); gaps=gaps+1
    for _,record in ipairs(records) do
      if record.session==session and active[record.phase] then
        if record.serial~=nil then pending[key(session,record.serial)]=nil end
        transition(record,'Unknown',reason or 'bridge_unavailable')
      end
    end
    return true
  end
  function api:get_pending_id(session,serial)
    if not enabled then return nil end
    local record=lookup(session,serial); return record and record.id or nil
  end
  function api:latest()
    local result={}
    for index=math.max(1,#records-11),#records do result[#result+1]=copy(records[index]) end
    return result
  end
  function api:summary()
    local last=records[#records]
    local incomplete=droppedRecords>0 or droppedTransitions>0 or droppedHints>0 or gaps>0
    return 'Guardian '..(enabled and 'ON' or 'OFF')..' | records '..tostring(#records)..
      ' | last '..(last and last.phase or 'None')..' | write Unknown | reload Unknown'..
      (incomplete and ' | history incomplete' or '')
  end
  function api:report()
    return {schema_version=1,run_id=run,enabled=enabled,total_requests=counter,event_sequence=sequence,
      history_incomplete=droppedRecords>0 or droppedTransitions>0 or droppedHints>0 or gaps>0,
      dropped_records=droppedRecords,dropped_transitions=droppedTransitions,dropped_hints=droppedHints,
      tracking_gaps=gaps,records=copy(records),transitions=copy(transitions),uncorrelated_hints=copy(hints)}
  end
  return api
end

return M
