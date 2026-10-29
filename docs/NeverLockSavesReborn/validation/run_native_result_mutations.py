#!/usr/bin/env python3
"""Mutation controls for the independent checked native-result regression."""
import argparse
import hashlib
import importlib.util
import json
import shutil
from pathlib import Path


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('release', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
test = load('independent_native_result_regression', Path(__file__).with_name('test_checkpoint_native_result.py'))
subset = load('mutation_native_result_subset', args.release / 'docs/NeverLockSavesReborn/validation/source_subset.py')
path = args.release / test.REDS
source = path.read_text()
args.output.mkdir(parents=True, exist_ok=True)


def change(name, before, after):
    body = subset.body(source, name)
    if body.count(before) != 1:
        raise ValueError('Expected unique mutation anchor: ' + name + ': ' + before)
    return source.replace(body, body.replace(before, after, 1), 1)


mutants = {
    'native_false_discarded': change('NLSRebornRequestCheckpoint',
        'if !autosave.RequestForcedCheckpoint() {', 'if autosave.RequestForcedCheckpoint() && false {'),
    'fresh_intro_guard_removed': change('NLSRebornRequestCheckpoint',
        ' || !this.NLSRebornDeferredIntroComplete()', ''),
    'failure_notification_ignores_master': change('NLSRebornCheckpointFailure',
        'if !this.NLSRebornGetNotificationsEnabled() { return; };', ''),
    'rejected_request_reports_accepted_code': change('NLSRebornRequestCheckpoint',
        'this.nlsCheckpointResult = 2;', 'this.nlsCheckpointResult = 1;'),
    'deferred_return_discards_helper_result': change('NLSRebornDeferredDispatch',
        'if !this.NLSRebornRequestCheckpoint(this.nlsDeferredSource) { return false; };',
        'let ignored: Bool = this.NLSRebornRequestCheckpoint(this.nlsDeferredSource);'),
    'attempt_serial_overflows_bound': change('NLSRebornRequestCheckpoint',
        'if this.nlsCheckpointSerial < 2147483647 {', 'if true {'),
}
outcomes = {}
for name, mutant in mutants.items():
    root = args.output / name
    reds = root / test.REDS
    reds.parent.mkdir(parents=True, exist_ok=True)
    reds.write_text(mutant)
    validation = root / 'docs/NeverLockSavesReborn/validation'
    validation.mkdir(parents=True, exist_ok=True)
    for file in ('source_subset.py', 'test_smart_queue_routes.py'):
        shutil.copyfile(args.release / 'docs/NeverLockSavesReborn/validation' / file, validation / file)
    result = test.evaluate(root)
    (args.output / (name + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    outcomes[name] = dict(detected=result['failed'] > 0, failed=result['failed'], boundary_errors=result['boundary_errors'])
report = dict(source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), controls=outcomes,
              detected=sum(v['detected'] for v in outcomes.values()), total=len(outcomes))
(args.output / 'MUTATION-RESULTS.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
raise SystemExit(any(not v['detected'] or v['boundary_errors'] for v in outcomes.values()))
