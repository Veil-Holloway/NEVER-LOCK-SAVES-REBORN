#!/usr/bin/env python3
"""Independent autosave bridge invariants through bounded actual source.
The Python evaluator is deliberately limited; this is not compilation/gameplay.
"""
import argparse,hashlib,itertools,json
from pathlib import Path
from types import SimpleNamespace as O
from source_subset import compile_function
p=argparse.ArgumentParser();p.add_argument('release',type=Path);a=p.parse_args()
path=a.release/'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds'
source=path.read_text();state={};game=O();calls=[];failures=[];cases=0
def force():
    calls.append('request')
    if state.get('reenter'):
        state['reentrant_result']=methods['NLSRebornDeferredDispatch'](state['player'],state['player'].nlsDeferredSerial)
    return True
ns={'__builtins__':{},'IsDefined':lambda v:v is not None,'ArraySize':len,'Equals':lambda a,b:a==b,'NotEquals':lambda a,b:a!=b}
ns['GameInstance']=O(
    GetQuestsSystem=lambda game:None if state['done'] is None else O(GetFact=lambda fact:state['done']),
    GetTimeSystem=lambda game:None if state['paused'] is None else O(IsPausedState=lambda:state['paused']),
    IsSavingLocked=lambda game,locks:state['locked'],
    GetAutoSaveSystem=lambda game:O(RequestForcedCheckpoint=force) if state['autosave_service'] else None,
    GetBlackboardSystem=lambda game:None if state['menu'] is None else O(Get=lambda key:None if state['menu']=='missing_board' else O(GetBool=lambda field:state['menu'])))
ns['GetAllBlackboardDefs']=lambda:O(UI_System=O(IsInMenu='menu'))
ns['VehicleComponent']=O(IsMountedToVehicle=lambda game,player:state['mounted'])
ns['NLSRebornPolicy']=O(GetImmersionSaveContext=lambda game:0,NotifyImmersionSaveRequest=lambda *x:None,CheckpointMessage=lambda *x:'request')
ns['PauseMenuGameController']=O(NLSRebornNotify=lambda *x:None)
names=('NLSRebornDeferredIntroComplete','NLSRebornDeferredSetEnabled','NLSRebornDeferredQueue',
       'NLSRebornPausedState','NLSRebornMenuState','NLSRebornMountedState','NLSRebornAutosaveSetEnabled',
       'NLSRebornAutosaveReady','NLSRebornAutosaveQueue','NLSRebornDeferredNativeUnlocked',
       'NLSRebornDeferredDispatch')
if 'func NLSRebornRequestCheckpoint(' in source:
    names += ('NLSRebornRequestCheckpoint','NLSRebornCheckpointFailure')
methods={n:compile_function(source,n,ns,instance=True) for n in names}

def fixture(**changes):
    state.clear();state.update(mode=3,enabled=True,manual=False,done=1,locked=False,paused=False,menu=False,phone=0,
                               mounted=False,combat=False,protected=False,autosave_service=True,reenter=False)
    state.update(changes);calls.clear()
    player=O(GetGame=lambda:game,nlsAutosaveEnabled=state['enabled'],nlsDeferredEnabled=state['manual'],
             nlsRebornSafetyBlock=state['protected'],nlsDeferredPending=False,nlsDeferredSerial=42,
             nlsDeferredSource=0,NLSRebornGetMode=lambda:state['mode'],IsInCombat=lambda:state['combat'],
             NLSRebornNotificationPhoneState=lambda:state['phone'])
    player.nlsCheckpointSerial=0;player.nlsCheckpointSource=0;player.nlsCheckpointResult=0
    player.nlsCheckpointLocks='unknown';player.nlsCheckpointCombat=-1;player.nlsCheckpointMounted=-1
    player.NLSRebornSaveLockSummary=lambda:'locked' if state['locked'] else 'unlocked'
    player.NLSRebornGetNotificationsEnabled=lambda:False
    player.NLSRebornGetTone=lambda:0
    state['player']=player
    for n,fn in methods.items():
        setattr(player,n,lambda *args,_fn=fn:_fn(player,*args))
    return player

def check(label,condition,detail=None):
    global cases
    cases+=1
    if not condition:failures.append({'label':label,'detail':detail})

# Invalid/unknown or active safety signals may never enqueue/submit.
for enabled,manual,done,locked,paused,menu,phone,mounted,combat,protected in itertools.product(
    (False,True),(False,True),(None,0,1),(False,True),(None,False,True),(None,'missing_board',False,True),(-1,0,1),(False,True),(False,True),(False,True)):
    player=fixture(enabled=enabled,manual=manual,done=done,locked=locked,paused=paused,menu=menu,phone=phone,
                   mounted=mounted,combat=combat,protected=protected)
    expected=bool(enabled and done==1 and not locked and paused is False and menu is False and phone==0 and not mounted and not combat and not protected)
    label=dict(enabled=enabled,manual=manual,done=done,locked=locked,paused=paused,menu=menu,phone=phone,
               mounted=mounted,combat=combat,protected=protected)
    try:actual=player.NLSRebornAutosaveReady();queued=player.NLSRebornAutosaveQueue();error=None
    except Exception as e:actual=queued=None;error=type(e).__name__+': '+str(e)
    check('readiness-and-enqueue',actual is expected and queued is expected and error is None,label)
    check('queue-side-effects',player.nlsDeferredPending is expected and player.nlsDeferredSerial==(43 if expected else 42) and player.nlsDeferredSource==(3 if expected else 0),label)
    # Force a stale queued token and demand current readiness is checked again.
    player.nlsDeferredPending=True;player.nlsDeferredSource=3;player.nlsDeferredSerial=50
    try:submitted=player.NLSRebornDeferredDispatch(50);error=None
    except Exception as e:submitted=None;error=type(e).__name__+': '+str(e)
    check('dispatch-fresh-readiness',submitted is expected and len(calls)==int(expected) and error is None,label)
    check('dispatch-consumes-once',player.nlsDeferredPending is (not expected),label)
    if expected:
        check('repeat-dispatch-denied',player.NLSRebornDeferredDispatch(50) is False and len(calls)==1)

# Manual requests win over automation; no automatic replacement of pending work.
for source in (1,2,3,999):
    player=fixture();player.nlsDeferredPending=True;player.nlsDeferredSource=source
    check('auto-never-replaces-pending',player.NLSRebornAutosaveQueue() is False and player.nlsDeferredSource==source and player.nlsDeferredSerial==42,source)
for source in (1,2):
    player=fixture(manual=True);player.NLSRebornAutosaveQueue();old=player.nlsDeferredSerial
    check('manual-replaces-auto',player.NLSRebornDeferredQueue(source) is True and player.nlsDeferredSource==source and player.nlsDeferredSerial==old+1,source)
    check('stale-auto-token-denied',player.NLSRebornDeferredDispatch(old) is False and not calls)

# Disabling one lane must not cancel unrelated pending work.
for source in (1,2,3):
    player=fixture(manual=True);player.nlsDeferredPending=True;player.nlsDeferredSource=source
    player.NLSRebornAutosaveSetEnabled(False)
    check('auto-disable-scope',player.nlsDeferredPending is (source!=3),source)
    player=fixture(manual=True);player.nlsDeferredPending=True;player.nlsDeferredSource=source
    player.NLSRebornDeferredSetEnabled(False)
    check('manual-disable-scope',player.nlsDeferredPending is (source==3),source)

# Unknown source IDs cannot enter or dispatch a manual lane.
for source in (0,-1,3,999):
    player=fixture(manual=True)
    check('manual-source-validation',player.NLSRebornDeferredQueue(source) is False and not player.nlsDeferredPending,source)
for source in (0,-1,999):
    player=fixture(manual=True);player.nlsDeferredPending=True;player.nlsDeferredSource=source
    check('dispatch-source-validation',player.NLSRebornDeferredDispatch(42) is False and not calls,source)

# A callback reentering dispatch cannot cause a duplicate submission.
player=fixture(reenter=True);player.NLSRebornAutosaveQueue()
check('dispatch-reentrancy',player.NLSRebornDeferredDispatch(43) is True and len(calls)==1 and state.get('reentrant_result') is False)
# Service absence must not lose a queued request or throw.
player=fixture(autosave_service=False);player.NLSRebornAutosaveQueue()
try:submitted=player.NLSRebornDeferredDispatch(43);error=None
except Exception as e:submitted=None;error=type(e).__name__+': '+str(e)
check('absent-autosave-service',submitted is False and player.nlsDeferredPending is True and not calls and error is None,{'actual':submitted,'pending':player.nlsDeferredPending,'error':error})

print(json.dumps({'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                  'scope':'bounded actual-source evaluation; external service doubles; not compiler/game evidence',
                  'assertions':cases,'failed':len(failures),'first_failures':failures[:25]},indent=2))
raise SystemExit(bool(failures))

