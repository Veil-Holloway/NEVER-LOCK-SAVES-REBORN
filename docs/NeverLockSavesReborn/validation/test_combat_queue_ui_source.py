#!/usr/bin/env python3
"""Bounded actual-REDscript-source execution against controlled game boundaries.
Not REDscript compilation or native game execution. No save files are created.
"""
import itertools
import json
import sys
from pathlib import Path
from types import SimpleNamespace as O
from test_smart_queue_routes import Runtime, HOOKS, REDS
from source_subset import compile_function

root = Path(sys.argv[1]).resolve()
source = (root / REDS).read_text()
class QueueRuntime(Runtime):
    def __init__(self):
        super().__init__(source, compile_function)
        self.policy.IsRequestBlocked = compile_function(source, 'IsRequestBlocked', self.ns)
    def force(self):
        self.state['forced'] += 1
        if self.state['reenter']:
            self.state['reenter'] = False  # One native callback, not unbounded fixture recursion.
            player = self.state['player']
            self.state['reentry_result'] = player.NLSRebornDeferredDispatch(player.nlsDeferredSerial)
        return self.state.get('native_result', True)
r = QueueRuntime()
count = 0
failures = []
def check(value, label, detail=None):
    global count
    count += 1
    if not value:
        failures.append({'label': label, 'detail': detail})

for hook, mode, enabled, mounted, combat, locked, allow in itertools.product(
        HOOKS, range(4), (False,True), (False,True), (False,True), (False,True), (False,True)):
    reasons=('Combat',) if combat and locked else ('Script',) if locked else ()
    p=r.fixture(mode=mode,enabled=enabled,mounted=mounted,combat=combat,locked=locked,reasons=reasons,
                allow_combat=allow,allow_vehicle=allow)
    detail=[hook,mode,enabled,mounted,combat,locked,allow]
    r.invoke(hook)
    blocked=combat or locked
    expected_queue=blocked and mode!=0 and enabled
    check(p.nlsDeferredPending==expected_queue,'queue admission matches mode/enable/state',detail)
    check(r.state['forced']==0,'no hook submits immediate checkpoint',detail)
    check(r.state['wrapped']==int(mode==0 or not blocked),'only permitted/Vanilla paths delegate',detail)
    if expected_queue:
        serial=p.nlsDeferredSerial
        check(serial==18 and p.nlsDeferredSource==(1 if hook==HOOKS[0] else 2),'single queue with correct source',detail)
        check(not p.NLSRebornDeferredDispatch(serial),'combat or native lock blocks dispatch',detail)
        r.state['combat']=False;r.state['locked']=False;r.state['reasons']=()
        check(p.NLSRebornDeferredDispatch(serial),'dispatch when combat/native locks clear while mount unchanged',detail)
        check(r.state['forced']==1 and not p.nlsDeferredPending,'one accepted submission closes pending ticket',detail)
        check(not p.NLSRebornDeferredDispatch(serial) and r.state['forced']==1,'same serial never repeats',detail)

for reason in ('Scene','Quest','Script','Combat',999):
    for hook in HOOKS:
        p=r.fixture(locked=False,reasons=(reason,),combat=False,mounted=True)
        r.invoke(hook)
        check(p.nlsDeferredPending and r.state['forced']==0 and r.state['wrapped']==0,'nonempty native lock data never treated clear',[reason,hook])
        check(not p.NLSRebornDeferredDispatch(p.nlsDeferredSerial),'inconsistent native lock blocks release',[reason,hook])
for hook,done,protected in itertools.product(HOOKS,(None,0,1),(False,True)):
    p=r.fixture(done=done,protected=protected,combat=True,mounted=True)
    r.invoke(hook)
    check(p.nlsDeferredPending==bool(done and not protected),'intro unavailable/unfinished stays protected',[hook,done,protected])
    check(r.state['forced']==0,'intro never forced',[hook,done,protected])
for done in (None,0):
    p=r.fixture(done=done)
    check(not p.NLSRebornDeferredQueue(1) and not p.nlsDeferredPending,'direct admission independently protects unreadable/unfinished intro',done)
for invalid in (0,-1,3,4,99):
    p=r.fixture();check(not p.NLSRebornDeferredQueue(invalid),'invalid player queue source refused',invalid)
for source_id in (-1,0,4,99):
    p=r.fixture(locked=False,reasons=());check(not p.NLSRebornRequestCheckpoint(source_id) and r.state['forced']==0,'invalid native request source refused',source_id)
for mode,combat,mounted in itertools.product(range(4),(False,True),(False,True)):
    p=r.fixture(mode=mode,combat=combat,mounted=mounted,allow_combat=True,allow_vehicle=True)
    check(not r.policy.SmartCombatFallback(r.game) and not r.policy.AllowForcedCheckpointFallback(r.game),'legacy bypass entry points always disabled',[mode,combat,mounted])
for fault in ('disabled','serial','relock','combat','intro','safety','service','native_false','reentrant'):
    p=r.fixture(locked=False,reasons=(),mounted=True)
    p.NLSRebornDeferredQueue(2);serial=p.nlsDeferredSerial
    if fault=='disabled':p.nlsDeferredEnabled=False
    elif fault=='serial':serial-=1
    elif fault=='relock':r.state['locked']=True;r.state['reasons']=('Script',)
    elif fault=='combat':r.state['combat']=True
    elif fault=='intro':r.state['done']=0
    elif fault=='safety':p.nlsRebornSafetyBlock=True
    elif fault=='service':r.state['service']=False
    elif fault=='native_false':r.state['native_result']=False
    elif fault=='reentrant':r.state['reenter']=True
    result=p.NLSRebornDeferredDispatch(serial)
    check(result==(fault=='reentrant'),'dispatch boundary fault handling',fault)
    check(r.state['forced']==int(fault in ('native_false','reentrant')),'fault never bypasses eligibility',fault)
    if fault=='native_false':
        check(p.nlsCheckpointResult==2,'native refusal stays refusal')
        check(not any('accepted' in x.lower() for x in r.state['notices']),'rejection never announces accepted')
    if fault=='reentrant':check(r.state.get('reentry_result') is False and r.state['forced']==1,'reentrant callback cannot dispatch twice')
# Race at the checked helper, after dispatch's earlier check succeeds.
p=r.fixture(locked=False,reasons=(),mounted=True);p.NLSRebornDeferredQueue(2)
checks=0
original=p.NLSRebornDeferredNativeUnlocked
def changing_gate():
    global checks
    checks+=1
    if checks>1:r.state['combat']=True
    return original()
p.NLSRebornDeferredNativeUnlocked=changing_gate
check(not p.NLSRebornDeferredDispatch(p.nlsDeferredSerial) and r.state['forced']==0,'live helper recheck rejects late combat')
# Busy quicksave controls keep their original wrapped path and never create queued work.
for hook in HOOKS[1:]:
    for flag in ('busy','failed','saved'):
        if hook==HOOKS[2] and flag!='busy':continue
        p=r.fixture(combat=True,**{flag:True});r.invoke(hook)
        check(not p.nlsDeferredPending and r.state['forced']==0,'busy quicksave guard preserved',[hook,flag])
result={'scope':__doc__,'assertions':count,'failures':failures,'passed':not failures}
print(json.dumps(result,indent=2))
sys.exit(bool(failures))
