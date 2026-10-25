local path=assert(arg[1],'module path required')
local M=assert(loadfile(path))()
local checks=0
local function eq(actual,expected,label)
  checks=checks+1
  assert(actual==expected,(label or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local Q,O='gameJournalQuest','gameJournalQuestObjective'
local function harness()
  local h={enabled=false,registrations=0,resolves=0,entries={}}
  h.adapter=M.new({
    enabled=function() return h.enabled end,
    observe=function(class,method,callback)
      h.registrations=h.registrations+1
      eq(class,'QuestTrackerGameController','observer class')
      eq(method,'OnStateChanges','observer method')
      h.callback=callback
    end,
    resolve=function(hash,className)
      h.resolves=h.resolves+1
      if h.onResolve then h.onResolve(hash,className) end
      if h.resolveError then error('injected journal boundary failure') end
      return h.entries[hash]
    end
  })
  function h:emit(hash,name)
    assert(self.callback,'observer not registered')
    self.callback({},hash,name or Q,'ignored-notification-option','ignored-change-type')
  end
  function h:complete(hash,kind)
    self.entries[hash]={defined=true,kind=kind or 'quest',succeeded=true}
  end
  function h:start(session)
    self.adapter:register()
    self.enabled=true
    eq(#self.adapter:drain(session or 1),0,'first drain has no initial event')
  end
  return h
end

-- Missing or silently unattached observer cannot synthesize a milestone.
do
  local h=harness()
  h.adapter:register();h.adapter:register()
  eq(h.registrations,1,'registration idempotent')
  eq(h.adapter:status():find('unconfirmed',1,true)~=nil,true,'attachment unconfirmed')
  h.enabled=true
  for i=1,10 do eq(#h.adapter:drain(1),0,'no callback no event') end
  eq(h.resolves,0,'no initial scan')
  local a=M.new({enabled=function() return true end})
  a:register();eq(#a:drain(1),0,'missing observer')
  eq(a:status():find('unavailable',1,true)~=nil,true,'missing observer status')
  local b=M.new({enabled=function() return true end,observe=function() error('missing target') end})
  b:register();eq(#b:drain(1),0,'throwing observer')
end

-- Only observed, defined, actually typed, currently succeeded entries release.
do
  local h=harness();h:start(1)
  h:complete(10);h:emit(10)
  eq(h.resolves,0,'callback never resolves game systems')
  local events=h.adapter:drain(1)
  eq(#events,1,'quest completion event')
  eq(events[1].hash,10);eq(events[1].className,Q)
  eq(events[1].kind,'quest');eq(events[1].session,1)
  eq(events[1].key,'journal:1:10','stable trigger identity')
  eq(h.resolves,1,'resolve on drain')
  eq(#h.adapter:drain(1),0,'single drain consumed')
  h:emit(10);h:emit(10)
  eq(#h.adapter:drain(1),0,'duplicate callbacks deduplicated')
  h:complete(11,'objective');h:emit(11,O)
  eq(#h.adapter:drain(1),1,'objective completion event')
  for i,value in ipairs({{}, {defined=false,kind='quest',succeeded=true},
    {defined=true,kind='quest',succeeded=false}, {defined=true,kind='quest',succeeded='true'},
    {defined=true,kind='other',succeeded=true}, {defined='true',kind='quest',succeeded=true},
    {defined=true,kind='objective',succeeded=true}}) do
    h.entries[20+i]=value;h:emit(20+i,Q)
    eq(#h.adapter:drain(1),0,'unknown/incomplete/wrong actual type rejected')
  end
  h.entries[50]=true;h:emit(50)
  eq(#h.adapter:drain(1),0,'non-table resolver evidence rejected')
  h.entries[51]=setmetatable({},{__index=function() error('unreadable result') end});h:emit(51)
  eq(#h.adapter:drain(1),0,'throwing result fields rejected')
  h:emit(60);eq(#h.adapter:drain(1),0,'absent entry unknown')
  h:complete(60);h:emit(60);eq(#h.adapter:drain(1),1,'later real success can be observed')
  h:complete(61);h:emit(61);h.entries[61].succeeded=false
  eq(#h.adapter:drain(1),0,'state is fresh at drain')
  h.resolveError=true;h:emit(62);eq(#h.adapter:drain(1),0,'resolver exception contained')
  h.resolveError=false;h:complete(62);h:emit(62);eq(#h.adapter:drain(1),1,'fault did not forge dedup state')
end

-- Strict scalar intake; the observer never invokes host enabled/resolve APIs.
do
  local h=harness();h:start(1)
  local rejected={-1,0,1.5,4294967296,math.huge,-math.huge,0/0,'10',true,{},function() end}
  for _,value in ipairs(rejected) do h:emit(value,Q) end
  for _,name in ipairs({'gameJournalInternetPage','JournalQuest','',string.rep('x',65),true,5,{value=Q}}) do
    h:emit(10,name)
  end
  eq(#h.adapter:drain(1),0,'unknown hash/class rejected')
  eq(h.resolves,0,'bad scalars never resolve')
  h:complete(4294967295);h:emit(4294967295,Q)
  eq(#h.adapter:drain(1),1,'full uint32 hash supported')
  -- Lua host-only CName boundary double: CET exposes CName.value as raw name.
  local value=assert(io.tmpfile());value:close()
  debug.setmetatable(value,{__index={value=Q},__tostring=function() error('must not stringify CName') end})
  h:complete(71);h:emit(71,value)
  eq(#h.adapter:drain(1),1,'CName value copied as scalar')
  local unknown=assert(io.tmpfile());unknown:close()
  debug.setmetatable(unknown,{__index=function() error('unresolved CName') end})
  h:emit(72,unknown);eq(#h.adapter:drain(1),0,'unknown CName rejected')
  local enabledCalls,resolveCalls=0,0
  local callback
  local a=M.new({enabled=function() enabledCalls=enabledCalls+1;return true end,
    observe=function(_,_,f) callback=f end,resolve=function() resolveCalls=resolveCalls+1 end})
  a:register();a:drain(1)
  local before=enabledCalls
  callback({},1,Q)
  eq(enabledCalls,before,'callback does not invoke host enabled')
  eq(resolveCalls,0,'callback does not invoke host resolve')
end

-- Disabled/unknown/session changes discard observations, never transfer them.
do
  local h=harness();h.adapter:register();h:complete(1);h:emit(1)
  eq(#h.adapter:drain(1),0,'default off')
  h.enabled=true;eq(#h.adapter:drain(1),0,'enabling does not replay')
  h:emit(1);h.enabled=false
  eq(#h.adapter:drain(1),0,'disable drops buffered event')
  h.enabled=true;eq(#h.adapter:drain(1),0,'reenable only rearms')
  h:emit(1);eq(#h.adapter:drain(2),0,'session change discards old event')
  h:emit(1);eq(#h.adapter:drain(2),1,'new session event accepted')
  h:complete(2);h:emit(2);eq(#h.adapter:drain(nil),0,'unknown session drops')
  h:emit(2);eq(#h.adapter:drain(2),0,'unknown session callback not rebound')
  h:emit(2);eq(#h.adapter:drain(2),1,'later confirmed session event accepted')
  h:complete(3);h:emit(3);h.adapter:clear()
  eq(#h.adapter:drain(2),0,'clear removes buffered event')
  h:emit(3);eq(#h.adapter:drain(2),1,'clear rearm accepts new callback')
  h.adapter:clear();eq(#h.adapter:drain(2),0,'pause clear only rearms')
  h:emit(3);eq(#h.adapter:drain(2),0,'pause clear preserves session dedup')
  h.enabled=false;eq(#h.adapter:drain(2),0,'disable only disarms')
  h.enabled=true;eq(#h.adapter:drain(2),0,'reenable only rearms')
  h:emit(3);eq(#h.adapter:drain(2),0,'off/on preserves session dedup')
  eq(#h.adapter:drain(nil),0,'unknown token disarms')
  eq(#h.adapter:drain(2),0,'same known token rearms')
  h:emit(3);eq(#h.adapter:drain(2),0,'unknown token preserves known-session dedup')
  for _,value in ipairs({0,-1,1.5,'2',true,math.huge,0/0}) do
    h:emit(3);eq(#h.adapter:drain(value),0,'invalid session fail closed')
  end
end

-- Entire ambiguous overflow batch drops; exact limits remain bounded.
do
  local h=harness();h:start(1)
  for i=1,64 do h:complete(i);h:emit(i) end
  eq(#h.adapter:drain(1),64,'64 callback capacity')
  for i=65,129 do h:complete(i);h:emit(i) end
  eq(#h.adapter:drain(1),0,'65th event invalidates entire batch')
  eq(h.resolves,64,'overflow resolves nothing')
  h:emit(65);eq(#h.adapter:drain(1),1,'overflow clears on drain')
  for i=66,128 do h:emit(i) end
  eq(#h.adapter:drain(1),63,'fill bounded dedup set')
  h:emit(1);h:emit(129)
  eq(#h.adapter:drain(1),0,'dedup saturation suppresses further session events')
  eq(h.resolves,128,'saturated dedup never rescans or evicts')
  eq(h.adapter:status():find('dedup 128/128',1,true)~=nil,true,'bounded dedup status')
  eq(#h.adapter:drain(2),0,'new session resets dedup without initial event')
  h:emit(129);eq(#h.adapter:drain(2),1,'new session can observe further milestones')
end

-- Reentrant interruptions or a changed opt-in cannot publish stale drain data.
do
  local h=harness();h:start(1);h:complete(1);h:emit(1)
  h.onResolve=function() h.adapter:clear() end
  eq(#h.adapter:drain(1),0,'reentrant clear invalidates in-flight resolution')
  h.onResolve=nil;eq(#h.adapter:drain(1),0,'clear rearms without replay')
  h:emit(1);eq(#h.adapter:drain(1),1,'discarded resolution did not claim completion')
  h:complete(2);h:emit(2)
  h.onResolve=function() h.onResolve=nil;h.adapter:drain(2) end
  eq(#h.adapter:drain(1),0,'reentrant new-session drain invalidates outer drain')
  h:emit(2);eq(#h.adapter:drain(2),1,'new session still owns intake')
  h:complete(3);h:emit(3)
  h.onResolve=function() h.enabled=false end
  eq(#h.adapter:drain(2),0,'disabled during resolution cannot publish')
  eq(h.adapter:status():find('off/unknown',1,true)~=nil,true,'mid-drain disable disarms')
  h.onResolve=nil;h.enabled=true;eq(#h.adapter:drain(2),0,'reenable does not replay discarded batch')
  h:complete(4);h:complete(5);h:emit(4);h:emit(5)
  h.onResolve=function(hash) if hash==5 then h.adapter:clear() end end
  eq(#h.adapter:drain(2),0,'later interruption invalidates entire unpublished result batch')
end

-- Malformed enabled dependency remains fail closed and observers return nil.
do
  local callback
  local a=M.new({enabled=function() error('not ready') end,
    observe=function(_,_,f) callback=f end,resolve=function() error('must not resolve') end})
  a:register();eq(#a:drain(1),0,'throwing enabled')
  eq(callback({},1,Q),nil,'observer supplies no return value')
  eq(#a:drain(1),0,'error cannot arm intake')
  local b=M.new({enabled=function() return 'true' end})
  b:register();eq(#b:drain(1),0,'truthy enabled is not explicit opt-in')
end

print('quest_milestones: '..checks..' assertions passed')
