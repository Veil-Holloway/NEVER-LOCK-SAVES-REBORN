-- Independent event->scheduler checks with a real pure scheduler and boundary doubles.
local module=assert(arg[1],'quest_milestones.lua required')
local scheduler=assert(arg[2],'autosave_policy.lua required')
local Q=dofile(module)
local A=dofile(scheduler)
local n=0
local function eq(a,b,label) n=n+1;assert(a==b,label..': '..tostring(a)..' != '..tostring(b)) end
local callback,enabled,enabledCalls,resolveCalls=nil,true,0,0
local states={}
local adapter=Q.new({observe=function(class,method,fn)
 eq(class,'QuestTrackerGameController','actual observer class');eq(method,'OnStateChanges','actual observer method');callback=fn
end,enabled=function() enabledCalls=enabledCalls+1;return enabled end,
resolve=function(hash,className)
 resolveCalls=resolveCalls+1
 local state=states[hash]
 if state==1 then return {defined=true,succeeded=true,kind='quest'} end
 if state==2 then return {defined=true,succeeded=true,kind='objective'} end
 return nil
end})
local autosave=A.new()
assert(A.configure(autosave,{enabled=true,questMilestone=true,exploration=false,postCombat=false,vehicleExit=false,cooldownSeconds=30}))
local session=1
local snapshot={session=1,playerReady=true,bridgeReady=true,introComplete=true,
 paused=false,combatKnown=true,combatActive=false,vehicleKnown=true,vehicleActive=false,
 phoneKnown=true,phoneActive=false,nativeUnlocked=true,stableReady=true,queueBusy=false,questMilestone=false}
local queued=0
local function tick(delta,patch)
 for k,v in pairs(patch or {}) do snapshot[k]=v end
 local events=adapter:drain(session)
 snapshot.questMilestone=#events>0
 return A.tick(autosave,delta,snapshot,function(reason,expected)
  eq(reason,'quest_milestone','only fresh journal event asks scheduler');eq(expected,session,'matching runtime session')
  queued=queued+1;return true
 end)
end
local function advance(count) for _=1,count do tick(0.25) end end
adapter:register();adapter:drain(session)
-- Thousands of old succeeded rows do not get scanned or synthesize work.
for i=1,5000 do states[i]=1 end
advance(125)
eq(resolveCalls,0,'no initial/resume scan of completed journal');eq(queued,0,'old completion never queues')
local beforeEnabled,beforeResolves=enabledCalls,resolveCalls
eq(callback({},2,'gameJournalQuest'),nil,'observer has no return value')
eq(enabledCalls,beforeEnabled,'observer does not call enabled');eq(resolveCalls,beforeResolves,'observer does not resolve')
eq(tick(0.25),'queue_request_accepted','fresh quest event accepted after cooldown');eq(queued,1,'exactly one queue handoff')
callback({},2,'gameJournalQuest');advance(125)
eq(queued,1,'duplicate remains suppressed after cooldown')
adapter:clear();adapter:drain(session);callback({},2,'gameJournalQuest');tick(0.25)
eq(queued,1,'suspend preserves completed-entry dedup')
enabled=false;adapter:drain(session);enabled=true;adapter:drain(session)
callback({},2,'gameJournalQuest');tick(0.25)
eq(queued,1,'disable reenable preserves dedup')
-- A valid callback with wrong resolved actual class cannot enqueue.
states[3]=2;callback({},3,'gameJournalQuest');tick(0.25)
eq(queued,1,'actual objective cannot satisfy quest class callback')
callback({},3,'gameJournalQuestObjective');tick(0.25)
eq(queued,2,'actual objective accepted when callback class matches')
-- Resolver is fresh: a no-longer-succeeded entry is discarded at drain.
advance(125);states[4]=1;callback({},4,'gameJournalQuest');states[4]=0;tick(0.25)
eq(queued,2,'stale success not promoted')
-- A whole overflow batch is discarded before resolving any entries.
local before=resolveCalls
for i=100,164 do callback({},i,'gameJournalQuest') end
tick(0.25)
eq(resolveCalls,before,'overflow resolves no partial batch');eq(queued,2,'overflow no handoff')
-- Work collected under another session never acquires current-player identity.
callback({},5,'gameJournalQuest');session=2;snapshot.session=2;tick(0.25)
eq(queued,2,'old session event discarded');advance(125)
callback({},2,'gameJournalQuest');tick(0.25)
eq(queued,3,'different positive session owns separate dedup')
-- Unknown current session disarms intake without replay on recovery.
callback({},6,'gameJournalQuest');eq(#adapter:drain(nil),0,'unknown session drops pending')
callback({},7,'gameJournalQuest');adapter:drain(session);advance(125)
eq(queued,3,'callbacks while disarmed cannot replay')
-- Queue priority suppresses event work instead of replacing player work.
callback({},8,'gameJournalQuest');tick(0.25,{queueBusy=true})
eq(queued,3,'player pending queue has priority');tick(0.25,{queueBusy=false});advance(125)
eq(queued,3,'player work does not cause deferred event burst')
-- Native lock can hold a fresh milestone until a safe stable sample appears.
callback({},9,'gameJournalQuest');tick(0.25,{nativeUnlocked=false})
eq(queued,3,'locked event not dispatched');tick(0.25,{nativeUnlocked=true,stableReady=false})
eq(queued,3,'unstable event not dispatched');tick(0.25,{stableReady=true})
eq(queued,4,'fresh pending event releases only after gates')
eq(A.status(autosave).written,'Unknown','handoff not written evidence')
eq(A.status(autosave).reload,'Unknown','handoff not reload evidence')
print('PASS independent quest handshake: '..n..' assertions')
