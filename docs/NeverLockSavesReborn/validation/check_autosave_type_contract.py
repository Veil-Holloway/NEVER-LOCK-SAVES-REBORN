#!/usr/bin/env python3
"""Regression for the exact unresolved type reported by the user's compiler.

The expected native type is pinned from primary game-script declarations in the
RC2 interface evidence. This source check cannot establish whole-mod compilation.
"""
from pathlib import Path
import json
import re
import sys

here = Path(__file__).parent
fixture = json.loads((here / 'fixtures/rc2_scope.json').read_text())
root = Path(sys.argv[1]).resolve()
spec = fixture['annotation_replacement']
data = (root / spec['path']).read_text()
match = re.search(r'public final func NLSRebornDeferredDispatch\(expectedSerial: Int32\) -> Bool \{(.*?)\n\}', data, re.S)
assert match, 'Deferred dispatch function not found'
body = match.group(1)
declarations = re.findall(r'let autosave: ref<([^>]+)> = GameInstance\.GetAutoSaveSystem\(this\.GetGame\(\)\);', body)
assert declarations == [spec['verified_type']], 'Autosave getter annotation must resolve to verified native gameAutoSaveSystem; found ' + repr(declarations)
assert 'ref<AutoSaveSystem>' not in data, 'Reported unresolved AutoSaveSystem type remains'
assert body.count('if !IsDefined(autosave) { return false; };') == 1, 'Service absence must remain fail-closed'
assert body.count('autosave.RequestForcedCheckpoint();') == 1, 'Expected one checkpoint submission'
assert body.index('if !IsDefined(autosave) { return false; };') < body.index('this.nlsDeferredPending = false;') < body.index('autosave.RequestForcedCheckpoint();'), 'Service guard/one-shot submission order changed'
assert body.index('this.NLSRebornDeferredNativeUnlocked()') < body.index('GameInstance.GetAutoSaveSystem'), 'Native dispatch guard must precede service query'
print('PASS source regression: verified gameAutoSaveSystem annotation, service fail-closed guard and one-shot order retained. Not a REDscript compiler pass.')
