#!/usr/bin/env python3
"""Focused mutation controls against the final scheduler, in temporary files.

Each deliberately weakened guard must fail for its intended public invariant.
This does not exercise the game or create a save.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('module',type=Path)
p.add_argument('--lua',required=True)
p.add_argument('--lua-arg',action='append',default=[])
a=p.parse_args()
test=Path(__file__).parent/'test_autosave_policy.lua'
source=a.module.read_text()
controls=[
 ('master_off','if not state.options.enabled then','if false then','default off has no requests'),
 ('native_gate','if not snapshot.nativeUnlocked or not snapshot.stableReady then','if false then','quest event cannot bypass native gate'),
 ('player_queue','if snapshot.queueBusy or snapshot.phoneActive or snapshot.combatActive or snapshot.vehicleActive then','if snapshot.phoneActive or snapshot.combatActive or snapshot.vehicleActive then','interruption clears quest event'),
 ('stalled_frame','if not finite(delta) or delta<0 or delta>1 then','if not finite(delta) or delta<0 then','interruption clears quest event'),
 ('postcombat_edge','if combatEnded and state.options.postCombat then','if false then','captured event'),
 ('player_cooldown','if snapshot.queueBusy then state.cooldownRemaining=state.options.cooldownSeconds end','if false then state.cooldownRemaining=state.options.cooldownSeconds end','a user queue finishing cannot cause an immediate automatic request'),
 ('quest_optin','elseif state.options.questMilestone and snapshot.questMilestone==true then','elseif snapshot.questMilestone==true then','quest event default off'),
 ('quest_type','elseif state.options.questMilestone and snapshot.questMilestone==true then','elseif state.options.questMilestone and snapshot.questMilestone then','only literal true is a verified quest event'),
 ('queue_evidence',"'queue_request_accepted'","'request_submitted'",'expected queue_request_accepted, got request_submitted'),
]
results=[]
with tempfile.TemporaryDirectory(prefix='nlsr-scheduler-controls-') as tmp:
    for name,before,after,expected in controls:
        assert before in source,'Missing control seam: '+name
        target=Path(tmp)/(name+'.lua')
        target.write_text(source.replace(before,after))
        run=subprocess.run([a.lua,*a.lua_arg,str(test),str(target)],text=True,capture_output=True,timeout=30)
        detected=run.returncode!=0 and expected in run.stdout+run.stderr
        results.append({'control':name,'detected_for_intended_reason':detected,'exit_code':run.returncode})
print(json.dumps({'scope':'Final-source pure Lua public-invariant mutation controls; not game evidence','controls':results},indent=2))
raise SystemExit(0 if all(row['detected_for_intended_reason'] for row in results) else 1)
