"""Controlled local fixture verifies protected-set checks cover journal IO."""
from pathlib import Path
import importlib.util
import sys
import json
import shutil
import tempfile
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('candidate',Path(sys.argv[1]))
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
with tempfile.TemporaryDirectory(prefix='guardian-protected-') as temp:
    home=Path(temp);slot=home/'slot';slot.mkdir();(slot/'sav.dat').write_bytes(b'fixture')
    root=home/'backups'
    for i in range(3):
        m=g.backup(slot,root,_probe=lambda:None)
        m.update(retention_profile='review',retention_source='a'*64,character_id='character',created_utc=f'2026-10-24T00:00:0{i}+00:00')
        (root/m['snapshot_id']/'manifest.json').write_text(json.dumps(m))
    plan=g._profile_plan(root,'review',2)
    protected=plan['streams'][0]['protected_ids'][0]
    original=g._journal;changed={'value':False}
    def journal_then_protected_changes(store,value):
        original(store,value)
        if value.get('status')=='in_progress' and not changed['value']:
            (root/protected/'data/sav.dat').write_bytes(b'corrupted during journal')
            changed['value']=True
    with mock.patch.object(g,'_journal',side_effect=journal_then_protected_changes):
        result=g._retire_locked(root,plan,_probe=lambda:None)
    active=g.list_snapshots(root)
    count=sum(x['status']=='hash_verified' for x in active)
    print(json.dumps({'retention':result,'verified_active_copies':count,'active':active},indent=2))
    assert count>=2 and result['status']=='stopped' and not result['retired_ids'],'changed protected copy must stop retirement before moving'
