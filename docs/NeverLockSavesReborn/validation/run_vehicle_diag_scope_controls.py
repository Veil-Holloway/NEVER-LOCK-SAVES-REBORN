#!/usr/bin/env python3
"""Require diagnostic exact-source guard to reject scoped and unrelated edits."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
from check_vehicle_diag_scope import fixture

root = Path(sys.argv[1]).resolve()
here = Path(__file__).resolve().parent
f = fixture()
reds = 'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds'
report = 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/support_report.lua'
reason = 'Diagnostic source differs outside reviewed request-result changes'


def run(candidate):
    return subprocess.run([sys.executable, str(here / 'check_vehicle_diag_scope.py'), str(candidate)], text=True, capture_output=True)


baseline = run(root)
assert baseline.returncode == 0, baseline.stdout + baseline.stderr
cases = [(('changed_file_' + str(i)), rel, None, b'\n# unreviewed bytes\n', reason)
         for i, rel in enumerate(f['changed_files'])]
cases += [
    ('native_false_not_checked', reds, b'if !autosave.RequestForcedCheckpoint() {', b'if autosave.RequestForcedCheckpoint() && false {', reason),
    ('native_rejection_marked_accepted', reds, b'this.nlsCheckpointResult = 2;', b'this.nlsCheckpointResult = 1;', reason),
    ('deferred_result_ignored', reds, b'if !this.NLSRebornRequestCheckpoint(this.nlsDeferredSource) { return false; };', b'let ignored: Bool = this.NLSRebornRequestCheckpoint(this.nlsDeferredSource);', reason),
    ('unrelated_module', 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/autosave_policy.lua', None, b'\n-- unreviewed\n', 'Changed protected diagnostic file'),
    ('extra_runtime', 'r6/scripts/NeverLockSavesReborn/unreviewed.reds', None, b'// unexpected\n', 'Diagnostic runtime/helper file inventory changed'),
    ('missing_runtime', 'r6/scripts/NeverLockSavesReborn/DarkFutureMessages.reds', b'__REMOVE_FILE__', b'', 'Diagnostic runtime/helper file inventory changed'),
]
results = []
with tempfile.TemporaryDirectory(prefix='nlsr-diagnostic-scope-') as temporary:
    for name, rel, before, after, expected in cases:
        candidate = Path(temporary) / name
        for top in f['protected_roots']:
            shutil.copytree(root / top, candidate / top, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.pyo'))
        path = candidate / rel
        if before == b'__REMOVE_FILE__':
            path.unlink()
        elif before is None:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((path.read_bytes() if path.exists() else b'') + after)
        else:
            raw = path.read_bytes()
            assert raw.count(before) == 1, 'Mutation anchor not unique: ' + name
            path.write_bytes(raw.replace(before, after, 1))
        result = run(candidate)
        assert result.returncode != 0 and expected in result.stderr, 'Unexpected mutation result: ' + name + '\n' + result.stdout + result.stderr
        results.append({'control': name, 'rejected': True, 'reason': expected})
print(json.dumps({'scope': 'Exact source-identity controls only; no compiler/runtime/save proof.',
                  'candidate': 'passed', 'negative_controls': results}, indent=2))
print('PASS ' + str(len(results)) + ' diagnostic source-scope mutation controls')
