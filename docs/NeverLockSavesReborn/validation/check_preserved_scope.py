#!/usr/bin/env python3
"""Identity checks for baseline bodies intentionally outside this change.

Hashes compare exact normalized source text, not executed game behavior.
The fixture was generated from the preserved authenticated preRC1 input.
"""
import argparse
import ast
import hashlib
import json
from pathlib import Path
from check_vehicle_diag_scope import normalized_rc4
from bounded_source_runner import body
from check_rc2_scope import normalized_rc1

def sha(value):
    return hashlib.sha256(value).hexdigest()

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('release',type=Path)
a=p.parse_args()
root=a.release.resolve()
fixture=json.loads((Path(__file__).parent/'fixtures/preserved_preRC1.json').read_text())
for name,expected in fixture['unchanged_files'].items():
    assert sha(normalized_rc4(root,name))==expected, 'Changed protected file: '+name
source=normalized_rc1(root,fixture['redscript_path']).decode('utf-8').replace('\r\n','\n')
for name,expected in fixture['redscript_functions'].items():
    assert sha(body(source,name).encode())==expected, 'Changed protected method: '+name
for name,expected in fixture['notification_only_hooks'].items():
    hook=body(source,name)
    addition=' && !queuePlayer.NLSRebornGetStatusNotificationsEnabled()'
    assert hook.count(addition)==1, 'Unexpected notification guard count: '+name
    assert sha(hook.replace(addition,'').encode())==expected, 'Changed save policy inside request hook: '+name
helper=(root/'tools/NLSRSaveGuardian/save_guardian.py').read_text()
nodes={n.name:n for n in ast.parse(helper).body if isinstance(n,(ast.FunctionDef,ast.ClassDef))}
for name,expected in fixture['helper_functions'].items():
    assert sha(ast.get_source_segment(helper,nodes[name]).encode())==expected, 'Changed prior companion mutator/helper: '+name
print('PASS preserved scope: '+str(len(fixture['unchanged_files']))+' files, '+
      str(len(fixture['redscript_functions']))+' REDscript methods, '+
      str(len(fixture['helper_functions']))+' companion functions/classes match preRC1; three request hooks differ only by a notification guard. Source identity only.')
