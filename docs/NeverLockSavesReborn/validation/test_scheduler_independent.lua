-- Independent scheduler checks through its public API. Lua host, not CET/game.
-- Usage: texlua test_scheduler_independent.lua /absolute/path/autosave_policy.lua
local m=assert(loadfile(assert(arg[1])))()
local assertions,calls,time,last=0,0,0,nil
local function check(value,label)
  assertions=assertions+1; assert(value,label)
end
local function base()
  return {session=7,playerReady=true,introComplete=true,bridgeReady=true,
    paused=false,nativeUnlocked=true,stableReady=true,queueBusy=false,
    combatKnown=true,combatActive=false,vehicleKnown=true,vehicleActive=false,
    phoneKnown=true,phoneActive=false}
end
local function make(options)
  local s=m.new()
  check(m.configure(s,options or {enabled=true,intervalSeconds=60,cooldownSeconds=30}),'configure')
  return s,base()
end
local function tick(s,p,callback,delta)
  time=time+(delta or 0.25)
  return m.tick(s,delta or 0.25,p,callback)
end
local function steps(s,p,count,callback)
  for _=1,count do tick(s,p,callback) end
end

-- Independently check every callback against the public safety contract, then
-- count a long sequence with each accepted request separated by >=30s.
local s,p=make()
local function accept(reason,session)
  check(session==7,'exact current session')
  check(p.playerReady==true and p.introComplete==true and p.bridgeReady==true,'positive lifecycle')
  check(p.paused==false and p.nativeUnlocked==true and p.stableReady==true and p.queueBusy==false,'readiness')
  check(p.combatKnown==true and p.combatActive==false and p.vehicleKnown==true and p.vehicleActive==false and p.phoneKnown==true and p.phoneActive==false,'safe observations')
  check(reason=='exploration_interval' or reason=='post_combat' or reason=='vehicle_exit' or reason=='quest_milestone','known reason')
  if last then check(time-last>=30,'global minimum accepted spacing') end
  last=time;calls=calls+1;return true
end
tick(s,p,accept)
for cycle=1,30 do
  steps(s,p,300,accept) -- enough safe time to exercise interval repeatedly
  p.combatActive=true;p.nativeUnlocked=false;p.stableReady=false
  steps(s,p,120,accept)
  p.combatActive=false;p.nativeUnlocked=true;p.stableReady=true
  tick(s,p,accept)
  p.queueBusy=true;steps(s,p,8,accept);p.queueBusy=false
  steps(s,p,120,accept)
  p.vehicleActive=true;steps(s,p,120,accept)
  p.vehicleActive=false;tick(s,p,accept)
  p.paused=true;steps(s,p,20,accept);p.paused=false
  tick(s,p,accept)
end
check(calls>=30,'stress actually exercises requests')
local countStress=calls

-- A previously accumulated interval cannot fire at or after an invalid sample.
-- Restore then requires a full new observation baseline and startup cooldown.
local invalid={
  {'playerReady',false},{'introComplete',false},{'bridgeReady',false},{'paused',true},
  {'nativeUnlocked','true'},{'stableReady',1},{'queueBusy',nil},{'combatKnown',false},
  {'combatActive',0},{'vehicleKnown',false},{'vehicleActive','false'},
  {'phoneKnown',false},{'phoneActive',1},{'session',0}
}
for _,test in ipairs(invalid) do
  local q,b=make();local n=0
  local cb=function() n=n+1;return true end
  tick(q,b,cb);steps(q,b,239,cb)
  check(n==0,'just before interval')
  local saved=b[test[1]];b[test[1]]=test[2]
  tick(q,b,cb);check(n==0,'invalid deadline refuses')
  b[test[1]]=saved;tick(q,b,cb);steps(q,b,119,cb)
  check(n==0,'invalid sample rebaselines')
  check(m.status(q).written=='Unknown' and m.status(q).reload=='Unknown','no false completion evidence')
end

-- Player work re-arms the automatic cooldown even when it coincides with
-- a combat end; the disappearing user queue cannot create another request.
do
  local q,b=make({enabled=true,exploration=false,postCombat=true,vehicleExit=true,
                 intervalSeconds=60,cooldownSeconds=30});local n=0
  local cb=function()n=n+1;return true end
  tick(q,b,cb);steps(q,b,120,cb)
  b.combatActive=true;b.queueBusy=true;tick(q,b,cb)
  b.combatActive=false;b.queueBusy=false;tick(q,b,cb)
  steps(q,b,119,cb)
  check(n==0,'manual priority plus cooldown')
  b.combatActive=true;tick(q,b,cb);b.combatActive=false;tick(q,b,cb)
  check(n==1,'a new postcooldown combat edge still works')
end

-- No individually disabled trigger may request, even with every edge repeated.
do
  local q,b=make({enabled=true,exploration=false,postCombat=false,vehicleExit=false,
                 intervalSeconds=60,cooldownSeconds=30});local n=0
  local cb=function()n=n+1;return true end
  tick(q,b,cb)
  for i=1,2000 do
    b.combatActive=(i%4==0);b.vehicleActive=(i%3==0)
    tick(q,b,cb)
  end
  check(n==0,'all triggers disabled')
end

-- Disable/re-enable and a different play session cannot retain elapsed credit.
do
  local q,b=make();local n=0;local cb=function()n=n+1;return true end
  tick(q,b,cb);steps(q,b,239,cb)
  check(m.configure(q,{enabled=false}),'disable')
  steps(q,b,1000,cb);check(n==0,'disabled')
  check(m.configure(q,{enabled=true}),'enable')
  tick(q,b,cb);steps(q,b,239,cb);check(n==0,'no retained interval credit')
  b.session=8;tick(q,b,cb);steps(q,b,239,cb);check(n==0,'session resets interval')
end

-- Journal input is an individually opted-in literal event, never an initial
-- state scan. Queue handoff still carries no engine dispatch/completion claim.
for _,enabled in ipairs({false,true}) do
  local q,b=make({enabled=true,exploration=false,postCombat=false,vehicleExit=false,
    questMilestone=enabled,intervalSeconds=60,cooldownSeconds=30})
  local n=0;local cb=function(reason)
    check(reason=='quest_milestone','exact journal reason');n=n+1;return true
  end
  b.questMilestone=true;tick(q,b,cb);check(n==0,'journal event on initial baseline dropped')
  b.questMilestone=false;steps(q,b,120,cb)
  b.questMilestone='true';tick(q,b,cb);check(n==0,'truthy journal input rejected')
  b.questMilestone=true;tick(q,b,cb)
  check(n==(enabled and 1 or 0),'journal opt-in independently enforced')
  if enabled then
    check(m.status(q).status=='queue_request_accepted','queue acceptance is not engine submission')
    check(m.status(q).checkpointSubmission=='Unknown','engine submission remains unknown')
  end
  check(m.status(q).written=='Unknown' and m.status(q).reload=='Unknown','journal event not save proof')
end
do
  local q,b=make({enabled=true,exploration=false,postCombat=false,vehicleExit=false,
    questMilestone=true,intervalSeconds=60,cooldownSeconds=30})
  local n=0;local cb=function()n=n+1;return true end
  tick(q,b,cb);steps(q,b,120,cb)
  b.nativeUnlocked=false;b.questMilestone=true;tick(q,b,cb)
  check(m.status(q).pendingReason=='quest_milestone','journal event captured across short native lock')
  b.questMilestone=false;steps(q,b,120,cb)
  b.nativeUnlocked=true;tick(q,b,cb)
  check(n==0 and m.status(q).pendingReason=='none','expired journal event cannot resume later')
end
print('PASS independent scheduler assertions='..assertions..' exercised_accepted_requests='..countStress)

