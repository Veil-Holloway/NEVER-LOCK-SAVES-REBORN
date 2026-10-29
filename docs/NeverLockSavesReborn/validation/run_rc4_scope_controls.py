#!/usr/bin/env python3
"""Require exact RC4 preservation checks to reject routing/guard/inventory mutations.

These temporary byte edits do not execute REDscript, CET, or Cyberpunk.
"""
import json
from pathlib import Path
from check_vehicle_diag_scope import normalize_reviewed_files
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
here = Path(__file__).resolve().parent
fixture = json.loads((here / 'fixtures/rc4_scope.json').read_text())
init, reds = tuple(fixture['changed_files'])
module = 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/support_report.lua'
helper = 'tools/NLSRSaveGuardian/save_guardian.py'
source_reason = 'RC4 source differs outside reviewed Unrestricted routing/cleanup'


def run(candidate):
    return subprocess.run([sys.executable, str(here / 'check_rc4_scope.py'), str(candidate)], capture_output=True, text=True)


baseline = run(root)
assert baseline.returncode == 0, 'Unmodified RC4 failed: ' + baseline.stdout + baseline.stderr
cases = [
    ('unrestricted_admission_guard_removed', reds, b'  if this.NLSRebornGetMode() == 2 {\r\n', b'  if false {\r\n', source_reason),
    ('unrestricted_fresh_request_cleanup_removed', reds, b'  if this.NLSRebornGetMode() == 2 {\r\n    this.nlsDeferredPending = false;\r\n', b'  if this.NLSRebornGetMode() == 2 {\r\n', source_reason),
    ('mode_switch_manual_cleanup_removed', reds, b'    if mode == 2 && (this.nlsDeferredSource == 1 || this.nlsDeferredSource == 2) { this.nlsDeferredPending = false; };\r\n', b'', source_reason),
    ('mode_switch_cancels_automatic_work', reds, b'if mode == 2 && (this.nlsDeferredSource == 1 || this.nlsDeferredSource == 2)', b'if mode == 2', source_reason),
    ('intro_queue_guard_removed', reds, b' || !this.NLSRebornDeferredIntroComplete() { return false; };', b' { return false; };', source_reason),
    ('smart_admission_removed', reds, b'if player.NLSRebornDeferredQueue(source) {', b'if false {', source_reason),
    ('native_unlock_dispatch_guard_removed', reds, b' || !this.NLSRebornDeferredNativeUnlocked()', b'', source_reason),
    ('checkpoint_pending_clear_removed', reds, b'  this.nlsDeferredPending = false; // clear before dispatch to prevent duplicates\r\n', b'', source_reason),
    ('reported_autosave_type_regression', reds, b'ref<gameAutoSaveSystem>', b'ref<AutoSaveSystem>', source_reason),
    ('mixed_init_version', init, b'1.0.0-rc4', b'1.0.0-rc3', source_reason),
    ('queue_help_drift', init, b'Unrestricted attempts immediately.', b'Unrestricted always queues.', source_reason),
    ('unrelated_init_change', init, None, b'\n-- unreviewed code\n', source_reason),
    ('module_changed', module, None, b'\n-- unreviewed module\n', 'Changed protected RC4 file'),
    ('companion_changed', helper, None, b'\n# unreviewed helper\n', 'Changed protected RC4 file'),
    ('extra_runtime_file', 'r6/scripts/NeverLockSavesReborn/unreviewed.reds', None, b'// unexpected runtime\n', 'RC4 runtime/helper file inventory changed'),
    ('missing_runtime_file', module, b'__REMOVE_FILE__', b'', 'RC4 runtime/helper file inventory changed'),
]
results = []
with tempfile.TemporaryDirectory(prefix='nlsr-rc4-scope-') as temporary:
    for name, rel, before, after, expected in cases:
        candidate = Path(temporary) / name
        for top in fixture['protected_roots']:
            shutil.copytree(root / top, candidate / top, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.pyo'))
        normalize_reviewed_files(candidate)
        path = candidate / rel
        if before == b'__REMOVE_FILE__':
            path.unlink()
        elif before is None:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((path.read_bytes() if path.exists() else b'') + after)
        else:
            data = path.read_bytes()
            assert data.count(before) >= 1, 'Mutation anchor missing: ' + name
            path.write_bytes(data.replace(before, after, 1))
        result = run(candidate)
        assert result.returncode != 0 and expected in result.stderr, 'Mutation was not rejected for intended reason: ' + name + '\n' + result.stdout + result.stderr
        results.append({'control': name, 'rejected': True, 'reason': expected})
print(json.dumps({'scope': 'Exact source/identity controls only; not compiler/runtime/gameplay.',
                  'unmodified_candidate': 'passed', 'negative_controls': results}, indent=2))
print('PASS sixteen intended RC4 source-scope mutation controls')
