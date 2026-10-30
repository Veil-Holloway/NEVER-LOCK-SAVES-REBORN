"""Current shipped inventory, test-plan coverage, saved-byte pins and frozen game code."""
import hashlib,json,re,sys
from pathlib import Path
r=Path(sys.argv[1]);version='1.0.0';checks=0
def check(value,label):
 global checks
 checks+=1;assert value,label
manifest=json.loads((r/'RUNTIME_MANIFEST.json').read_text())
baseline=json.loads((r/'BASELINE-RUNTIME.json').read_text())
tool=r/'tools/NLSRInstallAudit'
actual={p.relative_to(r).as_posix()for folder in ('bin','r6')for p in (r/folder).rglob('*')if p.is_file()and p.suffix in ('.lua','.reds')}
listed={row['path']for row in manifest['runtime_files']}
check(actual==listed,'every runtime file is covered exactly')
check(len(listed)==len(manifest['runtime_files'])==21,'unique complete runtime inventory')
check(manifest['release']==version,'manifest version')
check((tool/'runtime_inventory.json').read_bytes()==(r/'RUNTIME_MANIFEST.json').read_bytes(),'auditor and package inventory byte-identical')
pin=re.search(r"INVENTORY_SHA256 = '([0-9a-f]+)'",(tool/'audit_installation.py').read_text())[1]
check(pin==hashlib.sha256((tool/'runtime_inventory.json').read_bytes()).hexdigest(),'pin hashes saved bytes, not a platform newline template')
for row in manifest['runtime_files']:
 data=(r/row['path']).read_bytes()
 check(len(data)==row['size']and hashlib.sha256(data).hexdigest()==row['sha256'],'current manifest exact '+row['path'])
for row in baseline['runtime_files']:
 p=r/row['path']
 presentation=baseline.get('presentation_only_files',{}).get(row['path'])
 expected=presentation['expected_sha256'] if presentation else row['sha256']
 check(hashlib.sha256(p.read_bytes()).hexdigest()==expected,'working runtime frozen except exact presentation edits '+row['path'])
plan=json.loads((r/'docs/NeverLockSavesReborn/validation/RELEASE-TEST-PLAN.json').read_text())
names=[c['check']for c in plan['checks']]
check(len(names)==len(set(names)),'unique active check names')
retired={c['check']for c in plan['retired_checks']}
check(retired=={'backup_recovery','retention_journal_review','retention_protected_review'},'retired scope explicitly recorded')
check(not retired.intersection(names),'retired checks are not relabeled as passes')
for required in ('completion_tracker','completion_notifications','phone_bridge_fix','notification_plain_language','all_runtime_lua_syntax','release_contract','installation_auditor'):
 check(required in names,'current capability covered '+required)
check(len(list((r/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn').glob('*.lua')))==18,'all 18 Lua files including completion tracker included')
print('PASS release contract: '+str(checks)+' assertions; frozen runtime, exact saved-byte manifests and current plan')
