from lua_test_host import lua_command
"""Execute the actual-module tests against isolated, deliberately broken runtimes.

A detected mutant is a nonzero assertion result, not proof of game behavior.
No user data, game APIs or external service is accessed by this test.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
validation = Path(__file__).resolve().parent
relative = Path('bin/x64/plugins/cyber_engine_tweaks/mods/NeverLockSavesReborn')
lua=lua_command()
mutants = [
    ('deadline_reintroduced', 'deferred_save.lua', "if retention~='session' then s.pending.expires", 'if true then s.pending.expires', 'test_combat_events.lua'),
    ('event_wake_lost', 'combat_events.lua', "self.dirty=true;self.stable=0;self.lastSample=nil;self.lastWake=reason", "self.dirty=false;self.stable=0;self.lastSample=nil;self.lastWake=reason", 'test_combat_events.lua'),
    ('foreign_session_allowed', 'combat_events.lua', 'or session~=self.session then', 'then', 'test_combat_events.lua'),
    ('death_detach_ignored', 'combat_events.lua', "if reason=='death' or reason=='detach' then", 'if false then', 'test_combat_events.lua'),
    ('cancelled_intent_resurrected', 'deferred_save.lua', ' and s.generation==generation then', ' then', 'test_combat_events.lua'),
    ('stabilization_skipped', 'combat_events.lua', 'self.stable+0.000001>=2.0', 'self.stable+0.000001>=0.0', 'test_combat_events.lua'),
    ('native_lock_ignored', 'init.lua', "elseif not unlocked then reason='Waiting: native save lock'", "elseif false then reason='Waiting: native save lock'", 'test_combat_events_integration.lua'),
    ('vehicle_exit_required', 'init.lua', "else nativeUnlocked=true;reason='Combat clear and native unlocked: stabilization'", "else nativeUnlocked=queuePlayer:NLSRebornMountedState()==0;reason='Combat clear and native unlocked: stabilization'", 'test_combat_events_integration.lua'),
]
# A control run proves the harness works before interpreting nonzero mutant results.
for test in {'test_combat_events.lua', 'test_combat_events_integration.lua'}:
    result = subprocess.run([*lua, str(validation/test), str(root)], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise SystemExit('BASELINE FAILED: '+test+'\n'+result.stdout+result.stderr)
for name, file, before, after, test in mutants:
    with tempfile.TemporaryDirectory(prefix='nlsr-event-mutant-') as tmp:
        isolated = Path(tmp)
        shutil.copytree(root/'bin', isolated/'bin')
        path = isolated/relative/file
        source = path.read_text()
        if source.count(before) != 1:
            raise SystemExit('Ambiguous mutation anchor: '+name)
        path.write_text(source.replace(before, after))
        result = subprocess.run([*lua, str(validation/test), str(isolated)], capture_output=True, text=True, timeout=30)
        text = result.stdout+result.stderr
        if result.returncode == 0:
            raise SystemExit('UNDETECTED: '+name)
        # A syntax/module-load failure would not establish the behavioral assertion.
        if 'syntax error' in text or 'unexpected symbol' in text or 'cannot open' in text:
            raise SystemExit('INVALID MUTANT: '+name+'\n'+text)
        print('DETECTED '+name+' | '+text.strip().splitlines()[0])
print('PASS 8/8 injected-negative event/retention controls detected')
