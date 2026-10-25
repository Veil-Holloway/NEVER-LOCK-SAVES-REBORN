#!/usr/bin/env python3
"""RC4 Unrestricted user-request routing through bounded actual REDscript.

Compiles actual hooks, mode setter, queue, introduction and automatic/deferred
methods. Only external game services, scalar observations and the existing large
CheckpointMessage library use boundary doubles. No REDscript compiler, CET/native
runtime, UI rendering, engine acceptance, save write/reload or progression proof.
"""
import argparse
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
from types import SimpleNamespace as O

REDS = 'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds'
HOOKS = ('HandlePressToSaveGame', 'HandlePressToQuickSaveGame', 'HandleQuickSave')


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_runtime_class(base, compiler):
    class Runtime(base.Runtime):
        def __init__(self, source):
            super().__init__(source, compiler)
            self.ns['GameInstance'].GetTimeSystem = lambda game: None if self.state['paused'] is None else O(IsPausedState=lambda: self.state['paused'])
            self.ns['GameInstance'].GetBlackboardSystem = lambda game: None if self.state['menu'] is None else O(Get=lambda key: O(GetBool=lambda field: self.state['menu']))
            self.ns['GetAllBlackboardDefs'] = lambda: O(UI_System=O(IsInMenu='native menu observation'))
            for name in ('NLSRebornGetMode', 'NLSRebornSetMode', 'NLSRebornPausedState',
                         'NLSRebornMenuState', 'NLSRebornMountedState', 'NLSRebornAutosaveSetEnabled',
                         'NLSRebornAutosaveReady', 'NLSRebornAutosaveQueue'):
                self.methods[name] = compiler(source, name, self.ns, instance=True)

        def fixture(self, **changes):
            defaults = dict(paused=False, menu=False, phone=0, auto_enabled=True)
            defaults.update(changes)
            player = super().fixture(**defaults)
            player.nlsRebornMode = self.state['mode']
            player.nlsAutosaveEnabled = self.state['auto_enabled']
            player.NLSRebornNotificationPhoneState = lambda: self.state['phone']
            return player
    return Runtime


def evaluate(source, runtime_class):
    runtime = runtime_class(source)
    failures = []
    assertions = 0

    def check(label, condition, details=None):
        nonlocal assertions
        assertions += 1
        if not condition:
            failures.append({'label': label, 'details': details})

    def invoke(hook, **fixture):
        player = runtime.fixture(**fixture)
        try:
            runtime.invoke(hook)
            error = None
        except Exception as exc:
            error = type(exc).__name__ + ': ' + str(exc)
        check('actual route executes without boundary error', error is None,
              dict(hook=hook, fixture=fixture, error=error))
        return player

    reasons = [('Combat',), ('Combat', 'PlayerStateMachine'), ('Combat', 'Scene'),
               ('Tier',), (999,), ()]
    for hook, enabled, mounted, combat, allow_combat, allow_vehicle, master, status, locks in itertools.product(
            HOOKS, (False, True), (False, True), (False, True), (False, True),
            (False, True), (False, True), (False, True), reasons):
        player = invoke(hook, mode=2, enabled=enabled, mounted=mounted, combat=combat,
                        allow_combat=allow_combat, allow_vehicle=allow_vehicle,
                        master=master, status=status, reasons=locks)
        detail = dict(hook=hook, deferred=enabled, mounted=mounted, combat=combat,
                      allow_combat=allow_combat, allow_vehicle=allow_vehicle,
                      master=master, status=status, locks=locks)
        check('Unrestricted attempts exactly one immediate checkpoint',
              runtime.state['forced'] == 1 and runtime.state['wrapped'] == 0, detail)
        check('Unrestricted never creates deferred user work',
              not player.nlsDeferredPending and player.nlsDeferredSerial == 17 and player.nlsDeferredSource == 0, detail)
        check('immediate request feedback respects master switch',
              len(runtime.state['notices']) == int(master), detail)

    # Native-unlocked requests still use the original native route in every mode.
    for hook, mode, enabled in itertools.product(HOOKS, (0, 1, 2, 3), (False, True)):
        player = invoke(hook, mode=mode, enabled=enabled, locked=False, reasons=())
        check('native unlocked behavior is retained',
              runtime.state['wrapped'] == 1 and runtime.state['forced'] == 0 and not player.nlsDeferredPending,
              dict(hook=hook, mode=mode, enabled=enabled))

    # Current introduction facts always gate forced and queued work.
    for hook, done, protected, enabled in itertools.product(
            HOOKS, (None, -1, 0, 1), (False, True), (False, True)):
        if done == 1 and not protected:
            continue
        player = invoke(hook, mode=2, enabled=enabled, done=done, protected=protected,
                        mounted=True, combat=True, reasons=('Combat',))
        check('intro protection prevents immediate and queued requests',
              runtime.state['forced'] == 0 and not player.nlsDeferredPending,
              dict(hook=hook, done=done, protected=protected, enabled=enabled))

    # Direct invalid/source/intro refusals cannot erase another pending request.
    for mode, pending_source, requested_source in itertools.product(
            (0, 1, 2, 3), (1, 2, 3), (-1, 0, 3, 999)):
        player = runtime.fixture(mode=mode)
        player.nlsDeferredPending = True
        player.nlsDeferredSource = pending_source
        serial = player.nlsDeferredSerial
        accepted = player.NLSRebornDeferredQueue(requested_source)
        check('invalid user source preserves existing queue',
              accepted is False and player.nlsDeferredPending and
              player.nlsDeferredSource == pending_source and player.nlsDeferredSerial == serial,
              dict(mode=mode, pending_source=pending_source, source=requested_source))
    for done, protected, source in itertools.product((None, -1, 0, 1), (False, True), (1, 2)):
        if done == 1 and not protected:
            continue
        player = runtime.fixture(mode=2, done=done, protected=protected)
        player.nlsDeferredPending = True
        player.nlsDeferredSource = 3
        accepted = player.NLSRebornDeferredQueue(source)
        check('direct intro refusal leaves unrelated work unchanged',
              accepted is False and player.nlsDeferredPending and player.nlsDeferredSource == 3,
              dict(done=done, protected=protected, source=source))

    # A deliberately accepted user action wins over old automatic/manual work,
    # and it consumes that work before the immediate service call can reenter.
    for hook, enabled, pending_source in itertools.product(HOOKS, (False, True), (1, 2, 3)):
        player = runtime.fixture(mode=2, enabled=enabled, reenter=True,
                                 mounted=True, combat=True, reasons=('Combat',))
        player.nlsDeferredPending = True
        player.nlsDeferredSource = pending_source
        serial = player.nlsDeferredSerial
        runtime.invoke(hook)
        check('fresh immediate user request consumes old pending work',
              runtime.state['forced'] == 1 and not player.nlsDeferredPending and
              player.nlsDeferredSerial == serial and runtime.state.get('reentry_result') is False,
              dict(hook=hook, deferred=enabled, old_source=pending_source))
        runtime.state['locked'] = False
        runtime.state['reasons'] = ()
        runtime.state['combat'] = False
        runtime.state['mounted'] = False
        check('old request cannot dispatch later or duplicate',
              player.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 1,
              dict(hook=hook, old_source=pending_source))

    # Busy/notification debounce guards stay before any new user action.
    for hook, busy, failed, saved in (
            (HOOKS[1], True, False, False), (HOOKS[1], False, True, False),
            (HOOKS[1], False, False, True), (HOOKS[2], True, False, False)):
        player = runtime.fixture(mode=2, busy=busy, failed=failed, saved=saved)
        player.nlsDeferredPending = True
        player.nlsDeferredSource = 3
        runtime.invoke(hook)
        check('debounced input neither attempts nor consumes work',
              runtime.state['forced'] == 0 and player.nlsDeferredPending and
              player.nlsDeferredSource == 3 and not runtime.state['notices'],
              dict(hook=hook, busy=busy, failed=failed, saved=saved))

    # Valid mode changes have explicit queue ownership semantics; bad modes do
    # not change either the selected mode or pending state.
    for old_mode, new_mode, pending_source in itertools.product(
            (0, 1, 2, 3), (-10, -1, 0, 1, 2, 3, 4, 999), (1, 2, 3, 999)):
        player = runtime.fixture(mode=old_mode)
        player.nlsDeferredPending = True
        player.nlsDeferredSource = pending_source
        serial = player.nlsDeferredSerial
        player.NLSRebornSetMode(new_mode)
        valid = 0 <= new_mode <= 3
        expected_pending = not (new_mode == 2 and pending_source in (1, 2))
        check('mode setter keeps selection and queue ownership contract',
              player.NLSRebornGetMode() == (new_mode if valid else old_mode) and
              player.nlsDeferredPending == expected_pending and
              player.nlsDeferredSource == pending_source and player.nlsDeferredSerial == serial and
              runtime.state['forced'] == 0,
              dict(old_mode=old_mode, new_mode=new_mode, source=pending_source))

    for hook in HOOKS:
        player = invoke(hook, mode=3, reasons=('Scene',))
        serial = player.nlsDeferredSerial
        check('Smart initially owns one real queued request', player.nlsDeferredPending, hook)
        player.NLSRebornSetMode(2)
        check('entering Unrestricted cancels old manual queue without saving',
              not player.nlsDeferredPending and runtime.state['forced'] == 0, hook)
        runtime.state['locked'] = False
        runtime.state['reasons'] = ()
        check('mode change cannot revive old manual token on unlock',
              player.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 0, hook)
        runtime.state['locked'] = True
        runtime.state['reasons'] = ('Combat',)
        runtime.state['combat'] = True
        runtime.state['mounted'] = True
        runtime.invoke(hook)
        check('next user request after mode transition attempts once',
              runtime.state['forced'] == 1 and not player.nlsDeferredPending, hook)

    # The independent automatic lane still works in mode2 and stays gated.
    for enabled in (False, True):
        player = runtime.fixture(mode=2, enabled=enabled, locked=False, reasons=(), combat=False, mounted=False)
        check('automatic readiness remains available in Unrestricted', player.NLSRebornAutosaveReady() is True, enabled)
        check('automatic queue remains separate from manual preference',
              player.NLSRebornAutosaveQueue() is True and player.nlsDeferredSource == 3 and player.nlsDeferredPending, enabled)
        serial = player.nlsDeferredSerial
        player.NLSRebornSetMode(2)
        check('reapplying Unrestricted preserves automatic pending work', player.nlsDeferredPending, enabled)
        runtime.state['locked'] = True
        runtime.state['reasons'] = ('Scene',)
        check('automatic work still waits for native permission',
              player.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 0 and player.nlsDeferredPending, enabled)
        runtime.state['locked'] = False
        runtime.state['reasons'] = ()
        check('eligible automatic work dispatches exactly once',
              player.NLSRebornDeferredDispatch(serial) is True and runtime.state['forced'] == 1 and not player.nlsDeferredPending, enabled)
        check('automatic token stays consumed', player.NLSRebornDeferredDispatch(serial) is False and runtime.state['forced'] == 1, enabled)

    # Other modes retain their existing routing, including known DF Immersion.
    for hook, mode, enabled, df_active in itertools.product(HOOKS, (0, 1, 3), (False, True), (False, True)):
        player = runtime.fixture(mode=mode, enabled=enabled, reasons=('Scene',), combat=False)
        runtime.ns['NLSRebornDFPolicy'].Read = lambda p, active=df_active: O(
            vehicleSleep=int(active), addiction=0, starvation=0, dehydration=0, status='external DF observation')
        runtime.invoke(hook)
        expected_queue = enabled and (mode == 3 or (mode == 1 and df_active))
        expected_forced = mode == 1 and df_active and not enabled
        expected_wrapped = mode == 0 or (mode == 1 and not df_active)
        check('other mode routing remains scoped',
              player.nlsDeferredPending == expected_queue and
              runtime.state['forced'] == int(expected_forced) and runtime.state['wrapped'] == int(expected_wrapped),
              dict(hook=hook, mode=mode, deferred=enabled, df=df_active))

    return {'assertions': assertions, 'failed': len(failures),
            'boundary_errors': sum(item['label'] == 'actual route executes without boundary error' for item in failures),
            'first_failures': failures[:25]}


def mutate_method(source, subset, name, transform):
    before = subset.body(source, name)
    after = transform(before)
    assert before != after, 'Mutation anchor missing: ' + name
    return source.replace(before, after, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('release', type=Path)
    parser.add_argument('--expect-gap', action='store_true')
    parser.add_argument('--mutations', action='store_true')
    args = parser.parse_args()
    validation = args.release / 'docs/NeverLockSavesReborn/validation'
    subset = load_module('rc4_source_subset', validation / 'source_subset.py')
    base = load_module('rc4_existing_route_boundaries', validation / 'test_smart_queue_routes.py')
    runtime_class = make_runtime_class(base, subset.compile_function)
    path = args.release / REDS
    source = path.read_text()
    result = evaluate(source, runtime_class)
    result.update(source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                  scope=__doc__.strip(), negative_control=args.expect_gap)
    if args.mutations and not result['failed']:
        queue_fn = subset.body(source, 'NLSRebornDeferredQueue')
        setter_fn = subset.body(source, 'NLSRebornSetMode')
        mutants = {
            'Unrestricted returns to deferred admission': mutate_method(source, subset, 'NLSRebornDeferredQueue',
                lambda text: text.replace('if this.NLSRebornGetMode() == 2 {', 'if false {', 1)),
            'immediate request fails to consume stale work': mutate_method(source, subset, 'NLSRebornDeferredQueue',
                lambda text: text.replace('this.nlsDeferredPending = false;', 'this.nlsDeferredPending = this.nlsDeferredPending;', 1)),
            'mode selection carries stale player work': mutate_method(source, subset, 'NLSRebornSetMode',
                lambda text: text.replace('this.nlsDeferredPending = false;', 'this.nlsDeferredPending = this.nlsDeferredPending;', 1)),
            'mode selection cancels independent automatic work': mutate_method(source, subset, 'NLSRebornSetMode',
                lambda text: text.replace('mode == 2 && (this.nlsDeferredSource == 1 || this.nlsDeferredSource == 2)', 'mode == 2', 1)),
            'introduction guard removed from admission': mutate_method(source, subset, 'NLSRebornDeferredQueue',
                lambda text: text.replace(' || !this.NLSRebornDeferredIntroComplete()', '', 1)),
            'automatic native lock gate removed': mutate_method(source, subset, 'NLSRebornDeferredNativeUnlocked',
                lambda text: text.replace(' && !GameInstance.IsSavingLocked(this.GetGame(), locks)', '', 1)),
        }
        controls = {}
        for label, mutated in mutants.items():
            outcome = evaluate(mutated, runtime_class)
            controls[label] = {'detected': outcome['failed'] > 0, 'failed': outcome['failed'],
                               'first_failure': outcome['first_failures'][:1]}
        result['mutation_controls'] = controls
    print(json.dumps(result, indent=2))
    if args.expect_gap:
        return 0 if result['failed'] else 1
    return int(result['failed'] > 0 or (args.mutations and not all(x['detected'] for x in result.get('mutation_controls', {}).values())))


if __name__ == '__main__':
    raise SystemExit(main())
