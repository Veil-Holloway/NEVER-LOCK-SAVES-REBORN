-- On-demand bounded, allowlisted support snapshot. Never uploads or logs by itself.
-- Request/engine hints cannot prove a written, loadable or progressed save.
local profiles=require('profiles')
local M={}
local function tableValue(value)
  return type(value)=='table' and getmetatable(value)==nil and value or {}
end
local function integer(value,low,high)
  if type(value)=='number' and value==value and value>=low and value<=high and value==math.floor(value) then return value end
  return 'unknown'
end
local function boolean(value)
  if type(value)=='boolean' then return value end
  return 'unknown'
end
local function member(value,allowed,fallback) return allowed[value] and value or fallback or 'unknown' end
local function version(value)
  if type(value)=='string' and #value<=40 and value:match('^%d+[A-Za-z0-9._+-]*$') then return value end
  return 'unknown'
end
local DEPENDENCY_KEYS={'cet','codeware','nativeSettings','redscript','red4ext','darkFuture'}
local DEPENDENCY_SOURCES={cet='cet_get_version',codeware='codeware_version',nativeSettings='native_settings_version'}
local DEPENDENCY_OBSERVATIONS={observed=true,unavailable=true,invalid=true,read_failed=true}
local function dependencyEvidence(value,versions)
  local input=tableValue(value)
  local result={scope='on_demand_runtime_self_report',compatibility='unverified'}
  for _,key in ipairs(DEPENDENCY_KEYS) do
    local row=tableValue(rawget(input,key))
    local status,source=rawget(row,'status'),rawget(row,'source')
    local expected=DEPENDENCY_SOURCES[key]
    local valid=type(status)=='string' and type(source)=='string' and
      ((status=='not_sampled' and source=='none') or
       (expected and DEPENDENCY_OBSERVATIONS[status] and source==expected) or
       (not expected and status=='not_supported' and source=='none'))
    if not valid or (status=='observed' and versions[key]=='unknown') then status,source='not_sampled','none' end
    result[key]={status=status,source=source}
  end
  return result
end
local function tri(value) return value==0 and 0 or value==1 and 1 or -1 end
local function observation(known,active)
  if known~=true or type(active)~='boolean' then return 'unknown' end
  return active and 'active' or 'clear'
end
local sources={manual=true,pause_quicksave=true,gameplay_quicksave=true,quicksave=true,autosave=true,unknown=true}
local phases={Requested=true,Delegated=true,Queued=true,Waiting=true,Executing=true,
  Submitted=true,Blocked=true,Cancelled=true,Expired=true,Error=true,Unknown=true}
local causes={requested=true,queued=true,waiting=true,native_lock_or_unknown=true,
  stabilizing=true,cancelled_by_user=true,disabled=true,expired=true,dispatch_rejected=true,
  bridge_unavailable=true,player_unavailable=true,session_changed=true,replaced=true,
  tracking_stopped=true,preview=true,callback_returned=true,executing=true,submitted=true,
  blocked_intro=true,unknown=true,exploration_interval=true,post_combat=true,vehicle_exit=true,quest_milestone=true,apartment_entry=true,
  read_failed=true,write_failed=true,invalid_settings=true,invalid_bank=true,unreadable_bank=true,unsupported_schema=true,
  invalid_label=true,profile_not_found=true,bank_full=true,sensor_unavailable=true,
  scheduler_unavailable=true,status_unavailable=true,dispatch_error=true,report_failed=true,
  observations_unavailable=true,session_unavailable=true,pause_unknown=true,
  combat_unknown=true,vehicle_unknown=true,phone_unknown=true,native_state_unknown=true,
  stability_unknown=true,queue_unknown=true,clock_interrupted=true,configuration_changed=true,
  session_baseline=true,player_queue_priority=true,phone_active=true,combat_active=true,
  vehicle_active=true,native_save_lock=true,native_unlock_stabilizing=true,cooldown=true,
  watching_supported_triggers=true,retry_delay=true,request_callback_unavailable=true,
  safety_interrupted=true,profile_applied=true}
local reasonAliases={['configuration changed']='configuration_changed',['observations unavailable']='observations_unavailable',
  ['session unavailable']='session_unavailable',['player unavailable']='player_unavailable',
  ['bridge unavailable']='bridge_unavailable',['introduction protected or unknown']='blocked_intro',
  ['paused or pause state unknown']='pause_unknown',['combat unknown']='combat_unknown',
  ['vehicle unknown']='vehicle_unknown',['phone unknown']='phone_unknown',
  ['native lock state unknown']='native_state_unknown',['stability state unknown']='stability_unknown',
  ['queue state unknown']='queue_unknown',['clock interrupted']='clock_interrupted',
  ['session baseline']='session_baseline',['player queue has priority']='player_queue_priority',
  ['phone active']='phone_active',['combat active']='combat_active',['vehicle active']='vehicle_active',
  ['native save lock']='native_save_lock',['native unlock stabilizing']='native_unlock_stabilizing',
  ['watching supported triggers']='watching_supported_triggers',['retry delay']='retry_delay',
  ['request callback unavailable']='request_callback_unavailable',
  ['host did not accept request']='dispatch_rejected',['host request failed']='dispatch_error'}
local function cause(value) return member(reasonAliases[value] or value,causes) end
local gates={idle=true,disabled=true,preview=true,native_lock_or_unknown=true,stabilizing=true,
  blocked_intro=true,bridge_unavailable=true,player_unavailable=true,session_changed=true,
  expired=true,cancelled=true,dispatch_rejected=true,safety_interrupted=true,profile_applied=true}
local gateAliases={['Idle']='idle',['Disabled']='disabled',['Preview: dry run']='preview',
  ['Waiting: native save lock or unknown']='native_lock_or_unknown',
  ['Native unlocked: stabilization']='stabilizing',['Prologue protected or facts unknown']='blocked_intro',
  ['Bridge unavailable']='bridge_unavailable',['Player unavailable']='player_unavailable',
  ['Player session changed']='session_changed',['Expired without save']='expired',
  ['Cancelled by user']='cancelled',['Error: deferred dispatch rejected']='dispatch_rejected',
  ['Autosave interrupted by safety state']='safety_interrupted',['Autosave disabled']='disabled',
  ['Profile applied']='profile_applied'}
local categories={[0]='Exploration',[1]='Combat',[2]='Vehicle',[3]='Vehicle combat',
  [4]='Stealth',[5]='Phone call',[7]='Prologue Protection',[12]='Prologue Protection / Corpo call'}
local function pool(value)
  if type(value)~='string' or #value>160 then return 'unknown' end
  if value=='No checkpoint notification selected' then return value end
  local name,category,tone,body,mode,protected=value:match('^([A-Za-z /]+) | pool=(%d+)/(%d+)/(%d+) | mode=(%d+) | saveProtection=(%a+)$')
  category,tone,body,mode=tonumber(category),tonumber(tone),tonumber(body),tonumber(mode)
  if not name or categories[category]~=name or integer(tone,0,2)=='unknown' or
    integer(body,0,2)=='unknown' or integer(mode,0,3)=='unknown' or
    (protected~='true' and protected~='false') then return 'unknown' end
  return value
end
local function correlation(value)
  if type(value)~='string' or #value>96 then return 'unknown' end
  if value:match('^R%d+%-%d+:G%d+:%d+:%d+$') or value:match('^local_%d+:G%d+:%d+:%d+$') then return value end
  return 'unknown'
end
local function observerSummary(value)
  local outer=tableValue(value)
  local bridge,quest=tableValue(outer.guardian),tableValue(outer.quest)
  return {
    guardian={attempted=boolean(bridge.attempted),requested=integer(bridge.requested,0,10),
      observed=integer(bridge.observed,0,10),unconfirmed=integer(bridge.unconfirmed,0,10),
      unavailable=integer(bridge.unavailable,0,10),buffered=integer(bridge.buffered,0,128),
      capacity=integer(bridge.capacity,0,128),overflow=boolean(bridge.overflow),
      dropped=integer(bridge.dropped,0,2147483647),ledger_faults=integer(bridge.ledgerFaults,0,2147483647)},
    quest={attempted=boolean(quest.attempted),requested=boolean(quest.requested),
      callback_observed=boolean(quest.callbackObserved),unconfirmed=boolean(quest.unconfirmed),
      unavailable=boolean(quest.unavailable),armed=boolean(quest.armed),overflow=boolean(quest.overflow),
      buffered=integer(quest.buffered,0,64),capacity=integer(quest.capacity,0,64),
      dedup_count=integer(quest.dedupCount,0,128),dedup_capacity=integer(quest.dedupCapacity,0,128),
      resolved=integer(quest.resolved,0,2147483647),dropped=integer(quest.dropped,0,2147483647),
      saturated=integer(quest.saturated,0,2147483647),faults=integer(quest.faults,0,2147483647)}}
end
local LOCK_CODES={Nothing=true,Combat=true,Scene=true,Quest=true,Script=true,Boundary=true,
  MainMenu=true,LoadingScreen=true,PlayerStateMachine=true,PlayerState=true,Tier=true,
  NotEnoughSlots=true,NotEnoughSpace=true,PlayerOnMovingPlatform=true}
local function lockSummary(value)
  local locks=tableValue(value)
  local codes=locks.codes
  local result={known=boolean(locks.known),overflow=boolean(locks.overflow),reason_codes={},max_reasons=16}
  local plain=type(codes)=='table' and getmetatable(codes)==nil
  if not plain then
    if result.known==true then result.known=false end
    return result
  end
  local count,highest,valid=0,0,true
  -- Inspect a bounded set of keys; sparse/oversized or non-list data cannot
  -- be advertised as a complete native lock inventory.
  for key in pairs(codes) do
    count=count+1
    if count>16 then result.overflow=true;valid=false;break end
    if integer(key,1,16)=='unknown' then valid=false
    else highest=math.max(highest,key) end
  end
  if highest~=count then valid=false end
  for index=1,16 do
    local code=rawget(codes,index)
    if code~=nil then
      if type(code)=='string' and LOCK_CODES[code] then
        result.reason_codes[#result.reason_codes+1]=code
      else
        result.reason_codes[#result.reason_codes+1]='Unknown';valid=false
      end
    end
  end
  if not valid or result.overflow~=false then
    if result.known==true then result.known=false end
  end
  return result
end
local CHECKPOINT_SOURCES={[1]='manual',[2]='quicksave',[3]='autosave'}
local CHECKPOINT_RESULTS={[1]='native_accepted',[2]='native_rejected',[3]='service_unavailable',[4]='policy_blocked'}
local function checkpointLocks(value)
  local parsed={known=false,overflow=false,codes={}}
  if value=='unlocked' then parsed.known=true
  elseif value=='overflow' then parsed.overflow=true
  elseif type(value)=='string' and #value<=512 and value:match('^locked|') then
    local valid=true
    for code in value:sub(8):gmatch('[^|]+') do
      if #parsed.codes>=16 then parsed.overflow=true;valid=false;break end
      if not LOCK_CODES[code] then valid=false end
      -- Never copy a free-form native/string diagnostic into the report.
      parsed.codes[#parsed.codes+1]=LOCK_CODES[code] and code or 'Unknown'
    end
    parsed.known=valid and #parsed.codes>0 and value=='locked|'..table.concat(parsed.codes,'|')
  end
  return lockSummary(parsed)
end
local function checkpointAttempt(value)
  local input=tableValue(value)
  local serial=integer(rawget(input,'serial'),0,2147483647)
  local source=integer(rawget(input,'source'),1,3)
  local outcome=integer(rawget(input,'result'),0,4)
  local result={scope='latest_mod_checkpoint_attempt',observation='unknown',serial=serial,
    source='unknown',result='unknown',native_accepted='unknown',
    native_locks=checkpointLocks(nil),combat='unknown',mounted='unknown',
    write_status='Unknown',reload_status='Unknown'}
  if serial==0 and outcome==0 then
    result.observation='not_attempted';result.result='not_attempted'
  elseif type(serial)=='number' and serial>0 and CHECKPOINT_SOURCES[source] and CHECKPOINT_RESULTS[outcome] then
    result.observation='observed';result.source=CHECKPOINT_SOURCES[source];result.result=CHECKPOINT_RESULTS[outcome]
    if outcome==1 then result.native_accepted=true elseif outcome==2 then result.native_accepted=false end
    result.native_locks=checkpointLocks(rawget(input,'locks'))
    local combat,mounted=rawget(input,'combat'),rawget(input,'mounted')
    result.combat=combat==0 and 'clear' or combat==1 and 'active' or 'unknown'
    result.mounted=mounted==0 and 'clear' or mounted==1 and 'active' or 'unknown'
  end
  return result
end
local STATUS_KINDS={queued=true,auto_queued=true,submitted=true,expired=true,cancelled=true,error=true,none=true}
local function statusPool(value)
  if value=='none' then return value end
  if type(value)~='string' or #value>24 then return 'unknown' end
  local kind,tone,body=value:match('^([a-z_]+)/([0-2])/([0-2])$')
  if not kind or kind=='none' or not STATUS_KINDS[kind] then return 'unknown' end
  return value
end
local function statusSummary(value)
  local s=tableValue(value)
  return {enabled=boolean(s.enabled),tone=integer(s.tone,0,2),session=integer(s.session,0,2147483647),
    pending=integer(s.pending,0,16),pending_capacity=integer(s.pending_capacity,0,16),
    tracked_requests=integer(s.tracked_requests,0,128),history_capacity=integer(s.history_capacity,0,128),
    serial_high_water=integer(s.serial_high_water,0,2147483647),
    accepted_ui_handoffs=integer(s.accepted,0,2147483647),failed=integer(s.failed,0,2147483647),
    dropped=integer(s.dropped,0,2147483647),suppressed=integer(s.suppressed,0,2147483647),
    last_pool=statusPool(s.last_pool),last_kind=member(s.last_kind,STATUS_KINDS),
    ttl_seconds=integer(s.ttl_seconds,0,10),throttle_seconds=integer(s.throttle_seconds,0,2),
    acceptance_scope='ui_bridge_handoff_only',ui_visibility='unknown',write_status='Unknown',reload_status='Unknown'}
end
function M.build(snapshot)
  local s=tableValue(snapshot)
  local settings,settingsCode=profiles.validate(s.settings)
  local deps,facts,sensors,queue,df=tableValue(s.versions),tableValue(s.facts),tableValue(s.sensors),tableValue(s.queue),tableValue(s.darkFuture)
  local g,a=tableValue(s.guardian),tableValue(s.autosave)
  local report={schema_version=1,history_scope='snapshot_only',reborn_build=version(s.build),game_build=version(s.gameBuild),
    dependencies={},settings={validation=settings and 'valid' or 'invalid',effective=settings or {},
      config_write_status=member(s.configWriteStatus,{written=true,failed=true,not_written_this_session=true}),restart_persistence='unknown'},
    profile={selection='manual',selected=s.profileSelected==true,character_identity='unknown',automatic_character_selection=false},
    facts={q000_done=integer(facts.q000_done,0,2147483647),q001_started=integer(facts.q001_started,0,2147483647)},
    context={category=integer(s.context,0,12),body=integer(s.body,0,2),
      combat=observation(sensors.combatKnown,sensors.combatActive),vehicle=observation(sensors.vehicleKnown,sensors.vehicleActive),
      phone=observation(sensors.phoneKnown,sensors.phoneActive),paused=boolean(sensors.paused),in_menu=boolean(sensors.inMenu)},
    observers=observerSummary(s.observers),native_locks=lockSummary(s.locks),
    checkpoint_attempt=checkpointAttempt(s.checkpointAttempt),
    status_notifications=statusSummary(s.statusNotifications),
    queue={pending=boolean(queue.pending),source=member(queue.source,sources),serial=integer(queue.serial,0,2147483647),
      session=integer(queue.session,0,2147483647),gate=member(gateAliases[queue.gate] or queue.gate,gates),
      state=member(queue.state,phases),origin=member(queue.origin,{game=true,preview=true,autosave=true}),expires_in=integer(queue.expiresIn,0,120)},
    dark_future={vehicle_sleep=tri(df.vehicleSleep),addiction=tri(df.addiction),starvation=tri(df.starvation),dehydration=tri(df.dehydration),
      lifecycle=member(df.lifecycle,{Running=true,Uninitialized=true,Suspended=true}),enabled=boolean(df.enabled),
      gameplay_valid=boolean(df.valid),in_menu=boolean(df.inMenu)},notification_pool=pool(s.notificationPool),
    guardian={enabled=boolean(g.enabled),total_requests=integer(g.total_requests,0,2147483647),
      history_incomplete=boolean(g.history_incomplete),tracking_gaps=integer(g.tracking_gaps,0,2147483647),
      dropped_records=integer(g.dropped_records,0,2147483647),dropped_transitions=integer(g.dropped_transitions,0,2147483647),
      dropped_hints=integer(g.dropped_hints,0,2147483647),records={}},
    autosave={enabled=boolean(a.enabled),status=member(a.status,{disabled=true,waiting=true,cooldown=true,submitted=true,reset=true,blocked=true,error=true,
        request_submitted=true,request_accepted=true,queue_request_accepted=true,request_rejected=true,request_error=true,dispatching=true}),
      reason=cause(a.reason),accepted=integer(a.accepted,0,2147483647),rejected=integer(a.rejected,0,2147483647),
      queue_acceptances=integer(a.accepted,0,2147483647),acceptance_scope='host_queue_only',
      errors=integer(a.errors,0,2147483647),resets=integer(a.resets,0,2147483647),checkpoint_submission='Unknown',completion='Unknown'},latest_failures={}}
  for _,key in ipairs(DEPENDENCY_KEYS) do report.dependencies[key]=version(deps[key]) end
  report.dependency_evidence=dependencyEvidence(s.dependencyEvidence,report.dependencies)
  local records=tableValue(g.records)
  local last=math.min(#records,1000000)
  for index=math.max(1,last-11),last do
    local row=tableValue(records[index])
    report.guardian.records[#report.guardian.records+1]={id=correlation(row.id),source=member(row.source,sources),phase=member(row.phase,phases,'Unknown'),
      reason=cause(row.reason),serial=integer(row.serial,0,2147483647),session=integer(row.session,0,2147483647),
      write_status='Unknown',reload_status='Unknown'}
  end
  local errors=tableValue(s.errors)
  for index=math.max(1,#errors-7),#errors do
    if #report.latest_failures>=8 then break end
    local value=errors[index]
    if type(value)=='table' then value=tableValue(value).code end
    report.latest_failures[#report.latest_failures+1]=cause(value)
  end
  -- Include a current failed scheduler/write boundary even if the host has no
  -- separate failure ring. These are failure codes, never free-form error text.
  local currentFailure=a.status=='request_error' and 'dispatch_error' or
    a.status=='request_rejected' and 'dispatch_rejected' or
    s.configWriteStatus=='failed' and 'write_failed' or nil
  if currentFailure then
    if #report.latest_failures>=8 then table.remove(report.latest_failures,1) end
    report.latest_failures[#report.latest_failures+1]=currentFailure
  end
  return report
end
return M
