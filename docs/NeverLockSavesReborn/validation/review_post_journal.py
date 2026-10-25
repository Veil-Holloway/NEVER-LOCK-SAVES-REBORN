"""Isolated filesystem/fault-boundary repro; never runs game or Windows tasklist."""
from pathlib import Path
import importlib.util
import sys
import json
import tempfile
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('candidate',Path(sys.argv[1]))
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)

def fixture(home):
    slot=home/'slot';slot.mkdir();(slot/'sav.dat').write_bytes(b'fixture')
    root=home/'backups'
    for i in range(4):
        m=g.backup(slot,root,_probe=lambda:None)
        p=root/m['snapshot_id']/'manifest.json'
        m.update(retention_profile='review',retention_source='a'*64,character_id='character',created_utc=f'2026-10-24T00:00:0{i}+00:00')
        p.write_text(json.dumps(m))
    return root,g._profile_plan(root,'review',2)

results=[]
with tempfile.TemporaryDirectory(prefix='guardian-review-') as temp:
    home=Path(temp);root,plan=fixture(home)
    state={'running':False}
    original=g._journal
    def journal_then_game_starts(store,value):
        original(store,value)
        if value.get('status')=='in_progress':state['running']=True
    def probe():
        if state['running']:raise g.GuardianError('injected game reopened')
    with mock.patch.object(g,'_journal',side_effect=journal_then_game_starts):
        result=g._retire_locked(root,plan,_probe=probe)
    results.append({'case':'game_reopened_during_journal','retired_while_game_running':len(result['retired_ids']),'result':result})

with tempfile.TemporaryDirectory(prefix='guardian-review-') as temp:
    home=Path(temp);root,plan=fixture(home)
    outside=home/'outside';outside.mkdir()
    original=g._journal;changed={'value':False}
    def journal_then_store_swapped(store,value):
        original(store,value)
        if value.get('status')=='in_progress' and not changed['value']:
            store.rename(root/'.retired-original')
            store.symlink_to(outside,target_is_directory=True)
            changed['value']=True
    with mock.patch.object(g,'_journal',side_effect=journal_then_store_swapped):
        result=g._retire_locked(root,plan,_probe=lambda:None)
    moved=[p.name for p in outside.iterdir() if g.ID.fullmatch(p.name)]
    results.append({'case':'retired_directory_swapped_after_precheck','snapshot_ids_moved_outside_root':moved,'result':result})

print(json.dumps(results,indent=2))
assert results[0]['retired_while_game_running']==0,'game reopen must prevent moves'
assert not results[1]['snapshot_ids_moved_outside_root'],'store swap must prevent outside moves'
