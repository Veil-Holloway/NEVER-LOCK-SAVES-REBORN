#!/usr/bin/env python3
"""Independent actual-source native-result boundary regression.

Executes the supplied REDscript helper, wrappers and deferred dispatcher through
the existing strict bounded evaluator. Native/game/UI services are doubles; this
does not compile REDscript or demonstrate a game save, reload or progression.
"""
import argparse
import hashlib
import importlib.util
import itertools
import json
import re
from pathlib import Path
from types import SimpleNamespace as O

REDS = 'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds'
HOOKS = ('HandlePressToSaveGame', 'HandlePressToQuickSaveGame', 'HandleQuickSave')
HELPER = 'NLSRebornRequestCheckpoint'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def evaluate(release):
    validation = release / 'docs/NeverLockSavesReborn/validation'
    subset = load('native_result_source_subset', validation / 'source_subset.py')
    base = load('native_result_existing_game_boundaries', validation / 'test_smart_queue_routes.py')
    path = release / REDS
    raw = path.read_bytes()
    source = raw.decode()
    exists = 'func ' + HELPER + '(' in source
    assertions, failures, errors = 0, [], []

    def check(label, condition, detail=None):
        nonlocal assertions
        assertions += 1
        if not condition:
            failures.append({'label': label, 'detail': detail})

    class Runtime(base.Runtime):
        def __init__(self):
            super().__init__(source, subset.compile_function)
            self.ns['ToString'] = str
            # Diagnostic lock-summary formatting is not the changed seam here.
            # It is a read-only external observation for these request tests.
            if 'func ' + HELPER + '(' in source:
                self.methods[HELPER] = subset.compile_function(source, HELPER, self.ns, instance=True)
                self.methods['NLSRebornCheckpointFailure'] = subset.compile_function(source, 'NLSRebornCheckpointFailure', self.ns, instance=True)
                for suffix in ('Serial', 'Source', 'Result', 'Locks', 'Combat', 'Mounted'):
                    name = 'NLSRebornCheckpointGet' + suffix
                    self.methods[name] = subset.compile_function(source, name, self.ns, instance=True)

        def fixture(self, **changes):
            changes = dict(changes)
            changes.setdefault('mode', 2)
            player = super().fixture(**changes)
            self.state.setdefault('native_result', True)
            self.state.setdefault('seen_pending', [])
            self.state.setdefault('helper_sources', [])
            for name, kind in re.findall(r'@addField\(PlayerPuppet\)\s*(?:public|private|protected)\s+let\s+(\w+)\s*:\s*(\w+)', source):
                if not hasattr(player, name):
                    setattr(player, name, False if kind == 'Bool' else '' if kind == 'String' else 0)
            player.NLSRebornSaveLockSummary = lambda: ('locked|' + '|'.join(map(str, self.state['reasons']))) if self.state['locked'] else 'unlocked'
            player.NLSRebornMountedState = lambda: int(self.state['mounted'])
            return player

        def force(self):
            self.state['forced'] += 1
            self.state['seen_pending'].append(self.state['player'].nlsDeferredPending)
            if self.state['reenter']:
                p = self.state['player']
                self.state['reentry_result'] = p.NLSRebornDeferredDispatch(p.nlsDeferredSerial)
            return self.state['native_result']

    runtime = Runtime()

    def invoke(call, label, detail):
        try:
            return call()
        except Exception as exc:
            errors.append({'label': label, 'detail': detail, 'error': type(exc).__name__ + ': ' + str(exc)})
            return None

    # Baseline RC4 reaches its actual native call and emits positive request
    # feedback despite a false native result. The candidate must detect it.
    for hook, native_result, service, master, tone, deferred in itertools.product(
            HOOKS, (False, True), ((False, True) if exists else (True,)), (False, True), range(3), (False, True)):
        detail = dict(hook=hook, native_result=native_result, service=service,
                      master=master, tone=tone, deferred=deferred)
        player = runtime.fixture(native_result=native_result, service=service, master=master,
                                 tone=tone, enabled=deferred, mounted=True, combat=True,
                                 reasons=('Combat', 'PlayerStateMachine'))
        invoke(lambda: runtime.invoke(hook), 'immediate route', detail)
        check('immediate action attempts at most once without native delegation',
              runtime.state['forced'] == int(service) and runtime.state['wrapped'] == 0, detail)
        check('Unrestricted attempt does not leave a queue item', not player.nlsDeferredPending, detail)
        notices = runtime.state['notices']
        positive = [m for m in notices if m.startswith(('existing contextual request', 'DF request'))]
        check('positive request notification requires true native result',
              len(positive) == int(master and service and native_result), detail)
        check('notification master switch controls all attempt feedback', master or not notices, detail)
        if master and not (service and native_result):
            check('native failure has one explicit diagnostic notice', len(notices) == 1, detail)

    check('all native calls are centralized in checked helper',
          len(re.findall(r'\.RequestForcedCheckpoint\s*\(', source)) == 1)
    check('explicit native-result helper exists', exists)
    if exists:
        player = runtime.fixture()
        check('initial diagnostic records no attempt',
              player.NLSRebornCheckpointGetSerial() == player.NLSRebornCheckpointGetSource() ==
              player.NLSRebornCheckpointGetResult() == 0)
        # Fresh policy checks happen inside the helper, even if a caller carries
        # a stale earlier permission decision.
        for source_id, done, safety, service, result in itertools.product(
                (-1, 0, 1, 2, 3, 4, 999), (None, -1, 0, 1), (False, True), (False, True), (False, True)):
            detail = dict(source=source_id, done=done, safety=safety, service=service, result=result)
            player = runtime.fixture(done=done, protected=safety, service=service, native_result=result,
                                     mounted=True, combat=True)
            accepted = invoke(lambda: getattr(player, HELPER)(source_id), 'direct helper', detail)
            eligible = source_id in (1, 2, 3) and done == 1 and not safety
            check('helper result reflects native boolean and policy/service availability',
                  accepted is bool(eligible and service and result), detail)
            check('helper calls native once only after fresh policy and service checks',
                  runtime.state['forced'] == int(eligible and service), detail)
            check('diagnostic attempt records source and one bounded serial',
                  player.nlsCheckpointSource == source_id and player.nlsCheckpointSerial == 1, detail)
            expected_code = 4 if not eligible else 3 if not service else 1 if result else 2
            check('diagnostic result distinguishes policy service rejection and acceptance',
                  player.nlsCheckpointResult == expected_code, detail)
            check('attempt captures bounded lock combat and mounted observations',
                  player.nlsCheckpointLocks.startswith('locked|') and player.nlsCheckpointCombat == 1 and player.nlsCheckpointMounted == 1, detail)

        for serial, combat, mounted, locked in itertools.product((0, 17, 2147483646, 2147483647), (False, True), (False, True), (False, True)):
            player = runtime.fixture(combat=combat, mounted=mounted, locked=locked)
            player.nlsCheckpointSerial = serial
            accepted = invoke(lambda: getattr(player, HELPER)(2), 'diagnostic bounds', serial)
            expected_serial = serial + 1 if serial < 2147483647 else 1
            check('diagnostic serial stays bounded and getters expose current observations',
                  accepted is True and player.NLSRebornCheckpointGetSerial() == expected_serial and
                  player.NLSRebornCheckpointGetSource() == 2 and player.NLSRebornCheckpointGetResult() == 1 and
                  player.NLSRebornCheckpointGetCombat() == int(combat) and
                  player.NLSRebornCheckpointGetMounted() == int(mounted) and
                  player.NLSRebornCheckpointGetLocks() == player.NLSRebornSaveLockSummary(),
                  dict(serial=serial, combat=combat, mounted=mounted, locked=locked))
            check('diagnostic getters never submit extra native work', runtime.state['forced'] == 1)

        # Deferred attempts consume their token before a native call, and a
        # rejection is terminal for that token rather than an automatic retry.
        for source_id, result, service, reenter in itertools.product((1, 2, 3), (False, True), (False, True), (False, True)):
            detail = dict(source=source_id, native_result=result, service=service, reenter=reenter)
            player = runtime.fixture(mode=3, locked=False, reasons=(), enabled=True,
                                     native_result=result, service=service, reenter=reenter,
                                     combat=False, mounted=False)
            player.nlsAutosaveEnabled = True
            player.NLSRebornAutosaveReady = lambda: True
            player.nlsDeferredPending = True
            player.nlsDeferredSource = source_id
            serial = player.nlsDeferredSerial
            accepted = invoke(lambda: player.NLSRebornDeferredDispatch(serial), 'deferred dispatch', detail)
            check('deferred dispatch returns native request result', accepted is bool(service and result), detail)
            check('deferred token consumes only when service exists', player.nlsDeferredPending is (not service), detail)
            check('native sees consumed token', all(v is False for v in runtime.state['seen_pending']), detail)
            if service and reenter:
                check('reentrant dispatch cannot duplicate', runtime.state.get('reentry_result') is False, detail)
            second = invoke(lambda: player.NLSRebornDeferredDispatch(serial), 'repeat deferred dispatch', detail)
            check('rejected or accepted token never retries', second is False and runtime.state['forced'] == int(service), detail)
            positive = [m for m in runtime.state['notices'] if m.startswith(('existing contextual request', 'DF request'))]
            check('deferred positive notice needs native true', len(positive) == int(service and result), detail)

    return dict(source_sha256=hashlib.sha256(raw).hexdigest(), assertions=assertions,
                failed=len(failures), boundary_errors=len(errors),
                first_failures=failures[:30], first_errors=errors[:10],
                scope=__doc__.strip())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('release', type=Path)
    parser.add_argument('--expect-gap', action='store_true')
    args = parser.parse_args()
    result = evaluate(args.release)
    result['negative_control'] = args.expect_gap
    print(json.dumps(result, indent=2))
    raise SystemExit(not (result['failed'] > 0) if args.expect_gap else bool(result['failed'] or result['boundary_errors']))
