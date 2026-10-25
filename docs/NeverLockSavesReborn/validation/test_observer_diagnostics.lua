-- Public read-only diagnostics against actual observer modules; no Game/CET/IO.
local dir=assert(arg[1],'module directory required')
local Bridge=assert(loadfile(dir..'/guardian_bridge.lua'))()
local Quest=assert(loadfile(dir..'/quest_milestones.lua'))()
local n=0
local function check(value,label) n=n+1;assert(value,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' != '..tostring(b)) end
local function scalarCopy(value)
  check(type(value)=='table' and getmetatable(value)==nil,'plain diagnostics table')
  for key,item in pairs(value) do
    check(type(key)=='string','field names only')
    check(type(item)=='boolean' or type(item)=='number','bounded scalar only')
    if type(item)=='number' then check(item==item and item>=0 and item<=2147483647 and item%1==0,'finite bounded count') end
  end
end
local callbacks,reads={},0
local enabled=true
local ledger={begin=function() error('private/path error must not be exported') end,bridge_gap=function()end}
local bridge=Bridge.new(ledger,{
 enabled=function()reads=reads+1;return enabled end,
 session=function()reads=reads+1;return 12 end,
 ObserveBefore=function(class,method,fn)callbacks['before:'..class..'.'..method]=fn end,
 ObserveAfter=function(class,method,fn)callbacks['after:'..class..'.'..method]=fn end})
local initialStatus=bridge:status()
local d=bridge:diagnostics()
scalarCopy(d)
eq(d.attempted,false,'registration not inferred')
eq(d.requested,0,'no requested observers initially')
eq(d.observed,0,'no observed callbacks initially')
eq(d.unconfirmed,0,'no outstanding registration initially')
eq(d.capacity,128,'fixed buffer capacity')
eq(reads,0,'diagnostics never consult host APIs')
eq(bridge:status(),initialStatus,'diagnostics preserve legacy status')
d.requested=99;d.inject='private'
eq(bridge:diagnostics().requested,0,'returned table cannot mutate bridge')
eq(bridge:diagnostics().inject,nil,'injected fields cannot persist')
bridge:register()
d=bridge:diagnostics();scalarCopy(d)
eq(d.attempted,true,'attempted registration recorded')
eq(d.requested,10,'ten fixed observer registrations requested')
eq(d.observed,0,'registration is not callback observation')
eq(d.unconfirmed,10,'all registrations initially unconfirmed')
local onManual=assert(callbacks['before:PauseMenuGameController.HandlePressToSaveGame'])
onManual({})
d=bridge:diagnostics();eq(d.observed,1,'unique target observed')
eq(d.unconfirmed,9,'unconfirmed count derived without success claim')
eq(d.buffered,1,'scalar evidence buffered')
local readCount=reads;local priorStatus=bridge:status()
for _=1,100 do bridge:diagnostics() end
eq(reads,readCount,'repeated diagnostics never reenter injected APIs')
eq(bridge:status(),priorStatus,'repeated diagnostics do not drain or change status')
for _=1,128 do onManual({}) end
d=bridge:diagnostics();eq(d.buffered,0,'overflow discards ambiguous batch')
eq(d.overflow,true,'overflow signaled');eq(d.dropped,129,'dropped count retained')
bridge:drain(12)
eq(bridge:diagnostics().overflow,false,'drain consumes existing overflow state')
onManual({});bridge:drain(12)
d=bridge:diagnostics();eq(d.ledgerFaults,1,'ledger fault counted without error text')
scalarCopy(d)
bridge:clear();eq(bridge:diagnostics().buffered,0,'clear retains empty buffer')
eq(bridge:diagnostics().ledgerFaults,1,'diagnostics do not erase fault evidence')
local unavailable=Bridge.new({},{});unavailable:register()
eq(unavailable:diagnostics().unavailable,10,'missing registration boundaries counted')
eq(unavailable:diagnostics().requested,0,'missing boundaries cannot appear requested')

local callback,questReads,resolves=nil,0,0
local quest=Quest.new({observe=function(_,_,fn)callback=fn end,
 enabled=function()questReads=questReads+1;return true end,
 resolve=function()resolves=resolves+1;return {defined=true,kind='quest',succeeded=true}end})
local q=quest:diagnostics();scalarCopy(q)
eq(q.attempted,false,'quest registration initially unattempted')
eq(q.requested,false,'quest observer not yet requested')
eq(q.callbackObserved,false,'quest callback not yet observed')
eq(q.armed,false,'quest intake initially disarmed')
eq(q.capacity,64,'quest buffer bounded')
eq(q.dedupCapacity,128,'quest dedup bounded')
quest:register();q=quest:diagnostics()
eq(q.attempted,true,'quest registration attempted')
eq(q.requested,true,'quest registration request recorded')
eq(q.callbackObserved,false,'registration alone is not observed attachment')
quest:drain(23)
callback({},7,'gameJournalQuest')
q=quest:diagnostics();eq(q.callbackObserved,true,'quest callback observation explicit')
eq(q.buffered,1,'quest event buffered');eq(q.resolved,0,'callback alone is unresolved')
local oldReads,oldResolves,status=questReads,resolves,quest:status()
for _=1,100 do quest:diagnostics() end
eq(questReads,oldReads,'quest diagnostics do not query enable boundary')
eq(resolves,oldResolves,'quest diagnostics do not resolve journal entries')
eq(quest:status(),status,'quest diagnostics preserve status and buffer')
eq(#quest:drain(23),1,'ordinary drain behavior unchanged')
q=quest:diagnostics();eq(q.resolved,1,'resolved observations counted')
eq(q.dedupCount,1,'dedup count visible')
q.dedupCount=0;eq(quest:diagnostics().dedupCount,1,'quest snapshots cannot mutate dedup')
quest:clear();q=quest:diagnostics()
eq(q.armed,false,'interruption disarms intake')
eq(q.dedupCount,1,'same-session dedup survives interruption')
scalarCopy(q)
local noQuest=Quest.new({});noQuest:register()
eq(noQuest:diagnostics().unavailable,true,'missing quest registration boundary visible')
eq(noQuest:diagnostics().requested,false,'missing quest boundary cannot be requested')
print('PASS observer diagnostics: '..n..' assertions; read-only getters and legacy behavior')
