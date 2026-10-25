#!/usr/bin/env python3
"""Require RC3 exact-preservation checks to reject mutations and inventory drift.

Temporary byte edits do not execute REDscript, CET or the game.
"""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
here = Path(__file__).resolve().parent
fixture = json.loads((here / 'fixtures/rc3_scope.json').read_text())
init, reds = tuple(fixture['changed_files'])
module = 'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/support_report.lua'
helper = 'tools/NLSRSaveGuardian/save_guardian.py'


def run(candidate):
    return subprocess.run([sys.executable, str(here / 'check_rc3_scope.py'), str(candidate)], capture_output=True, text=True)


baseline = run(root)
assert baseline.returncode == 0, 'Unmodified RC3 failed: ' + baseline.stdout + baseline.stderr
source_reason = 'RC3 source differs outside reviewed Smart routing/labels'
cases = [
    ('smart_mode_scope_changed', reds, b'player.NLSRebornGetMode() != 3 ||', b'player.NLSRebornGetMode() != 0 ||', source_reason),
    ('smart_queue_admission_removed', reds, b'if player.NLSRebornDeferredQueue(source) {', b'if false {', source_reason),
    ('manual_smart_call_removed', reds, b'    if NLSRebornPolicy.HandleSmartBlockedSave(this.m_gameInstance, 1) { return; };\r\n', b'', source_reason),
    ('pause_smart_call_removed', reds, b'    if NLSRebornPolicy.HandleSmartBlockedSave(this.m_gameInstance, 2) { return; };\r\n', b'', source_reason),
    ('gameplay_smart_call_removed', reds, b'    if NLSRebornPolicy.HandleSmartBlockedSave(this.GetPlayerControlledObject().GetGame(), 2) { return; };\r\n', b'', source_reason),
    ('native_unlock_dispatch_guard_removed', reds, b' || !this.NLSRebornDeferredNativeUnlocked()', b'', source_reason),
    ('pending_clear_removed', reds, b'  this.nlsDeferredPending = false; // clear before dispatch to prevent duplicates\r\n', b'', source_reason),
    ('reported_autosave_type_regression', reds, b'ref<gameAutoSaveSystem>', b'ref<AutoSaveSystem>', source_reason),
    ('mixed_init_version', init, b'1.0.0-rc3', b'1.0.0-rc2', source_reason),
    ('init_nonlabel_change', init, None, b'\n-- unreviewed source edit\n', source_reason),
    ('module_changed', module, None, b'\n-- unreviewed source edit\n', 'Changed protected RC3 file'),
    ('companion_changed', helper, None, b'\n# unreviewed helper edit\n', 'Changed protected RC3 file'),
    ('extra_runtime_file', 'r6/scripts/NeverLockSavesReborn/unreviewed.reds', None, b'// unreviewed\n', 'RC3 runtime/helper file inventory changed'),
    ('missing_runtime_file', module, b'__REMOVE_FILE__', b'', 'RC3 runtime/helper file inventory changed'),
]
results = []
with tempfile.TemporaryDirectory(prefix='nlsr-rc3-scope-') as temporary:
    for name, rel, before, after, expected in cases:
        candidate = Path(temporary) / name
        for top in fixture['protected_roots']:
            shutil.copytree(root / top, candidate / top, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.pyo'))
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
print(json.dumps({'scope': 'Exact source/identity controls only; no game/runtime/compiler.',
                  'unmodified_candidate': 'passed', 'negative_controls': results}, indent=2))
print('PASS fourteen intended RC3 source-scope mutation controls')
