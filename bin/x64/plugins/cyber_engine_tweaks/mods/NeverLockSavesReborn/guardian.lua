-- Save Guardian v0.11 foundation. Pure bounded observation; no game APIs or IO.
-- A callback return or submitted checkpoint is never evidence of a file write.
local M = {}
local instanceCounter = 0
local MAX_RECORDS, MAX_TRANSITIONS, MAX_HINTS = 64, 128, 16
local sources = {manual=true, pause_quicksave=true, gameplay_quicksave=true, quicksave=true, autosave=true, unknown=true}
local phases = {Requested=true, Delegated=true, Queued=true, Waiting=true,
  Executing=true, Submitted=true, Blocked=true, Cancelled=true, Expired=true,
  Error=true, Unknown=true}
local active = {Requested=true, Delegated=true, Queued=true, Waiting=true, Executing=true}
local endings = {Blocked=true, Cancelled=true, Expired=true, Error=true, Unknown=true}
local reasons = {requested=true, queued=true, waiting=true, native_lock_or_unknown=true,
  stabilizing=true, cancelled_by_user=true, disabled=true, expired=true,
  dispatch_rejected=true, bridge_unavailable=true, player_unavailable=true,
  session_changed=true, replaced=true, tracking_stopped=true, preview=true,
  callback_returned=true, executing=true, submitted=true, blocked_intro=true, unknown=true,
  combat_active=true, combat_unknown=true, pause_unknown=true, paused=true,
  native_state_unknown=true, native_save_lock=true, native_permission_changed=true, cooldown=true}
local reasonAliases = {
  ['Waiting: combat active']='combat_active',
  ['Waiting: combat state unknown']='combat_unknown',
  ['Waiting: pause/menu state unknown']='pause_unknown',
  ['Waiting: paused or menu open']='paused',
  ['Waiting: native permission unknown']='native_state_unknown',
  ['Waiting: native save lock']='native_save_lock',
  ['Waiting: native permission changed before dispatch']='native_permission_changed',
  ['Waiting: dispatch cooldown']='cooldown',
  ['Combat clear and native unlocked: stabilization']='stabilizing',
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

function M.new(runId, clock)
  instanceCounter=instanceCounter+1
  local instance=instanceCounter
  local run=type(runId)=='string' and #runId>0 and #runId<=64 and
    runId:match('^[A-Za-z0-9_-]+$') and runId or 'local_'..tostring(instance)
  local enabled=false
  local counter, sequence=0,0
  local records, byId, pending, transitions, hints={},{},{},{},{}
  local droppedRecords,droppedTransitions,droppedHints,gaps=0,0,0,0
  local api={}
  -- Optional host clock is observation timing only. Never gates or retries a save.
  -- It is sampled during update/report processing, not the original engine callback.
  local lastClock=nil
  local function observedTime()
    if type(clock)~='function' then return nil end
    local ok,value=pcall(clock)
    if not ok or type(value)~='number' or value~=value or value<0 or value>2147483647 or
      (lastClock~=nil and value<lastClock) then return nil end
    lastClock=value
    return value
  end
  local function elapsed(now,thenTime)
    if type(now)~='number' or type(thenTime)~='number' or now<thenTime then return 'unknown' end
    return math.floor(now-thenTime)
  end
  local function recordSnapshot(record,now)
    local result=copy(record)
    result.observed_age_seconds=elapsed(now,record.first_observed_seconds)
    result.phase_age_seconds=elapsed(now,record.last_transition_seconds)
    result.awaiting_write_evidence=record.phase=='Submitted'
    return result
  end
  local function evidenceSummary()
    local value={scope='retained_records_only',waiting=0,executing=0,submitted_unverified=0,
      unknown_outcomes=0,uncorrelated_callbacks=#hints}
    for _,record in ipairs(records) do
      if record.phase=='Queued' or record.phase=='Waiting' then value.waiting=value.waiting+1
      elseif record.phase=='Executing' then value.executing=value.executing+1
      elseif record.phase=='Submitted' then value.submitted_unverified=value.submitted_unverified+1
      elseif record.phase=='Unknown' then value.unknown_outcomes=value.unknown_outcomes+1 end
    end
    return value
  end
  local function key(session,serial) return tostring(session)..':'..tostring(serial) end
  local function transition(record,phase,reason)
    reason=reasonValue(reason)
    if record.phase==phase and record.reason==reason then return record.id end
    record.phase=phase; record.reason=reason
    record.last_transition_seconds=observedTime() or 'unknown'
    -- Evidence fields are deliberately immutable throughout this implementation.
    record.write_status='Unknown'; record.reload_status='Unknown'
    sequence=sequence+1; record.last_sequence=sequence
    if #transitions>=MAX_TRANSITIONS then
      table.remove(transitions,1); droppedTransitions=droppedTransitions+1
    end
    transitions[#transitions+1]={sequence=sequence,trace_id=record.id,phase=phase,reason=reason,
      observed_seconds=record.last_transition_seconds}
    return record.id
  end
  local function create(source,session,phase,dryRun,reason)
    counter=counter+1
    local id=run..':G'..tostring(instance)..':'..tostring(session)..':'..tostring(counter)
    local record={id=id,source=sourceValue(source),session=session,first_observed=phase,
      dry_run=dryRun==true,write_status='Unknown',reload_status='Unknown',
      first_observed_seconds=observedTime() or 'unknown'}
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
  function api:preflight_wait(session,serial)
    if not enabled then return nil end
    local record=lookup(session,serial)
    -- Host calls only after a matching pending serial and unchanged attempt counter
    -- prove that the checkpoint helper was not entered. Never for an engine timeout.
    if record and not record.dry_run and record.phase=='Executing' then
      return transition(record,'Waiting','native_permission_changed')
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
  function api:hint(origin,success,session)
    if not enabled then return nil end
    if #hints>=MAX_HINTS then table.remove(hints,1); droppedHints=droppedHints+1 end
    hints[#hints+1]={origin=origins[origin] and origin or 'unknown',
      outcome=success==true and 'SuccessHint' or success==false and 'FailureHint' or 'Unknown',
      correlated=false,write_status='Unknown',reload_status='Unknown',
      session=sessionValue(session),observed_seconds=observedTime() or 'unknown'}
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
    local now=observedTime()
    for index=math.max(1,#records-11),#records do result[#result+1]=recordSnapshot(records[index],now) end
    return result
  end
  function api:summary()
    local last=records[#records]
    local incomplete=droppedRecords>0 or droppedTransitions>0 or droppedHints>0 or gaps>0
    return 'Guardian '..(enabled and 'ON' or 'OFF')..' | records '..tostring(#records)..
      ' | last '..(last and last.phase or 'None')..' | write Unknown | reload Unknown'..
      ' | accepted/unverified (retained) '..tostring(evidenceSummary().submitted_unverified)..
      (incomplete and ' | history incomplete' or '')
  end
  function api:report()
    local now=observedTime()
    local snapshots={}
    for _,record in ipairs(records) do snapshots[#snapshots+1]=recordSnapshot(record,now) end
    return {schema_version=1,run_id=run,enabled=enabled,total_requests=counter,event_sequence=sequence,
      history_incomplete=droppedRecords>0 or droppedTransitions>0 or droppedHints>0 or gaps>0,
      dropped_records=droppedRecords,dropped_transitions=droppedTransitions,dropped_hints=droppedHints,
      tracking_gaps=gaps,records=snapshots,transitions=copy(transitions),uncorrelated_hints=copy(hints),
      observation_clock=type(clock)=='function' and 'coordinator_update_clock' or 'unknown',
      evidence_summary=evidenceSummary()}
  end
  return api
end

return M
