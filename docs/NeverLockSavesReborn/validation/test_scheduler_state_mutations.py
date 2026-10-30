from lua_test_host import lua_command
#!/usr/bin/env python3
from pathlib import Path
import shutil,subprocess,sys,tempfile,json
root=Path(sys.argv[1]).resolve(); here=Path(__file__).resolve().parent
lua=root/'bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn'
controls=[]
with tempfile.TemporaryDirectory(prefix='nlsr-scheduler-state-neg-') as td:
    base=Path(td)
    # 1) Reintroduce per-frame blocker transitions.
    case=base/'thrash';[shutil.copytree(root/folder,case/folder) for folder in ('bin','r6')]
    p=case/lua.relative_to(root)/'autosave_policy.lua';s=p.read_text();needle='local changed=state.blockedReason~=why or (validSession and state.session~=session)'
    assert s.count(needle)==1
    p.write_text(s.replace(needle,'local changed=true'))
    r=subprocess.run([*lua_command(),str(here/'test_scheduler_state_fix.lua'),str(case)],capture_output=True,text=True,timeout=30)
    controls.append({'mutation':'per_frame_blocker_transition_restored','detected':r.returncode!=0,'exit_code':r.returncode})
    # 2) Collapse current queue state back into historical state.
    case=base/'queue_merge';[shutil.copytree(root/folder,case/folder) for folder in ('bin','r6')]
    p=case/lua.relative_to(root)/'support_report.lua';s=p.read_text();needle='current_state=member(queue.currentState,currentPhases)'
    assert s.count(needle)==1
    p.write_text(s.replace(needle,'current_state=member(queue.state,currentPhases)'))
    r=subprocess.run([*lua_command(),str(here/'test_scheduler_state_fix.lua'),str(case)],capture_output=True,text=True,timeout=30)
    controls.append({'mutation':'current_queue_merged_with_history','detected':r.returncode!=0,'exit_code':r.returncode})
print(json.dumps({'passed':all(x['detected'] for x in controls),'controls':controls},indent=2))
sys.exit(not all(x['detected'] for x in controls))
