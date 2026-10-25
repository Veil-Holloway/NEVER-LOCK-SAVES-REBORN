#!/usr/bin/env python3
"""Require RC2's source contract and exact-preservation guard to reject edits.

Temporary source mutations are not game or REDscript compiler executions.
"""
import json
from check_rc3_scope import normalized_rc2
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
here = Path(__file__).resolve().parent
fixture = json.loads((here / 'fixtures/rc2_scope.json').read_text())
init, reds = tuple(fixture['label_files'])
module = 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/support_report.lua'
helper = 'tools/NLSRSaveGuardian/save_guardian.py'


def run(candidate, script='check_rc2_scope.py'):
    return subprocess.run([sys.executable, str(here / script), str(candidate)], capture_output=True, text=True)


for script in ('check_rc2_scope.py', 'check_autosave_type_contract.py'):
    result = run(root, script)
    assert result.returncode == 0, 'Unmodified candidate failed ' + script + ': ' + result.stdout + result.stderr

cases = [
    ('reported_type_regression', reds, b'ref<gameAutoSaveSystem>', b'ref<AutoSaveSystem>', 'Verified autosave type declaration missing'),
    ('guessed_type_regression', reds, b'ref<gameAutoSaveSystem>', b'ref<AutosaveSystem>', 'Verified autosave type declaration missing'),
    ('getter_spelling_changed', reds, b'GameInstance.GetAutoSaveSystem(this.GetGame());', b'GameInstance.GetAutosaveSystem(this.GetGame());', 'Verified autosave type declaration missing'),
    ('service_guard_removed', reds, b'  if !IsDefined(autosave) { return false; };\r\n', b'', 'RC2 source differs outside exact type/labels'),
    ('pending_clear_removed', reds, b'  this.nlsDeferredPending = false; // clear before dispatch to prevent duplicates\r\n', b'', 'RC2 source differs outside exact type/labels'),
    ('checkpoint_submit_changed', reds, b'autosave.RequestForcedCheckpoint();', b'autosave.RequestCheckpoint();', 'RC2 source differs outside exact type/labels'),
    ('mixed_init_version', init, b'1.0.0-rc2', b'1.0.0-rc1', 'Unexpected RC2 version count'),
    ('init_nonlabel_change', init, None, b'\n-- unreviewed source edit\n', 'RC2 source differs outside exact type/labels'),
    ('module_changed', module, None, b'\n-- unreviewed source edit\n', 'Changed protected RC2 file'),
    ('companion_changed', helper, None, b'\n# unreviewed helper edit\n', 'Changed protected RC2 file'),
    ('extra_runtime_file', 'r6/scripts/NeverLockSavesReborn/unreviewed.reds', None, b'// unexpected runtime file\n', 'RC2 runtime/helper file inventory changed'),
    ('missing_runtime_file', module, b'__REMOVE_FILE__', b'', 'RC2 runtime/helper file inventory changed'),
]
results = []
with tempfile.TemporaryDirectory(prefix='nlsr-rc2-source-') as tmp:
    for name, rel, before, after, expected in cases:
        candidate = Path(tmp) / name
        for top in fixture['protected_roots']:
            shutil.copytree(root / top, candidate / top, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.pyo'))
        # Retain the original twelve RC2 mutations on exact RC2-normalized fixtures.
        for label_rel in fixture['label_files']:
            (candidate / label_rel).write_bytes(normalized_rc2(root, label_rel))
        p = candidate / rel
        if before == b'__REMOVE_FILE__':
            p.unlink()
        elif before is None:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes((p.read_bytes() if p.exists() else b'') + after)
        else:
            data = p.read_bytes()
            assert data.count(before) >= 1, 'Control anchor missing: ' + name
            p.write_bytes(data.replace(before, after, 1))
        result = run(candidate)
        assert result.returncode != 0 and expected in result.stderr, 'Control did not fail for intended reason: ' + name + '\n' + result.stdout + result.stderr
        if name in ('reported_type_regression', 'guessed_type_regression'):
            contract = run(candidate, 'check_autosave_type_contract.py')
            assert contract.returncode != 0 and 'must resolve to verified native gameAutoSaveSystem' in contract.stderr, 'Type contract missed ' + name
        results.append({'control': name, 'rejected': True, 'reason': expected})
print(json.dumps({'scope': 'RC2 source/identity checks only; no compiler or game runtime.',
                  'unmodified_candidate': 'passed', 'negative_controls': results}, indent=2))
print('PASS twelve intended RC2 source-scope mutation controls; reported and guessed type regressions also fail focused contract')
