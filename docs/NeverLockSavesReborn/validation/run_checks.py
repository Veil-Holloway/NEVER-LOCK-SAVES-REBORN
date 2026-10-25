#!/usr/bin/env python3
"""Offline boundary checks only; no game launch or save-file access.

Requirements: Python 3.10+ and texlua or luatex. Optional --lua accepts a
Lua 5.3+ executable; the integration harness uses explicit Lua environments.
This runner does not compile REDscript or certify CET's Lua 5.1 runtime.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--release',type=Path,default=HERE.parents[2])
p.add_argument('--output',type=Path,required=True)
p.add_argument('--lua')
a=p.parse_args()
root=a.release.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
module_dir=root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn'
if a.lua:
    lua=[a.lua]
elif shutil.which('texlua'):
    lua=[shutil.which('texlua')]
elif shutil.which('luatex'):
    lua=[shutil.which('luatex'),'--luaonly']
else:
    raise SystemExit('Lua 5.3+ test host missing; no checks are claimed passed.')
cases=[
 ('lua_syntax',lua+[str(HERE/'check_lua_syntax.lua'),str(root)]),
 ('guardian_ledger',lua+[str(HERE/'test_guardian.lua'),str(root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn')]),
 ('guardian_observers',lua+[str(HERE/'test_guardian_bridge.lua'),str(root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/guardian_bridge.lua'),str(root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn/guardian.lua')]),
 ('guardian_integration',lua+[str(HERE/'test_guardian_integration.lua'),str(root)]),
 ('backup_recovery',[sys.executable,'-m','unittest','discover','-s',str(root/'tools/NLSRSaveGuardian'),'-p','test_*.py','-v']),
 ('retention_journal_review',[sys.executable,str(HERE/'review_post_journal.py'),str(root/'tools/NLSRSaveGuardian/save_guardian.py')]),
 ('retention_protected_review',[sys.executable,str(HERE/'review_protected_journal.py'),str(root/'tools/NLSRSaveGuardian/save_guardian.py')]),
 ('lua_integration',lua+[str(HERE/'test_lua_integration.lua'),str(root)]),
 ('queue_lifecycle',lua+[str(HERE/'test_queue_fresh.lua'),str(root)]),
 ('df_adapter',lua+[str(HERE/'test_dark_future.lua'),str(root)]),
 ('intro_routing',[sys.executable,str(HERE/'reproduce_fresh_intro_fallback.py'),str(root),'--expect-fixed']),
 ('df_reader',[sys.executable,str(HERE/'test_df_reader.py'),'--release',str(root),'--self-check']),
 ('notifications',[sys.executable,str(HERE/'test_notifications.py'),'--release',str(root)]),
 ('smart_policy_independent',[sys.executable,str(HERE/'test_smart_source.py'),str(root)]),
 ('autosave_bridge_independent',[sys.executable,str(HERE/'test_autosave_source.py'),str(root)]),
 ('autosave_scheduler',lua+[str(HERE/'test_autosave_policy.lua'),str(module_dir/'autosave_policy.lua')]),
 ('autosave_scheduler_independent',lua+[str(HERE/'test_scheduler_independent.lua'),str(module_dir/'autosave_policy.lua')]),
 ('support_report',lua+[str(HERE/'test_support_report.lua'),str(module_dir)]),
 ('profiles_independent',lua+[str(HERE/'review_profiles.lua'),str(module_dir/'profiles.lua')]),
 ('support_report_independent',lua+[str(HERE/'review_support_report.lua'),str(module_dir)]),
 ('quest_milestone_events',lua+[str(HERE/'test_quest_milestones.lua'),str(module_dir/'quest_milestones.lua')]),
 ('preserved_scope',[sys.executable,str(HERE/'check_preserved_scope.py'),str(root)]),
 ('autosave_init_independent',lua+[str(HERE/'test_init_priority.lua'),str(root)]),
 ('runtime_settings',lua+[str(HERE/'test_runtime_settings.lua'),str(root)]),
 ('quest_scheduler_independent',lua+[str(HERE/'review_quest_milestones.lua'),str(module_dir/'quest_milestones.lua'),str(module_dir/'autosave_policy.lua')]),
 ('quest_reentry_independent',lua+[str(HERE/'review_reentrant_boundaries.lua'),str(module_dir/'quest_milestones.lua')]),
 ('quest_bridge_source_independent',[sys.executable,str(HERE/'review_quest_source.py'),str(root/'r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds')]),
 ('quest_mutation_controls',[sys.executable,str(HERE/'run_quest_checks.py'),'--module',str(module_dir/'quest_milestones.lua'),'--output',str(out/'quest_mutation_controls'),'--lua',lua[0]]+['--lua-arg='+value for value in lua[1:]]),
 ('scheduler_mutation_controls',[sys.executable,str(HERE/'run_scheduler_controls.py'),str(module_dir/'autosave_policy.lua'),'--lua',lua[0]]+['--lua-arg='+value for value in lua[1:]]),
 ('status_messages',lua+[str(HERE/'test_status_messages.lua'),str(module_dir)]),
 ('status_mutation_controls',[sys.executable,str(HERE/'run_status_checks.py'),'--module-dir',str(module_dir),'--output',str(out/'status_mutation_controls'),'--lua',lua[0]]+['--lua-arg='+value for value in lua[1:]]),
 ('apartment_policy',lua+[str(HERE/'test_apartment_policy.lua'),str(module_dir/'autosave_policy.lua')]),
 ('apartment_mutation_controls',[sys.executable,str(HERE/'run_apartment_checks.py'),'--module',str(module_dir/'autosave_policy.lua'),'--output',str(out/'apartment_mutation_controls'),'--lua',lua[0]]+['--lua-arg='+value for value in lua[1:]]),
 ('observer_diagnostics',lua+[str(HERE/'test_observer_diagnostics.lua'),str(module_dir)]),
 ('support_observers',lua+[str(HERE/'test_report_observers.lua'),str(module_dir)]),
 ('runtime_polish_independent',lua+[str(HERE/'test_runtime_polish_independent.lua'),str(root)]),
 ('status_independent',lua+[str(HERE/'test_status_public_independent.lua'),str(module_dir)]),
 ('dependency_export_independent',[sys.executable,str(HERE/'run_dependency_export_independent.py'),'--release',str(root),'--output',str(out/'dependency_export_independent'),'--lua',lua[0]]+['--lua-arg='+value for value in lua[1:]]),
 ('dependency_scope',[sys.executable,str(HERE/'check_dependency_scope.py'),str(root)]),
 ('rc1_source_freeze',[sys.executable,str(HERE/'check_rc1_scope.py'),str(root)]),
 ('autosave_type_contract',[sys.executable,str(HERE/'check_autosave_type_contract.py'),str(root)]),
 ('smart_queue_routes',[sys.executable,str(HERE/'test_smart_queue_routes.py'),str(root)]),
 ('unrestricted_routes',[sys.executable,str(HERE/'test_unrestricted_routes.py'),str(root)]),
 ('rc4_source_freeze',[sys.executable,str(HERE/'check_rc4_scope.py'),str(root)]),
 ('rc4_scope_controls',[sys.executable,str(HERE/'run_rc4_scope_controls.py'),str(root)]),
 ('rc3_source_freeze',[sys.executable,str(HERE/'check_rc3_scope.py'),str(root)]),
 ('rc3_scope_controls',[sys.executable,str(HERE/'run_rc3_scope_controls.py'),str(root)]),
 ('rc2_source_freeze',[sys.executable,str(HERE/'check_rc2_scope.py'),str(root)]),
 ('rc2_scope_controls',[sys.executable,str(HERE/'run_rc2_scope_controls.py'),str(root)]),
 ('rc1_scope_controls',[sys.executable,str(HERE/'run_rc1_scope_controls.py'),str(root)]),
 ('installation_auditor',[sys.executable,'-B','-m','unittest','discover','-s',str(root/'tools/NLSRInstallAudit/tests'),'-p','test_*.py','-v']),
 ('dependency_versions',lua+[str(HERE/'test_dependency_versions.lua'),str(module_dir/'dependency_versions.lua')]),
 ('dependency_report',lua+[str(HERE/'test_dependency_report.lua'),str(module_dir)]),
 ('dependency_mutation_controls',[sys.executable,str(HERE/'run_dependency_controls.py'),'--module-dir',str(module_dir),'--output',str(out/'dependency_mutation_controls'),'--lua',lua[0]]+['--lua-arg='+value for value in lua[1:]]),
 ('main_config_scope',[sys.executable,str(HERE/'check_main_config_scope.py'),str(root)]),
 ('main_config_independent',[sys.executable,str(HERE/'run_main_config_independent.py'),'--release',str(root),'--output',str(out/'main_config_independent'),'--lua',lua[0]]+['--lua-arg='+value for value in lua[1:]]),
 ('readonly_readers',[sys.executable,str(HERE/'test_diagnostic_readers.py'),str(root),'--self-check']),
]
results=[]
with tempfile.TemporaryDirectory(prefix='nlsr-config-test-') as fixture:
    cases.insert(2,('config_recovery',lua+[str(HERE/'test_config_store.lua'),str(root),fixture]))
    cases.append(('profiles_disk',lua+[str(HERE/'test_profiles.lua'),str(module_dir),fixture,str(module_dir/'config_store.lua')]))
    cases.append(('profiles_disk_faults_independent',lua+[str(HERE/'review_profile_disk_failures.lua'),str(module_dir),str(module_dir/'config_store.lua'),fixture]))
    cases.append(('schema_recovery',lua+[str(HERE/'test_schema_recovery.lua'),str(module_dir),fixture]))
    cases.append(('main_config_recovery',lua+[str(HERE/'test_main_settings_recovery.lua'),str(root),fixture]))
    cases.append(('runtime_polish',lua+[str(HERE/'test_runtime_polish.lua'),str(root)]))
    for name,command in cases:
        result=subprocess.run(command,text=True,capture_output=True)
        (out/(name+'.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
        results.append({'check':name,'exit_code':result.returncode,'command':command,'log':name+'.log'})
        print(('PASS' if result.returncode==0 else 'FAIL')+' '+name)
summary={'scope':'Fresh offline actual-Lua and constrained REDscript-source boundary tests. No REDscript compiler, CET/game runtime, save creation, reload, or quest progression.','results':results,'passed':all(x['exit_code']==0 for x in results)}
(out/'RESULTS.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
sys.exit(0 if summary['passed'] else 1)
