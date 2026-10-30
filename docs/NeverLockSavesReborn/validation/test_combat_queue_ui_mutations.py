from lua_test_host import lua_command
#!/usr/bin/env python3
"""Negative controls: deliberate local source defects must fail the new suites."""
from pathlib import Path
import subprocess,sys,tempfile,json,shutil
root=Path(sys.argv[1]).resolve();here=Path(__file__).resolve().parent
reds=Path('r6/scripts/NeverLockSavesReborn/NeverLockSavesReborn.reds')
lua=Path('bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn')
original=(root/reds).read_text()
mutations={
 'combat_guard_removed':('&& !this.IsInCombat() &&','&& true &&'),
 'mounted_release_forbidden':('&& !this.IsInCombat() &&','&& !this.IsInCombat() && this.NLSRebornMountedState() == 0 &&'),
 'native_lock_guard_removed':('!GameInstance.IsSavingLocked(this.GetGame(), locks) && ArraySize(locks) == 0','true'),
 'duplicate_pending_clear_removed':('this.nlsDeferredPending = false; // clear before dispatch to prevent duplicates','// Deliberately broken negative control'),
 'native_false_treated_accepted':('if !autosave.RequestForcedCheckpoint() {','if autosave.RequestForcedCheckpoint() {'),
 'intro_guard_removed':('this.nlsRebornSafetyBlock || !this.NLSRebornDeferredIntroComplete()','this.nlsRebornSafetyBlock'),
}
results=[]
with tempfile.TemporaryDirectory(prefix='nlsr-negative-controls-')as temp:
 testroot=Path(temp);(testroot/reds).parent.mkdir(parents=True)
 for name,(before,after)in mutations.items():
  assert original.count(before)==1,(name,original.count(before))
  (testroot/reds).write_text(original.replace(before,after))
  r=subprocess.run([sys.executable,str(here/'test_combat_queue_ui_source.py'),str(testroot)],capture_output=True,text=True,timeout=30)
  # A failing requirement assertion, not merely a compiler/evaluator syntax error.
  try: report=json.loads(r.stdout);caught=r.returncode!=0 and bool(report['failures'])
  except (ValueError,KeyError):
   caught=False;print(name, r.stdout[-300:]+r.stderr[-1200:], file=sys.stderr)
  results.append({'mutation':name,'detected_by_assertions':caught,'exit_code':r.returncode})
 shutil.copytree(root/lua,testroot/lua)
 p=testroot/lua/'native_settings_ui.lua';s=p.read_text();before='if self.syncing or self.failed then return end';assert s.count(before)==1
 p.write_text(s.replace(before,'if self.failed then return end'))
 r=subprocess.run([*lua_command(),str(here/'test_organized_ui.lua'),str(testroot)],capture_output=True,text=True,timeout=30)
 results.append({'mutation':'native_reentrant_registration_guard_removed','detected_by_assertions':r.returncode!=0 and 'registration callbacks suppressed'in(r.stdout+r.stderr),'exit_code':r.returncode})
print(json.dumps({'passed':all(x['detected_by_assertions']for x in results),'controls':results},indent=2))
sys.exit(not all(x['detected_by_assertions']for x in results))
