#!/usr/bin/env python3
"""Independent Smart policy invariants against bounded actual source.
Not REDscript compilation/native ABI/gameplay. External service boundaries doubled.
"""
import argparse, hashlib, itertools, json
from pathlib import Path
from types import SimpleNamespace as O
from source_subset import compile_function

p=argparse.ArgumentParser()
p.add_argument('release',type=Path)
p.add_argument('--expect-gap',action='store_true')
a=p.parse_args()
path=a.release/'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds'
source=path.read_text()
state={}
game=O()
def saving_locked(game,locks):
    locks[:]=[O(reason=v) for v in state['reasons']]
    return state['locked']
ns={'__builtins__':{},'IsDefined':lambda v:v is not None,
    'ArraySize':len,'Equals':lambda x,y:x==y,'NotEquals':lambda x,y:x!=y,
    'gameSaveLockReason':O(Combat=1)}
ns['GameInstance']=O(
    GetPlayerSystem=lambda game:None if not state['player_system'] else O(GetLocalPlayerControlledGameObject=lambda:state['player']),
    GetQuestsSystem=lambda game:None if not state['quest_system'] else O(GetFact=lambda name:state['done']),
    IsSavingLocked=saving_locked)
ns['VehicleComponent']=O(IsMountedToVehicle=lambda game,player:state['mounted'])
ns['NLSRebornPolicy']=O()
intro=compile_function(source,'NLSRebornDeferredIntroComplete',ns,instance=True)
if 'func SmartCombatFallback(' in source:
    ns['NLSRebornPolicy'].SmartCombatFallback=compile_function(source,'SmartCombatFallback',ns)
policy=compile_function(source,'AllowForcedCheckpointFallback',ns)

cases=0; failures=[]; permitted=0; denied=0
reason_sets=[[],[1],[1,1],[2],[999],[1,2],[2,1],[1,999],[999,1],[1,1,2],[2,1,1]]
# The oracle comes from the contract: only nonempty all-Combat native locks,
# current combat, explicit opt-in, and any mounted opt-in. It does not copy a
# particular ordering/implementation of source guards.
for locked,reasons,combat,mounted,allow_combat,allow_vehicle,done,protected in itertools.product(
    (False,True),reason_sets,(False,True),(False,True),(False,True),(False,True),(-1,0,1),(False,True)):
    state.update(locked=locked,reasons=reasons,combat=combat,mounted=mounted,
                 player_system=True,quest_system=True,done=done)
    player=O(nlsRebornSafetyBlock=protected,GetGame=lambda:game,
        NLSRebornGetMode=lambda:3,NLSRebornGetCombat=lambda:allow_combat,
        NLSRebornGetVehicle=lambda:allow_vehicle,IsInCombat=lambda:combat,
        GetMountedVehicle=lambda:O() if mounted else None)
    # ABI field getter aliases allow the actual source to read its own fields.
    player.nlsRebornAllowCombat=allow_combat;player.nlsRebornAllowVehicle=allow_vehicle
    player.NLSRebornDeferredIntroComplete=lambda:intro(player)
    state['player']=player
    expected=bool(done>0 and not protected and locked and reasons and
                  all(r==1 for r in reasons) and combat and allow_combat and
                  (not mounted or allow_vehicle))
    error=None
    try:actual=policy(game)
    except Exception as e:actual=None;error=type(e).__name__+': '+str(e)
    cases+=1
    permitted+=expected;denied+=not expected
    if type(actual) is not bool or actual!=expected or error:
        failures.append({'locked':locked,'reasons':reasons,'combat':combat,'mounted':mounted,
                         'allow_combat':allow_combat,'allow_vehicle':allow_vehicle,'done':done,
                         'protected':protected,'expected':expected,'actual':actual,'error':error})

# Missing player/quest services must not throw or authorize the Smart fallback.
for missing in ('player','player_system','quest_system'):
    state.update(locked=True,reasons=[1],combat=True,mounted=False,
                 player_system=missing!='player_system',quest_system=missing!='quest_system',done=1)
    player=O(nlsRebornSafetyBlock=False,GetGame=lambda:game,NLSRebornGetMode=lambda:3,
        NLSRebornGetCombat=lambda:True,NLSRebornGetVehicle=lambda:True,IsInCombat=lambda:True,
        GetMountedVehicle=lambda:None,nlsRebornAllowCombat=True,nlsRebornAllowVehicle=True)
    player.NLSRebornDeferredIntroComplete=lambda:intro(player)
    state['player']=None if missing=='player' else player
    error=None
    try:actual=policy(game)
    except Exception as e:actual=None;error=type(e).__name__+': '+str(e)
    cases+=1
    if actual is not False or error:failures.append({'missing':missing,'expected':False,'actual':actual,'error':error})

result={'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'scope':'bounded actual-source Python evaluation with game/service doubles; not compiler/runtime evidence',
        'cases':cases,'expected_permits':permitted,'expected_denials':denied+3,
        'failed_cases':len(failures),'first_failures':failures[:25],
        'negative_control':a.expect_gap}
print(json.dumps(result,indent=2))
if a.expect_gap:
    raise SystemExit(0 if failures else 1)
raise SystemExit(1 if failures else 0)

