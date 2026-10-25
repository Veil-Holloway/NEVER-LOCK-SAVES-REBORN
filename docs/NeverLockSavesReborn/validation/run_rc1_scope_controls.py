#!/usr/bin/env python3
"""Exercise RC1 source-freeze rejection using independent, temporary byte edits."""
import json
from pathlib import Path
from check_rc2_scope import normalized_rc1
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
here = Path(__file__).resolve().parent
fixture = json.loads((here / 'fixtures/rc1_scope.json').read_text())
init, reds = tuple(fixture['label_files'])
module = 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/support_report.lua'
helper = 'tools/NLSRSaveGuardian/save_guardian.py'

def run(candidate):
    return subprocess.run([sys.executable, str(here / 'check_rc1_scope.py'), str(candidate)], capture_output=True, text=True)

baseline = run(root)
assert baseline.returncode == 0, 'Unmodified candidate must pass before controls: ' + baseline.stderr
cases = [
    ('mixed_init_version', init, b'1.0.0-rc1', b'0.14.0-preRC4', 'Unexpected RC1 version count'),
    ('mixed_init_title', init, b'Release Candidate', b'Release Testing Preview', 'Unexpected RC1 title count'),
    ('init_nonlabel_change', init, b'local function saveConfig()', b'local function saveConfig() -- unreviewed body edit', 'RC1 source differs from frozen labels'),
    ('reds_wrong_version', reds, b'1.0.0-rc1', b'1.0.0-rc2', 'Unexpected RC1 version count'),
    ('reds_nonlabel_change', reds, None, b'\n// unreviewed source edit\n', 'RC1 source differs from frozen labels'),
    ('module_changed', module, None, b'\n-- unreviewed module edit\n', 'Changed protected RC1 file'),
    ('companion_changed', helper, None, b'\n# unreviewed companion edit\n', 'Changed protected RC1 file'),
    ('extra_runtime_file', 'r6/scripts/NeverLockSavesReborn/unreviewed.reds', None, b'// unexpected runtime file\n', 'Runtime/helper file inventory changed'),
    ('missing_runtime_file', module, b'__REMOVE_FILE__', b'', 'Runtime/helper file inventory changed'),
]
results = []
with tempfile.TemporaryDirectory(prefix='nlsr-rc1-scope-') as tmp:
    for name, rel, before, after, expected in cases:
        candidate = Path(tmp) / name
        for top in fixture['protected_roots']:
            shutil.copytree(root / top, candidate / top, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.pyo'))
        # Exercise the original nine RC1 controls against exact RC1-normalized fixtures.
        for label_rel in fixture['label_files']:
            (candidate / label_rel).write_bytes(normalized_rc1(root, label_rel))
        p = candidate / rel
        if before == b'__REMOVE_FILE__':
            p.unlink()
        elif before is None:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes((p.read_bytes() if p.exists() else b'') + after)
        else:
            b = p.read_bytes()
            assert b.count(before) >= 1, 'Control anchor missing: ' + name
            p.write_bytes(b.replace(before, after, 1))
        result = run(candidate)
        assert result.returncode != 0 and expected in result.stderr, 'Control did not fail for intended source-scope reason: ' + name + '\n' + result.stdout + result.stderr
        results.append({'control': name, 'rejected': True, 'reason': expected})
print(json.dumps({'scope':'RC1 source-preservation checks only; no game runtime.', 'unmodified_candidate':'passed', 'negative_controls':results}, indent=2))
print('PASS nine intended RC1 source-freeze mutation controls')
