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
assert body.count('if !this.NLSRebornRequestCheckpoint(this.nlsDeferredSource) { return false; };') == 1, 'Deferred dispatch must propagate checkpoint request rejection'
assert body.index('if !IsDefined(autosave) { return false; };') < body.index('this.nlsDeferredPending = false;') < body.index('this.NLSRebornRequestCheckpoint('), 'Service guard/one-shot submission order changed'
assert body.index('this.NLSRebornDeferredNativeUnlocked()') < body.index('GameInstance.GetAutoSaveSystem'), 'Native dispatch guard must precede service query'
helper_match = re.search(r'public final func NLSRebornRequestCheckpoint\(source: Int32\) -> Bool \{(.*?)\n\}', data, re.S)
assert helper_match, 'Shared checkpoint request helper missing'
helper = helper_match.group(1)
assert re.findall(r'let autosave: ref<([^>]+)> = GameInstance\.GetAutoSaveSystem\(this\.GetGame\(\)\);', helper) == [spec['verified_type']], 'Shared helper must use verified gameAutoSaveSystem type'
assert data.count('autosave.RequestForcedCheckpoint()') == 1, 'Expected exactly one native checkpoint seam'
assert helper.count('if !autosave.RequestForcedCheckpoint() {') == 1, 'Native Bool result must be tested'
assert helper.index('if !IsDefined(autosave) {') < helper.index('autosave.RequestForcedCheckpoint()'), 'Shared service guard must precede native call'
assert helper.index('this.nlsCheckpointResult = 2;') < helper.index('this.nlsCheckpointResult = 1;'), 'Native rejection and acceptance states missing'
print('PASS source regression: verified gameAutoSaveSystem types, service fail-closed guards, consume-before-shared-request ordering and checked single native Bool seam. Not a REDscript compiler pass.')
