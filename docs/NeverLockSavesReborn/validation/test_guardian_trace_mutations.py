from lua_test_host import lua_command
"""Negative controls against actual changed modules, not game simulation claims."""
from pathlib import Path
import sys,shutil,subprocess,tempfile
root=Path(sys.argv[1]).resolve();here=Path(__file__).resolve().parent
lua=lua_command()
rel=Path('bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn')
cases=[
 ('recursive_dispatch', 'deferred_save.lua', "  if s.dispatching then return 'waiting' end", '', 'test_guardian_trace.lua', 'nested dispatch must wait'),
 ('stuck_executing','guardian.lua', "return transition(record,'Waiting','native_permission_changed')", "return record.id", 'test_guardian_trace.lua', 'preflight refusal returns to Waiting'),
 ('uncorrelated_promoted','guardian.lua', "correlated=false,write_status='Unknown',reload_status='Unknown',", "correlated=true,write_status='Unknown',reload_status='Unknown',", 'test_guardian_trace.lua', 'success hint stays uncorrelated'),
 ('clock_regression','guardian.lua', "(lastClock~=nil and value<lastClock)", 'false', 'test_guardian_trace.lua', 'backwards clock is unknown'),
 ('host_preflight_not_recorded','init.lua', "                guardianCall('preflight_wait',session,deferredGameSerial)", '', 'test_guardian_trace_integration.lua', 'actual-init preflight refusal not stuck Executing'),
 ('generic_wait_reason','init.lua', "deferredOrigin=='preview' and 'preview' or deferredGate)", "deferredOrigin=='preview' and 'preview' or 'native_lock_or_unknown')", 'test_guardian_trace_integration.lua', 'actual-init specific Guardian combat wait'),
 ('unvalidated_age_export','support_report.lua', 'observed_age_seconds=integer(row.observed_age_seconds,0,2147483647)', 'observed_age_seconds=row.observed_age_seconds', 'test_guardian_trace.lua', 'untrusted age rejected'),
 ('lost_callback_session','guardian_bridge.lua', "invoke('hint',event.origin,event.success,event.session)", "invoke('hint',event.origin,event.success)", 'test_guardian_trace_integration.lua', 'existing hint transported with event session'),
]
for name,file,old,new,test,expected in cases:
 with tempfile.TemporaryDirectory(prefix='nlsr-negative-') as td:
  mutant=Path(td);shutil.copytree(root/'bin',mutant/'bin')
  p=mutant/rel/file;s=p.read_text();assert s.count(old)==1,(name,s.count(old));p.write_text(s.replace(old,new))
  run=subprocess.run([*lua,str(here/test),str(mutant)],capture_output=True,text=True,timeout=30)
  output=run.stdout+run.stderr
  assert run.returncode!=0 and expected in output,(name,'negative control was not rejected at the expected behavior',output[-1800:])
  print('DETECTED',name,'|',expected)
print('PASS 8/8 Guardian trace injected-negative controls; no runtime game evidence')
