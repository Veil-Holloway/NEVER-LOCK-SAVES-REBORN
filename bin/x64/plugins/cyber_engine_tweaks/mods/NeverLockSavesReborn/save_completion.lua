-- Conservative engine-completion correlation for Reborn-dispatched checkpoints.
-- A completion callback is not a reload proof and never becomes a file-write claim by itself.
local M={}
local MAX_HINTS=16
local function integer(v) return type(v)=='number' and v==v and v>=0 and v<=2147483647 and v==math.floor(v) end
local function text(v) return type(v)=='string' and #v>0 and #v<=256 and v or 'unknown' end
function M.new(clock)
  local inflight,last,hints=nil,nil,{}
  local sequence=0
  local function now()
    if type(clock)~='function' then return nil end
    local ok,v=pcall(clock)
    return ok and type(v)=='number' and v==v and v>=0 and v<math.huge and v or nil
  end
  local function hint(value)
    if #hints>=MAX_HINTS then table.remove(hints,1) end
    hints[#hints+1]=value
  end
  local api={}
  function api:can_dispatch(session)
    if not inflight then return true end
    return false, inflight.session==session and 'previous_save_completion_unknown' or 'previous_session_completion_unknown'
  end
  function api:submitted(session,serial,source,beforeFingerprint)
    if not integer(session) or session<=0 or not integer(serial) or serial<=0 then return false,'invalid_identity' end
    if inflight then return false,'inflight_exists' end
    sequence=sequence+1
    inflight={sequence=sequence,session=session,serial=serial,source=text(source),
      submitted_seconds=now() or 'unknown',before_fingerprint=text(beforeFingerprint)}
    return true
  end
  function api:hint(session,success,origin,afterFingerprint)
    local t=now() or 'unknown'
    if not inflight or not integer(session) or session~=inflight.session then
      hint({session=integer(session) and session or 0,origin=text(origin),success=type(success)=='boolean' and success or 'unknown',
        correlated=false,observed_seconds=t})
      return false,'uncorrelated'
    end
    if type(success)~='boolean' then
      hint({session=session,origin=text(origin),success='unknown',correlated=false,observed_seconds=t})
      return false,'unknown_callback'
    end
    local before=inflight.before_fingerprint
    local after=text(afterFingerprint)
    local metadataChanged=before~='unknown' and after~='unknown' and before~=after
    last={sequence=inflight.sequence,session=inflight.session,serial=inflight.serial,source=inflight.source,
      origin=text(origin),completion_success=success,observed_seconds=t,
      metadata_before=before,metadata_after=after,metadata_changed=metadataChanged,
      write_status=success and (metadataChanged and 'ObservedLatestMetadataChanged' or 'Unknown') or 'Failed',
      reload_status='Unknown',evidence_scope='engine_completion_callback'}
    inflight=nil
    return true,success and 'completion_observed' or 'completion_failed'
  end
  function api:invalidate(session,reason)
    if not inflight then return false end
    if integer(session) and session>0 and inflight.session~=session then return false end
    last={sequence=inflight.sequence,session=inflight.session,serial=inflight.serial,source=inflight.source,
      completion_success='unknown',write_status='Unknown',reload_status='Unknown',
      evidence_scope='session_invalidation',reason=text(reason),observed_seconds=now() or 'unknown'}
    inflight=nil
    return true
  end
  function api:report()
    local current=nil
    if inflight then
      current={sequence=inflight.sequence,session=inflight.session,serial=inflight.serial,source=inflight.source,
        submitted_seconds=inflight.submitted_seconds,write_status='Unknown',reload_status='Unknown',
        state='InFlight',reason='awaiting_engine_completion'}
    end
    return {current=current,last=last,hints=hints,correlation='single_reborn_inflight_only',
      write_claim='completion callback is not reload proof'}
  end
  return api
end
return M
