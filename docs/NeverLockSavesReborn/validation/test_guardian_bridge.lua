local modulePath=assert(arg[1],'pass guardian_bridge.lua')
local realLedgerPath=arg[2]
local bridgeModule=assert(loadfile(modulePath))()
local checks=0
local function eq(actual,expected,label)
  checks=checks+1;assert(actual==expected,label..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function check(value,label) checks=checks+1;assert(value,label) end
local function fixture()
  local f={enabled=false,session=1,callbacks={},calls={},registrations=0,nextId=0}
  local ledger={}
  for _,name in ipairs({'begin','returned','queued','close','hint','bridge_gap'}) do
    local method=name
    ledger[method]=function(self,...)
      local record={kind=method,args={...}}
      f.calls[#f.calls+1]=record
      if f.ledgerFault then error('injected ledger failure') end
      if method=='begin' or method=='queued' then f.nextId=f.nextId+1;record.id=f.nextId;return f.nextId end
    end
  end
  local function register(kind,class,method,callback)
    f.registrations=f.registrations+1
    f.callbacks[kind..':'..class..'.'..method]=callback
    return 'not an attachment acknowledgement'
  end
  local api={enabled=function() return f.enabled end,session=function() return f.session end,
    ObserveBefore=function(...) return register('before',...) end,
    ObserveAfter=function(...) return register('after',...) end}
  f.bridge=bridgeModule.new(ledger,api);f.api=api
  function f:fire(kind,class,method,...)
    local cb=assert(self.callbacks[kind..':'..class..'.'..method],'missing callback')
    eq(cb(...),nil,'observer returns no value')
  end
  function f:events(kind)
    local found={};for _,call in ipairs(self.calls) do if call.kind==kind then found[#found+1]=call end end
    return found
  end
  function f:queue(player,source,accepted)
    self:fire('before','PlayerPuppet','NLSRebornDeferredQueue',player,source)
    if accepted then player.nlsDeferredSerial=player.nlsDeferredSerial+1;player.nlsDeferredPending=true end
    self:fire('after','PlayerPuppet','NLSRebornDeferredQueue',player,source,false)
  end
  return f
end
local player={nlsDeferredSerial=0,nlsDeferredPending=false}
local f=fixture();f.bridge.register();f.bridge.register();eq(f.registrations,10,'registration idempotent')
check(f.bridge.status():find('unconfirmed 10',1,true),'registration stays unconfirmed')
f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{})
f.bridge.drain(1);eq(#f.calls,0,'disabled tracking records nothing')
f.enabled=true
f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{})
f:queue(player,1,true)
f:fire('after','PauseMenuGameController','HandlePressToSaveGame',{})
eq(#f.calls,0,'callback performs no ledger work before drain')
f.bridge.drain(1)
eq(#f:events('begin'),1,'one wrapper begin')
eq(#f:events('queued'),1,'queue mutation observed')
eq(f:events('queued')[1].args[1],f:events('begin')[1].id,'queue linked to wrapper id')
eq(f:events('queued')[1].args[2],'manual','manual source retained')
eq(f:events('queued')[1].args[3],1,'session linked')
eq(f:events('queued')[1].args[4],1,'serial copied')
eq(#f:events('returned'),1,'wrapper returned')
check(f.bridge.status():find('callback targets observed 4',1,true),'callback evidence confirms only observed targets')
-- Nested wrappers pair the queue with the innermost request, never the latest time.
f.calls={};player.nlsDeferredPending=true
f:fire('before','PauseMenuGameController','HandlePressToQuickSaveGame',{})
f:fire('before','gameuiInGameMenuGameController','HandleQuickSave',{})
f:queue(player,2,true)
f:fire('after','gameuiInGameMenuGameController','HandleQuickSave',{})
f:fire('after','PauseMenuGameController','HandlePressToQuickSaveGame',{})
f.bridge.drain(1)
local begins=f:events('begin');local queued=f:events('queued')[1]
eq(#begins,2,'nested begins retained')
eq(queued.args[1],begins[2].id,'queue uses innermost wrapper id')
eq(queued.args[2],'gameplay_quicksave','nested source retained')
eq(#f:events('close'),1,'replacement closes prior pending request')
eq(f:events('close')[1].args[2],1,'old serial closed')
eq(f:events('close')[1].args[3],'Cancelled','replacement state explicit')
eq(f:events('close')[1].args[4],'replaced','replacement reason explicit')
eq(f:events('returned')[1].args[1],begins[2].id,'inner returns first')
eq(f:events('returned')[2].args[1],begins[1].id,'outer returns second')
-- A queue outside any wrapper has no request attribution.
f.calls={};f:queue(player,2,true);f.bridge.drain(1)
eq(f:events('queued')[1].args[1],nil,'unwrapped queue has no guessed wrapper')
eq(f:events('queued')[1].args[2],'quicksave','unwrapped source decoded')
-- A rejected queue is not treated as accepted due to an observer return argument.
f.calls={};f:queue(player,2,false);f.bridge.drain(1);eq(#f:events('queued'),0,'unchanged serial never queued')
-- Engine hints retain only source and Boolean; self and lock userdata are ignored.
f.calls={};local dangerous=setmetatable({},{__index=function() error('must not read engine object') end})
f:fire('after','PauseMenuGameController','OnSavingComplete',dangerous,true,dangerous)
f:fire('after','gameuiInGameMenuGameController','OnSavingComplete',dangerous,false,dangerous)
f:fire('after','gameuiInGameMenuGameController','OnSavingComplete',dangerous,'unknown',dangerous)
eq(#f.calls,0,'hints buffered before drain');f.bridge.drain(1)
eq(#f:events('hint'),3,'uncorrelated hints retained')
eq(f:events('hint')[1].args[2],true,'success Boolean copied')
eq(f:events('hint')[2].args[2],false,'failure Boolean copied')
eq(f:events('hint')[3].args[2],nil,'invalid hint remains unknown')
eq(f:events('hint')[1].args[1],'save_notification','pause hint origin matches ledger whitelist')
eq(f:events('hint')[2].args[1],'game_notification','gameplay hint origin matches ledger whitelist')
eq(#f:events('returned'),0,'hint does not finish a request')
-- All direct scalar field access is contained and never invokes mod methods.
f.calls={};f:queue(dangerous,1,false);f.bridge.drain(1)
eq(#f:events('queued'),0,'invalid fields cannot claim acceptance')
check(#f:events('bridge_gap')>0,'invalid fields signal gap')
-- Session zero and stale-session buffers are discarded rather than reassigned.
for _,s in ipairs({0,2}) do
  f.calls={};f.session=s
  f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{})
  f:fire('after','PauseMenuGameController','HandlePressToSaveGame',{})
  f.bridge.drain(1)
  eq(#f:events('begin'),0,'mismatched session never begins')
  check(#f:events('bridge_gap')>0,'mismatched session signals gap')
end
f.session=1;f.calls={}
f:fire('after','PauseMenuGameController','HandlePressToSaveGame',{})
f.bridge.drain(1);eq(#f:events('returned'),0,'unmatched return has no fake id')
check(#f:events('bridge_gap')>0,'unmatched return signals gap')
-- Overflow resets both transports and attribution stacks.
f.calls={}
for i=1,140 do f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{}) end
f.bridge.drain(1)
eq(#f:events('begin'),0,'overflow batch discarded')
eq(#f:events('bridge_gap'),1,'overflow produces one gap')
check(f.bridge.status():find('buffered 0',1,true),'buffer remains bounded and drained')
f.calls={};f:fire('after','PauseMenuGameController','HandlePressToSaveGame',{});f.bridge.drain(1)
eq(#f:events('returned'),0,'overflow leaves no stale stack')
f.calls={};f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{});f.bridge.clear();f.bridge.drain(1)
eq(#f.calls,0,'clear drops events and stacks')
-- Missing observers, silent native registration, throwing APIs and ledger faults.
local missing=bridgeModule.new({},{});check(pcall(missing.register),'missing observers contained')
check(missing.status():find('unavailable 10',1,true),'missing observer count visible')
local silent=bridgeModule.new({}, {enabled=function()return true end,session=function()return 1 end,
 ObserveBefore=function()end,ObserveAfter=function()end});silent.register()
check(silent.status():find('unconfirmed 10',1,true),'silent registrations remain unconfirmed')
local throwing=bridgeModule.new({}, {ObserveBefore=function()error('registration failure')end,ObserveAfter=function()error('registration failure')end})
check(pcall(throwing.register),'registration errors contained')
check(throwing.status():find('unavailable 10',1,true),'registration failures visible')
local badApi=bridgeModule.new({},setmetatable({},{__index=function()error('hostile observer getter')end}))
check(pcall(badApi.register),'observer method lookup error contained')
check(badApi.status():find('unavailable 10',1,true),'hostile observer getter visible')
f.calls={};f.ledgerFault=true
f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{})
f:fire('after','PauseMenuGameController','HandlePressToSaveGame',{})
check(pcall(f.bridge.drain,1),'ledger errors never escape drain')
check(f.bridge.status():find('ledger faults 1',1,true),'ledger fault visible')
local hostile=bridgeModule.new(setmetatable({},{__index=function()error('hostile method getter')end}),f.api)
hostile.register()
f:fire('before','PauseMenuGameController','HandlePressToSaveGame',{})
check(pcall(hostile.drain,1),'hostile ledger method lookup contained')
check(hostile.status():find('ledger faults 1',1,true),'hostile getter fault visible')
if realLedgerPath then
  local real=assert(loadfile(realLedgerPath))().new('bridge_test');real:set_enabled(true)
  local realCallbacks={}
  local realBridge=bridgeModule.new(real,{enabled=function()return true end,session=function()return 1 end,
    ObserveBefore=function(class,method,cb)realCallbacks['before:'..class..'.'..method]=cb end,
    ObserveAfter=function(class,method,cb)realCallbacks['after:'..class..'.'..method]=cb end})
  realBridge.register()
  realCallbacks['after:PauseMenuGameController.OnSavingComplete']({},false,{})
  realCallbacks['after:gameuiInGameMenuGameController.OnSavingComplete']({},true,{})
  realCallbacks['after:gameuiInGameMenuGameController.OnSavingComplete']({},nil,{})
  realBridge.drain(1)
  local report=real:report();local hints=report.uncorrelated_hints
  eq(hints[1].outcome,'FailureHint','real ledger preserves false failure hint')
  eq(hints[1].origin,'save_notification','real ledger preserves pause origin')
  eq(hints[2].outcome,'SuccessHint','real ledger preserves true success hint')
  eq(hints[2].origin,'game_notification','real ledger preserves gameplay origin')
  eq(hints[3].outcome,'Unknown','real ledger unknown hint stays unknown')
  eq(hints[1].correlated,false,'real ledger hint uncorrelated')
  eq(hints[1].write_status,'Unknown','real ledger hint never proves file write')
  eq(#report.records,0,'real ledger completion hint creates no fake request')
end
local file=assert(io.open(modulePath,'r'));local source=file:read('*a');file:close()
check(not source:find('Game%.') and not source:find('io%.') and not source:find('os%.'),'module has no game/global IO calls')
print('PASS '..checks..' Guardian bridge assertions; observer/ledger boundary doubles, no game runtime')
