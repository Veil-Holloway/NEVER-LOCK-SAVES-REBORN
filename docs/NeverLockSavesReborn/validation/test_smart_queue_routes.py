#!/usr/bin/env python3
"""Smart user-request routing regression against bounded actual REDscript source.

The tested methods, route branches, queue admission and dispatch are translated
from the supplied release. Only game/service boundaries and the large existing
CheckpointMessage library are doubled. This is not REDscript compilation, CET,
notification rendering, scheduler stability or actual save/reload evidence.
"""
import argparse
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
from types import SimpleNamespace as O

REDS = Path('r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds')
HOOKS = ('HandlePressToSaveGame', 'HandlePressToQuickSaveGame', 'HandleQuickSave')


class Runtime:
    def __init__(self, source, compiler):
        self.state = {}
        self.game = O()
        self.ns = {'__builtins__': {}, 'IsDefined': lambda x: x is not None,
                   'ArraySize': len, 'Equals': lambda a, b: a == b,
                   'NotEquals': lambda a, b: a != b,
                   'gameSaveLockReason': O(Combat='Combat')}
        self.ns['GameInstance'] = O(
            GetPlayerSystem=lambda game: O(GetLocalPlayerControlledGameObject=lambda: self.state['player']),
            GetQuestsSystem=lambda game: None if self.state['done'] is None else O(GetFact=lambda fact: self.state['done']),
            IsSavingLocked=self.locked,
            GetAutoSaveSystem=lambda game: O(RequestForcedCheckpoint=self.force) if self.state['service'] else None)
        self.ns['VehicleComponent'] = O(IsMountedToVehicle=lambda game, player: self.state['mounted'])
        self.ns['NLSRebornDFPolicy'] = O(Read=lambda player: O(
            vehicleSleep=0, addiction=0, starvation=0, dehydration=0, status='boundary: no DF context'))
        self.ns['NLSRebornDFMessages'] = O(Message=lambda *args: 'DF request')
        self.ns['PauseMenuGameController'] = O(NLSRebornNotify=self.notify)
        self.ns['wrappedMethod'] = self.wrapped
        self.controller = O(m_gameInstance=self.game, m_quickSaveInProgress=False,
                            IsSaveFailedNotificationActive=lambda: self.state['failed'],
                            IsGameSavedNotificationActive=lambda: self.state['saved'],
                            GetPlayerControlledObject=lambda: self.state['player'])
        self.ns['this'] = self.controller
        self.policy = O()
        self.ns['NLSRebornPolicy'] = self.policy
        for name in ('GetImmersionSaveContext', 'NotifyImmersionSaveRequest',
                     'IsProtectedIntroduction', 'SmartCombatFallback', 'AllowForcedCheckpointFallback'):
            setattr(self.policy, name, compiler(source, name, self.ns))
        if 'func HandleSmartBlockedSave(' in source:
            self.policy.HandleSmartBlockedSave = compiler(source, 'HandleSmartBlockedSave', self.ns)
        self.policy.CheckpointMessage = lambda game, context: 'existing contextual request' if self.state['master'] else ''
        self.methods = {name: compiler(source, name, self.ns, instance=True) for name in (
            'NLSRebornDeferredIntroComplete', 'NLSRebornDeferredQueue',
            'NLSRebornDeferredNativeUnlocked', 'NLSRebornDeferredDispatch',
            'NLSRebornGetDFNotificationContext')}
        self.hooks = {name: compiler(source, name, self.ns) for name in HOOKS}

    def locked(self, game, locks):
        locks[:] = [O(reason=x) for x in self.state['reasons']]
        return self.state['locked']

    def force(self):
        self.state['forced'] += 1
        if self.state['reenter']:
            p = self.state['player']
            self.state['reentry_result'] = p.NLSRebornDeferredDispatch(p.nlsDeferredSerial)
        return True

    def notify(self, game, message):
        if message:
            self.state['notices'].append(message)

    def wrapped(self, *args):
        self.state['wrapped'] += 1

    def fixture(self, **changes):
        self.state.clear()
        self.state.update(mode=3, enabled=True, locked=True, reasons=('Scene',), combat=False,
                          allow_combat=False, mounted=False, allow_vehicle=False, done=1,
                          protected=False, master=True, status=False, tone=0, busy=False,
                          failed=False, saved=False, service=True, reenter=False,
                          forced=0, wrapped=0, notices=[])
        self.state.update(changes)
        s = self.state
        p = O(nlsDeferredEnabled=s['enabled'], nlsDeferredPending=False,
              nlsDeferredSerial=17, nlsDeferredSource=0, nlsRebornSafetyBlock=s['protected'],
              nlsRebornDFNotifyVehicleSleep=True, nlsRebornDFNotifyAddiction=True,
              nlsRebornDFNotifyStarvation=True, nlsRebornDFNotifyDehydration=True,
              GetGame=lambda: self.game, NLSRebornGetMode=lambda: s['mode'],
              NLSRebornGetCombat=lambda: s['allow_combat'], NLSRebornGetVehicle=lambda: s['allow_vehicle'],
              IsInCombat=lambda: s['combat'], NLSRebornGetNotificationsEnabled=lambda: s['master'],
              NLSRebornGetStatusNotificationsEnabled=lambda: s['status'], NLSRebornGetTone=lambda: s['tone'],
              NLSRebornEnsureDFStateInitialized=lambda: None)
        s['player'] = p
        for name, fn in self.methods.items():
            setattr(p, name, lambda *args, _fn=fn: _fn(p, *args))
        self.controller.m_quickSaveInProgress = s['busy']
        return p

    def invoke(self, hook):
        if hook == HOOKS[0]:
            self.hooks[hook](None)
        else:
            self.hooks[hook]()


def evaluate(source, compiler):
    runtime = Runtime(source, compiler)
    failures = []
    count = 0

    def check(label, condition, details=None):
        nonlocal count
        count += 1
        if not condition:
            failures.append({'label': label, 'details': details})

    def invoke(hook, **fixture):
        p = runtime.fixture(**fixture)
        try:
            runtime.invoke(hook)
            error = None
        except Exception as exc:
            error = type(exc).__name__ + ': ' + str(exc)
        check('route executes without boundary error', error is None, dict(hook=hook, fixture=fixture, error=error))
        return p

    # Queue admission waits for native permission regardless of the lock reason,
    # combat exception toggle or notification presentation toggles.
    reason_sets = [('Scene',), ('Quest',), ('Script',), ('Combat', 'Scene'), (999,), (), ('Combat',)]
    for hook, reasons, master, status, allow_combat in itertools.product(
            HOOKS, reason_sets, (False, True), (False, True), (False, True)):
        p = invoke(hook, reasons=reasons, master=master, status=status, allow_combat=allow_combat,
                   combat='Combat' in reasons)
        details = dict(hook=hook, reasons=reasons, master=master, status=status, allow_combat=allow_combat)
        check('blocked Smart request enters one queue', p.nlsDeferredPending and p.nlsDeferredSerial == 18, details)
        check('request source survives real wrapper', p.nlsDeferredSource == (1 if hook == HOOKS[0] else 2), details)
        check('queue admission never forces or delegates', runtime.state['forced'] == runtime.state['wrapped'] == 0, details)
        check('legacy notice or status-lane handoff follows switches',
              len(runtime.state['notices']) == int(master and not status), details)

    # A disabled queue cannot create a checkpoint during a protected interaction.
    # A custom refusal is required with the master notification switch on; tone
    # selection must not affect permission or claim a save was queued/written.
    tone_messages = {}
    for hook, reasons, master, status, tone in itertools.product(
            HOOKS, reason_sets[:-1], (False, True), (False, True), range(3)):
        p = invoke(hook, enabled=False, reasons=reasons, master=master, status=status, tone=tone)
        details = dict(hook=hook, reasons=reasons, master=master, status=status, tone=tone)
        check('disabled queue remains empty', not p.nlsDeferredPending and p.nlsDeferredSerial == 17, details)
        check('blocked interaction never forces or delegates', runtime.state['forced'] == runtime.state['wrapped'] == 0, details)
        check('blocked custom notice follows master switch', len(runtime.state['notices']) == int(master), details)
        if master and runtime.state['notices']:
            text = runtime.state['notices'][0].lower()
            check('refusal truthfully says no request queued', 'no save' in text and 'queu' in text, details)
            check('refusal makes no completion claim', all(x not in text for x in ('saved successfully', 'save complete', 'save written')), details)
            tone_messages.setdefault(tone, runtime.state['notices'][0])
    check('three tones have distinct refusal wording', len(set(tone_messages.values())) == 3, tone_messages)

    # Keep the existing explicitly opted-in pure-combat immediate exception.
    for hook, master in itertools.product(HOOKS, (False, True)):
        p = invoke(hook, enabled=False, reasons=('Combat',), combat=True, allow_combat=True, master=master)
        check('queue-off combat exception remains immediate',
              not p.nlsDeferredPending and runtime.state['forced'] == 1 and runtime.state['wrapped'] == 0,
              dict(hook=hook, master=master))
        check('combat request notification follows master', len(runtime.state['notices']) == int(master))

    # Incomplete/unknown fresh introduction or active cached protection must never
    # be admitted or forced. Cached wording may still delegate to vanilla.
    for hook, done, protected in itertools.product(HOOKS, (None, -1, 0, 1), (False, True)):
        if done == 1 and not protected:
            continue
        p = invoke(hook, done=done, protected=protected)
        check('introduction gate remains closed', not p.nlsDeferredPending and runtime.state['forced'] == 0,
              dict(hook=hook, done=done, protected=protected))

    for hook, master in itertools.product(HOOKS, (False, True)):
        p = invoke(hook, locked=False, reasons=(), master=master)
        check('unlocked Smart request retains native path',
              not p.nlsDeferredPending and runtime.state['forced'] == 0 and runtime.state['wrapped'] == 1 and not runtime.state['notices'],
              dict(hook=hook, master=master))

    # Original quicksave debounce guards must remain ahead of Smart admission.
    for hook, busy, failed, saved in (
            (HOOKS[1], True, False, False), (HOOKS[1], False, True, False),
            (HOOKS[1], False, False, True), (HOOKS[2], True, False, False)):
        p = invoke(hook, busy=busy, failed=failed, saved=saved)
        check('busy quicksave does not enter new lane',
              not p.nlsDeferredPending and runtime.state['forced'] == 0 and not runtime.state['notices'],
              dict(hook=hook, busy=busy, failed=failed, saved=saved))

    # Do not extend deferred behavior to Vanilla or ordinary Immersion. Keep
    # Unrestricted's existing queue and queue-off forced request behavior.
    for hook, mode, enabled in itertools.product(HOOKS, (0, 1, 2), (False, True)):
        p = invoke(hook, mode=mode, enabled=enabled)
        expected_queue = mode == 2 and enabled
        check('other modes retain queue scope', p.nlsDeferredPending == expected_queue,
              dict(hook=hook, mode=mode, enabled=enabled))
        check('other modes retain native/fallback routes',
              runtime.state['forced'] == int(mode == 2 and not enabled) and runtime.state['wrapped'] == int(mode in (0, 1)),
              dict(hook=hook, mode=mode, enabled=enabled))

    # Exercise the actual REDscript dispatch guard after a real wrapper queued a
    # request. Lua's separate stable-window scheduling is outside this test.
    for hook in HOOKS:
        p = invoke(hook)
        serial = p.nlsDeferredSerial
        check('native lock prevents dispatch', p.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 0 and p.nlsDeferredPending, hook)
        runtime.state['locked'] = False
        runtime.state['reasons'] = ()
        check('wrong token never dispatches', p.NLSRebornDeferredDispatch(serial + 1) is False and runtime.state['forced'] == 0, hook)
        runtime.state['locked'] = True
        runtime.state['reasons'] = ('Quest',)
        check('renewed lock keeps request pending', p.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 0 and p.nlsDeferredPending, hook)
        runtime.state['locked'] = False
        runtime.state['reasons'] = ()
        runtime.state['done'] = 0
        check('fresh introduction regression prevents dispatch', p.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 0 and p.nlsDeferredPending, hook)
        runtime.state['done'] = 1
        runtime.state['service'] = False
        check('absent service preserves queued request', p.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 0 and p.nlsDeferredPending, hook)
        runtime.state['service'] = True
        runtime.state['reenter'] = True
        check('unlocked request dispatches once and consumes queue', p.NLSRebornDeferredDispatch(serial) is True and runtime.state['forced'] == 1 and not p.nlsDeferredPending, hook)
        check('reentrant callback cannot dispatch again', runtime.state.get('reentry_result') is False and runtime.state['forced'] == 1, hook)
        check('repeat dispatch stays consumed', p.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 1, hook)

    return {'assertions': count, 'failed': len(failures), 'first_failures': failures[:30]}


def replace_body(source, subset, name, replacement):
    fn = subset.body(source, name)
    mutated = fn[:fn.index('{') + 1] + replacement + '\n}'
    return source.replace(fn, mutated, 1)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('release', type=Path)
    p.add_argument('--expect-gap', action='store_true', help='Baseline negative control: succeeds only when requirements fail')
    p.add_argument('--mutations', action='store_true')
    args = p.parse_args()
    subset_path = args.release / 'docs/NeverLockSavesReborn/validation/source_subset.py'
    spec = importlib.util.spec_from_file_location('candidate_source_subset', subset_path)
    subset = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(subset)
    source_path = args.release / REDS
    source = source_path.read_text()
    result = evaluate(source, subset.compile_function)
    result.update(scope=__doc__.strip(), source_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
                  negative_control=args.expect_gap)
    if args.mutations and not result['failed']:
        controls = {}
        mutants = {
            'smart route disabled': replace_body(source, subset, 'HandleSmartBlockedSave', '\n return false;'),
            'native unlock guard removed': replace_body(source, subset, 'NLSRebornDeferredNativeUnlocked',
                '\n return !this.nlsRebornSafetyBlock && this.NLSRebornDeferredIntroComplete();')}
        for name, mutant in mutants.items():
            outcome = evaluate(mutant, subset.compile_function)
            controls[name] = dict(detected=outcome['failed'] > 0, failed=outcome['failed'], first_failure=outcome['first_failures'][:1])
        result['mutation_controls'] = controls
    print(json.dumps(result, indent=2))
    if args.expect_gap:
        return 0 if result['failed'] else 1
    if result['failed']:
        return 1
    if args.mutations and not all(x['detected'] for x in result.get('mutation_controls', {}).values()):
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
